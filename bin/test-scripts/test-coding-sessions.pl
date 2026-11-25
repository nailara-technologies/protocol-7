#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
## coding zenka : session registry and cache keep-alive. the real events   ##
## zenka [ bucket, usage.window.reset ] runs in this process with the      ##
## repo's access.zenki \ access.signals ; the cube is a buffer and pump()  ##
## the event loop. every delivery path is a fake command, idle time is the ##
## record's `due` moved into the past. the mcp reporter : the real         ##
## bin/mcp-server-p7 against a fake cube                                   ##

use File::Spec;
use File::Temp qw| tempdir |;
use File::Path qw| make_path |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Date::Parse;
use IPC::Open3 ();
use IO::Select;
use IO::Socket::UNIX;
use Symbol      qw| gensym |;
use POSIX       qw| strftime |;
use Time::HiRes ();

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
use Time::Seconds
    ; ## base.parser.duration needs it and its ONE_* constants [ the zenka loads it ]

my $root_path = $main::root_path;

our %data;
our %code;
our $call;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    die "ok() without a name [ a list-context match ? ]\n" if @ARG != 2;
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
    my ( $src, $name ) = @ARG;
    $src =~ s{\n#[^\n]*\z}{\n} while $src =~ m{\n#[,\[\\|:][^\n]*\z};
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $translated = join '', @seg;
    my $sub        = eval qq|#line 1 "src/$name"\nsub { $translated }|;
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

sub load_module {
    my $name = shift;
    $code{$name}
        = compile_source(
        read_file( File::Spec->catfile( $root_path, 'src', $name ) ), $name );
}

## stubs : log, cube, timers, zenka dir ##

my ( @logged, @timers, @pending, %replies, @cube_log );

sub fmt_log {
    my @a     = @ARG;
    my $level = $a[0] =~ m|\A\d+\z| && @a > 1 ? shift @a : 1;
    my $fmt   = shift @a;
    return "[$level] " . ( @a ? sprintf( $fmt, @a ) : $fmt );
}
our $zenka = 'coding';
my %down;
$code{'base.log'}  = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.logs'} = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.s_warn'}
    = sub { push @logged, 'warn ' . sprintf( shift, @ARG ); TRUE };
$code{'base.time'} = sub {time};
$code{'base.callback.cmd_reply'}
    = sub { $replies{ $ARG[0] } = $ARG[1]; TRUE };
$code{'base.perlmod.loaded'} = sub {FALSE};
$code{'base.perlmod.load'}   = sub { require AMOS7::Switch; TRUE };

