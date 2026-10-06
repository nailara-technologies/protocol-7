#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the  ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## external named links [ 2026-10-06 ] compiles the real external.link.open ##
## and external.cmd.connect and drives them with stubs : base.open hands out ##
## socketpair ends, auth \ handshake \ session \ activate are scripted      ##
## recorders, event.add_timer records its timer and the callback is run by  ##
## hand. regex.base.usr comes from the real base.regex module. no zenka     ##
## started, restarted or reloaded, no network, no key dirs touched.        ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;
use Socket  qw| AF_UNIX SOCK_STREAM PF_UNSPEC |;

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

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;
our %data;

my $fail_count = 0;
my $pass_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## $prefix : source prepended inside the compiled sub [ the .cmd. header ] ##
sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= '';
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "sub {\n$prefix\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## generic stubs ##
my @logged;
$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub {return};
my @complaints;
$code{'base.s_warn'}
    = sub { push @complaints, sprintf( shift, @ARG ); return };
$code{'base.caller'} = sub { return '[ test ]' };

## the real regex cache : base.regex returns the hash of compiled regexes ##
$code{'base.regex'} = undef;
compile_module('base.regex');
$data{'regex'}{'base'} = $code{'base.regex'}->();
ok( ref $data{'regex'}{'base'}{'usr'} eq 'Regexp',
    'regex.base.usr taken from the real base.regex module' );

## scripted behaviour of the stubbed collaborators ##
my %script;
my @calls;    ## [ name, args.. ] in call order ##
my @socks;    ## our ends of every socketpair handed out ##
my $next_sid = 7000;

sub reset_script {
    %script = (
        'open'      => 'sock',    ## sock | undef ##
        'auth'      => 'ok',      ## ok | undef | die ##
        'handshake' => 'ok',      ## ok | fail | die ##
        'init'      => 'ok',      ## ok | undef ##
        'activate'  => 'ok',      ## ok | false ##
    );
    @calls = ();
    @socks = ();
    %{ $data{'session'} } = ();
    %{ $data{'external'} } = ( 'cfg' => { 'link_user' => 'linkuser' } );
    return;
}

sub calls_named {
    my $name = shift;
    return grep { $ARG->[0] eq $name } @calls;
}

$code{'base.open'} = sub {
    push @calls, [ 'open', @ARG ];
    return if $script{'open'} eq 'undef';
    socketpair( my $ours, my $theirs, AF_UNIX, SOCK_STREAM, PF_UNSPEC )
        or die "socketpair : $ERRNO";
    push @socks, [ $ours, $theirs ];
    return $ours;
};
$code{'auth.client.auth-keypair.authenticate'} = sub {
    push @calls, [ 'auth', @ARG ];
    die "auth exploded\n" if $script{'auth'} eq 'die';
    return if $script{'auth'} eq 'undef';
    return TRUE;
};
$code{'protocol.protocol-7.link-upgrade.handshake'} = sub {
    push @calls, [ 'handshake', @ARG ];
    die "handshake exploded\n" if $script{'handshake'} eq 'die';
    return ( 0, { 'error' => 'bad greeting' } )
        if $script{'handshake'} eq 'fail';
    return ( 1, { 'key' => 'stub-link' } );
};
$code{'base.session.init'} = sub {
    push @calls, [ 'session.init', @ARG ];
    return if $script{'init'} eq 'undef';
    my $id = $next_sid++;
    $data{'session'}{$id} = { 'name' => $ARG[3] };
    return $id;
};
$code{'base.session.init_state'} = sub {
    push @calls, [ 'init_state', @ARG ];
    return;
};
$code{'protocol.protocol-7.link-upgrade.client_activate'} = sub {
    push @calls, [ 'activate', @ARG ];
    return $script{'activate'} eq 'ok' ? TRUE : FALSE;
};
$code{'base.session.shutdown'} = sub {
    push @calls, [ 'shutdown', @ARG ];
    delete $data{'session'}{ $ARG[0] };
    return;
};

compile_module('external.link.open');
my $open = $code{'external.link.open'};

sub sock_closed { my $s = shift; return not defined fileno($s) }

sub is_false {
    my ($res) = @ARG;
    return ref $res eq 'HASH' && $res->{'mode'} eq 'false';
}

## ---- external.link.open ---- ##
say 'external.link.open : argument validation';
for my $case (
    [ 'missing name', { host => 'h.example', port => 42 } ],
    [ 'missing host', { name => 'lnk',       port => 42 } ],
    [ 'missing port', { name => 'lnk', host => 'h.example' } ],
    [ 'non-numeric port', { name => 'lnk', host => 'h', port => '4x2' } ],
    [ 'empty args', {} ],
    )
{
    reset_script();
    my $res = $open->( $case->[1] );
    ok( is_false($res), "$case->[0] -> false" );
    ok( !calls_named('open'), "$case->[0] -> no base.open call" );
}

