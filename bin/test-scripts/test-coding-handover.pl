#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
## coding zenka : live handover state and reminders with a target.  the    ##
## real events zenka [ buckets, signals, send-command ] runs in this       ##
## process with the repo's access.zenki \ access.signals ; the cube is a   ##
## buffer [ route-send ] and pump() the event loop. claude \ kimi \ menu \ ##
## task \ notify are fake commands. git : a tmp repo with an upstream.  a  ##
## restart drops memory, files stay                                        ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Date::Parse;
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

## stubs : log, cube, timers, task persistence ##

my ( @logged, @timers, @pending, %replies, @cube_log );

sub fmt_log {
    my @a     = @ARG;
    my $level = $a[0] =~ m|\A\d+\z| && @a > 1 ? shift @a : 1;
    my $fmt   = shift @a;
    return "[$level] " . ( @a ? sprintf( $fmt, @a ) : $fmt );
}
our $zenka = 'coding';
my %down;    ## zenki not present ##
$code{'base.log'}  = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.logs'} = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.s_warn'}
    = sub { push @logged, 'warn ' . sprintf( shift, @ARG ); TRUE };
$code{'base.time'} = sub {time};
$code{'base.callback.cmd_reply'}
    = sub { $replies{ $ARG[0] } = $ARG[1]; TRUE };

my $tmp = tempdir( 'coding-handover-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
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
    push @cube_log, "$zenka> $c->{'command'} $c->{'call_args'}{'args'}";
    push @pending, { %{$c}, 'from' => $zenka };
    return TRUE;
};
$code{'protocol-7.command.send.local'} = sub {
    my $c = shift;
    push @cube_log,
        "$zenka> $c->{'command'} " . ( $c->{'call_args'}{'args'} // '' );
    push @pending, { %{$c}, 'from' => $zenka };
    return TRUE;
};

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
    m{\A(?:park\.|events\.(?:plugin|source|fire|handler\.event_triggered|calc_unix|set_up_timers|action\.|access\.|signal\.|cmd\.signal\z|bucket\.|cmd\.bucket-)|plugin\.events\.(?:action|source)\.|base\.interval\.next\z|base\.interval\.rhythm\.|base\.reply\.mode_text\z|coding\.handover\.|coding\.remind\.|coding\.handler\.(?:handover|remind)_|coding\.cmd\.(?:handover|remind))}
} @src;
load_module($ARG) for qw|
    coding.park.store coding.sign_queue.store
    base.n2u_time base.u2n_time base.round_truncate |;

## the fakes : what the real commands answer ##
my %fake = (
    'claude' => "state   : running [ turn running ]\npid     : "
        . "41\nsession : s-1\nturn    : 3\nqueued  : 0\n",
    'kimi'     => "phase   : idle\npid     : -\nqueued  : 0\n",
    'decision' => "no pending questions\n",
    'parked'   => undef,
    'live'     => 1
);
my ( @posted, @notified );
$code{'claude.cmd.status'}
    = sub { { 'mode' => 'size', 'data' => $fake{'claude'} } };
$code{'kimi.cmd.acp-status'}
    = sub { { 'mode' => 'size', 'data' => $fake{'kimi'} } };
$code{'protocol-7-menu.cmd.pending-question-list'}
    = sub { { 'mode' => 'true', 'data' => $fake{'decision'} } };
$code{'task.cmd.queue'} = sub {
    return { 'mode' => 'false', 'data' => 'no tasks found' }
        if not defined $fake{'parked'};
    return { 'mode' => 'size', 'data' => $fake{'parked'} };
};
$code{'claude.cmd.sessions'} = sub {
    return { 'mode' => 'true', 'data' => 'no live session registered' }
        if not defined $fake{'sessions'};
    return { 'mode' => 'size', 'data' => $fake{'sessions'} };
};
$code{'claude.cmd.session-post'} = sub {
    return { 'mode' => 'false', 'data' => 'no live session registered' }
        if not $fake{'live'};
    push @posted, $call->{'args'};
    return { 'mode' => 'true', 'data' => 'posted into live session s' };
};
$code{'notify.cmd.message'} = sub {
    push @notified, $call->{'args'};
    return { 'mode' => 'true', 'data' => 'shown' };
};

my $access_file = "$root_path/cfg/zenki/cube/access.zenki";
my $grants_file = "$root_path/cfg/zenki/events/access.signals";

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