my $tmp = tempdir( 'coding-sessions-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
$code{'file.zenka_dir.load'} = sub {
    my $path = "$tmp/zdir/$zenka." . shift;
    return undef if !-f $path;
    my $text = read_file($path);
    return \$text;
};
$code{'file.zenka_dir.write'} = sub {
    my ( $name, $sref ) = @ARG;
    mkdir "$tmp/zdir";
    open my $fh, '>:encoding(UTF-8)', "$tmp/zdir/$zenka.$name" or return;
    print {$fh} $sref->$*;
    close $fh;
    return TRUE;
};

## the cube : route-send buffers, pump() delivers ##
$code{'protocol-7.route-send'} = sub {
    my $c = shift;
    push @cube_log,
        "$zenka> $c->{'command'} " . ( $c->{'call_args'}{'args'} // '' );
    push @pending, { %{$c}, 'from' => $zenka };
    return TRUE;
};
$code{'protocol-7.command.send.local'} = $code{'protocol-7.route-send'};

sub run_cmd {
    my ( $as, $name, $args, $reply_id ) = @ARG;
    local $zenka = $as;
    local $call  = { 'args' => $args, 'reply_id' => $reply_id };
    my $rv = eval { $code{$name}->() };
    if ($EVAL_ERROR) {
        say "# DIE $name : $EVAL_ERROR";
        return { 'mode' => 'false', 'data' => "died : $EVAL_ERROR" };
    }
    return $rv;
}

sub pump {
    my $guard = 0;
    while ( my $c = shift @pending ) {
        die "pump loops\n" if ++$guard > 500;
        my $cmd = $c->{'command'} =~ s{\Acube\.}{}r;
        my ( $target, $sub ) = $cmd =~ m{\A([\w-]+)\.(.+)\z};
        my $rv;
        if ( $down{$target} ) {
            $rv = { 'mode' => 'false', 'data' => 'client not present' };
        } elsif ( $target eq 'events' ) {
            $rv = run_cmd( 'events', "events.cmd.$sub",
                "$c->{'from'} " . ( $c->{'call_args'}{'args'} // '' ) );
        } else {
            $rv = run_cmd( $target, "$target.cmd.$sub",
                $c->{'call_args'}{'args'}, 'silent' );
        }
        next if ref $c->{'reply'} ne 'HASH';
        my $mode  = uc( $rv->{'mode'} // '' );
        my $reply = { 'params' => $c->{'reply'}{'params'} };
        if ( $mode eq 'SIZE' ) {
            $reply->{'data'} = \( $rv->{'data'} );
            $reply->{'cmd'}  = 'SIZE';
        } else {
            $reply->{'cmd'} = $mode;
            ## a true \ false line : newlines escaped on the wire ##
            $reply->{'call_args'}
                = { 'args' => ( $rv->{'data'} // '' ) =~ s{\n}{\\n}gr };
        }
        local $zenka = $c->{'from'};
        $code{ $c->{'reply'}{'handler'} }->($reply);
    }
}

{

    package FakeTimer;
    sub new       { bless { 'active' => 1, 'args' => $_[1] }, $_[0] }
    sub cancel    { $_[0]{'active'} = 0 }
    sub is_active { $_[0]{'active'} }
    sub now       { }
}
$code{'event.add_timer'} = sub {
    my $args = shift;
    push @timers, $args;
    return FakeTimer->new($args);
};

{

    package FakeEvent;
    sub new  { bless { data => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]->{'data'} }
}

my $src = File::Spec->catdir( $root_path, 'src' );
opendir my $dh, $src or die "cannot open src : $OS_ERROR";
my @src = readdir $dh;
closedir $dh;
load_module($ARG) for grep {
    m{\A(?:park\.|events\.(?:plugin|source|fire|handler\.event_triggered|calc_unix|set_up_timers|action\.|access\.|signal\.|cmd\.signal\z|bucket\.|cmd\.bucket-)|plugin\.events\.(?:action|source)\.|base\.interval\.next\z|base\.interval\.rhythm\.|base\.reply\.mode_text\z|coding\.handover\.|coding\.remind\.|coding\.keepalive\.|coding\.sessions\.|coding\.handler\.(?:handover|remind|keepalive)_|coding\.cmd\.(?:handover|remind|keepalive|session))}
} @src;
load_module($ARG) for qw|
    coding.park.store coding.sign_queue.store
    base.n2u_time base.u2n_time base.round_truncate base.parser.duration |;

## the fakes : what the real commands answer ##
my ( %fake, %got, @notified );

sub fake_reset {
    %fake = (
        'claude' => "state   : idle\npid     : 41\nqueued  : 0\n",
        'kimi'   => "phase   : ready\npid     : 42\nqueued  : 0\n",
        'refuse' => {}
    );
    %got = ();
}
$code{'claude.cmd.status'}
    = sub { { 'mode' => 'size', 'data' => $fake{'claude'} } };
$code{'kimi.cmd.acp-status'}
    = sub { { 'mode' => 'size', 'data' => $fake{'kimi'} } };
$code{'claude.cmd.sessions'}
    = sub { { 'mode' => 'true', 'data' => 'no live session registered' } };
$code{'protocol-7-menu.cmd.pending-question-list'}
    = sub { { 'mode' => 'true', 'data' => 'no pending questions' } };
$code{'task.cmd.queue'}
    = sub { { 'mode' => 'false', 'data' => 'no tasks found' } };
foreach my $path (
    qw| claude.cmd.session-post claude.cmd.send kimi.cmd.acp-send
    notify.cmd.message |
) {
    $code{$path} = sub {
        return { 'mode' => 'false', 'data' => 'refused' }
            if $fake{'refuse'}{$path};
        push @{ $got{$path} }, $call->{'args'};
        return { 'mode' => 'true', 'data' => 'taken' };
    };
}

sub delivered {    ## 'path=count ..' of what arrived ##
    return join ' ', map { "$ARG=" . scalar @{ $got{$ARG} } } sort keys %got;
}

my $access_file = "$root_path/cfg/zenki/cube/access.zenki";
my $grants_file = "$root_path/cfg/zenki/events/access.signals";
my %interval    = ();
foreach ( split m{\n}, read_file("$root_path/cfg/zenki/coding/zenka.v7") ) {
    $interval{$1}{$2} = $3
        if m{\Abase\.interval\.cfg\.type\.([\w-]+)\.(\w+)\s*=\s*(\S+)};
}

sub fresh_events {
    $data{'events'} = {
        'bucket_dir' => "$tmp/var",
        'signal'     => {
            'access_file'  => $access_file,
            'grants_file'  => $grants_file,
            'journal_path' => "$tmp/var/signal.journal"
        },
        'setup'   => {},
        'enabled' => {}
    };
}

make_path("$tmp/repo/data/ai-mem/claude");
system( 'git', 'init', '-q', "$tmp/repo" ) == 0 or die "git init\n";
system(
    'git',            '-C',          "$tmp/repo",
    '-c',             'user.name=t', '-c',
    'user.email=t@t', '-c',          'commit.gpgsign=false',
    'commit',         '-q',          '--allow-empty',
    '-m',             'one'
    ) == 0
    or die "git commit\n";

sub reset_all {
    system 'rm', '-rf', "$tmp/var", "$tmp/zdir";
    %data   = ();
    @logged = @timers = @pending = @cube_log = ();
    %down   = ();
    fake_reset();
    fresh_events();
    $data{'coding'}{'cfg'}{'handover_root'} = "$tmp/repo";
    $data{'base'}{'interval'}{'cfg'}{'type'} = {%interval};
}

sub cmd {
    my ( $name, $args ) = @ARG;
    my $rv = run_cmd( 'coding', "coding.cmd.$name", $args // '', 1 );
    pump();
    return $rv;
}

sub rec { $data{'coding'}{'sessions'}{'records'}{ $_[0] } }

sub tick {
    local $zenka = 'coding';
    $code{'coding.keepalive.tick'}->();
    pump();
}
sub timer { $data{'coding'}{'keepalive'}{'timer'} }

## the session goes idle : its due time \ last keep-alive lie in the past ##
sub idle {
    my $name = shift;
    rec($name)->{'due'} = time - 1;
    rec($name)->{'sent'} -= 3600 if defined rec($name)->{'sent'};
}

sub session {
    my ( $name, $type ) = @ARG;
    cmd( 'session-touch', "name=$name type=$type via=tool" );
    return cmd( 'keepalive', "$name on" );
}

## 1. the registry ##
reset_all();
ok( cmd('sessions')->{'data'} eq 'no session known', 'sessions : empty' );
ok( cmd( 'session-touch', 'name=a type=other' )->{'mode'} eq 'false'
        && cmd( 'session-touch', 'type=claude-live' )->{'mode'} eq 'false',
    'session-touch : name and a known type needed'
);
ok( cmd( 'keepalive', 'a on' )->{'mode'} eq 'false',
    'keepalive : an unknown session is refused'
);
cmd( 'session-touch', 'name=claude-7.x type=claude-live via=tool' );
ok( rec('claude-7.x')->{'switch'} eq 'off', 'keep-alive : off by default' );
ok( !defined timer(), 'nothing on : no keep-alive timer' );
my $list = cmd('sessions')->{'data'};
ok( scalar $list =~ m{^claude-7\.x\s+claude-live\s+\S+ ago\s+off$}m,
    'sessions : name, type, activity, keep-alive state'
);
ok( read_file("$tmp/zdir/coding.sessions")
        =~ m{^session\.claude-7\.x\.type = claude-live$}m,
    'registry : p7 config style in the zenka dir'
);
cmd( 'keepalive-pending', "claude-7.x waits for the owner's \x{e4} = : #" );
delete $data{'coding'}{'sessions'};
cmd('sessions');
ok( rec('claude-7.x')->{'pending'} eq "waits for the owner's \x{e4} = : #"
        && rec('claude-7.x')->{'type'} eq 'claude-live',
    'registry : survives a restart, a dotted name and a marker kept'
);
cmd( 'keepalive-pending', 'claude-7.x -' );
ok( !defined rec('claude-7.x')->{'pending'}, 'marker : - clears it' );

my @delays = map { $code{'coding.keepalive.delay'}->() } 1 .. 233;
ok( !( grep { $_ > 55 * 60 or $_ < 45 * 60 } @delays ),
    'delay : about 54 minutes, never past the ceiling'
);

## 2. idle : pending -> one message, nothing pending -> none ##
reset_all();
session( 'live', 'claude-live' );
ok( timer()->{'args'}{'after'} > 45 * 60,
    'on : the timer waits the idle time'
);
tick();
ok( delivered() eq '', 'not idle yet : nothing sent' );
idle('live');
tick();
ok( delivered() eq '', 'idle, nothing pending : none' );
ok( rec('live')->{'due'} > time + 45 * 60 && rec('live')->{'count'} == 0,
    'idle, nothing pending : the next look an idle time later'
);
cmd( 'keepalive-pending', 'live the kimi review' );
idle('live');
tick();
ok( delivered() eq 'claude.cmd.session-post=1',
    'idle + pending : one message, claude-live -> claude.session-post' );
ok( scalar $got{'claude.cmd.session-post'}[0]
        =~ m{\Ato=live from=coding keep-alive \[ 1 of 6 \] pending : the kimi review },
    'message : to the session, names what is pending'
);
tick();
ok( delivered() eq 'claude.cmd.session-post=1', 'a second tick : no repeat' );

## 3. what counts as pending ##
reset_all();
session( 'live', 'claude-live' );
$fake{'claude'} = "state   : running [ turn running ]\npid     : 41\n";
$fake{'kimi'}   = "phase   : prompting\npid     : 42\n";
cmd( 'session-touch', 'name=live type=claude-live via=state dispatches=2' );
$data{'coding'}{'sign_queue'}{'records'} = {
    'entry' => {
        'sq-1' => { 'status' => 'signing' },
        'sq-2' => { 'status' => 'committed' }
    },
    'plan' => { 'plan-1' => { 'status' => 'waiting' } }
};
$data{'coding'}{'remind'}{'records'}
    = { 'remind-1' => { 'status' => 'undelivered' } };
run_cmd( 'events', 'events.cmd.bucket-add',
          'coding remind-2 after=bucket-wait action=send-command '
        . 'command="coding.remind-fire x" reason="r"' );
$data{'base'}{'interval'}{'cfg'}{'type'}{'bucket-wait'} = { 'minutes' => 13 };
run_cmd( 'events', 'events.cmd.bucket-add',
          'coding remind-3 after=bucket-wait action=send-command '
        . 'command="coding.remind-fire y" reason="r"' );
@pending = ();
idle('live');
tick();
my $text = $got{'claude.cmd.session-post'}[0] // '';
ok( scalar $text =~ m{2 dispatch\(es\) running},
    'pending : a running dispatch' );
ok( scalar $text =~ m{sign queue : sq-1 ;}
        && $text =~ m{commit plans : plan-1},
    'pending : open signs and plans, not the committed one'
);
ok( scalar $text =~ m{[2-3] reminder\(s\) waiting},
    'pending : undelivered and waiting reminders'
);
ok( scalar $text =~ m{claude zenka run ; kimi zenka run},
    'pending : runs of the claude and kimi zenka'
);

## 4. the other delivery paths ##
foreach my $case (
    [ 'claude-zenka', 'claude-zenka', 'claude.cmd.send' ],
    [ 'kimi-acp',     'kimi-acp',     'kimi.cmd.acp-send' ],
    [ 'kimi-9',       'kimi-tui',     'notify.cmd.message' ]
) {
    my ( $name, $type, $path ) = @{$case};
    reset_all();
    session( $name, $type );
    cmd( 'keepalive-pending', "$name a thing" );
    idle($name);
    tick();
    ok( delivered() eq "$path=1"
            && $got{$path}[0] =~ m{keep-alive \[ 1 of 6 },
        "delivery : $type -> $path"
    );
}
ok( scalar $got{'notify.cmd.message'}[0]
        =~ m{\Akimi-9 not reachable \[ kimi tui \]},
    'delivery : a kimi tui is only notified about'
);
reset_all();
session( 'kimi-acp', 'kimi-acp' );
cmd( 'keepalive-pending', 'kimi-acp x' );
$fake{'kimi'} = "phase   : stopped\npid     : -\n";
idle('kimi-acp');
tick();
ok( delivered() eq '',
    'kimi acp stopped : not sent to [ it would start one ]' );
reset_all();
session( 'claude-zenka', 'claude-zenka' );
cmd( 'keepalive-pending', 'claude-zenka x' );
$fake{'claude'} = "state   : idle\npid     : -\n";
idle('claude-zenka');
tick();
ok( delivered() eq '', 'claude zenka without a process : not sent to' );
$fake{'claude'} = "state   : running [ turn running ]\npid     : 41\n";
idle('claude-zenka');
tick();
ok( delivered() eq '', 'its own turn running : not idle' );

## 5. the cap : 6 in a row, echoes are no activity ##
reset_all();
session( 'kimi-acp', 'kimi-acp' );
cmd( 'keepalive-pending', 'kimi-acp x' );
foreach my $n ( 1 .. 5 ) {
    idle('kimi-acp');
    tick();
    ## the zenka reports the prompt, the session answers with a tool ##
    cmd( 'session-touch', 'name=kimi-acp type=kimi-acp via=keepalive' );
    cmd( 'session-touch', 'name=kimi-acp type=kimi-acp via=tool' );
}
ok( rec('kimi-acp')->{'count'} == 5 && rec('kimi-acp')->{'switch'} eq 'on',
    'cap : the keep-alive and its answer reset nothing' );
idle('kimi-acp');
tick();
ok( @{ $got{'kimi.cmd.acp-send'} } == 6
        && $got{'kimi.cmd.acp-send'}[5]
        =~ m{\[ 6 of 6 \].*keep-alive now off},
    'cap : the 6th message says it is the last'
);
ok( rec('kimi-acp')->{'switch'} eq 'off'
        && cmd('sessions')->{'data'} =~ m{off \[ 6 keep-alives in a row},
    'cap : switched itself off, the list says why'
);
idle('kimi-acp');
tick();
ok( @{ $got{'kimi.cmd.acp-send'} } == 6, 'cap : no 7th message' );
cmd( 'keepalive', 'kimi-acp on' );
idle('kimi-acp');
tick();
rec('kimi-acp')->{'sent'} -= 3600;
cmd( 'session-touch', 'name=kimi-acp type=kimi-acp via=prompt' );
ok( rec('kimi-acp')->{'count'} == 0,
    'cap : other activity resets the count' );

## 6. switch off \ timed ##
reset_all();
session( 'live', 'claude-live' );
cmd( 'keepalive-pending', 'live x' );
ok( cmd( 'keepalive', 'live off' )->{'mode'} eq 'true' && !defined timer(),
    'off : the timer is gone' );
idle('live');
tick();
ok( delivered() eq '', 'off : nothing sent' );
ok( cmd( 'keepalive', 'live on for=soon' )->{'mode'} eq 'false'
        && cmd( 'keepalive', 'live off for=1h' )->{'mode'} eq 'false',
    'timed : a bad span refused'
);
cmd( 'keepalive', 'live on for=2h' );
ok( abs( rec('live')->{'until'} - time - 7200 ) < 5
        && cmd('sessions')->{'data'} =~ m{on \[ 0 of 6, 1\d\dm left \]},
    'timed : on for the span'
);
rec('live')->{'until'} = time - 1;
idle('live');
tick();
ok( delivered() eq '' && rec('live')->{'switch'} eq 'off',
    'timed : ended, switched off, nothing sent'
);

## 7. refused delivery, a silent source ##
reset_all();
session( 'live', 'claude-live' );
cmd( 'keepalive-pending', 'live x' );
$fake{'refuse'}{'claude.cmd.session-post'} = 1;
idle('live');
tick();
ok( rec('live')->{'count'} == 0
        && !defined rec('live')->{'sent'}
        && rec('live')->{'due'} < time + 400,
    'refused : not counted, tried again soon'
);
foreach ( 2 .. 6 ) { rec('live')->{'due'} = time - 1; tick() }
ok( rec('live')->{'switch'} eq 'off'
        && rec('live')->{'note'} =~ m{not deliverable},
    'refused : as often as the cap, then off'
);
reset_all();
session( 'live', 'claude-live' );
cmd( 'keepalive-pending', 'live x' );
idle('live');
{
    local $zenka = 'coding';
    $code{'coding.keepalive.tick'}->();
}
@pending = ();    ## no source ever answers ##
$data{'coding'}{'keepalive'}{'round'}{'at'} -= 100;
tick();
ok( delivered() eq 'claude.cmd.session-post=1',
    'a silent source : the round is decided with what came' );

## 8. the hand-over at the 5h reset ##
reset_all();
session( 'lead', 'claude-live' );
cmd( 'session-touch', 'name=quiet type=claude-live via=tool' );
cmd( 'session-touch', 'name=kimi-old type=kimi-tui via=tool' );
cmd( 'session-touch', 'name=kimi-acp type=kimi-acp via=prompt' );
rec('kimi-old')->{'last'} -= 7000;

sub signal {
    my ($args) = @ARG;
    my $rv = run_cmd( 'usage', 'events.cmd.signal', "usage $args" );
    pump();
    return $rv;
}
signal('usage.window.reset provider=kimi window=5h');
signal('usage.window.reset provider=claude window=7d');
ok( delivered() eq '', 'reset : other providers and windows are ignored' );
my $rv = signal('usage.window.reset provider=claude window=5h');
ok( $rv->{'mode'} eq 'true', 'reset : the real signal grants' );
ok( delivered() eq 'claude.cmd.session-post=1'
        && $got{'claude.cmd.session-post'}[0] =~ m{\Ato=lead from=coding },
    'reset : only the claude-live sessions kept alive'
);
ok( scalar $got{'claude.cmd.session-post'}[0]
        =~ m{window reset : kimi session kimi-acp is leading \[ active 0 min ago \] ; handover is current : \S+handover-live\.md},
    'reset : the line names the leader and the handover'
);
ok( -f "$tmp/repo/data/ai-mem/claude/handover-live.md",
    'reset : the handover written first' );
ok( rec('lead')->{'count'} == 0, 'reset : the post is not counted' );
signal('usage.window.reset provider=claude window=5h');
ok( @{ $got{'claude.cmd.session-post'} } == 2, 'reset : the watch re-armed' );
delete $data{'coding'}{'sessions'}{'records'}{$_} for qw| kimi-old kimi-acp |;
$data{'coding'}{'cfg'}{'handover_root'} = "$tmp/nowhere";
signal('usage.window.reset provider=claude window=5h');
ok( scalar $got{'claude.cmd.session-post'}[2]
        =~ m{no kimi session is leading ; handover not written : },
    'reset : no leader, a failed write is said so'
);

## 9. the zenka reporters tag a keep-alive ##
reset_all();
load_module($ARG) for qw| claude.turn.next kimi.acp.next_prompt |;
$code{'claude.child.write'} = sub {TRUE};
$code{'claude.event.add'}   = $code{'claude.signal.raise'} = sub {TRUE};
$code{'kimi.acp.event'}     = $code{'kimi.acp.rpc'}        = sub {TRUE};
my $st = {
    'phase' => 'ready',
    'queue' => [ 'go', 'keep-alive [ 1 of 6 ] pending : x' ],
    'turns' => 0
};
$code{'kimi.acp.state'}  = sub {$st};
$data{'claude'}{'child'} = { 'in' => 1 };
$data{'claude'}{'queue'} = [ 'keep-alive [ 1 of 6 ] pending : x', 'go' ];
@cube_log                = ();

foreach ( 1, 2 ) {
    $code{'claude.turn.next'}->();
    $data{'claude'}{'turn_active'} = FALSE;
    $code{'kimi.acp.next_prompt'}->();
    $st->{'phase'} = 'ready';
}
my @touch = map {m{coding\.session-touch (.*)}} @cube_log;
ok( join( ' ; ', @touch ) eq
        'name=claude-zenka type=claude-zenka via=keepalive ; name=kimi-acp '
        . 'type=kimi-acp via=prompt ; name=claude-zenka '
        . 'type=claude-zenka via=turn ; name=kimi-acp type=kimi-acp '
        . 'via=keepalive',
    'reporters : claude turns and kimi acp prompts, keep-alives tagged'
);

## 10. the mcp server reporter, against a fake cube ##
sub mcp_run {
    my ( $label, $command, %env ) = @ARG;
    my $path   = "$tmp/c-$label.sock";
    my $record = "$tmp/record-$label";
    my $users  = "  cube   12:00:00  1\n"
        . ( delete $env{'FAKE_ABSENT'} ? '' : "  coding 12:00:01  1\n" );
    my $listen = IO::Socket::UNIX->new(
        'Type'   => SOCK_STREAM,
        'Local'  => $path,
        'Listen' => 5
    ) // die "fake cube : $OS_ERROR";
    my $inbox = IO::Socket::UNIX->new(
        'Type'   => SOCK_STREAM,
        'Local'  => "$tmp/i-$label.sock",
        'Listen' => 5
    ) // die "fake inbox : $OS_ERROR";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( not $pid ) {
        open my $rec, '>>:raw', $record or die $OS_ERROR;
        $rec->autoflush(1);
        while ( IO::Select->new($listen)->can_read(13) ) {
            my $c = $listen->accept // next;
            $c->autoflush(1);
            print {$c} "\\\\PROTOCOL-7-VERSION\\\\ fake\n";
            while ( defined( my $line = <$c> ) ) {
                print {$rec} $line;
                if    ( $line =~ m{\Aauth } ) { print {$c} "AUTH_TRUE ok\n" }
                elsif ( $line =~ m{\Aclose} ) {last}
                elsif ( $line =~ m{\+\n\z} ) {
                    while ( defined( my $more = <$c> ) ) {
                        last if $more eq ".\n";
                    }
                    print {$c} "TRUE registered\n";
                } elsif ( $line =~ m{\Alist users$} ) {
                    print {$c} 'SIZE ', length($users), "\n", $users;
                } else {
                    print {$c} "TRUE ok\n";
                }
            }
            close $c;
        }
        POSIX::_exit(0);
    }
    close $listen;
    local %ENV = %ENV;
    delete @ENV{
        qw| P7_SESSION_REGISTER P7_SESSION_REPORT P7_SESSION_NAME
            CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN
            CLAUDE_CODE_SESSION_ID |
    };
    my $live = delete $env{'FAKE_LIVE'};
    %ENV = (
        %ENV,
        'PROTOCOL_7_UNIX_PATH' => $path,
        'HOME'                 => $tmp,
        'P7_SESSION_NAME'      => 'mcp-test',
        (   $live
            ? ( 'CLAUDE_CODE_MESSAGING_SOCKET' => "$tmp/i-$label.sock",
                'CLAUDE_CODE_MESSAGING_TOKEN'  => 'not-a-token'
                )
            : ()
        ),
        %env
    );
    my $err = gensym;
    my $mcp = IPC::Open3::open3( my $in, my $out, $err, $EXECUTABLE_NAME,
        qw| -C31 |, "$root_path/bin/mcp-server-p7" );
    sleep 2;
    foreach my $id ( 1, 2 ) {
        syswrite( $in,
                  qq|{"jsonrpc":"2.0","id":$id,"method":"tools/call",|
                . qq|"params":{"name":"p7_command",|
                . qq|"arguments":{"command":"$command"}}}\n| );
        sleep 1;
    }
    close $in;
    { local $INPUT_RECORD_SEPARATOR = undef; my $drain = <$err> }
    waitpid $mcp, 0;
    kill 'TERM', $pid;
    waitpid $pid, 0;
    return -f $record ? read_file($record) : '';
}
sub touches { return [ $_[0] =~ m{^(coding\.session-touch .*)$}mg ] }

my $seen = mcp_run(
    'live', 'list sessions',
    'FAKE_LIVE' => 1,
    'AI_AGENT'  => 'claude-code'
);
ok( @{ touches($seen) } == 1
        && touches($seen)->[0] eq 'coding.session-touch name=mcp-test '
        . 'type=claude-live via=tool '
        . 'dispatches=0',
    'mcp : claude live reports once for two calls inside a minute'
);
$seen = mcp_run( 'kimi', 'list sessions', 'AI_AGENT' => 'kimi' );
ok( ( touches($seen)->[0] // '' ) =~ m{name=mcp-test type=kimi-tui },
    'mcp : under kimi it reports a kimi tui' );
foreach my $var (qw| P7_SESSION_REGISTER P7_SESSION_REPORT |) {
    $seen = mcp_run(
        lc $var, 'list sessions',
        'FAKE_LIVE' => 1,
        'AI_AGENT'  => 'claude-code',
        $var        => 'no'
    );
    ok( $seen =~ m{^list sessions$}m && !@{ touches($seen) },
        "mcp : a dispatched run [ $var=no ] does not report"
    );
}
$seen = mcp_run(
    'absent', 'list sessions',
    'FAKE_LIVE'   => 1,
    'AI_AGENT'    => 'claude-code',
    'FAKE_ABSENT' => 1
);
ok( $seen =~ m{^list users$}m && !@{ touches($seen) },
    'mcp : an absent coding zenka is not started for a report'
);
$seen = mcp_run(
    'first', 'coding.keepalive mcp-test on',
    'FAKE_LIVE' => 1,
    'AI_AGENT'  => 'claude-code'
);
ok( scalar $seen
        =~ m{^coding\.session-touch .*?^coding\.keepalive mcp-test on$}ms,
    'mcp : the session is known before it switches keep-alive on'
);
$seen = mcp_run(
    'first-absent', 'coding.keepalive mcp-test on',
    'FAKE_LIVE'   => 1,
    'AI_AGENT'    => 'claude-code',
    'FAKE_ABSENT' => 1
);
ok( scalar $seen
        =~ m{^coding\.session-touch .*?^coding\.keepalive mcp-test on$}ms,
    'mcp : also with coding not running [ the command starts it ]'
);

## 11. the stable session id ##
my $sid_1 = '11111111-2222-4333-8444-555555555555';
my $sid_2 = '99999999-aaaa-4bbb-8ccc-dddddddddddd';

sub touch {
    my ( $name, $sid, $via ) = @ARG;
    return cmd( 'session-touch',
              "name=$name type=claude-live via="
            . ( $via // 'tool' )
            . ( defined $sid ? " sid=$sid" : '' ) );
}
reset_all();
ok( touch( 'a', 'not-a-uuid' )->{'mode'} eq 'false', 'sid : a uuid only' );
touch( 'claude-1446', $sid_1 );
cmd( 'keepalive',         'claude-1446 on' );
cmd( 'keepalive-pending', 'claude-1446 the review' );
rec('claude-1446')->{'count'} = 3;
rec('claude-1446')->{'sent'}  = time;         ## the next report is an echo ##
rec('claude-1446')->{'last'}  = time - 500;
my $last = rec('claude-1446')->{'last'};
touch( 'claude-1292', $sid_1 );
my $new = rec('claude-1292') // {};
ok( !defined rec('claude-1446') && ( $new->{'switch'} // '' ) eq 'on',
    'same sid, new name : one record, keep-alive still on'
);
ok( ( $new->{'count'} // 0 ) == 3
        && ( $new->{'pending'} // '' ) eq 'the review'
        && ( $new->{'last'}    // 0 ) == $last,
    'same sid : count, pending marker, last activity carried over'
);
delete $data{'coding'}{'sessions'};           ## a restart ##
$list = cmd('sessions')->{'data'};
ok( scalar $list =~ m{^claude-1292 \[ was claude-1446 \]\s+claude-live}m,
    'sessions : the former name is shown, after a restart too'
);
ok( cmd('sessions')->{'data'} !~ m{was claude-1446},
    'sessions : shown once' );
delete $data{'coding'}{'sessions'};
ok( cmd( 'keepalive-pending', 'claude-1446 more' )->{'mode'} eq 'true'
        && rec('claude-1292')->{'pending'} eq 'more',
    'the old name resolves, also after a restart'
);
idle('claude-1292');
tick();
ok( ( $got{'claude.cmd.session-post'}[0] // '' )
        =~ m{\Ato=claude-1292 sid=$sid_1 from=coding keep-alive},
    'keep-alive : to the new name, with the sid'
);

## reminders : set for a name, delivered to the name of its sid ##
reset_all();
touch( 'claude-1446', $sid_1 );
$data{'base'}{'interval'}{'cfg'}{'type'}{'bucket-wait'} = { 'minutes' => 13 };
cmd( 'remind', 'after=bucket-wait to=session:claude-1446 look here' );
my ($fire) = map {m{(remind-\d+ session:claude-1446\@$sid_1)}} @cube_log;
ok( defined $fire, 'remind to=session : the sid is recorded with the name' );
touch( 'claude-1292', $sid_1 );
$fake{'refuse'}{'claude.cmd.session-post'}
    = $fake{'refuse'}{'notify.cmd.message'} = 1;
cmd( 'remind-fire', ( $fire // 'remind-1 session:x' ) . ' look here' );
my ($kept) = values %{ $data{'coding'}{'remind'}{'records'} };
ok( ( $kept->{'sid'} // '' ) eq $sid_1
        && $kept->{'to'} eq 'session:claude-1446',
    'reminder record : name and sid kept apart'
);
%{ $fake{'refuse'} } = ();
$data{'coding'}{'remind'}   = {};    ## read from the file again ##
$data{'coding'}{'sessions'} = {};
cmd('remind-wake');
ok( ( $got{'claude.cmd.session-post'}[-1] // '' ) eq
        "to=claude-1292 sid=$sid_1 reminder : look here from=coding",
    'a reminder for the old name arrives at the new one'
);
cmd( 'remind-fire', 'remind-77 session:claude-1446 by name only' );
ok( ( $got{'claude.cmd.session-post'}[-1] // '' )
        =~ m{\Ato=claude-1292 sid=$sid_1 reminder : by name only},
    'one recorded by the old name only arrives too'
);

## another sid stays separate, also under a reused name ##
reset_all();
touch( 'claude-7', $sid_1 );
cmd( 'keepalive',         'claude-7 on' );
cmd( 'keepalive-pending', 'claude-7 first one' );
rec('claude-7')->{'due'} = time - 1;
touch( 'claude-7', $sid_2, 'state' );
ok( rec('claude-7')->{'sid'} eq $sid_1,
    'a state report of another sid takes no name' );
touch( 'claude-7', $sid_2 );
ok( rec('claude-7')->{'sid'} eq $sid_2
        && rec('claude-7')->{'switch'} eq 'off'
        && !defined rec('claude-7')->{'pending'},
    'another sid under the same name : nothing taken over'
);
ok( ( rec("prev-$sid_1")->{'pending'} // '' ) eq 'first one'
        && !defined timer(),
    'the former one is parked with its state, not kept alive'
);
tick();
ok( delivered() eq '', 'parked : nothing sent' );
delete $data{'coding'}{'sessions'};
touch( 'claude-9', $sid_1 );
ok( rec('claude-9')->{'switch'} eq 'on'
        && rec('claude-9')->{'pending'} eq 'first one'
        && !rec('claude-9')->{'parked'}
        && !defined rec("prev-$sid_1")
        && rec('claude-7')->{'sid'} eq $sid_2,
    'parked : back under a new name with its state'
);
ok( !defined $data{'coding'}{'sessions'}{'aliases'}{'claude-7'},
    'a name in use by another sid is no alias' );
touch( 'claude-7', $sid_1 );
ok( rec('claude-7')->{'sid'} eq $sid_1
        && rec("prev-$sid_2")->{'sid'} eq $sid_2
        && !defined rec('claude-9'),
    'a swapped name : both records stay'
);

## stale old names run out ; one used again points nowhere else ##
reset_all();
touch( 'old', $sid_1 );
touch( 'new', $sid_1 );
my $alias = $data{'coding'}{'sessions'}{'aliases'}{'old'};
ok( $alias->{'until'} - time > 12 * 86400, 'old name : kept for long' );
$alias->{'until'} = time - 1;
ok( cmd( 'keepalive', 'old on' )->{'mode'} eq 'false',
    'old name : not followed after its time'
);
touch( 'new', $sid_1 );
ok( !exists $data{'coding'}{'sessions'}{'aliases'}{'old'}
        && read_file("$tmp/zdir/coding.sessions") !~ m{^alias\.}m,
    'old name : dropped from the file'
);
touch( 'newer', $sid_1 );
touch('new');
ok( !exists $data{'coding'}{'sessions'}{'aliases'}{'new'}
        && !defined rec('new')->{'sid'}
        && rec('newer')->{'sid'} eq $sid_1,
    'no sid under an old name : a session of its own'
);

## without a sid : as before ##
reset_all();
touch('plain');
cmd( 'keepalive-pending', 'plain x' );
cmd( 'keepalive',         'plain on' );
idle('plain');
tick();
ok( $got{'claude.cmd.session-post'}[0] =~ m{\Ato=plain from=coding }
        && read_file("$tmp/zdir/coding.sessions") !~ m{sid|alias|was},
    'no sid : no sid in the message or the file'
);

## the mcp reporter and its sid ##
$seen = mcp_run(
    'sid', 'coding.remind after=x look',
    'FAKE_LIVE'              => 1,
    'AI_AGENT'               => 'claude-code',
    'CLAUDE_CODE_SESSION_ID' => $sid_1
);
ok( ( touches($seen)->[0] // '' ) =~ m{ dispatches=0 sid=$sid_1\z},
    'mcp : a report carries the sid' );
ok( $seen
        =~ m{^coding\.session-touch .*?^coding\.remind to=session:mcp-test }ms,
    'mcp : the session is known before a reminder records it'
);
$seen = mcp_run(
    'kimi-sid', 'list sessions',
    'AI_AGENT'               => 'kimi',
    'CLAUDE_CODE_SESSION_ID' => $sid_1
);
ok( @{ touches($seen) } && $seen !~ m{sid=},
    'mcp : under kimi an inherited claude id is not sent' );

say "\n# pass $pass fail $fail";
exit( $fail ? 1 : 0 );

#,,,,,...,.,,,,..,.,,,,..,.,,,,..,.,,,,..,,,.,..,,...,...,...,,,.,,..,..,,...,
#BAYLPYWKE2F3GE3LRJUKEGVGTQ5PRUGYHBJT5VC3CYSMI5PHTA6Y3DTJQRKPZDPEYSQB6WK6RKLH2
#\\\|ZSNV5W4FCXC3SULGJBI3OJ5WH5ULFUJQVTX7LMG6WDCXEUL7CFI \ / AMOS7 \ YOURUM ::
#\[7]FOVY33TEVN7X7USYLBLISBBBBYF7KWQKOHQHRYNQHE3O3A2O5UAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