reset_script();
for my $bad ( 'bad name', 'bad/name', '-lead', 'x' x 40, 'a[b]' ) {
    my $res = $open->( { name => $bad, host => 'h', port => 42 } );
    ok( is_false($res) && $res->{'data'} =~ m{not a valid link name},
        "invalid link name '$bad' -> false" );
}
ok( !calls_named('open'), 'invalid names -> no base.open call' );
{
    my $res = $open->( { name => 'good-name_1', host => 'h', port => 42 } );
    ok( !is_false($res) || $res->{'data'} !~ m{not a valid link name},
        'a valid name passes the name check' );
}

reset_script();
delete $data{'external'}{'cfg'}{'link_user'};
{
    my $res = $open->( { name => 'lnk', host => 'h', port => 42 } );
    ok( is_false($res) && $res->{'data'} =~ m{no link identity},
        'no as_username and no cfg.link_user -> false' );
    ok( !calls_named('open'), 'no identity -> no base.open call' );
}

say 'external.link.open : failure paths close the socket';
reset_script();
$script{'open'} = 'undef';
{
    my $res = $open->( { name => 'lnk', host => 'h', port => 42 } );
    ok( is_false($res) && $res->{'data'} =~ m{cannot connect to h:42},
        'base.open undef -> false "cannot connect"' );
    ok( !calls_named('auth'), 'open failure -> auth not attempted' );
}

reset_script();
$script{'auth'} = 'undef';
{
    my $res = $open->( { name => 'lnk', host => 'h', port => 42 } );
    ok( is_false($res) && $res->{'data'} =~ m{auth-keypair as linkuser},
        'auth undef -> false' );
    ok( sock_closed( $socks[0][0] ), 'auth undef -> socket closed' );
    ok( !calls_named('handshake'), 'auth undef -> no handshake' );
}

reset_script();
$script{'auth'} = 'die';
{
    my $res = eval { $open->( { name => 'lnk', host => 'h', port => 42 } ) };
    ok( $EVAL_ERROR eq "auth exploded\n", 'auth dies -> die propagates' );
    ok( sock_closed( $socks[0][0] ), 'auth dies -> socket closed' );
}

reset_script();
$script{'handshake'} = 'fail';
{
    my $res = $open->( { name => 'lnk', host => 'h', port => 42 } );
    ok( is_false($res) && $res->{'data'} =~ m{bad greeting},
        'handshake ( 0, { error } ) -> false with the error text' );
    ok( sock_closed( $socks[0][0] ), 'handshake failure -> socket closed' );
    ok( !calls_named('session.init'), 'handshake failure -> no session' );
}

reset_script();
$script{'handshake'} = 'die';
{
    my $res = eval { $open->( { name => 'lnk', host => 'h', port => 42 } ) };
    ok( $EVAL_ERROR eq "handshake exploded\n",
        'handshake dies -> die propagates' );
    ok( sock_closed( $socks[0][0] ), 'handshake dies -> socket closed' );
}

reset_script();
$script{'init'} = 'undef';
{
    my $res = $open->( { name => 'lnk', host => 'h', port => 42 } );
    ok( is_false($res), 'session.init undef -> false' );
    ok( sock_closed( $socks[0][0] ), 'session.init undef -> socket closed' );
    ok( !calls_named('init_state'), 'session.init undef -> no init_state' );
}

reset_script();
$script{'activate'} = 'false';
{
    my $res = $open->( { name => 'lnk', host => 'h', port => 42 } );
    my @sd  = calls_named('shutdown');
    ok( is_false($res), 'client_activate false -> false' );
    ok( @sd == 1 && !exists $data{'session'}{ $sd[0][1] },
        'client_activate false -> session.shutdown( id ) once' );
    ok( !exists $data{'external'}{'links'}{'lnk'},
        'client_activate false -> no link registered' );
}