## git : a repo with an upstream, one commit pushed, two not, a deploy tag ##
my $repo = "$tmp/repo";
my $git  = sub {
    system(
        'git',                  '-C', $repo,            '-c',
        'user.name=t',          '-c', 'user.email=t@t', '-c',
        'commit.gpgsign=false', @ARG
        ) == 0
        or die "git @ARG failed\n";
};
mkdir $repo;
mkdir "$repo/data";
mkdir "$repo/data/ai-mem";
mkdir "$repo/data/ai-mem/claude";
system( 'git', 'init', '-q', '-b', 'base', $repo ) == 0 or die "git init\n";
system( 'git', 'init', '-q', '--bare', "$tmp/up.git" ) == 0 or die "bare\n";
$git->( 'commit', '-q',  '--allow-empty', '-m', 'one pushed' );
$git->( 'remote', 'add', 'origin',        "$tmp/up.git" );
$git->( 'push',   '-q',  '-u',            'origin', 'base' );
$git->( 'tag',    'deployed-test' );
$git->( 'commit', '-q', '--allow-empty', '-m', 'two local' );
$git->( 'commit', '-q', '--allow-empty', '-m', 'three local' );
## another memory file : must stay as it is ##
open my $mfh, '>', "$repo/data/ai-mem/claude/MEMORY.md" or die;
print {$mfh} "keep\n";
close $mfh;

sub reset_all {
    system 'rm', '-rf', "$tmp/var", "$tmp/zdir";
    %data    = ();
    @logged  = @timers = @pending = @cube_log = @posted = @notified = ();
    %replies = ();
    %down    = ();
    fresh_events();
    $data{'coding'}{'cfg'}{'handover_root'}         = $repo;
    $data{'coding'}{'cfg'}{'handover_deployed_ref'} = 'deployed-test';
    $data{'base'}{'interval'}{'cfg'}{'type'}{'remind-test'}
        = { 'start' => 34, 'factor' => 1.2, 'cap' => 89, 'cap_jitter' => 13 };
    ## the retry rhythm as the zenka is configured ##
    $data{'base'}{'interval'}{'cfg'}{'type'}{'coding-remind-retry'}
        = { read_file("$root_path/cfg/zenki/coding/zenka.v7")
            =~ m{^base\.interval\.cfg\.type\.coding-remind-retry\.(\w+)\s*=\s*(\S+)}mg
        };
}

sub entry { $data{'events'}{'buckets'}{ $_[0] }{'entries'}{ $_[1] } }

sub fire_timer {
    my ( $owner, $id ) = @ARG;
    local $zenka = 'events';
    $code{'events.handler.event_triggered'}->(
        FakeEvent->new(
            { 'type' => 'at', 'id' => "$owner/$id", 'at' => time }
        )
    );
}

sub restart_all {    ## memory gone, files stay ##
    my $base = $data{'base'};
    my $cfg  = $data{'coding'}{'cfg'};
    %data = ( 'base' => $base, 'coding' => { 'cfg' => $cfg } );
    fresh_events();
    @pending = @cube_log = ();
    local $zenka = 'events';
    $code{'events.bucket.start'}->();
}

sub coding_start {
    local $zenka = 'coding';
    $code{'coding.handover.start'}->( FakeEvent->new( {} ) );
    pump();
}

sub signal {
    my ( $from, $args ) = @ARG;
    my $rv = run_cmd( $from, 'events.cmd.signal', "$from $args" );
    pump();
    return $rv;
}

