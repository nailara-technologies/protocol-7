#!/usr/bin/perl
use v5.32;
use strict;
use English;
use warnings;

###                                                            ###
## login admission harness [ LOGIN-ADMISSION.md sections 2+3 ]  ##
###                                                            ###

##       exercises the real translated source of the admission              ##
##       modules [ plugin.web.auth.admit.*, web.cmd.auth-login,             ##
##       httpd.route.handler.web-login, httpd.handler.web-relay.login       ##
##       ] against an in-process %data / %code stub environment -- no       ##
##       live zenki, time is stubbed throughout [ settable $now ] :         ##
##                                                                          ##
##       - source key + prefix chain derivation                             ##
##       [ v4, v6, mapped, invalid ]                                        ##
##       - per-source limit : 5 free failures, doubling wait, 429           ##
##       with Retry-After, success resets                                   ##
##       - per-source queue cap 5 : only that source gets 429               ##
##       - fairness : 500-vs-1 [ the single request is checked next ]       ##
##       - prefix grouping : level-by-level turns                           ##
##       [ /16, /24, source ]                                               ##
##       - failure weighting + half-life decay                              ##
##       - heavy-hitter merge + unmerge by decay                            ##
##       - 429 at admission for a source that entered its wait while        ##
##       queued                                                             ##
##       - state save / load roundtrip [ shared web-auth store ]            ##
##       - the httpd relay : socket facts passed, 429 + Set-Cookie          ##
##       replies                                                            ##

use File::stat;    ## like bin/Protocol-7 : a plain stat in the modules   ##
## under test then returns an OBJECT and fails loudly  ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use List::Util                qw| max |;   ## base.format.multiline_command ##
use JSON::XS                  ();
use YAML::XS                  ();
use File::Path                ();

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;

##[ fake event objects ]######################################################

package FakeTimer {
    use strict;
    use English;

    sub new {
        my ( $class, $params ) = @ARG;
        return bless { 'params' => $params, 'active' => 1 }, $class;
    }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
    sub data      { shift->{'params'}{'data'} }
}

package FakeEvent {
    use strict;
    use English;

    sub new {
        my ( $class, $data ) = @ARG;
        return bless { 'data' => $data, 'active' => 1 }, $class;
    }
    sub w    {shift}               ## the watcher IS the event wrapper here ##
    sub data { shift->{'data'} }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
}

package FakeIOWatcher {
    use strict;
    use English;

    sub new    { bless { 'fd' => 42, 'active' => 1 }, shift }
    sub fd     { shift->{'fd'} }
    sub cancel { shift->{'active'} = 0; return }
}

package Event {    ## enough of Event for the httpd relay handler ##
    use strict;
    use English;

    sub io { my $class = shift; return FakeIOWatcher->new(@ARG) }
}

package main;

my $now = 1_000_000;    ## stub time [ seconds ], advanced per scenario ##

my $tmp_store = tempdir( CLEANUP => 1 );

my @log_calls;       ## every base.logs invocation [ level, rendered ]    ##
my @timer_calls;     ## event.add_timer invocations [ FakeTimer ]         ##
my %cmd_replies;     ## reply_id -> reply hash [ base.callback.cmd_reply ] ##
my @route_sends;     ## protocol-7.route-send params                      ##
my @verify_calls;    ## tokens passed to verify_session                   ##

## scripted token validity : token => session hashref ##
my %valid_tokens;
my $refuse_plaintext = FALSE;    ## scenario toggle for the httpd relays ##
my $secure_transport = TRUE;     ## web-relay routes : tls \ loopback    ##
my %destroy_ok;                  ## scripted logout results : token -> 1  ##
my @destroy_calls;               ## tokens passed to destroy_session      ##

my $me = getpwuid($EFFECTIVE_USER_ID) // qw| protocol-7 |;