say 'external.link.open : success and reuse';
reset_script();
my $sid;
{
    my $res = $open->(
        { name => 'lnk', host => 'h.example', port => 42, as_username => 'bob' }
    );
    $sid = $res->{'data'};
    ok( $res->{'mode'} eq 'true' && $sid =~ m{^\d+$},
        'success -> ( true, sid )' );
    my @a = calls_named('auth');
    ok( $a[0][2] eq 'bob' && $a[0][3] eq 'lnk',
        'auth got as_username and the link name' );
    my @o = calls_named('open');
    ok( "@{$o[0]}[1..4]" eq 'ip.tcp output h.example 42',
        'base.open got ip.tcp output host port' );
    my @si = calls_named('session.init');
    ok( $si[0][4] eq 'lnk' && $si[0][2] eq 'protocol-7'
            && $si[0][3] eq 'client',
        'session.init got the link name as session name' );
    my @is = calls_named('init_state');
    ok( @is == 1 && $is[0][1] == $sid && $is[0][2] == 1,
        'init_state( id, 1 ) called' );
    my @ac = calls_named('activate');
    ok( @ac == 1 && $ac[0][1] == $sid && $ac[0][2]{'key'} eq 'stub-link',
        'client_activate got id and the handshake link' );
    ok( $data{'session'}{$sid}{'authenticated'} eq 'yes',
        'session marked authenticated = yes' );
    my $l = $data{'external'}{'links'}{'lnk'};
    ok( $l->{'sid'} == $sid && $l->{'host'} eq 'h.example'
            && $l->{'port'} eq '42' && $l->{'user'} eq 'bob',
        'external.links entry = { sid host port user }' );
    ok( !sock_closed( $socks[0][0] ), 'success -> socket left open' );
}

{
    my $before = scalar calls_named('open');
    my $res    = $open->( { name => 'lnk', host => 'h.example', port => 42 } );
    ok( $res->{'mode'} eq 'true' && $res->{'data'} == $sid,
        'reuse : same name host port -> same sid' );
    ok( calls_named('open') == $before, 'reuse -> no new base.open' );
}

{
    my $before = scalar calls_named('open');
    my $res = $open->( { name => 'lnk', host => 'other.example', port => 42 } );
    ok( is_false($res)
            && $res->{'data'} =~ m{link lnk is open to h\.example:42},
        'same name other host -> false "link lnk is open to .."' );
    my $res2 = $open->( { name => 'lnk', host => 'h.example', port => 43 } );
    ok( is_false($res2) && $res2->{'data'} =~ m{open to h\.example:42},
        'same name other port -> false' );
    ok( calls_named('open') == $before, 'conflict -> no new base.open' );
    ok( $data{'external'}{'links'}{'lnk'}{'sid'} == $sid,
        'conflict -> old entry kept' );
}

{
    delete $data{'session'}{$sid};    ## session gone : entry is stale ##
    my $before = scalar calls_named('open');
    my $res = $open->( { name => 'lnk', host => 'h2.example', port => 99 } );
    ok( $res->{'mode'} eq 'true' && $res->{'data'} != $sid,
        'stale entry -> a new link is opened [ new sid ]' );
    ok( calls_named('open') == $before + 1, 'stale entry -> one new open' );
    ok( $data{'external'}{'links'}{'lnk'}{'host'} eq 'h2.example',
        'stale entry replaced by the new link' );
}

reset_script();
{
    ## as_username falls back to cfg.link_user ##
    $open->( { name => 'lnk', host => 'h', port => 42 } );
    my @a = calls_named('auth');
    ok( $a[0][2] eq 'linkuser', 'as_username //= external.cfg.link_user' );
}

## ---- external.cmd.connect ---- ##
say 'external.cmd.connect';
## the compiled-in .cmd. header from bin/Protocol-7 ##
compile_module( 'external.cmd.connect',
    'my $call = {}; if ( ref( $ARG[0] ) eq q|HASH| ) { $call = $ARG[0] } '
        . 'else { $call->{q|args|} = $ARG[0] }' );
my $connect = $code{'external.cmd.connect'};

my @timers;
my @replies;
my @open_args;
my $open_result;
$code{'event.add_timer'} = sub { push @timers, $ARG[0]; return };
$code{'base.callback.cmd_reply'} = sub { push @replies, [@ARG]; return };
$code{'external.link.open'} = sub {
    push @open_args, $ARG[0];
    die $open_result->{'die'} if exists $open_result->{'die'};
    return $open_result->{'ret'};
};

sub reset_connect {
    @timers = @replies = @open_args = ();
    $open_result = { 'ret' => { 'mode' => 'true', 'data' => 321 } };
    delete $data{'protocol-7'};
    return;
}

reset_connect();
for my $args ( '', 'onlyname' ) {
    my $res = $connect->( { args => $args, reply_id => 'r1' } );
    ok( is_false($res) && $res->{'data'} =~ m{^usage : connect},
        "args '$args' -> false usage" );
}
{
    my $res = $connect->( { args => '', reply_id => 'r1' } );
    ok( !@timers, 'usage failure -> no timer' );
    my $res2 = $connect->( { args => 'a b:1' } );
    ok( is_false($res2) && $res2->{'data'} =~ m{reply route},
        'no reply_id -> false' );
    ok( !@timers, 'no reply_id -> no timer' );
}