## 1. start : watches armed, every source asked ##
reset_all();
coding_start();
ok(
    (   grep {
            ( entry( 'coding', "handover-watch-$ARG" ) // {} )->{'state'}
                // '' eq 'waiting'
        } qw| claude kimi decision |
    ) == 3,
    'start : three watch entries wait in the coding bucket'
);
ok( entry( 'coding', 'handover-watch-claude' )->{'on'} eq 'claude.run.done'
        && entry( 'coding', 'handover-watch-decision' )->{'on'} eq
        'decision.answered',
    'start : each watch waits for its signal'
);
ok(
    (   grep { $data{'coding'}{'handover'}{'state'}{'watch'}{$ARG}{'ok'} }
            qw| claude kimi decision |
    ) == 3,
    'start : the events zenka accepted every watch [ real grants ]'
);
ok( join(
        ' ', sort keys %{ $data{'coding'}{'handover'}{'state'}{'source'} }
    ) eq 'claude decision kimi task',
    'start : claude, kimi, decisions, parked tasks asked'
);

## 2. the rendered block ##
my $rv   = run_cmd( 'coding', 'coding.cmd.handover', '', 1 );
my $text = $rv->{'data'};
ok( $rv->{'mode'} eq 'size' && $text =~ m{\A\.:\[ coding handover : },
    'handover : a p7 block with its head' );
ok( scalar $text
        =~ m{\n  claude : state running \[ turn running \], turn 3, queued 0 \[},
    'handover : the claude run from claude.status'
);
ok( scalar $text =~ m{\n  kimi   : phase idle, queued 0 \[},
    'handover : kimi phase' );
ok( scalar $text =~ m{\nsign queue\n  empty\n},
    'handover : empty sign queue' );
ok( scalar $text
        =~ m{\ncommits \[ base \]\n  not pushed : 2\n    \w+ three local\n    \w+ two local\n},
    'handover : the commits not pushed, newest first'
);
ok( scalar $text =~ m{\n  not deployed : 2\n},
    'handover : not deployed after the deploy ref'
);
ok( scalar $text =~ m{\nopen decisions\n  none\n},
    'handover : no decisions' );
ok( scalar $text =~ m{\nparked \[ coding \]\n  none\n}
        && $text =~ m{\nparked \[ task \]\n  none\n},
    'handover : nothing parked [ no tasks found is empty, not an error ]'
);
ok( $text !~ m{not followed}, 'handover : no refused watch shown' );
$rv = run_cmd( 'coding', 'coding.cmd.handover', 'short', 1 );
ok( scalar $rv->{'data'} =~ m{\n  not pushed : 2\n}
        && $rv->{'data'} !~ m{two local},
    'handover short : counts, no commit lines'
);
ok( run_cmd( 'coding', 'coding.cmd.handover', 'bogus', 1 )->{'mode'} eq
        'false',
    'handover : an unknown word is refused'
);
pump();

## 3. signals keep it current ##
$fake{'claude'}   = "state   : idle\nturn    : 4\nqueued  : 0\n";
$fake{'decision'} = "question.q1.type = text\nquestion.q1.question "
    . "= deploy now ?\nquestion.q1.decision = yes\n";
$fake{'parked'}
    = "AAAAAAA pending  work\n--- parked ---\nBBBBBBB "
    . "parked   task-BBBBBBB-1 waiting time x\n";
my $before = scalar @cube_log;
signal( 'claude', 'claude.run.done state=done' );
ok( entry( 'coding', 'handover-watch-claude' )->{'state'} eq 'waiting',
    'claude.run.done : the watch is armed again under its id'
);
ok( grep( {m{coding> events\.bucket-remove handover-watch-claude}}
        @cube_log[ $before .. $#cube_log ] ),
    'claude.run.done : the fired entry removed first'
);
ok( defined $data{'coding'}{'handover'}{'state'}{'signal'}{'claude'},
    'claude.run.done : the signal time kept' );
$text = run_cmd( 'coding', 'coding.cmd.handover', '', 1 )->{'data'};
ok( scalar $text
        =~ m{\n  claude : state idle, turn 4, queued 0 \[ \d\d:\d\d \] ; run\.done \d\d:\d\d\n},
    'claude.run.done : claude asked again, its new state shown'
);
ok( scalar $text
        =~ m{\nparked \[ task \]\n  BBBBBBB parked   task-BBBBBBB-1 waiting time x\n},
    'claude.run.done : the task parks asked again [ only the parked lines ]'
);
ok( scalar $text =~ m{\nopen decisions\n  none\n},
    'claude.run.done : decisions not asked [ their own signal ]' );
signal( 'protocol-7-menu', 'decision.answered id=q0 answer=yes' );
$text = run_cmd( 'coding', 'coding.cmd.handover', '', 1 )->{'data'};
ok( scalar $text
        =~ m{\nopen decisions\n  question\.q1\.question = deploy now \?\n\n},
    'decision.answered : the open decisions read again [ question lines ]'
);
signal( 'kimi', 'kimi.run.done state=end session=k' );
ok( entry( 'coding', 'handover-watch-kimi' )->{'state'} eq 'waiting'
        && defined $data{'coding'}{'handover'}{'state'}{'signal'}{'kimi'},
    'kimi.run.done : noted and armed again'
);
signal( 'claude', 'claude.run.done state=done' );
ok( entry( 'coding', 'handover-watch-claude' )->{'state'} eq 'waiting',
    'claude.run.done : a second signal is followed too' );
ok( run_cmd( 'coding', 'coding.cmd.handover-event', 'bogus' )->{'mode'} eq
        'false',
    'handover-event : an unknown source is refused'
);
pump();

## 4. write : the one file, overwritten ##
$rv = run_cmd( 'coding', 'coding.cmd.handover', 'write', 1 );
my $target = "$repo/data/ai-mem/claude/handover-live.md";
ok( $rv->{'mode'} eq 'true' && $rv->{'data'} eq "handover written : $target",
    'write : answers with the exact path'
);
my $written = read_file($target);
ok( $written
        =~ m{\A# handover live \[ coding\.handover write \]\n\n\.:\[ coding handover : }
        && $written =~ m{two local},
    'write : the full block in handover-live.md'
);
opendir my $md, "$repo/data/ai-mem/claude" or die;
my @files = sort grep { !m{\A\.} } readdir $md;
closedir $md;
ok( "@files" eq 'MEMORY.md handover-live.md'
        && read_file("$repo/data/ai-mem/claude/MEMORY.md") eq "keep\n",
    'write : no other file made or touched [ no tmp left ]'
);
$fake{'claude'} = "state   : stopped\n";
pump();
run_cmd( 'coding', 'coding.cmd.handover', 'write', 1 );
ok( read_file($target) =~ m{claude : state stopped}
        && read_file($target) !~ m{state idle},
    'write : overwritten each time'
);
pump();

## 5. a refused watch shows ##
{
    local $code{'events.cmd.bucket-add'}
        = sub { { 'mode' => 'false', 'data' => 'not allowed' } };
    local $zenka = 'coding';
    $code{'coding.handover.arm'}->('kimi');
    pump();
}
$text = run_cmd( 'coding', 'coding.cmd.handover', '', 1 )->{'data'};
ok( scalar $text
        =~ m{\nnot followed \[ watch refused \]\n  kimi : not allowed\n},
    'watch refused : named in the block'
);
pump();
run_cmd( 'coding', 'coding.cmd.handover-event', 'kimi' );
pump();

## 6. sources down : the block says so ##
$down{'claude'} = 1;
run_cmd( 'coding', 'coding.cmd.handover', '', 1 );
pump();
$text = run_cmd( 'coding', 'coding.cmd.handover', '', 1 )->{'data'};
ok( scalar $text =~ m{\n  claude : no answer : not reachable \[},
    'claude down : no answer : not reachable' );
delete $down{'claude'};
pump();

## 7. reminders : at \ after, list, drop ##
my $at = time + 3600;
$rv = run_cmd( 'coding', 'coding.cmd.remind',
    "at=$at look at the deploy", 21 );
ok( $rv->{'mode'} eq 'deferred', 'remind : deferred to the events answer' );
pump();
my ($rid)
    = grep {m{\Aremind-}} @{ $data{'events'}{'buckets'}{'coding'}{'order'} };
my $e = defined $rid ? entry( 'coding', $rid ) : {};
ok( defined $rid
        && $e->{'state'} eq 'waiting'
        && $e->{'at'} == $at
        && $e->{'action'}{'type'} eq 'send-command'
        && $e->{'action'}{'command'} eq "coding.remind-fire $rid "
        . "session look at the deploy",
    'remind at= : a send-command entry, to=session by default'
);
ok( $replies{21}{'mode'} eq 'true'
        && $replies{21}{'data'} =~ m{\Areminder $rid : },
    'remind : the caller gets the events answer'
);
run_cmd( 'coding', 'coding.cmd.remind',
    'after=remind-test to=panel check "usage" now', 22 );
pump();
my ($rid2)
    = grep { m{\Aremind-} and $ARG ne $rid }
    @{ $data{'events'}{'buckets'}{'coding'}{'order'} };
my $e2 = defined $rid2 ? entry( 'coding', $rid2 ) : {};
ok( defined $rid2
        && $e2->{'when'} eq 'after'
        && $e2->{'at'} > time
        && $e2->{'action'}{'command'} eq "coding.remind-fire $rid2 "
        . "panel check \"usage\" now",
    'remind after= : interval type, to=panel, quotes kept'
);
ok( run_cmd( 'coding', 'coding.cmd.remind', 'look' )->{'mode'} eq 'false'
        && run_cmd( 'coding', 'coding.cmd.remind', "at=$at after=x t" )
        ->{'mode'} eq 'false'
        && run_cmd( 'coding', 'coding.cmd.remind', "at=$at to=mail t" )
        ->{'mode'} eq 'false'
        && run_cmd( 'coding', 'coding.cmd.remind', "at=$at" )->{'mode'} eq
        'false'
        && run_cmd( 'coding', 'coding.cmd.remind', "at=$at x=1 t" )->{'mode'}
        eq 'false',
    'remind : no time, two times, bad to=, no text, unknown key refused'
);
run_cmd( 'coding', 'coding.cmd.reminders', '', 23 );
pump();
ok( $replies{23}{'mode'} eq 'size'
        && $replies{23}{'data'}
        =~ m{\A\Q$rid\E\s+waiting .*# look at the deploy \[ to=session \]\n}
        && $replies{23}{'data'} =~ m{\Q$rid2\E\s+waiting }
        && $replies{23}{'data'} !~ m{handover-watch},
    'reminders : the waiting reminders only, with their text'
);

## 8. restart : reminders stay, the handover is rebuilt ##
restart_all();
ok( !defined $data{'coding'}{'handover'}, 'restart : handover memory gone' );
coding_start();
ok( entry( 'coding', $rid )->{'state'} eq 'waiting'
        && entry( 'coding', $rid2 )->{'state'} eq 'waiting',
    'restart : both reminders still wait [ the bucket file ]'
);
ok( entry( 'coding', 'handover-watch-claude' )->{'state'} eq 'waiting'
        && defined $data{'coding'}{'handover'}{'state'}{'source'}{'claude'},
    'restart : watches armed, sources asked again'
);
$text = run_cmd( 'coding', 'coding.cmd.handover', '', 1 )->{'data'};
ok( scalar $text =~ m{claude : state stopped},
    'restart : the block from the sources'
);
pump();

## 9. delivery : session, notify fallback, panel, session fallback ##
fire_timer( 'coding', $rid );
pump();
ok( entry( 'coding', $rid )->{'state'} eq 'fired'
        && "@posted" eq 'reminder : look at the deploy from=coding'
        && !@notified,
    'fire to=session : posted into the live session'
);
$fake{'live'} = 0;
@posted = ();
run_cmd( 'coding', 'coding.cmd.remind-fire',
    'remind-1 session no session now' );
pump();
ok( !@posted && "@notified" eq 'reminder no session now',
    'fire to=session : no live session -> notify'
);
@notified = ();
$fake{'live'} = 1;
fire_timer( 'coding', $rid2 );
pump();
ok( "@notified" eq 'reminder check "usage" now' && !@posted,
    'fire to=panel : the notify path' );
@notified = ();
$down{'notify'} = 1;
run_cmd( 'coding', 'coding.cmd.remind-fire',
    'remind-2 notify notify is gone' );
pump();
ok( "@posted" eq 'reminder : notify is gone from=coding',
    'fire to=notify : notify not present -> the session'
);
@posted       = ();
$fake{'live'} = 0;
@logged       = ();
run_cmd( 'coding', 'coding.cmd.remind-fire', 'remind-3 notify nowhere' );
pump();
ok( grep( {m{\Q<< reminder remind-3 not delivered : nowhere >>\E}} @logged ),
    'fire : no path left -> logged at level 0'
);
ok( run_cmd( 'coding', 'coding.cmd.remind-fire', 'remind-3 mail x' )->{'mode'}
        eq 'false',
    'remind-fire : a bad target refused'
);

## 9b. undelivered : kept, listed with the reason, retried, woken ##
sub kept {
    local $zenka = 'coding';
    return $code{'coding.remind.store'}->( 'get', $_[0] );
}

sub list_now {
    my $id = shift;
    local $zenka = 'coding';
    run_cmd( 'coding', 'coding.cmd.reminders', '', $id );
    pump();
    return $replies{$id}{'data'};
}

sub retry_tick {
    local $zenka = 'coding';
    $code{'coding.remind.tick'}->( FakeEvent->new( {} ) );
    pump();
}
ok( ( kept('remind-3') // {} )->{'status'} eq 'undelivered'
        && kept('remind-3')->{'reason'} eq
        'notify : client not present ; session : no live session registered',
    'undelivered : kept with the reason of every path'
);
ok( !kept('remind-1') && !kept('remind-2') && !kept($rid) && !kept($rid2),
    'undelivered : delivered reminders left the store' );
ok( scalar list_now(40)
        =~ m{^remind-3\s+undelivered\s+tries 1 \[ notify : client not present ; .*\] \# nowhere \[ to=notify \]$}m,
    'reminders : the undelivered one listed with its reason'
);
my @retry = grep { $ARG->{'handler'} eq 'coding.remind.tick' } @timers;
ok( @retry && $retry[-1]{'after'} > 20 && $retry[-1]{'after'} < 50,
    'undelivered : a retry timer armed [ short first delay ]'
);
ok( ( entry( 'coding', 'reminder-wake' ) // {} )->{'on'} eq
        'claude.session.registered',
    'undelivered : waits for a live session registration'
);
retry_tick();
my @retry2 = grep { $ARG->{'handler'} eq 'coding.remind.tick' } @timers;
ok( kept('remind-3')->{'tries'} == 2
        && @retry2 > @retry
        && !@posted
        && !@notified,
    'retry : paths still down, kept and the timer armed again'
);
restart_all();
ok( ( kept('remind-3') // {} )->{'text'} eq 'nowhere'
        && read_file("$tmp/zdir/coding.reminders")
        =~ m{^reminder\.remind-3\.status = undelivered$}m,
    'restart : the undelivered one is still there [ its file ]'
);
$fake{'live'} = 1;
retry_tick();
ok( "@posted" eq 'reminder : nowhere from=coding' && !kept('remind-3'),
    'retry : delivered once a path is back, then gone' );
ok( !entry( 'coding', 'reminder-wake' ),
    'nothing kept : the session watch removed'
);

## woken by the registration signal [ real grants ] ##
@posted = ();
$fake{'live'} = 0;
run_cmd( 'coding', 'coding.cmd.remind-fire', 'remind-4 session wake me' );
pump();
$fake{'live'} = 1;
my $woke = signal( 'claude', 'claude.session.registered name=main' );
ok( $woke->{'mode'} eq 'true'
        && "@posted" eq 'reminder : wake me from=coding'
        && !kept('remind-4'),
    'claude.session.registered : the undelivered reminder is delivered'
);

## the registration comes while a round is still on its way ##
@posted = ();
$fake{'live'} = 0;
run_cmd( 'coding', 'coding.cmd.remind-fire', 'remind-5 session in flight' );
run_cmd( 'coding', 'coding.cmd.remind-wake', '' );
ok( @pending && kept('remind-5')->{'status'} eq 'sending',
    'wake while sending : no second round beside the first'
);
{
    ## the first answer says no session, then it is there ##
    my $post = $code{'claude.cmd.session-post'};
    my $n    = 0;
    local $code{'claude.cmd.session-post'} = sub {
        local $fake{'live'} = $n++ ? 1 : 0;
        return $post->();
    };
    local $down{'notify'} = 1;
    pump();
}
ok( "@posted" eq 'reminder : in flight from=coding' && !kept('remind-5'),
    'wake while sending : repeated once after it failed, one delivery'
);

## no route at all, then drop ##
{
    local $code{'protocol-7.route-send'} = sub {0};
    $rv = run_cmd( 'coding', 'coding.cmd.remind-fire',
        'remind-6 session no route' );
}
ok( $rv->{'mode'} eq 'true'
        && $rv->{'data'} =~ m{kept : not delivered}
        && kept('remind-6')->{'reason'} eq
        'session : not routable ; notify : not routable',
    'not routable : kept with the reason'
);
$down{'events'} = 1;
ok( scalar list_now(41) =~ m{^remind-6\s+undelivered}m,
    'reminders : events down, the kept ones still listed'
);
$rv = run_cmd( 'coding', 'coding.cmd.remind-drop', 'remind-6', 42 );
pump();
ok( $rv->{'mode'} eq 'true' && !kept('remind-6'),
    'remind-drop : an undelivered one dropped, events not needed' );
delete $down{'events'};
@posted = ();

delete $down{'notify'};
$fake{'live'} = 1;

## 10. drop ##
run_cmd( 'coding', 'coding.cmd.remind', "at=$at drop me", 31 );
pump();
my ($rid3)
    = grep { m{\Aremind-} and $ARG ne $rid and $ARG ne $rid2 }
    @{ $data{'events'}{'buckets'}{'coding'}{'order'} };
run_cmd( 'coding', 'coding.cmd.remind-drop', $rid3, 32 );
pump();
ok( !defined entry( 'coding', $rid3 ) && $replies{32}{'mode'} eq 'true',
    'remind-drop : the entry removed' );
ok( run_cmd( 'coding', 'coding.cmd.remind-drop', 'handover-watch-claude' )
        ->{'mode'} eq 'false',
    'remind-drop : only remind- ids [ not the watches ]'
);
run_cmd( 'coding', 'coding.cmd.reminders', '', 33 );
pump();
ok( $replies{33}{'data'} eq "no reminders\n",
    'reminders : none left waiting'
);
$down{'events'} = 1;
run_cmd( 'coding', 'coding.cmd.remind', "at=$at t", 34 );
pump();
ok( $replies{34}{'mode'} eq 'false'
        && $replies{34}{'data'} =~ m{events zenka not reachable},
    'remind : events down -> refused'
);

## 10. the target of to=session : recorded when set ##
delete $down{'events'};

sub new_reminders {
    my %seen = map { $ARG => 1 } @{ $_[0] };
    return
        grep { m{\Aremind-} and not $seen{$ARG} }
        @{ $data{'events'}{'buckets'}{'coding'}{'order'} };
}

sub set_reminder {
    my ( $args, $reply_id ) = @ARG;
    my @before = new_reminders( [] );
    run_cmd( 'coding', 'coding.cmd.remind', $args, $reply_id );
    pump();
    my ($new) = new_reminders( \@before );
    return ( $new, defined $new ? entry( 'coding', $new ) : {} );
}

$fake{'sessions'} = "owner : since Tue Nov 24 12:00:00 2026\n";
my ( $t1, $e1 ) = set_reminder( "at=$at to the owner", 41 );
ok( defined $t1
        && $e1->{'action'}{'command'} eq
        "coding.remind-fire $t1 session:owner to the owner"
        && $replies{41}{'mode'} eq 'true',
    'remind : one session -> its name is recorded'
);
$fake{'sessions'} .= "run : since Tue Nov 24 12:13:00 2026\n";
my ($t2) = set_reminder( "at=$at who gets it", 42 );
ok( !defined $t2
        && $replies{42}{'mode'} eq 'false'
        && $replies{42}{'data'}
        =~ m{several live sessions \[ owner, run \] : to=session:<name>},
    'remind : several sessions and no name -> refused with the names'
);
my ( $t3, $e3 ) = set_reminder( "at=$at to=session:owner named one", 43 );
ok( defined $t3
        && $e3->{'action'}{'command'} eq
        "coding.remind-fire $t3 session:owner named one",
    'remind to=session:<name> : recorded as given'
);
@posted = ();
$fake{'live'} = 1;
fire_timer( 'coding', $t3 );
pump();
ok( "@posted" eq 'to=owner reminder : named one from=coding',
    'fire : posted with to=<name>' );
@posted       = ();
@notified     = ();
$fake{'live'} = 0;
run_cmd( 'coding', 'coding.cmd.remind-fire',
    'remind-41 session:gone it is away' );
pump();
ok( !@posted && "@notified" eq 'reminder it is away',
    'fire : the named session is away -> notify, no other session' );
$fake{'live'} = 1;
ok( run_cmd( 'coding', 'coding.cmd.remind', "at=$at to=session: t" )->{'mode'}
        eq 'false',
    'remind : an empty session name refused'
);

say "1..", $pass + $fail;
say "# pass $pass fail $fail";
exit( $fail ? 1 : 0 );

#,,.,,.,.,...,.,,,,,,,.,,,..,,..,,,.,,,.,,,.,,..,,...,...,..,,,..,.,,,..,,..,,
#UVBINVKMXFUPSSBNJCJGR6YUVX5ZILVI3MFZKCFHLNDXEV6ELQKSQD3WQEPS5V3B65U3JDJCTTS2U
#\\\|VGGDQGRADFWK62AUOVEUO6WWWW4G27PQLT7QL3NRYG7P555YOL4 \ / AMOS7 \ YOURUM ::
#\[7]X7BDJVYL3BTZVBAVA5C2HB2UAL5BRX46XHSZFFMVQX7HABXHG2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