%code = (
    'base.logs' => sub {
        my ( $level, $fmt, @args ) = @ARG;
        push @log_calls, [ $level, sprintf( $fmt, @args ) ];
        return TRUE;
    },
    'base.log'          => sub { return TRUE },
    'base.reverse-sort' => sub {
        my $hash = shift // {};
        return reverse sort keys %{$hash};
    },
    'base.caller'    => sub { return ('main') },
    'base.gen_id'    => sub { return 7 },
    'base.route.add' => sub {
        my $arg = shift;
        return {
            'source' => $arg->{'source'},
            'target' => { 'cmd_id' => 7 },
            'reply'  => $arg->{'reply'}
        };
    },
    'base.zenki.resolve_routing_sids' => sub {
        my ( $name, $undef, $sids ) = @ARG;
        return @{$sids};
    },
    'base.session.calc_cmd_stats' => sub { return TRUE },
    'base.s_warn'                 => sub {
        my ( $f, @a ) = @ARG;
        warn sprintf( $f, @a );
        return 0;
    },
    'base.str.eval_error'     => sub { return $EVAL_ERROR // '' },
    'base.time'               => sub { return $now },
    'base.perlmod.load'       => sub { require Socket; return TRUE },
    'base.callback.cmd_reply' => sub {
        my ( $reply_id, $reply ) = @ARG;
        $cmd_replies{$reply_id} = $reply;
        return TRUE;
    },
    'event.add_timer' => sub {
        my $timer = FakeTimer->new(shift);
        push @timer_calls, $timer;
        return $timer;
    },
    'plugin.web.auth.session.path'   => sub { return $tmp_store },
    'plugin.web.auth.store.group'    => sub { return getgrgid($EGID) // $me },
    'plugin.web.auth.verify_session' => sub {
        my $token = shift // '';
        push @verify_calls, $token;
        return $valid_tokens{$token};    ## undef when invalid ##
    },
    'file.make_path' => sub {
        my ( $path, $mode ) = @ARG;
        File::Path::make_path( $path, { 'mode' => $mode // 0700 } );
        return -d $path ? $path : undef;
    },
    'file.open' => sub {
        my ( $path, $enc, $mode, $create, $perm ) = @ARG;
        $perm //= 0664;
        if ( not -f $path ) {
            return undef if not $create;
            open( my $cfh, '>', $path ) or return undef;
            close($cfh);
            chmod( $perm, $path );
        }
        open( my $fh, ( $mode // '>' ), $path ) or return undef;
        binmode( $fh, $enc ) if length( $enc // '' );
        return $fh;
    },
    'format.yaml.load_file' => sub {
        my $file = shift;
        my $data = eval { YAML::XS::LoadFile($file) };
        return ( undef, $EVAL_ERROR ) if length $EVAL_ERROR;
        return ( $data, undef );
    },
    'plugin.web.auth.refuse_plaintext' => sub { return $refuse_plaintext },
    'plugin.web.auth.secure_transport' => sub { return $secure_transport },
    'plugin.web.auth.destroy_session'  => sub {
        my $token = shift // '';
        push @destroy_calls, $token;
        return $destroy_ok{$token} // FALSE;
    },
    'protocol-7.route-send' => sub {
        push @route_sends, shift;
        return TRUE;
    },
    'base.handler.read' => sub {return},
    'httpd.new_header'  => sub {
        my ( $code, $header ) = @ARG;
        my $str = "HTTP/1.1 $code TEST\r\n";
        $str .= "$ARG: $header->{$ARG}\r\n" for sort keys %{$header};
        return $str . "\r\n";
    },
    'httpd.send_error_page' => sub {
        my ( $sid, $code ) = @ARG;
        return "HTTP/1.1 $code TEST\r\n\r\n";
    },
);

$data{'system'}{'amos-zenka-user'}               = $me;
$data{'system'}{'zenka'}{'name'}                 = 'httpd';
$data{'system'}{'zenka'}{'verbosity'}{'console'} = 3;
$data{'system'}{'zenka'}{'verbosity'}{'buffer'}  = 3;
$data{'base'}{'session'}{'uname'}{'server'}      = 'server';
$data{'base'}{'session'}{'uname'}{'client'}      = 'client';

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

for my $module (
    qw|
    base.format.multiline_command
    base.protocol-7.command.send.local
    plugin.web.auth.admit.cfg
    plugin.web.auth.admit.source
    plugin.web.auth.admit.wait_until
    plugin.web.auth.admit.envelope_429
    plugin.web.auth.admit.check
    plugin.web.auth.admit.record
    plugin.web.auth.admit.select
    plugin.web.auth.admit.schedule
    plugin.web.auth.admit.state_load
    plugin.web.auth.admit.state_save
    plugin.web.auth.admit
    plugin.web.auth.admit.gate
    plugin.web.auth.admit.status
    plugin.web.auth.admit.logout
    plugin.web.auth.admit.bearer
    web.cmd.auth-login
    web.cmd.auth-status
    web.cmd.auth-logout
    web.cmd.auth-bearer
    httpd.route.handler.web-login
    httpd.route.handler.web-status
    httpd.route.handler.web-logout
    httpd.route.handler.web-relay
    httpd.handler.web-relay.login
    httpd.handler.web-relay.auth
    httpd.handler.web-relay.auth-check
    base.reply.mode_text
    |
) {
    compile_module($module);
}

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub reset_state {
    $data{'plugin.web.auth'} = {
        'admit' => {
            ## a booted zenka with an empty store : the lazy state_load     ##
            ## stays a no-op, so direct record() calls [ bypassing the      ##
            ## admission entry that would have loaded first ] cannot be     ##
            ## clobbered by a stale state file [ production order : load at ##
            ## first use, always before any record ]                        ##
            'state_loaded' => TRUE,
            'sources'      => {},
            'groups'       => {},
            'queue'        => [],
            'served'       => {},
            'merged'       => {},
            'fail_src'     => {},
        },
    };
    %cmd_replies      = ();
    @verify_calls     = ();
    @timer_calls      = ();
    %valid_tokens     = ();
    @destroy_calls    = ();
    %destroy_ok       = ();
    $secure_transport = TRUE;
    unlink "$tmp_store/admission/state.yaml";    ## persisted state too ##
    return;
}

my $next_reply_id = 1000;

## the route-send stub delivers ONLY what the wire carries : the call_args ##
## go through the REAL base.format.multiline_command                       ##
## [ or the single-line join ] and are parsed back with the receiver's     ##
## rules [ base.handler .command ] -- a fact passed as its own call_args   ##
## key would be SILENTLY DROPPED, exactly like on the live cube            ##
sub wire_deliver {
    my $send = shift;
    my $ca   = $send->{'call_args'} // {};
    my $call = {};
    if ( ref $ca->{'param'} eq 'HASH' or defined $ca->{'data'} ) {
        ## build the multi-line packet inline [ mirrors base.format        ##
        ## .multiline_command, which the p7 translator cannot compile here ##
        ## ] : ' key : value' header lines [ key width right-aligned ],    ##
        ## empty line, dot-stuffed LF-terminated body, '.' terminator --   ##
        ## then parse it back with the receiver's rules                    ##
        ## [ base.handler.command ]                                        ##
        my $param = $ca->{'param'} // {};
        my $maxw  = 0;
        for my $k ( keys %{$param} ) {
            my $l = length $k;
            $maxw = $l if $l > $maxw;
        }
        my @lines;
        for my $k ( reverse sort keys %{$param} ) {
            my $v = $param->{$k} // '';
            $v =~ s|[\r\n]+||g;    ## httpd strips these before send ##
            push @lines, sprintf ' %*s : %s', $maxw, $k, $v;
        }
        if ( defined $ca->{'data'} ) {
            my $body = $ca->{'data'};
            $body .= "\n"
                if index( $body, "\n", length($body) - 1 ) == -1;
            chomp $body;
            push @lines, q||;
            for my $line ( split m|\n|, $body, -1 ) {
                $line = ".$line" if $line =~ m|^\.+$|;    ## dot-stuff ##
                push @lines, $line;
            }
            push @lines, qw| . |;
        } else {
            push @lines, q||, qw| . |;
        }
        my $ph   = {};
        my $data = q||;
        my $mode = 'header';
        for my $line (@lines) {
            if ( $mode eq 'header' ) {
                $line =~ s{^[ \t]+|[ \t]+$}{}g;           ## receiver trims ##
                if ( $line =~ m|^[ \t]*$| ) { $mode = 'body'; next }
                my ( $k, $v ) = split m|[ \t]*[=:][ \t]*|, $line, 2;
                $ph->{$k} = $v // q||;
            } else {
                last if $line eq qw| . |;
                $line =~ s|^\.(\.+)$|$1|;    ## dot-stuffing removal ##
                $data .= "$line\n";
            }
        }
        $call->{'param'} = $ph;
        $call->{'data'}  = $data;
    } else {
        $call->{'args'} = $ca->{'args'} // '';
    }
    return $call;
}

sub wire_call {
    my ( $command, $call_args, $reply_id ) = @ARG;
    my $call = wire_deliver(
        { 'command' => $command, 'call_args' => $call_args } );
    $call->{'reply_id'} = $reply_id // 0;
    return $code{$command}->($call);
}

sub status_call {    ## one web.auth-status call as the wire delivers it ##
    my ( $reply_id, $peer, %facts ) = @ARG;
    return wire_call(
        qw| web.cmd.auth-status |,
        {   'param' => {
                'peer_addr' => $peer,
                'peer_tls'  => 1,
                %facts
            },
        },
        $reply_id
    );
}

sub logout_call {    ## one web.auth-logout call as the wire delivers it ##
    my ( $reply_id, $peer, %facts ) = @ARG;
    my $body = delete $facts{'body'} // q||;
    my $call_args
        = { 'param' => { 'peer_addr' => $peer, 'peer_tls' => 1, %facts } };
    $call_args->{'data'} = $body . "\n" if length $body;
    return wire_call( qw| web.cmd.auth-logout |, $call_args, $reply_id );
}

sub bearer_call {    ## one web.auth-bearer call as the wire delivers it ##
    my ( $reply_id, $peer, %facts ) = @ARG;
    return wire_call(
        qw| web.cmd.auth-bearer |,
        {   'param' => {
                'peer_addr' => $peer,
                'peer_tls'  => 1,
                %facts
            },
        },
        $reply_id
    );
}

sub login_call {    ## one web.auth-login call as the wire delivers it ##
    my ( $peer, $token ) = @ARG;
    my $reply_id = $next_reply_id++;
    my $reply    = wire_call(
        qw| plugin.web.auth.admit |,
        {   'param' => {
                'peer_addr'     => $peer,
                'peer_tls'      => 1,
                'auth_header'   => q||,
                'cookie_header' => q||,
            },
            'data' => sprintf( '{"token":"%s"}', $token ) . "\n",
        },
        $reply_id
    );
    return ( $reply_id, $reply );
}

sub tick {    ## fire one scheduler tick ##
    return $code{'plugin.web.auth.admit.schedule'}->( FakeEvent->new( {} ) );
}

sub admit_state { return $data{'plugin.web.auth'}{'admit'} //= {} }

sub decode_reply {
    my $reply_id = shift;
    my $reply    = $cmd_replies{$reply_id} // return {};
    return eval { JSON::XS::decode_json( $reply->{'data'} // '' ) } // {};
}

##[ 1 : source key + prefix chain derivation ]################################

say '1 : source key + prefix chain';

{
    my ( $src, $groups )
        = $code{'plugin.web.auth.admit.source'}->('192.0.2.42');
    ok( $src eq qw| v4/32:192.0.2.42 |, 'ipv4 source = the address' );
    ok(
        (           $groups->[0] eq qw| v4/24:192.0.2 |
                and $groups->[1] eq qw| v4/16:192.0 |
        ),
        'ipv4 groups /24 + /16'
    );

    ( $src, $groups )
        = $code{'plugin.web.auth.admit.source'}->('::FFFF:192.0.2.42');
    ok( $src eq qw| v4/32:192.0.2.42 |, 'v4-mapped v6 normalized' );

    ( $src, $groups )
        = $code{'plugin.web.auth.admit.source'}->('2001:db8:abcd:1234::1');
    ok( $src eq qw| v6/64:20010db8abcd1234 |, 'ipv6 source = the /64' );
    ok(
        (           $groups->[0] eq qw| v6/48:20010db8abcd |
                and $groups->[1] eq qw| v6/32:20010db8 |
        ),
        'ipv6 groups /48 + /32'
    );

    my ( $src2, undef )
        = $code{'plugin.web.auth.admit.source'}->('2001:db8:abcd:1234::9');
    ok( $src2 eq $src, 'same /64, different host part : same source' );

    ok( !defined(
            scalar $code{'plugin.web.auth.admit.source'}->('not-an-ip')
        ),
        'unparseable peer : undef'
    );
    ok( !defined( scalar $code{'plugin.web.auth.admit.source'}->('') ),
        'empty peer : undef' );
}

##[ 2 : per-source limit ]####################################################

say '2 : per-source limit [ 5 free, doubling wait, 429, success resets ]';

reset_state();
{
    my $peer = '203.0.113.7';

    ## five failures are free : all deferred + checked ##
    for my $n ( 1 .. 5 ) {
        my ( $rid, $reply ) = login_call( $peer, "bad$n" );
        ok( ( $reply->{'mode'} // '' ) eq qw| deferred |,
            "failure $n : held for the queue [ no wait yet ]"
        );
        tick();
        ok( decode_reply($rid)->{'status'} == 401,
            "failure $n : checked [ 401 ]"
        );
    }

    ## the 6th failure starts the wait [ 1 s ] ##
    my ( $rid6, undef ) = login_call( $peer, 'bad6' );
    tick();
    ok( decode_reply($rid6)->{'status'} == 401, '6th failure : checked' );

    ## inside the wait : immediate 429, no check ##
    my $verify_before = scalar @verify_calls;
    my ( $rid7, $reply7 ) = login_call( $peer, 'bad7' );
    ok( ( $reply7->{'mode'} // '' ) eq qw| size |,
        'in wait : immediate reply [ not held ]'
    );
    my $env7 = eval { JSON::XS::decode_json( $reply7->{'data'} ) } // {};
    ok( $env7->{'status'} == 429,               'in wait : 429' );
    ok( ( $env7->{'retry_after'} // 0 ) == 1,   'Retry-After 1 s' );
    ok( scalar @verify_calls == $verify_before, 'in wait : no check ran' );

    ## after the wait : checked again ; failure 7 -> 2 s wait ##
    $now += 2;
    my ( $rid8, $reply8 ) = login_call( $peer, 'bad8' );
    ok( ( $reply8->{'mode'} // '' ) eq qw| deferred |,
        'wait over : admitted to the queue'
    );
    tick();
    ( undef, my $reply9 ) = login_call( $peer, 'bad9' );
    my $env9 = eval { JSON::XS::decode_json( $reply9->{'data'} ) } // {};
    ok( ( $env9->{'status'} == 429 and ( $env9->{'retry_after'} // 0 ) == 2 ),
        'failure 7 : wait doubled to 2 s'
    );

    ## wait cap : many failures -> 3600 s ##
    my $src_state = admit_state->{'sources'}{'v4/32:203.0.113.7'};
    $src_state->{'fails'}{'login'}     = 30;
    $src_state->{'last_fail'}{'login'} = $now;
    my $until = $code{ 'plugin.web.auth.' . 'admit.wait_until' }
        ->( $src_state, qw| login |, $now );
    ok( $until - $now == 3600, 'wait capped at 1 h' );

    ## a success resets the source ##
    $valid_tokens{'good-token'} = {
        'token_hash'       => 'TH7',
        'user_id'          => 'tester',
        'node_id'          => 'nailara',
        'expires_at_epoch' => $now + 3600,
    };
    $src_state->{'fails'}{'login'}     = 6;
    $src_state->{'last_fail'}{'login'} = $now - 10;    ## wait long over ##
    my ( $rid10, $reply10 ) = login_call( $peer, 'good-token' );
    ok( ( $reply10->{'mode'} // '' ) eq qw| deferred |,
        'wait over : success path queued' );
    tick();
    my $env10 = decode_reply($rid10);
    ok( $env10->{'status'} == 200, 'valid token : 200' );
    ok( ( $env10->{'set_cookie'} // '' ) =~ m|p7_session=good-token|,
        '200 : session cookie set' );
    ok( ( $env10->{'set_cookie'} // '' ) =~ m|; Secure$|,
        'tls peer : cookie Secure' );
    ok( ( $src_state->{'fails'}{'login'} // -1 ) == 0,
        'success : failures ' . 'reset' );
    ok( ( $src_state->{'ok_epoch'} // 0 ) == $now, 'success : source known' );
}

##[ 3 : per-source queue cap ]################################################

say '3 : per-source queue cap [ 5 ] : only that source gets 429';

reset_state();
{
    my @held;
    for my $n ( 1 .. 5 ) {
        my ( $rid, $reply ) = login_call( '198.51.100.1', "x$n" );
        push @held, $reply->{'mode'} // '';
    }
    my ( undef, $reply6 ) = login_call( '198.51.100.1', 'x6' );
    ok( ( scalar grep { $ARG eq qw| deferred | } @held ) == 5,
        '5 waiting requests held' );
    my $env6 = eval { JSON::XS::decode_json( $reply6->{'data'} ) } // {};
    ok( $env6->{'status'} == 429,       '6th of the same source : 429' );
    ok( defined $env6->{'retry_after'}, '429 carries Retry-After' );

    ## another source is not touched by it ##
    my ( undef, $reply_b ) = login_call( '203.0.113.9', 'y1' );
    ok( ( $reply_b->{'mode'} // '' ) eq qw| deferred |,
        'another source still queued, not refused'
    );
}

##[ 4 : fairness -- the 500-vs-1 case ]#######################################

say '4 : fairness : a source with a full queue never blocks a fresh one';

reset_state();
{
    my @order;    ## admitted sources, per tick ##
    my %src_of;
    for my $n ( 1 .. 5 ) {
        my ( $rid, undef ) = login_call( '198.51.100.1', "a$n" );
        $src_of{$rid} = 'A';
    }
    my ( $rid_b, undef ) = login_call( '203.0.113.9', 'b1' );
    $src_of{$rid_b} = 'B';

    for ( 1 .. 6 ) {
        tick();
        for my $rid ( keys %cmd_replies ) {
            push @order, $src_of{$rid} if delete $cmd_replies{$rid};
        }
    }
    ## B is admitted second -- not after A's whole queue ##
    ok( join( '', @order ) eq 'ABAAAA',
        "order @order : B second [ one request per group per turn ]" );
}

##[ 5 : prefix grouping -- level-by-level turns ]#############################

say '5 : prefix grouping : top prefix, then subnet, then source';

reset_state();
{
    ## distinct enqueue times : longest-wait is the observable tie-break ##
    my %src_of;
    my ( $rid_a1, undef ) = login_call( '203.0.113.1', 'a1' );
    $src_of{$rid_a1} = 'A1';    ## 203.0.113/24 , /16 203.0 ##
    $now += 1;
    my ( $rid_a2, undef ) = login_call( '203.0.113.2', 'a2' );
    $src_of{$rid_a2} = 'A2';    ## same /24 as A1 ##
    $now += 1;
    my ( $rid_b, undef ) = login_call( '198.51.100.1', 'b1' );
    $src_of{$rid_b} = 'B';      ## another /16 ##
    $now += 1;
    my ( $rid_c1, undef ) = login_call( '203.0.114.1', 'c1' );
    $src_of{$rid_c1} = 'C1';    ## same /16, another /24 ##

    my @order;
    for ( 1 .. 4 ) {
        tick();
        for my $rid ( keys %cmd_replies ) {
            push @order, $src_of{$rid} if delete $cmd_replies{$rid};
        }
    }
    ok( join( '', @order ) eq 'A1BC1A2',
        "order @order : other /16, other /24, then same /24" );
}

##[ 6 : failure weight sinks a group, decay lifts it ]########################

say '6 : failure weighting + half-life decay';

reset_state();
{
    ## F has failed [ weight 1.0, just now ] ; G is fresh ##
    $code{'plugin.web.auth.admit.record'}->(
        'failure', qw| login |, 'v4/32:203.0.113.7',
        [ 'v4/24:203.0.113', 'v4/16:203.0' ]
    );

    my %src_of;
    my ( $rid_f, undef ) = login_call( '203.0.113.7', 'f1' );
    $src_of{$rid_f} = 'F';
    my ( $rid_g, undef ) = login_call( '203.0.113.8', 'g1' );
    $src_of{$rid_g} = 'G';    ## same /24, no failures ##

    my @order;
    for ( 1 .. 2 ) {
        tick();
        for my $rid ( keys %cmd_replies ) {
            push @order, $src_of{$rid} if delete $cmd_replies{$rid};
        }
    }
    ok( join( '', @order ) eq 'GF',
        "order @order : the failed source sinks behind a fresh one" );

    ## decay : after one half-life the weight halves [ measured by a fresh ##
    ## failure touching the same nodes after the time advance ]            ##
    reset_state();
    $code{'plugin.web.auth.admit.record'}->(
        'failure', qw| login |, 'v4/32:203.0.113.7',
        [ 'v4/24:203.0.113', 'v4/16:203.0' ]
    );
    $now += 7200;    ## one half-life ##
    $code{'plugin.web.auth.admit.record'}->(
        'failure', qw| login |, 'v4/32:203.0.113.7',
        [ 'v4/24:203.0.113', 'v4/16:203.0' ]
    );
    my $w0    = admit_state->{'sources'}{'v4/32:203.0.113.7'}{'weight'};
    my $mid_w = admit_state->{'groups'}{'v4/24:203.0.113'}{'weight'};
    ok( ( abs( $w0 - 1.5 ) < 0.001 ),
        "source weight : 1.0 decayed to 0.5 + 1.0 new [ $w0 ]" );
    ok( ( abs( $mid_w - 0.375 ) < 0.001 ),
        "mid group weight : 0.25 decayed to 0.125 + 0.25 new [ $mid_w ]" );
    my $cfg = $code{'plugin.web.auth.admit.cfg'}->();
    ok( $cfg->{'half_life'} == 7200, 'half-life = 2 h' );
}

##[ 7 : heavy-hitter merge + unmerge ]########################################

say '7 : merge when conspicuous, unmerge by decay';

reset_state();
{
    my $mid = 'v4/24:203.0.113';
    ## nine distinct failing sources under one /24 -> merged [ nine so the ##
    ## merge survives the success below removing one from the view ]       ##
    for my $n ( 1 .. 9 ) {
        $code{'plugin.web.auth.admit.record'}->(
            'failure', qw| login |, "v4/32:203.0.113.$n",
            [ $mid, 'v4/16:203.0' ]
        );
    }
    ok( admit_state->{'merged'}{$mid}, '9 failing sources : prefix merged' );

    ## inside the bucket : a known source wins every turn   ##
    ## [ no per-source round-robin inside a merged prefix ] ##
    $code{'plugin.web.auth.admit.record'}->(
        'success', qw| login |, 'v4/32:203.0.113.42', [ $mid, 'v4/16:203.0' ]
    );
    my %src_of;
    my ( $rid_k1, undef ) = login_call( '203.0.113.42', 'k1' );
    $src_of{$rid_k1} = 'K1';
    ## a never-failed source : out of any wait, joins the queue ##
    my ( $rid_f, undef ) = login_call( '203.0.113.9', 'f1' );
    $src_of{$rid_f} = 'F';
    my ( $rid_k2, undef ) = login_call( '203.0.113.42', 'k2' );
    $src_of{$rid_k2} = 'K2';

    my @order;
    for ( 1 .. 3 ) {
        tick();
        for my $rid ( keys %cmd_replies ) {
            push @order, $src_of{$rid} if delete $cmd_replies{$rid};
        }
    }
    ok( join( '', @order ) eq 'K1K2F',
        "order @order : merged bucket, known source wins every turn" );

    ## decay below the epsilon unmerges ##
    $now += 7200 * 12;    ## 12 half-lives : weight ~ 2^-12 < 0.05 ##
    my ( $rid_x, undef ) = login_call( '203.0.113.1', 'x1' );
    tick();
    ok( !defined( admit_state->{'merged'}{$mid} ),
        'decayed below epsilon : prefix unmerged'
    );
}

##[ 8 : 429 at admission when the wait began while queued ]###################

say '8 : source enters its wait while queued : 429, no check';

reset_state();
{
    my ( $rid, undef ) = login_call( '203.0.113.7', 'q1' );
    my $src_state = admit_state->{'sources'}{'v4/32:203.0.113.7'} //= {};
    $src_state->{'fails'}{'login'}     = 6;
    $src_state->{'last_fail'}{'login'} = $now;
    my $verify_before = scalar @verify_calls;
    tick();
    my $env = decode_reply($rid);
    ok( $env->{'status'} == 429,                'queued entry answered 429' );
    ok( scalar @verify_calls == $verify_before, 'no check ran' );
}

##[ 9 : state save / load roundtrip ]#########################################

say '9 : state survives a restart [ shared web-auth store ]';

reset_state();
{
    $code{'plugin.web.auth.admit.record'}->(
        'failure', qw| login |, 'v4/32:203.0.113.7',
        [ 'v4/24:203.0.113', 'v4/16:203.0' ]
    );
    $code{'plugin.web.auth.admit.record'}->(
        'success', qw| login |, 'v4/32:198.51.100.1',
        [ 'v4/24:198.51.100', 'v4/16:198.51' ]
    );
    ## failure was throttled, success forced : both on disk ##
    $code{'plugin.web.auth.admit.state_save'}->(TRUE);

    my $file = "$tmp_store/admission/state.yaml";
    ok( -f $file, 'state file written' );
    my $mode = ( CORE::stat $file )[2] & 07777;
    ok( $mode == 0660, sprintf 'state file mode %04o', $mode );

    $data{'plugin.web.auth'} = {};    ## the restart ##
    $code{'plugin.web.auth.admit.state_load'}->();
    my $s = admit_state->{'sources'}{'v4/32:203.0.113.7'};
    ok( ( $s->{'fails'}{'login'} // 0 ) == 1, 'failure count survived' );
    ok( ( admit_state->{'sources'}{'v4/32:198.51.100.1'}{'ok_epoch'} // 0 )
            == $now,
        'known source survived'
    );
    ok( ( admit_state->{'groups'}{'v4/24:198.51.100'}{'ok_epoch'} // 0 )
            == $now,
        'known prefix survived'
    );
}

##[ 10 : the httpd relay -- socket facts + reply rendering ]##################

say '10 : httpd relay : real socket facts out, http answer rendered';

reset_state();
{
    ## the route handler passes real socket facts, never a header ##
    $data{'session'}{77} = {
        'buffer' => { 'input' => '{"token":"abc"}', 'output' => '' },
        'http'   => {
            'request' => {
                'headers' => { 'authorization' => q||, 'cookie' => q|| },
                'client'  => { 'addr'          => '198.51.100.7' },
            },
        },
        'handle'  => bless( {}, 'FakeSock' ),    ## not IO::Socket::SSL ##
        'watcher' => { 'input_handler' => FakeIOWatcher->new() },
    };
    my $ret = $code{'httpd.route.handler.web-login'}->( 77, {} );
    ok( $ret == 0, 'route handler : deferred' );
    my $sent = $route_sends[-1] // {};
    ok( ( $sent->{'command'} // '' ) eq qw| web.auth-login |,
        'relayed to web.auth-login' );
    ## the wire carries ONLY what send.local frames : the facts must arrive ##
    ## as param lines, the body as data [ wire_deliver mirrors the real     ##
    ## sender + receiver -- the scenario fails if the handler still puts    ##
    ## them anywhere else ]                                                 ##
    my $delivered = wire_deliver($sent);
    ok( ( $delivered->{'param'}{'peer_addr'} // '' ) eq '198.51.100.7',
        'real socket peer arrived as a param line' );
    ok( ( $delivered->{'param'}{'peer_tls'} // -1 ) == 0,
        'plain socket : tls flag 0' );
    ok( ( $delivered->{'data'} // '' ) eq "{\"token\":\"abc\"}\n",
        'body arrived as data' );

    ## plaintext refusal stays first ##
    $refuse_plaintext = TRUE;
    my @before = @route_sends;
    my $ret2   = $code{'httpd.route.handler.web-login'}->( 77, {} );
    ok( ( $ret2 == 2 and @route_sends == @before ),
        'plaintext refused first : no relay'
    );
    $refuse_plaintext = FALSE;

    ## the reply handler renders the envelope ##
    my $env = JSON::XS::encode_json(
        {   'status'      => 429,
            'retry_after' => 17,
            'body'        => '{"ok":false}',
        }
    );
    $data{'session'}{88} = { 'buffer' => { 'output' => q|| } };
    $code{'httpd.handler.web-relay.login'}->(
        {   'cmd'    => 'SIZE',
            'data'   => \$env,
            'params' => { 'http_sid' => 88 },
        }
    );
    my $out = $data{'session'}{88}{'buffer'}{'output'};
    ok( $out =~ m|^HTTP/1\.1 429 |,        '429 status line' );
    ok( $out =~ m{^Retry-After: 17\x0d$}m, 'Retry-After header' );
    ok( $out =~ m|\{"ok":false\}|,         'body rendered' );
    ok( $data{'session'}{88}{'flush_shutdown'}, 'flush_shutdown set' );

    ## a SIZE-less FALSE reply : 502 ##
    $data{'session'}{89} = { 'buffer' => { 'output' => q|| } };
    $code{'httpd.handler.web-relay.login'}->(
        {   'cmd'       => 'FALSE',
            'call_args' => { 'args'     => 'nope' },
            'params'    => { 'http_sid' => 89 },
        }
    );
    ok( $data{'session'}{89}{'buffer'}{'output'} =~ m|^HTTP/1\.1 502 |,
        'FALSE reply : 502' );
}

##[ 11 : web.cmd.auth-login goes through admission ]##########################

say '11 : web.cmd.auth-login wrapper';

reset_state();
{
    my $reply = wire_call(
        qw| web.cmd.auth-login |,
        {   'param' => {
                'peer_addr' => '203.0.113.55',
                'peer_tls'  => 1,
            },
            'data' => '{"token":"w1"}',
        },
        4242
    );
    ok( ( $reply->{'mode'} // '' ) eq qw| deferred |,
        'wrapper queues through admission'
    );
    tick();
    ok( decode_reply(4242)->{'status'} == 401, 'wrapper : checked' );

    ## local call without socket facts : immediate ##
    $valid_tokens{'local-good'} = {
        'token_hash'       => 'TH9',
        'user_id'          => 'u',
        'node_id'          => 'n',
        'expires_at_epoch' => $now + 60,
    };
    my $local = $code{'web.cmd.auth-login'}
        ->( { 'reply_id' => 4243, 'args' => '{"token":"local-good"}' } );
    ok( ( $local->{'mode'} // '' ) eq qw| size |,
        'local call : immediate reply' );
    my $env = eval { JSON::XS::decode_json( $local->{'data'} ) } // {};
    ok( ( $env->{'status'} // 0 ) == 200, 'local valid token : 200' );
    ok( ( $env->{'set_cookie'} // '' ) !~ m|Secure|,
        'no tls fact : cookie not Secure'
    );
}

##[ done ]####################################################################

##[ 12 : /auth/status through the gate -- recorded, gated, never queued ]#####

say '12 : status path : guesses recorded, wait gated, no queue';

reset_state();
{
    my $peer = '203.0.113.20';

    ## no token at all : 401, nothing recorded ##
    my $r   = status_call( 5001, $peer, );
    my $env = eval { JSON::XS::decode_json( $r->{'data'} ) } // {};
    ok( ( $env->{'status'} // 0 ) == 401,              'no token : 401' );
    ok( ( $env->{'body'}   // '' ) =~ m|unauthorized|, 'no token : body' );
    ok( !defined( admit_state->{'sources'}{'v4/32:203.0.113.20'} ),
        'no token : nothing recorded' );

    ## six presented-but-invalid cookies are checked and recorded ##
    ## [ the 6th is checked : its failure OPENS the wait ]        ##
    for my $n ( 1 .. 6 ) {
        my $rr = status_call( 5010 + $n, $peer,
            cookie_header => "other=1; p7_session=guess$n", );
        my $ee = eval { JSON::XS::decode_json( $rr->{'data'} ) } // {};
        ok( ( $ee->{'status'} // 0 ) == 401,
            "bad cookie $n : checked [ 401, recorded ]" );
    }

    ## the wait is open now : the 7th is gated, no check ##
    my $verify_before = scalar @verify_calls;
    my $r7
        = status_call( 5017, $peer, cookie_header => "p7_session=guess7", );
    my $e7 = eval { JSON::XS::decode_json( $r7->{'data'} ) } // {};
    ok( ( $e7->{'status'} // 0 ) == 429,    'in wait : status answers 429' );
    ok( ( $e7->{'retry_after'} // 0 ) == 1, 'status 429 : Retry-After 1 s' );
    ok( scalar @verify_calls == $verify_before, 'status 429 : no check ran' );

    ## every answer was immediate : the login scheduler stayed out      ##
    ## [ the state_save catch-up timer is a different, legitimate one ] ##
    ok(
        (   scalar grep {
                $ARG->{'params'}{'desc'} eq
                    'web-auth login admission scheduler'
            } @timer_calls
        ) == 0,
        'status path : no admission scheduler timer'
    );

    ## a valid cookie answers 200 + session info, resets the counter ##
    $now += 2;
    $valid_tokens{'live-cookie'} = {
        'user_id'    => 'u12',
        'node_id'    => 'n12',
        'created_at' => 'c12',
        'last_seen'  => 'l12',
    };
    my $rv = status_call( 5018, $peer,
        cookie_header => "p7_session=live-cookie", );
    my $ev = eval { JSON::XS::decode_json( $rv->{'data'} ) } // {};
    ok( ( $ev->{'status'} // 0 ) == 200, 'valid cookie : 200' );
    ok( ( $ev->{'body'}   // '' ) =~ m|"user_id":"u12"|,
        '200 : session info answered' );
    ok(
        (   admit_state->{'sources'}{'v4/32:203.0.113.20'}{'fails'}{'status'}
                // -1
        ) == 0,
        'valid cookie : status counter reset'
    );
}

##[ 13 : /auth/logout through the gate -- the wait precedes the destroy ]#####

say '13 : logout path : guesses recorded, wait precedes the destroy';

reset_state();
{
    my $peer = '203.0.113.21';

    ## no token at all : 400, nothing recorded ##
    my $r   = logout_call( 5101, $peer, body => "{}" );
    my $env = eval { JSON::XS::decode_json( $r->{'data'} ) } // {};
    ok( ( $env->{'status'} // 0 ) == 400, 'no token : 400' );
    ok( !defined( admit_state->{'sources'}{'v4/32:203.0.113.21'} ),
        'no token : nothing recorded' );

    ## six bad tokens checked + recorded -> the source waits now ##
    for my $n ( 1 .. 6 ) {
        logout_call( 5110 + $n, $peer, body => "{\"token\":\"bye$n\"}" );
    }
    my $destroy_before = scalar @destroy_calls;
    my $r7 = logout_call( 5117, $peer, body => "{\"token\":\"bye7\"}" );
    my $e7 = eval { JSON::XS::decode_json( $r7->{'data'} ) } // {};
    ok( ( $e7->{'status'} // 0 ) == 429, 'in wait : logout answers 429' );
    ok( scalar @destroy_calls == $destroy_before,
        'in wait : the session is NOT destroyed'
    );

    ## a valid token destroys the session + clears the cookie ##
    $now += 2;
    $destroy_ok{'good-bye'} = TRUE;
    my $rv = logout_call( 5118, $peer, body => "{\"token\":\"good-bye\"}" );
    my $ev = eval { JSON::XS::decode_json( $rv->{'data'} ) } // {};
    ok( ( $ev->{'status'}     // 0 ) == 200, 'valid token : 200' );
    ok( ( $ev->{'set_cookie'} // '' ) =~ m|p7_session=; Max-Age=0|,
        '200 : cookie cleared' );
    ok( ( $ev->{'set_cookie'} // '' ) =~ m|; Secure$|,
        'tls peer : clear-cookie Secure' );
    ok(
        (   admit_state->{'sources'}{'v4/32:203.0.113.21'}{'fails'}{'logout'}
                // -1
        ) == 0,
        'valid token : logout counter reset'
    );
}

##[ 14 : bearer guesses through the gate [ the scan-through-/jobs.json case ] ]#

say '14 : bearer path : Authorization guesses recorded and gated';

reset_state();
{
    my $peer = '203.0.113.22';

    for my $n ( 1 .. 6 ) {
        my $rr
            = bearer_call( 5200 + $n, $peer, auth_header => "Bearer scan$n",
            );
        my $ee = eval { JSON::XS::decode_json( $rr->{'data'} ) } // {};
        ok( ( $ee->{'status'} // 0 ) == 401,
            "bad bearer $n : checked [ 401, recorded ]" );
    }

    my $verify_before = scalar @verify_calls;
    my $r7 = bearer_call( 5207, $peer, auth_header => "Bearer scan7", );
    my $e7 = eval { JSON::XS::decode_json( $r7->{'data'} ) } // {};
    ok( ( $e7->{'status'} // 0 ) == 429, 'in wait : bearer answers 429' );
    ok( scalar @verify_calls == $verify_before, 'bearer 429 : no check ran' );

    ## a valid token answers 200 and the counter resets ##
    $now += 2;
    $valid_tokens{'good-bearer'} = { 'user_id' => 'u14', 'node_id' => 'n14' };
    my $rv = bearer_call( 5208, $peer, auth_header => "Bearer good-bearer", );
    my $ev = eval { JSON::XS::decode_json( $rv->{'data'} ) } // {};
    ok( ( $ev->{'status'} // 0 ) == 200, 'valid bearer : 200' );
    ok(
        (   admit_state->{'sources'}{'v4/32:203.0.113.22'}{'fails'}{'bearer'}
                // -1
        ) == 0,
        'valid bearer : bearer counter reset'
    );
}

##[ 15 : interleave defense -- a success cannot launder another path ]########

say '15 : per-path counters : a success resets only its own path';

reset_state();
{
    my $peer = '203.0.113.23';

    ## five status failures -- a 6th would be checked, a 7th gated ##
    for my $n ( 1 .. 5 ) {
        status_call( 5300 + $n, $peer, cookie_header => "p7_session=s$n", );
    }

    ## a valid bearer token succeeds : it must NOT clear the status ##
    ## failures [ nor the login failures ]                          ##
    $valid_tokens{'vip'} = { 'user_id' => 'u15', 'node_id' => 'n15' };
    my $rb = bearer_call( 5306, $peer, auth_header => "Bearer vip", );
    my $eb = eval { JSON::XS::decode_json( $rb->{'data'} ) } // {};
    ok( ( $eb->{'status'} // 0 ) == 200, 'valid bearer : 200' );

    ## the 6th status failure is still CHECKED [ status count is 5 ] : then ##
    ## the 7th is gated -- proof the bearer success did not reset the       ##
    ## status counter                                                       ##
    my $r6 = status_call( 5307, $peer, cookie_header => "p7_session=s6", );
    my $e6 = eval { JSON::XS::decode_json( $r6->{'data'} ) } // {};
    ok( ( $e6->{'status'} // 0 ) == 401,
        '6th status failure ' . ': still checked' );

    my $r7 = status_call( 5308, $peer, cookie_header => "p7_session=s7", );
    my $e7 = eval { JSON::XS::decode_json( $r7->{'data'} ) } // {};
    ok( ( $e7->{'status'} // 0 ) == 429,
        '7th status guess : gated -- the bearer success did not reset it' );

    ## and a success on the status path DOES clear the status wait ##
    $now += 2;
    my $rs = status_call( 5309, $peer, cookie_header => "p7_session=vip", );
    my $es = eval { JSON::XS::decode_json( $rs->{'data'} ) } // {};
    ok( ( $es->{'status'} // 0 ) == 200,
        'valid cookie after the wait : 200' );
}

##[ 16 : the protected-route relay : gate first, original relay on 200 ]######

say '16 : web-relay : bearer gate first, original relay only when admitted';

reset_state();
{
    my $relay_args = {
        'command'              => 'web.jobs-data',
        'auth.required'        => 1,
        'auth.exempt-loopback' => 1,
    };
    my $mk_session = sub {
        my ( $sid, %hdr ) = @ARG;
        $data{'session'}{$sid} = {
            'buffer' => { 'input' => q||, 'output' => q|| },
            'http'   => {
                'body'    => q||,
                'request' => {
                    'uri'     => '/jobs.json',
                    'headers' => \%hdr,
                    'client'  => { 'addr' => '198.51.100.7' },
                },
            },
            'handle'  => bless( {}, 'FakeSock' ),
            'watcher' => { 'input_handler' => FakeIOWatcher->new() },
        };
        return;
    };

    ## no token presented : local 401, web never asked ##
    $mk_session->(60);
    my @sends_before = @route_sends;
    my $ret = $code{'httpd.route.handler.web-relay'}->( 60, $relay_args );
    ok( ( $ret =~ m|^HTTP/1\.1 401 | ), 'no token : immediate 401' );
    ok( ( scalar @route_sends == scalar @sends_before ),
        'no token : no relay to web' );

    ## plaintext : secure_transport refuses first, no relay at all ##
    $secure_transport = FALSE;
    $mk_session->( 61, 'authorization' => 'Bearer abc' );
    @sends_before = @route_sends;
    my $ret61 = $code{'httpd.route.handler.web-relay'}->( 61, $relay_args );
    ok( ( $ret61 =~ m|^HTTP/1\.1 403 | ),
        'plain http : secure_transport refuses first' );
    ok( ( scalar @route_sends == scalar @sends_before ),
        'plain http : no relay' );
    $secure_transport = TRUE;

    ## a presented token asks web first [ real socket facts in the call ] ##
    $mk_session->( 62, 'authorization' => 'Bearer abc' );
    my $ret62 = $code{'httpd.route.handler.web-relay'}->( 62, $relay_args );
    ok( $ret62 == 0, 'token presented : deferred to the gate' );
    my $sent = $route_sends[-1] // {};
    ok( ( $sent->{'command'} // '' ) eq qw| web.auth-bearer |,
        'relayed to web.auth-bearer' );
    ## the socket facts survive the wire as param lines ##
    my $delivered = wire_deliver($sent);
    ok( ( $delivered->{'param'}{'peer_addr'} // '' ) eq '198.51.100.7',
        'real socket peer arrived as a param line' );

    ## a 429 envelope answers at once : no original relay ##
    my $relay_params = $sent->{'reply'}{'params'} // {};
    my $env429       = JSON::XS::encode_json(
        {   'status'      => 429,
            'retry_after' => 9,
            'body'        => '{"ok":false}',
        }
    );
    my $sends_at_gate = scalar @route_sends;
    $data{'session'}{63} = { 'buffer' => { 'output' => q|| } };
    $relay_params->{'http_sid'} = 63;
    $code{'httpd.handler.web-relay.auth-check'}->(
        {   'cmd'    => 'SIZE',
            'data'   => \$env429,
            'params' => $relay_params,
        }
    );
    my $out63 = $data{'session'}{63}{'buffer'}{'output'};
    ok( $out63 =~ m|^HTTP/1\.1 429 |,       'gate 429 : status line' );
    ok( $out63 =~ m{^Retry-After: 9\x0d$}m, 'gate 429 : Retry-After' );
    ok( ( scalar @route_sends == $sends_at_gate ),
        'gate 429 : original relay NOT fired'
    );

    ## a 200 envelope fires the original relay with the stored spec ##
    my $env200 = JSON::XS::encode_json(
        {   'status' => 200,
            'body'   => '{"ok":true}',
        }
    );
    $code{'httpd.handler.web-relay.auth-check'}->(
        {   'cmd'    => 'SIZE',
            'data'   => \$env200,
            'params' => $relay_params,
        }
    );
    my $orig = $route_sends[-1] // {};
    ok( ( $orig->{'command'} // '' ) eq qw| web.jobs-data |,
        'gate 200 : original relay fired' );
    ok( ( $orig->{'reply'}{'handler'} // '' ) eq
            qw| httpd.handler.web-relay.strm_open |,
        'gate 200 : original reply handler kept'
    );

    ## loopback peers stay exempt : direct relay, no gate ##
    $mk_session->( 64, q||, q|| );
    $data{'session'}{64}{'http'}{'request'}{'client'}{'addr'}
        = '127.0.0.1';
    @sends_before = @route_sends;
    $code{'httpd.route.handler.web-relay'}->( 64, $relay_args );
    my $ex_direct = $route_sends[-1] // {};
    ok(
        (   scalar @route_sends == scalar @sends_before + 1
                and ( $ex_direct->{'command'} // '' ) eq qw| web.jobs-data |
        ),
        'loopback : exempt, direct relay'
    );
}

##[ 17 : the three new paths never queue -- not even under load ]#############

say '17 : status \ logout \ bearer answer at once : no queue, no scheduler';

reset_state();
{
    my $peer = '203.0.113.24';
    my @modes;
    for my $n ( 1 .. 7 ) {
        my $rs = status_call( 5400 + $n, $peer,
            cookie_header => "p7_session=z$n", );
        push @modes, $rs->{'mode'} // q||;
        my $rl
            = logout_call( 5410 + $n, $peer, body => "{\"token\":\"z$n\"}" );
        push @modes, $rl->{'mode'} // q||;
        my $rb = bearer_call( 5420 + $n, $peer,
            auth_header => "Bearer " . "z$n", );
        push @modes, $rb->{'mode'} // q||;
    }
    ok( ( scalar grep { $ARG eq qw| deferred | } @modes ) == 0,
        '21 calls on the three paths : every answer immediate'
    );
    ok(
        (   scalar grep {
                $ARG->{'params'}{'desc'} eq
                    'web-auth login admission scheduler'
            } @timer_calls
        ) == 0,
        'no admission scheduler timer was armed'
    );
    ok( ( scalar grep { $ARG eq qw| size | } @modes ) == 21,
        'every answer was a size envelope [ 401 or 429 ]'
    );
}

##[ 18 : the wire itself : packet bytes, receiver parse, end-to-end ]#########

say '18 : the wire : multi-line packet + receiver parse + status relay';

reset_state();
{
    ## the exact packet bytes for one /auth/status relay [ cmd id 7 ] ##
    my $param = {
        'peer_addr'     => '198.51.100.7',
        'peer_tls'      => 1,
        'auth_header'   => q||,
        'cookie_header' => 'p7_session=guess1',
    };
    my $packet = $code{'base.format.multiline_command'}
        ->( 7, 'auth-status', { 'param' => $param } );
    ok( defined $packet, 'packet built' );
    ok( $packet =~ m|^\(7\)auth-status\+\n|,
        'packet head : ' . '(7)auth-status+'
    );
    ok( $packet =~ m| cookie_header : p7_session=guess1\n|,
        'packet : cookie_header line' );
    ok( $packet =~ m| auth_header : \n|,
        'packet : empty auth_header keeps \' key : \' with an empty value' );
    ok( $packet =~ m|\n\.\n\z|, 'packet ends with the lone . line' );

    ## receiver parse round trip : values arrive exactly, empty stays '' ##
    my $call = wire_deliver(
        {   'command'   => 'web.auth-status',
            'call_args' => { 'param' => $param },
        }
    );
    ok( ( $call->{'param'}{'cookie_header'} // '' ) eq 'p7_session=guess1',
        'wire round trip : cookie_header exact' );
    ok(
        (   exists $call->{'param'}{'auth_header'}
                and ( $call->{'param'}{'auth_header'} // 1 ) eq q||
        ),
        'wire round trip : empty auth_header arrives as empty string'
    );
    ok( ( $call->{'param'}{'peer_addr'} // '' ) eq '198.51.100.7',
        'wire round trip : peer_addr exact' );

    ## body dot-stuffing round trip : a line of dots survives ##
    my $body_call = wire_deliver(
        {   'command'   => 'web.auth-login',
            'call_args' => {
                'param' => { 'peer_addr' => '192.0.2.1', 'peer_tls' => 1 },
                'data'  => "{\"token\":\"x\"}\n..\n",
            },
        }
    );
    ok( ( $body_call->{'data'} // '' ) eq "{\"token\":\"x\"}\n..\n",
        'wire round trip : body + dot-stuffed line exact'
    );

    ## end to end : the REAL route handler -> wire -> web.auth-status ##
    $data{'session'}{70} = {
        'buffer' => { 'input' => q||, 'output' => q|| },
        'http'   => {
            'request' => {
                'uri'     => '/auth/status',
                'headers' => {
                    'authorization' => q||,
                    'cookie'        => 'p7_session=wire-guess',
                },
                'client' => { 'addr' => '198.51.100.9' },
            },
        },
        'handle'  => bless( {}, 'FakeSock' ),
        'watcher' => { 'input_handler' => FakeIOWatcher->new() },
    };
    my $ret = $code{'httpd.route.handler.web-status'}->( 70, {} );
    ok( $ret == 0, 'status route handler : deferred' );
    my $live = wire_deliver( $route_sends[-1] );
    my $ans
        = $code{'web.cmd.auth-status'}->( { %{$live}, 'reply_id' => 5501 } );
    my $env = eval { JSON::XS::decode_json( $ans->{'data'} ) } // {};
    ok( ( $env->{'status'} // 0 ) == 401,
        'end to end over the wire : bad cookie checked [ 401 ]' );
    ok(
        (   admit_state->{'sources'}{'v4/32:198.51.100.9'}{'fails'}{'status'}
                // 0
        ) == 1,
        'end to end over the wire : failure recorded'
    );
}

##[ 19 : send.local : multi-line branch, refusals, single-line intact ]#######

say '19 : send.local : multi-line send, refusals, single-line unchanged';

reset_state();
{
    $data{'user'}{'web'}{'session'} = { 900 => 1 };
    $data{'session'}{900} = {
        'mode'          => 'client',
        'user'          => 'httpd',
        'authenticated' => 'yes',
        'buffer'        => { 'output' => q|| },
    };

    my $call_args = {
        'param' => {
            'peer_addr' => '192.0.2.1',
            'peer_tls'  => 1,
        },
        'data' => "{\"token\":\"x\"}\n",
    };
    my $count = $code{'base.protocol-7.command.send.local'}->(
        {   'command'   => 'web.auth-login',
            'call_args' => $call_args,
            'reply'     => { 'handler' => 'dev.null' },
        }
    );
    my $expected = $code{'base.format.multiline_command'}
        ->( 7, 'auth-login', $call_args );
    ok( $count == 1, 'multi-line send : one command sent' );
    ok( ( $data{'session'}{900}{'buffer'}{'output'} // '' ) eq $expected,
        'multi-line send : buffer holds the multiline packet'
    );
    ok( ( $data{'session'}{900}{'buffer'}{'output'} // '' )
            =~ m|\(7\)auth-login\+\n|,
        'multi-line send : packet head framed'
    );

    ## single-line : byte for byte as before ##
    $data{'session'}{900}{'buffer'}{'output'} = q||;
    my $sl_count = $code{'base.protocol-7.command.send.local'}->(
        {   'command'   => 'web.request',
            'call_args' => { 'args'    => 'ping' },
            'reply'     => { 'handler' => 'dev.null' },
        }
    );
    ok(
        (           $sl_count == 1
                and $data{'session'}{900}{'buffer'}{'output'} eq
                "(7)request ping\n"
        ),
        'single-line send : unchanged bytes'
    );

    ## refusals : nothing on the wire, zero returned ##
    for my $case (
        [ 'bad key chars',            { 'Bad Key'   => 'x' } ],
        [ 'linebreak in value',       { 'peer_addr' => "a\nb" } ],
        [ 'carriage return in value', { 'peer_addr' => "a\rb" } ],
    ) {
        my ( $label, $bad_param ) = @{$case};
        $data{'session'}{900}{'buffer'}{'output'} = q||;
        my $rc = $code{'base.protocol-7.command.send.local'}->(
            {   'command'   => 'web.auth-login',
                'call_args' => { 'param'   => $bad_param },
                'reply'     => { 'handler' => 'dev.null' },
            }
        );
        ok( ( $rc == 0 and $data{'session'}{900}{'buffer'}{'output'} eq q|| ),
            "refused : $label"
        );
    }
    ok(
        (   scalar grep { $ARG->[0] == 0 and $ARG->[1] =~ m|refused| }
                @log_calls
        ) >= 3,
        'refusals logged at level 0'
    );
}

say q||;
if ($fail_count) {
    say "FAILED : $fail_count test(s)";
    exit 1;
}
say 'all tests passed';
exit 0;

#,,.,,,,.,,,,,,,.,,,.,.,,,.,.,.,,,,..,,..,.,.,..,,...,...,.,,,,..,...,,.,,.,,,
#57Z556WLE3EHLG3TIZYCCE6V4IMQX7O6HIMYIAN2FHV2XPC7GZW25HROJDOYVIOBVYX5U7ODC2MJ4
#\\\|TAHLLAT6SFBFMMKSUUGIB3UHS66FQJZRXSSFCXXLI4Z7Y2PAHMN \ / AMOS7 \ YOURUM ::
#\[7]SBUKDIBAMYQO5I2YT5TUXMDTJSN3XQOXB2NDK3DC7HMG4AWKYKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
