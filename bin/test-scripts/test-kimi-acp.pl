#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
## kimi zenka acp adapter : compiles the real kimi.acp.*, kimi.cmd.acp-*,   ##
## kimi.handler.acp_* modules and the kimi-send events plugin. the child is ##
## a FAKE `kimi acp` : a small perl script written to a temp dir that       ##
## speaks the json-rpc wire format [ one message per line ]. the event loop ##
## is stubbed : watchers are recorded and pumped with select, the cube is a ##
## recorder. no real kimi process is ever started.                          ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use POSIX      qw| WNOHANG strftime |;
use Fcntl      ();
use IO::Select;
use JSON::XS   ();
use IPC::Open3 ();
use Symbol     ();
use Encode     ();

BEGIN {
    my $root = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::root_path = $root;
    unshift @INC, "$root/data/lib-path/pm";
}

use constant TRUE  => 5;
use constant FALSE => 0;

my $root_path = $main::root_path;

our %data;
our %code;
our $call;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    $name //= "unnamed at line " . ( caller(0) )[2];
    if   ($cond) { $pass++; say "ok   - $name" }
    else         { $fail++; say "FAIL - $name" }
    return $cond;
}

## module loading : the same <..> translation the zenka loader does ##

sub translate_code {
    my $code = shift;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>(?=\s*->)|"\$code{$1}"|eg;
    $code =~ s|<\[(\$[A-Za-z]\w*)\]>|"\$code{$1}->()"|eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, $1;
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub compile_source {
    my $src = shift;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    my $sub        = eval "sub { $translated }";
    die "compile error : $EVAL_ERROR" if $EVAL_ERROR;
    return $sub;
}

sub read_file {
    my $path = shift;
    open my $fh, '<:encoding(UTF-8)', $path
        or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $src = <$fh>;
    close $fh;
    return $src;
}

sub read_file_raw {
    my $path = shift;
    open my $fh, '<:raw', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $raw = <$fh>;
    close $fh;
    return $raw;
}

sub load_module {
    my $name = shift;
    $code{$name}
        = compile_source(
        read_file( File::Spec->catfile( $root_path, 'src', $name ) ) );
}

## stubs : log, cube, zenka dir, event loop ##

my ( @logged, @routes, @plugin_sent, %calls );

$code{'base.log'}  = sub { push @logged, join ' ', @ARG; TRUE };
$code{'base.logs'} = sub {
    my @a = @ARG;
    shift @a if $a[0] =~ m|\A\d\z|;
    my $fmt = shift @a;
    push @logged, @a ? sprintf( $fmt, @a ) : $fmt;
    TRUE;
};
$code{'base.perlmod.load'} = sub { $calls{'perlmod'}++; TRUE };
$code{'base.zenki.pause_ondemand_timeout'}
    = sub { $calls{'pause'}++; TRUE };
$code{'base.zenki.resume_ondemand_timeout'}
    = sub { $calls{'resume'}++; TRUE };
$code{'base.zenki.report_child_pid'}
    = sub { push @{ $calls{'child_pids'} }, shift; TRUE };

$code{'base.s_read'} = sub {
    my ( $fh, $ref, $len ) = @ARG;
    my $buf;
    my $n = sysread( $fh, $buf, $len );
    return 0        if not defined $n and $OS_ERROR{EAGAIN};
    return -1       if not defined $n;
    ${$ref} .= $buf if $n > 0;
    return $n;
};
$code{'base.s_write'} = sub {
    my ( $fh, $ref, $len ) = @ARG;
    my $n = syswrite( $fh, ${$ref}, $len );
    return 0  if not defined $n and $OS_ERROR{EAGAIN};
    return -1 if not defined $n;
    return $n;
};

my $tmp = tempdir( 'kimi-acp-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
$code{'file.zenka_dir.load'} = sub {
    my $path = "$tmp/zdir/" . shift;
    return undef if !-f $path;
    my $text = read_file($path);
    return \$text;
};
$code{'file.zenka_dir.write'} = sub {
    my ( $name, $sref, $mode, $perm, $layer ) = @ARG;
    mkdir "$tmp/zdir";
    open my $fh, ( $mode // '>' ), "$tmp/zdir/$name" or return;
    binmode( $fh, $layer // ':raw' );    ## the real default is :raw ##
    print {$fh} $sref->$*;
    close $fh;
    return TRUE;
};

## the cube : recorded, nothing is delivered ##
my @start_routes;    ## the run.start signals, apart from the rest ##
$code{'protocol-7.route-send'} = sub {
    my $route = shift;
    if ( ( $route->{'call_args'}{'args'} // '' ) =~ m{\Akimi\.run\.start } ) {
        push @start_routes, $route;
    } else {
        push @routes, $route;
    }
    return TRUE;
};
$code{'protocol-7.command.send.local'} = sub {
    push @plugin_sent, shift;
    return TRUE;
};

## the event loop : watchers recorded, pumped by hand ##
{

    package FakeWatcher;
    sub new       { my $c = shift; bless { 'active' => 1, %{ +shift } }, $c }
    sub cancel    { $_[0]{'active'} = 0 }
    sub is_active { $_[0]{'active'} }
    sub fd        { $_[0]{'fd'} }
    sub data      { $_[0]{'data'} }
    sub w         { $_[0] }
}
my ( @watchers, @timers );
$code{'event.add_io'} = sub {
    my $w = FakeWatcher->new(shift);
    push @watchers, $w;
    return $w;
};
$code{'event.add_timer'} = sub {
    my $t = FakeWatcher->new(shift);
    push @timers, $t;
    return $t;
};

## run the watchers until $cond is true [ or the time is up ] ##
sub pump {
    my ( $cond, $seconds, $quiet ) = @ARG;
    my $deadline = time + ( $seconds // 8 );
    while ( time < $deadline ) {
        return TRUE if $cond->();
        my @live = grep { $_->{'active'} and defined fileno( $_->{'fd'} ) }
            @watchers;
        for my $w ( grep { $_->{'poll'} eq 'w' } @live ) {
            $code{ $w->{'handler'} }->($w);
        }
        my @read = grep { $_->{'poll'} eq 'r' } @live;
        my $sel  = IO::Select->new( map { $_->{'fd'} } @read );
        for my $fh ( $sel->can_read(0.05) ) {
            my ($w) = grep { $_->{'active'} and $_->{'fd'} == $fh } @read;
            $code{ $w->{'handler'} }->($w) if $w;
        }
    }
    return TRUE  if $cond->();
    return FALSE if $quiet;
    ## a timed out wait says where the session stood ##
    say '# pump timed out : phase ' . $code{'kimi.acp.state'}->()->{'phase'};
    my @seen = @{ $code{'kimi.acp.state'}->()->{'events'} };
    say "# event : $ARG" for @seen > 12 ? @seen[ -12 .. -1 ] : @seen;
    say "# log : $ARG"   for @logged;
    say '# fake log : ' . ( fake_log() =~ s{\n}{ | }gr );
    return FALSE;
}

sub fire_timer {
    my @due = grep { $_->{'active'} } @timers;
    @timers = ();
    for my $t (@due) {
        $t->{'active'} = 0;
        $code{ $t->{'handler'} }->($t);
    }
    return scalar @due;
}

## the fake child : speaks json-rpc lines, driven by the prompt text ##

my $fake = "$tmp/fake-kimi.pl";
open my $ffh, '>', $fake or die $OS_ERROR;
print {$ffh} <<'FAKE';
use strict; use warnings; use JSON::XS;
$| = 1;
my $json = JSON::XS->new->utf8->canonical;
my $log  = $ENV{'FAKE_LOG'};
sub note { open my $l, '>>', $log or return; print {$l} join( ' ', @_ ), "\n"; close $l }
sub out  { print $json->encode( { 'jsonrpc' => '2.0', %{ +shift } } ), "\n" }
sub update { out( { 'method' => 'session/update', 'params' => { 'sessionId' => 'fake-sess', 'update' => shift } } ) }
sub chunk  { update( { 'sessionUpdate' => 'agent_message_chunk', 'content' => { 'type' => 'text', 'text' => shift } } ) }
my ( $session, $slow_id, $wait_perm, $wait_unknown ) = ( undef, undef, undef, undef );
while (1) {
    my $line = <STDIN>;
    if ( not defined $line ) {
        note('eof');
        if ( $ENV{'FAKE_DEAF'} ) { sleep 1 while 1 }
        exit 0;
    }
    my $m = eval { $json->decode($line) } or next;
    my ( $method, $id, $p ) = ( $m->{'method'} // '', $m->{'id'}, $m->{'params'} // {} );
    if ( $method eq 'initialize' ) {
        note('initialize');
        my $caps = $ENV{'FAKE_CAPS'} // 'resume';
        out( { 'id' => $id, 'result' => { 'protocolVersion' => 1,
            'agentCapabilities' => $caps eq 'load'
                ? { 'loadSession' => JSON::XS::true() }
                : { 'sessionCapabilities' => { 'resume' => {} }, 'loadSession' => JSON::XS::true() } } } );
    } elsif ( $method eq 'session/new' ) {
        note( 'session/new', $p->{'cwd'} // '' );
        $session = 'fake-sess-' . $$;
        out( { 'id' => $id, 'result' => { 'sessionId' => $session } } );
    } elsif ( $method eq 'session/resume' or $method eq 'session/load' ) {
        note( $method, $p->{'sessionId'} );
        if ( $ENV{'FAKE_FAIL_RESUME'} ) {
            out( { 'id' => $id, 'error' => { 'code' => -32602, 'message' => 'no such session' } } );
            next;
        }
        $session = $p->{'sessionId'};
        if ( $method eq 'session/load' ) {
            update( { 'sessionUpdate' => 'user_message_chunk', 'content' => { 'type' => 'text', 'text' => 'old question' } } );
            chunk('old answer');
        }
        out( { 'id' => $id, 'result' => $method eq 'session/load' ? undef : {} } );
    } elsif ( $method eq 'session/cancel' ) {
        note('cancel');
        if ( defined $slow_id ) {
            out( { 'id' => $slow_id, 'result' => { 'stopReason' => 'cancelled' } } );
            $slow_id = undef;
        }
    } elsif ( $method eq 'session/prompt' ) {
        my $text = $p->{'prompt'}[0]{'text'} // '';
        note( 'prompt', length $text > 40 ? length($text) . ' bytes' : $text );
        if ( $text eq 'crash' ) { exit 3 }
        elsif ( $text eq 'slow' ) { chunk('working'); $slow_id = $id }
        elsif ( $text eq 'perm' ) {
            $wait_perm = $id;
            out( { 'id' => 900, 'method' => 'session/request_permission', 'params' => { 'sessionId' => $session,
                'toolCall' => { 'toolCallId' => 'tc1', 'title' => 'run a command' },
                'options' => [ { 'optionId' => 'approve_once', 'name' => 'Approve', 'kind' => 'allow_once' },
                               { 'optionId' => 'reject', 'name' => 'Reject', 'kind' => 'reject_once' } ] } } );
        }
        elsif ( $text eq 'unknown' ) {
            $wait_unknown = $id;
            out( { 'id' => 901, 'method' => 'fs/read_text_file', 'params' => { 'path' => '/etc/passwd' } } );
        }
        elsif ( $text =~ m{\Auni } ) {
            chunk( 'cp ' . join( ' ', map { ord } split //, $text ) );
            out( { 'id' => $id, 'result' => { 'stopReason' => 'end_turn' } } );
        }
        elsif ( $text eq 'garbage' ) {
            print "this is not json\n";
            chunk('after garbage');
            out( { 'id' => $id, 'result' => { 'stopReason' => 'end_turn' } } );
        }
        else {
            ## one message split over two writes : the reader must keep the rest ##
            my $msg = $json->encode( { 'jsonrpc' => '2.0', 'method' => 'session/update', 'params' => { 'sessionId' => $session,
                'update' => { 'sessionUpdate' => 'agent_message_chunk', 'content' => { 'type' => 'text', 'text' => 'echo : ' } } } } ) . "\n";
            my $half = int( length($msg) / 2 );
            syswrite( STDOUT, substr( $msg, 0, $half ) ); select( undef, undef, undef, 0.1 );
            syswrite( STDOUT, substr( $msg, $half ) );
            chunk( length $text > 40 ? 'got ' . length($text) . ' bytes' : $text );
            update( { 'sessionUpdate' => 'tool_call', 'toolCallId' => 'tc9', 'title' => 'read a file', 'status' => 'pending' } );
            update( { 'sessionUpdate' => 'tool_call_update', 'toolCallId' => 'tc9', 'status' => 'completed' } );
            update( { 'sessionUpdate' => 'usage_update', 'used' => 1200, 'size' => 256000 } );
            out( { 'id' => $id, 'result' => { 'stopReason' => 'end_turn' } } );
        }
    } elsif ( defined $m->{'id'} and not defined $m->{'method'} ) {
        if ( $m->{'id'} == 900 ) {
            my $o = $m->{'result'}{'outcome'} // {};
            chunk( 'permission ' . ( $o->{'outcome'} // '?' ) . ' ' . ( $o->{'optionId'} // '-' ) );
            out( { 'id' => $wait_perm, 'result' => { 'stopReason' => 'end_turn' } } );
        } elsif ( $m->{'id'} == 901 ) {
            chunk( 'unknown answered ' . ( $m->{'error'}{'code'} // 'none' ) );
            out( { 'id' => $wait_unknown, 'result' => { 'stopReason' => 'end_turn' } } );
        }
    }
}
FAKE
close $ffh;

$ENV{'FAKE_LOG'} = "$tmp/fake.log";

sub fake_log {
    return '' if !-f "$tmp/fake.log";
    return read_file("$tmp/fake.log");
}

## load the modules under test ##

my $src = File::Spec->catdir( $root_path, 'src' );
opendir my $dh, $src or die "cannot open src : $OS_ERROR";
my @src = readdir $dh;
closedir $dh;
my @kimi_acp = sort grep {
    m{\A(?:stream_child\.|kimi\.acp\.|kimi\.cmd\.acp-|kimi\.handler\.acp_|kimi\.end_code\z|plugin\.events\.action\.kimi-send\z|base\.interval\.next\z|base\.interval\.rhythm\.)}
} @src;
ok( scalar(@kimi_acp) >= 30,
    'modules : the acp set is present [ ' . scalar(@kimi_acp) . ' ]' );
my $compiled = 0;
for my $name (@kimi_acp) {
    eval { load_module($name); 1 } and ++$compiled
        or say "# $name : $EVAL_ERROR";
}
ok( $compiled == @kimi_acp, 'modules : every one compiles' );

sub fresh {
    %data     = ();
    @logged   = @routes = @plugin_sent = ();
    %calls    = ();
    @watchers = @timers = ();
    unlink "$tmp/fake.log";
    system 'rm', '-rf', "$tmp/zdir";
    $data{'system'}{'root_path'} = $root_path;
    $data{'kimi'}{'acp'}{'cfg'}{'command'} = "$EXECUTABLE_NAME $fake";

    for my $type (qw| kimi-acp-stop kimi-acp-exit |) {
        $data{'base'}{'interval'}{'cfg'}{'type'}{$type} = {
            'start'      => 0.1,
            'factor'     => 1.2,
            'cap'        => 0.3,
            'cap_jitter' => 0.1
        };
    }
    delete @ENV{qw| FAKE_CAPS FAKE_FAIL_RESUME FAKE_DEAF |};
}

sub cmd {
    my ( $name, $args ) = @ARG;
    local $call = { 'args' => $args // '' };
    return $code{"kimi.cmd.$name"}->();
}
sub st          { $code{'kimi.acp.state'}->() }
sub events_text { join "\n", @{ st()->{'events'} } }

sub signals {
    [   map  { $_->{'call_args'}{'args'} }
        grep { $_->{'command'} eq 'events.signal' } @routes
    ];
}

sub phase_is {
    my $p = shift;
    sub { st()->{'phase'} eq $p }
}
sub alive { my $pid = shift; defined $pid and kill( 0, $pid ) }

sub is_sig {
    my ( $n, $want ) = @ARG;
    ok( ( signals()->[$n] // '' ) eq $want, "signal : $want" );
}

## configuration and grants on disk ##

my $zenka_v7 = read_file("$root_path/cfg/zenki/kimi/zenka.v7");
ok( $zenka_v7 =~ m{kimi-acp-stop\.start}
        && $zenka_v7 =~ m{kimi-acp-exit\.start},
    'config : the stop and exit interval types are declared'
);
ok( $zenka_v7
        =~ m{acp-start acp-send acp-cancel acp-status\s*\\\s*acp-tail acp-stop}s,
    'config : the acp commands are in the kimi command list'
);
my $access = read_file("$root_path/cfg/zenki/cube/access.zenki");
ok( $access =~ m{access\.cmd\.usr\.kimi\s*=[^\n]*events\.signal},
    'access : kimi may call events.signal' );
ok( $access =~ m{access\.cmd\.usr\.events\s*=[^\n]*kimi\.acp-send},
    'access : events may call kimi.acp-send' );
my $whitelist = read_file("$root_path/cfg/zenki/kimi/subroutines.load-early");
ok(
    (   grep { $whitelist =~ m{^\Q$ARG\E$}m }
            qw| kimi.acp.spawn kimi.cmd.acp-send kimi.handler.acp_stdout kimi.end_code |
    ) == 4,
    'config : the kimi whitelist lists the acp modules'
);
ok( read_file("$root_path/cfg/zenki/events/subroutines.load-early")
        =~ m{^plugin\.events\.action\.kimi-send$}m,
    'config : the events whitelist lists kimi-send'
);
my $bad_header = grep {
    my $f = $ARG;
    grep { m{^#\s*(?:descr|param)\s*=\s*(.+)$} and length($1) > 55 }
        split m{\n},
        read_file("$src/$f")
} grep {m{\Akimi|kimi-send}} @kimi_acp;
ok( !$bad_header,
    'modules : descr and param values are at most 55 characters' );

ok( read_file("$root_path/cfg/zenki/events/access.signals")
        =~ m{^##\s+events\.signal\.kimi\s*=\s*kimi\.run\.done}m,
    'access.signals : kimi.run.done is listed as a commented example'
);

## start, handshake, a stored id ##

fresh();
my $r = cmd( 'acp-start', '' );
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{new session},
    'start : a new session is started' );
ok( st()->{'phase'} eq 'starting' && st()->{'pid'},
    'start : starting with a child pid' );
ok( $calls{'pause'} && @{ $calls{'child_pids'} // [] } == 1,
    'start : idle shutdown paused, child pid reported'
);
$r = cmd( 'acp-start', '' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{already},
    'start : a second start is refused' );
ok( pump( phase_is('ready') ), 'start : the handshake reaches ready' );
my $pid1 = st()->{'pid'};
my $sid  = st()->{'session_id'};
ok( defined $sid && $sid =~ m{\Afake-sess-\d+\z},
    "start : session id from the child [ $sid ]"
);
ok( read_file("$tmp/zdir/acp.session") =~ m{\Asession_id = \Q$sid\E\n\z},
    'start : the id is stored in p7 config style' );
ok( !-e "$tmp/zdir/session_id",
    'start : the kimi-web session_id file is not used' );
ok( fake_log() =~ m{session/new \Q$root_path\E},
    'start : session/new carries the repo as cwd'
);
ok( events_text() =~ m{session : \Q$sid\E ready \[ new \]},
    'start : the ready event is in the buffer'
);

## send, events out, a result ##

$r = cmd( 'acp-send', '' );
ok( $r->{'mode'} eq 'false', 'send : empty text refused' );
$r = cmd( 'acp-send', 'hello world' );
ok( $r->{'mode'} eq 'true' && $r->{'data'} eq 'sent',
    'send : sent at once while idle' );
ok( st()->{'phase'} eq 'prompting',      'send : the session is prompting' );
ok( pump( sub { @{ signals() } >= 1 } ), 'send : the prompt ends' );
my $ev = events_text();
ok( $ev =~ m{prompt : hello world}, 'events : the prompt line' );
ok( $ev =~ m{agent : echo : hello world},
    'events : message chunks are joined, a split line is kept whole' );
ok( $ev =~ m{tool : tc9 read a file \[ pending \]}
        && $ev =~ m{tool : tc9 \[ completed \]},
    'events : tool call and update'
);
ok( $ev =~ m{usage : 1200 of 256000}, 'events : usage update' );
ok( $ev =~ m{done : prompt ended \[ end_turn \]},
    'events : the end of the prompt' );
ok( st()->{'phase'} eq 'ready', 'send : back to ready' );
is_sig( 0, "kimi.run.done state=end_turn session=$sid" );
ok(
    (   scalar grep {
            $ARG->{'reply'}{'handler'} eq 'kimi.handler.acp_signal_reply'
        } @routes
    ) == 1,
    'signal : a reply handler is attached'
);
ok( read_file("$tmp/zdir/acp.log") =~ m{prompt : hello world},
    'log : events are appended to acp.log' );

$r = cmd( 'acp-tail', '3' );
my @tail_lines = split m{\n}, $r->{'data'};
ok( $r->{'mode'} eq 'size' && @tail_lines == 3, 'tail : the last 3 lines' );
$r = cmd( 'acp-status', '' );
ok( $r->{'data'}        =~ m{phase\s+: ready}
        && $r->{'data'} =~ m{session : \Q$sid\E}
        && $r->{'data'} =~ m{permission deny},
    'status : phase, session, policy'
);

## the reply handler logs a refusal ##

@logged = ();
$code{'kimi.handler.acp_signal_reply'}->(
    {   'cmd'       => 'FALSE',
        'call_args' =>
            { 'args' => "'kimi' may not raise signal 'kimi.run.done'" }
    }
);
ok( ( grep {m{refused}} @logged )
        && events_text() =~ m{error : signal kimi.run.done refused},
    'signal : a refused signal is logged and shown'
);

## queued while a prompt runs, interrupt ##

$r = cmd( 'acp-send', 'slow' );
ok( $r->{'data'} eq 'sent', 'queue : the slow prompt goes out' );
$r = cmd( 'acp-send', 'after the slow one' );
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{queued \[ 1 ahead \]},
    'queue : the second text waits' );
ok( pump( sub { ( st()->{'chunk'} // {} )->{'text'} } ),
    'queue : the child is working' );
$r = cmd( 'acp-cancel', '' );
ok( $r->{'data'} =~ m{cancel sent}, 'cancel : session/cancel sent' );
ok( pump( sub { @{ signals() } >= 3 } ),
    'cancel : cancelled, then the queued prompt runs and ends' );
is_sig( 1, "kimi.run.done state=cancelled session=$sid" );
ok(
    (   grep {
            ( $_->{'call_args'}{'args'} // '' )
                =~ m{\Akimi\.run\.start session=\Q$sid\E turn=\d+\z}
                and $_->{'reply'}{'params'}{'signal'} eq 'kimi.run.start'
        } @start_routes
    ) == 3,
    'signal : kimi.run.start for each prompt, with session and turn'
);
is_sig( 2, "kimi.run.done state=end_turn session=$sid" );
ok( fake_log() =~ m{^cancel$}m, 'cancel : the child saw the notification' );
$r = cmd( 'acp-cancel', '' );
ok( $r->{'data'} =~ m{nothing running},
    'cancel : nothing running is said so'
);

## permission policy, unknown requests, stray lines ##

@routes = ();
cmd( 'acp-send', 'perm' );
ok( pump( sub { @{ signals() } >= 1 } ), 'permission : the prompt ends' );
ok( events_text() =~ m{permission : run a command : deny \[ reject \]},
    'permission : default policy denies, logged' );
ok( events_text() =~ m{agent : permission selected reject},
    'permission : the child got the reject option'
);
$data{'kimi'}{'acp'}{'cfg'}{'permission'} = 'allow-once';
cmd( 'acp-send', 'perm' );
ok( pump( sub { @{ signals() } >= 2 } ),
    'permission : allow-once prompt ends'
);
ok( events_text() =~ m{agent : permission selected approve_once},
    'permission : allow-once selects approve_once' );
$data{'kimi'}{'acp'}{'cfg'}{'permission'} = 'bogus';
cmd( 'acp-send', 'perm' );
my $pump_ok = pump( sub { @{ signals() } >= 3 } );
my @rejects = events_text() =~ m{agent : permission selected reject}g;
ok( $pump_ok && @rejects == 2,
    'permission : an unknown policy value denies' );
delete $data{'kimi'}{'acp'}{'cfg'}{'permission'};
cmd( 'acp-send', 'unknown' );
ok( pump( sub { @{ signals() } >= 4 } ),
    'unknown request : the prompt ends' );
ok( events_text() =~ m{refused : request fs/read_text_file}
        && events_text() =~ m{agent : unknown answered -32601},
    'unknown request : answered with -32601'
);
cmd( 'acp-send', 'garbage' );
ok( pump( sub { @{ signals() } >= 5 } ),
    'stray line : the prompt still ends'
);
ok( events_text() =~ m{raw : this is not json}
        && events_text() =~ m{agent : after garbage},
    'stray line : shown as raw, the session goes on'
);

## utf-8 : octets in, characters in the events, valid utf-8 in the log ##

{
    my $word   = "gr\x{fc}\x{df}e \x{2192} \x{2713}";
    my @want   = map {ord} split //, "uni $word";
    my $count  = @{ signals() };
    my $octets = Encode::encode( 'UTF-8', "uni $word" );
    cmd( 'acp-send', $octets );
    ok( pump( sub { @{ signals() } > $count } ), 'utf-8 : the prompt ends' );
    ok( events_text() =~ m{agent : cp \Q@want\E\b},
        'utf-8 : the child received every code point once, no double encoding'
    );
    ok( index( events_text(), "prompt : uni $word" ) >= 0,
        'utf-8 : the prompt event holds characters'
    );
    cmd( 'acp-send', "uni $word" );    ## already characters ##
    ok( pump( sub { @{ signals() } > $count + 1 } ),
        'utf-8 : a character string ends too'
    );
    my @cp = events_text() =~ m{agent : cp \Q@want\E\b}g;
    ok( @cp == 2, 'utf-8 : octets and characters give the same text' );
    my $bytes = read_file_raw("$tmp/zdir/acp.log");
    my $text = eval { Encode::decode( 'UTF-8', $bytes, Encode::FB_CROAK() ) };
    ok( defined $text && index( $text, "prompt : uni $word" ) >= 0,
        'utf-8 : acp.log is valid utf-8 with the characters in it'
    );
}

## a long text : the write queue and the writable watcher ##

cmd( 'acp-send', 'x' x 300_000 );
ok( pump( sub { @{ signals() } >= 8 } ), 'big text : the prompt ends' );
ok( events_text() =~ m{agent : echo : got 300000 bytes},
    'big text : the child got every byte' );
ok( !length st()->{'wbuf'}, 'big text : the write queue is empty' );

## stop, restart resumes ##

my $before = @{ signals() };
$r = cmd( 'acp-stop', '' );
ok( $r->{'data'} eq 'stopping',  'stop : stopping' );
ok( pump( phase_is('stopped') ), 'stop : the child ends on end of input' );
ok( !alive($pid1),               'stop : the child process is gone' );
ok( @{ signals() } == $before, 'stop : no signal without a running prompt' );
ok( ( $calls{'resume'} // 0 ) >= 1, 'stop : idle shutdown resumed' );
ok( !grep( { $ARG->{'active'} } @watchers ),
    'stop : every watcher is cancelled'
);
ok( cmd( 'acp-stop', '' )->{'mode'} eq 'false',
    'stop : stopping a stopped session says so'
);
ok( read_file("$tmp/zdir/acp.session") =~ m{\Q$sid\E},
    'stop : the stored id is kept' );

cmd( 'acp-start', '' );
ok( pump( phase_is('ready') ), 'resume : the restart reaches ready' );
ok( fake_log() =~ m{session/resume \Q$sid\E},
    'resume : session/resume with the stored id'
);
ok( st()->{'session_id'} eq $sid && events_text() =~ m{ready \[ resume \]},
    'resume : same session id' );
cmd( 'acp-stop', '' );
pump( phase_is('stopped') );

## load when the child cannot resume : the history is a replay [ log only ] ##

$ENV{'FAKE_CAPS'} = 'load';
cmd( 'acp-start', '' );
ok( pump( phase_is('ready') ), 'load : the restart reaches ready' );
ok( fake_log() =~ m{session/load \Q$sid\E},
    'load : session/load when resume is not offered'
);
ok( events_text() !~ m{old (?:question|answer)},
    'load : replayed history is not in the event buffer'
);
my $acp_log = read_file("$tmp/zdir/acp.log");
ok( $acp_log =~ m{replay-user : old question}
        && $acp_log =~ m{replay-agent : old answer},
    'load : replayed history is in the log'
);
cmd( 'acp-stop', '' );
pump( phase_is('stopped') );

## resume fails : a new session ##

$ENV{'FAKE_FAIL_RESUME'} = 1;
cmd( 'acp-start', '' );
ok( pump( phase_is('ready') ),
    'resume failure : falls back to a new session' );
ok( events_text()
        =~ m{error : session/(?:resume|load) failed : no such session}
        && events_text() =~ m{ready \[ new \]},
    'resume failure : said, then a new session'
);
ok( st()->{'session_id'} ne $sid, 'resume failure : a new id' );
my $sid2 = st()->{'session_id'};
cmd( 'acp-stop', '' );
pump( phase_is('stopped') );
delete $ENV{'FAKE_FAIL_RESUME'};
delete $ENV{'FAKE_CAPS'};

## resume=none, a bad parameter ##

$r = cmd( 'acp-start', 'bogus' );
ok( $r->{'mode'} eq 'false', 'start : an unknown parameter is refused' );
cmd( 'acp-start', 'resume=none' );
ok( pump( phase_is('ready') ) && st()->{'session_id'} ne $sid2,
    'start : resume=none starts a new session' );
my $sid_none = st()->{'session_id'};
cmd( 'acp-stop', '' );
pump( phase_is('stopped') );

## autostart : send with no child ##

@routes = ();
$r      = cmd( 'acp-send', 'wake up' );
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{queued},
    'autostart : send starts the session and queues the text'
);
ok( pump( sub { @{ signals() } >= 1 } ),
    'autostart : the text is sent after the handshake' );
ok( events_text() =~ m{agent : echo : wake up}, 'autostart : answered' );
ok( fake_log() =~ m{session/resume \Q$sid_none\E},
    'autostart : resumed the stored id'
);
cmd( 'acp-stop', '' );
pump( phase_is('stopped') );
$data{'kimi'}{'acp'}{'cfg'}{'autostart'} = 'no';
$r = cmd( 'acp-send', 'no child' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{acp-start first},
    'autostart no : send is refused without a session'
);
delete $data{'kimi'}{'acp'}{'cfg'}{'autostart'};

## child crash ##

@routes = ();
cmd( 'acp-start', '' );
pump( phase_is('ready') );
my $pid_crash = st()->{'pid'};
cmd( 'acp-send', 'crash' );
ok( pump( phase_is('stopped') ), 'crash : the dead child is noticed' );
ok( !alive($pid_crash),          'crash : the process is gone' );
ok( ( signals()->[0] // '' ) =~ m{\Akimi\.run\.done state=crashed session=},
    'crash : kimi.run.done state=crashed' );
ok( events_text() =~ m{crash : child ended on its own},
    'crash : shown in the events' );
ok( !defined st()->{'pid'} && !defined st()->{'in'},
    'crash : handles are closed' );
ok( cmd( 'acp-status', '' )->{'data'} =~ m{phase\s+: stopped},
    'crash : status says stopped' );

## stop while a prompt runs : cancel, one signal ##

@routes = ();
cmd( 'acp-start', '' );
pump( phase_is('ready') );
cmd( 'acp-send', 'slow' );
pump( sub { ( st()->{'chunk'} // {} )->{'text'} } );
cmd( 'acp-send', 'dropped by stop' );
cmd( 'acp-stop', '' );
ok( pump( phase_is('stopped') ), 'stop mid prompt : ends' );
ok( @{ signals() } == 1 && signals()->[0] =~ m{state=cancelled},
    'stop mid prompt : one signal, cancelled' );
ok( fake_log() !~ m{prompt dropped by stop},
    'stop mid prompt : the queued text was dropped'
);

## stop during the handshake, nothing queued : no signal ##

@routes = ();
cmd( 'acp-start', '' );
cmd( 'acp-stop',  '' );
ok( pump( phase_is('stopped') ), 'stop in the handshake : ends' );
ok( !@{ signals() },
    'stop in the handshake : no kimi.run.done without a prompt' );

## a child that ignores end of input : TERM from the timer ##

@routes = ();
$ENV{'FAKE_DEAF'} = 1;
cmd( 'acp-start', '' );
pump( phase_is('ready') );
my $pid_deaf = st()->{'pid'};
@timers = ();
cmd( 'acp-stop', '' );
ok( @timers == 1, 'escalation : a timer from base.interval.next is armed' );
my $deadline = time + 8;

while ( st()->{'phase'} ne 'stopped' and time < $deadline ) {
    pump( phase_is('stopped'), 1, TRUE );
    fire_timer() if st()->{'phase'} ne 'stopped';
}
ok( st()->{'phase'} eq 'stopped' && !alive($pid_deaf),
    'escalation : the deaf child is ended by TERM'
);
ok( events_text() =~ m{stop : child still alive : TERM},
    'escalation : TERM is logged' );
delete $ENV{'FAKE_DEAF'};

## zenka exit : kimi.end_code leaves no child ##

cmd( 'acp-start', '' );
pump( phase_is('ready') );
my $pid_exit = st()->{'pid'};
## a forked child of the zenka inherits the state : its END must not touch ##
## the child                                                               ##
my $forked = fork();
if ( !$forked ) {
    $code{'kimi.end_code'}->();
    POSIX::_exit(0);
}
waitpid( $forked, 0 );
ok( alive($pid_exit),
    'end_code : a forked copy of the zenka leaves the child alone' );
$code{'kimi.end_code'}->();
ok( !alive($pid_exit),
    'end_code : the child is gone after the zenka exit hook' );
$code{'kimi.end_code'}->();
ok( 1, 'end_code : a second call with a gone child is harmless' );

## the kimi-send plugin ##

my $plugin = $code{'plugin.events.action.kimi-send'}->();
ok( $plugin->{'name'} eq 'kimi-send'
        && $plugin->{'kind'} eq 'action'
        && length $plugin->{'describe'},
    'plugin : registers as an action'
);
@plugin_sent = ();
$plugin->{'run'}->(
    {   'ev_type' => 'signal',
        'action'  =>
            { 'type' => 'kimi-send', 'message' => "carry   on\nplease" }
    }
);
ok( @plugin_sent == 1
        && $plugin_sent[0]{'command'} eq 'cube.kimi.acp-send'
        && $plugin_sent[0]{'call_args'}{'args'} eq 'carry on please',
    'plugin : sends kimi.acp-send through the cube'
);
ok( !eval {
        $plugin->{'run'}
            ->( { 'ev_type' => 'start', 'action' => { 'message' => 'x' } } );
        1;
    },
    'plugin : refuses a start event'
);
ok( !eval {
        $plugin->{'run'}->(
            { 'ev_type' => 'at', 'action' => { 'type' => 'kimi-send' } } );
        1;
    }
        && $EVAL_ERROR =~ m{message},
    'plugin : refuses a missing message'
);

## a bucket entry checks the command kimi-send sends ##
load_module('events.bucket.action_route');
ok(
    (   $code{'events.bucket.action_route'}->( { 'type' => 'kimi-send' } )
            // ''
    ) eq 'kimi.acp-send',
    'bucket : kimi-send routes to kimi.acp-send'
);

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,.,,.,,,.,,..,,,..,,,,,.,.,,..,.,.,,.,,,,.,..,,...,...,.,.,.,.,...,,,,,.,,,
#NOFL4BTXSHDVCCGG3H5MSDSKYMHOLFKJ442H4ORHUJWLB765TDO33DGILB5CZ3WDSYOPHCWZR52MU
#\\\|LWPZEHYP27JXKZMRUQFJBLMSATZ3DV3NFEAHEVHI4IHP5R2S6UJ \ / AMOS7 \ YOURUM ::
#\[7]4J45MJBPFZIPXY6D4UAS66ZNJV7X63HYSFYV3H3HPXXALK2ZDCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