reset_connect();
{
    my $res = $connect->(
        { args => 'lnk host.example:4242 carol', reply_id => 'r9' } );
    ok( ref $res eq 'HASH' && $res->{'mode'} eq 'deferred',
        'valid -> mode deferred' );
    ok( @timers == 1 && $timers[0]{'after'} == 0, 'ONE timer with after 0' );
    ok( ref $timers[0]{'cb'} eq 'CODE', 'timer carries a callback' );
    ok( !@open_args, 'link.open not called before the timer fires' );
    ok( !@replies,   'no reply before the timer fires' );

    $timers[0]{'cb'}->();
    ok( @open_args == 1, 'cb -> link.open called once' );
    my $oa = $open_args[0];
    ok( $oa->{'name'} eq 'lnk' && $oa->{'host'} eq 'host.example'
            && $oa->{'port'} eq '4242' && $oa->{'as_username'} eq 'carol',
        'link.open got { name host port as_username }' );
    ok( @replies == 1 && $replies[0][0] eq 'r9'
            && $replies[0][1]{'mode'} eq 'true'
            && $replies[0][1]{'data'}
            =~ m{^linked lnk -> host\.example:4242 \[ encrypted, session 321 \]$},
        'link.open true -> cmd_reply( reply_id, true, "linked .. session N" )'
    );
}

reset_connect();
{
    $connect->( { args => 'lnk hostonly', reply_id => 'r2' } );
    $timers[0]{'cb'}->();
    ok( $open_args[0]{'port'} == 42, 'port defaults to 42 when unset' );
    ok( !defined $open_args[0]{'as_username'},
        'as_username undef when not given [ link.open applies cfg ]' );
}
reset_connect();
{
    $data{'protocol-7'}{'remote'}{'default-port'} = 5151;
    $connect->( { args => 'lnk hostonly', reply_id => 'r3' } );
    $timers[0]{'cb'}->();
    ok( $open_args[0]{'port'} == 5151,
        'port defaults to protocol-7.remote.default-port when set' );
}
reset_connect();
{
    ## args as a bare string [ the non-hash invocation form ] ##
    my $res = $connect->('lnk h.example:1');
    ok( ref $res eq 'HASH' && $res->{'mode'} eq 'false'
            && $res->{'data'} =~ m{reply route},
        'bare-string args without reply_id -> reply route error' );
}

reset_connect();
{
    my $fail = { 'mode' => 'false', 'data' => 'link lnk is open to x:1' };
    $open_result = { 'ret' => $fail };
    $connect->( { args => 'lnk h:1', reply_id => 'r4' } );
    $timers[0]{'cb'}->();
    ok( @replies == 1 && $replies[0][0] eq 'r4' && $replies[0][1] == $fail,
        'link.open false -> that false result passed through' );
}

reset_connect();
{
    $open_result = { 'die' => "auth exploded\n" };
    $connect->( { args => 'lnk h:1', reply_id => 'r5' } );
    my $lived = eval { $timers[0]{'cb'}->(); 1 };
    ok( $lived, 'link.open dies -> cb itself does not die' );
    ok( @replies == 1 && $replies[0][0] eq 'r5'
            && $replies[0][1]{'mode'} eq 'false'
            && $replies[0][1]{'data'} eq 'link setup failed : auth exploded',
        'link.open dies -> cmd_reply false "link setup failed : <msg>"' );
}

reset_connect();
{
    $open_result = { 'die' => "multi\nline\n\n" };
    $connect->( { args => 'lnk h:1', reply_id => 'r6' } );
    $timers[0]{'cb'}->();
    ok( @replies == 1 && $replies[0][1]{'data'} eq "link setup failed : multi\nline",
        'die message trailing whitespace trimmed' );
}

reset_connect();
{
    $open_result = { 'ret' => undef };
    $connect->( { args => 'lnk h:1', reply_id => 'r7' } );
    $timers[0]{'cb'}->();
    ok( @replies == 1 && $replies[0][1]{'mode'} eq 'false'
            && $replies[0][1]{'data'} eq 'link setup failed : no result',
        'link.open returns undef -> still a reply [ "no result" ]' );
}

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,,,,.,,.,,,.,,,..,,,,.,.,,,.,.,...,...,.,.,..,,...,...,...,..,,..,,,,,,,..,
#53AOAXKX33WJ6WRSDUNAFMCRBB2JVHEN2JKIVUUSGWCLFU6ZRITRIEDX3X4OC7GYJ2AYA5G7BIQTC
#\\\|JRXC6ENKXAS4KG4R2J2ZALVKTZGI273G5OPO5KSIO7DNDCLYRG7 \ / AMOS7 \ YOURUM ::
#\[7]NVSNKNVW3WAM7J55PQ66O3UQF3K75KIUOZUDMMYJUJ7STNASRGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
