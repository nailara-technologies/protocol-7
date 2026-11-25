#!/usr/bin/env perl
## watcher registry : fake process tables, files, logs, signals
use v5.32.0;
use strict;
use warnings;
use English;

use Test::More;
use FindBin     qw| $RealBin |;
use File::Temp  qw| tempdir |;
use POSIX       qw| strftime |;
use Date::Parse qw| str2time |;
use lib "$RealBin/../../data/lib-path/pm";
use AMOS7::Switch;
use AMOS7::Config;
use AMOS7::Config::Writer;

use constant { TRUE => 5, FALSE => 0 };

our %data;
our %code;
our $call;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[(\$\w+)\]>(?=\s*->)}{chr(36).qq|code{$1}|}eg;
    $code =~ s{<\[(\$\w+)\]>}{chr(36).qq|code{$1}->()|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=\s*->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$RealBin/../../src/$name";
    open my $fh, '<:encoding(UTF-8)', $path or die "$path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $src = <$fh>;
    close $fh;
    $src =~ s{^#,,.*}{}ms;
    my @seg = split m{('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"|\#[^\n]*)}x,
        $src, -1;

    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub
        = eval qq|sub {\n#line 1 "src/$name"\n| . join( '', @seg ) . qq|\n}|;
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

load_src("system.watch.$ARG")
    for qw| init_code post_init path save load sweep value trigger gate emit
    send_outbox handler.signal_reply check.proc check.file check.log
    check.threshold unless.get unless.finish unless.pass cmd.watch-add
    cmd.watch-remove cmd.watches |;
load_src("events.$ARG")
    for qw| bucket.parse_args bucket.unless.parse bucket.unless.check
    bucket.unless.handler.reply bucket.unless.handler.guard
    bucket.gate.parse bucket.gate.holds signal.encode signal.decode
    signal.journal_read |;
load_src('base.reply.mode_text');
load_src('base.sig_chld');

my $tmp = tempdir( 'watch-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
my $now = 10_000;
my ( @sent, @timers, @logs, %waited );

$code{'base.time'} = sub { return $now };
$code{'base.logs'} = sub { shift; push @logs, sprintf shift, @ARG };
$code{'base.log'}  = sub { push @logs, $ARG[1] };
$code{'base.perlmod.load'}     = sub { return TRUE };
$code{'base.perlmod.loaded'}   = sub { return TRUE };
$code{'base.perlmod.autoload'} = sub { return TRUE };
$code{'base.interval.next'}    = sub { return 13 };
$code{'event.add_timer'}       = sub { push @timers, shift; return undef };
$code{'protocol-7.route-send'} = sub { push @sent,   shift; return TRUE };
$code{'base.waitpid'}          = sub {
    my $pid = shift;
    return -1 if not exists $waited{$pid};
    $CHILD_ERROR = delete $waited{$pid};
    return $pid;
};

$data{'system'}{'watch'}{'registry_path'} = "$tmp/watch.registry";
$data{'events'}{'signal'}{'journal_path'} = "$tmp/signal.journal";

sub start {
    delete $data{'system'}{'watch'}{$ARG}
        for qw| entries outbox loaded seq dirty load_failed |;
    $code{'system.watch.init_code'}->();
    $code{'system.watch.post_init'}->();
}
sub watches { return $data{'system'}{'watch'}{'entries'} }

sub add {
    local $call = { 'args' => shift };
    return $code{'system.watch.cmd.watch-add'}->();
}

sub added_ok {
    my $reply = add( $ARG[0] );
    is $reply->{'mode'}, 'true', "added : $ARG[0]"
        or diag $reply->{'data'};
}

sub proc {
    my ( $pid, $cmd, %more ) = @ARG;
    return {
        'pid'   => $pid,
        'ppid'  => 1,
        'start' => 9_000,
        'uid'   => 1000,
        'state' => 'sleep',
        'cmd'   => $cmd,
        'fname' => 'perl',
        %more
    };
}
sub sweep { $now += 5; $code{'system.watch.sweep'}->( [@ARG], $now ) }

## answer every sent signal TRUE and hand back the argument lines ##
sub signals {
    my @lines;
    foreach my $msg ( splice @sent ) {
        if ( $msg->{'command'} ne 'events.signal' ) {
            push @sent, $msg;
            next;
        }
        push @lines, $msg->{'call_args'}{'args'};
        $code{'system.watch.handler.signal_reply'}->(
            {   'cmd'       => 'TRUE',
                'call_args' => { 'args' => 'ok' },
                'params'    => $msg->{'reply'}{'params'}
            }
        );
    }
    return @lines;
}

sub spew {
    my ( $path, $text, $mode ) = @ARG;
    open my $fh, ( $mode // '>' ) . ':raw', $path or die "$path : $OS_ERROR";
    print {$fh} $text;
    close $fh;
}

start();

##  argument checks  ##
foreach my $bad (
    'a bogus x signal=y',
    'a proc-exit x',
    'a.b proc-exit x signal=y',
    'a proc-exit ( signal=y',
    'a file relative signal=y',
    'a log /x signal=y',
    'a threshold mem.used_percent signal=y',
    'a threshold nothing above=1 signal=y',
    'a file /x signal=y on=grow',
    'a proc-exit x signal=Y',
    'a proc-exit x signal=y unless=nonsense',
    'a proc-exit x signal=y valid-until=soonish',
    'a proc-exit x signal=y above=3',
    'a proc-exit x y signal=y',
) {
    is add($bad)->{'mode'}, 'false', "refused : $bad";
}
is keys %{ watches() }, 0, 'refused watches leave nothing behind';

##  proc-exit, once : non-child  ##
added_ok('place proc-exit n7fs\s.*\bplace\b signal=place.complete once');
is watches()->{'place'}{'signal'}, 'watch.place.complete',
    'the signal gets the watch. prefix';
my $run    = proc( 50, 'perl /x/n7fs -v place /data' );
my $worker = proc( 51, 'perl /x/n7fs -v place /data', 'ppid' => 50 );
my $adder  = proc( 52, 'p7c system.watch-add place proc-exit n7fs place' );
sweep( $run, $worker, $adder );
is_deeply [ sort keys %{ watches()->{'place'}{'seen'} } ], ['50.9000'],
    'only the root of a matching tree is tracked, never the adding command';
sweep( $run, $worker );
is_deeply [ signals() ], [], 'running : no signal';
sweep($run);
is_deeply [ signals() ], [], 'a worker ending is not the run ending';
sweep();
my @got = signals();
is scalar @got, 1, 'the end triggers once';
is $got[0],
    'watch.place.complete age=1015 pid=50 rc=unknown runtime=10 watch=place',
    'signal values : not a child, rc=unknown';
is watches()->{'place'}{'state'}, 'fired', 'once : fired';
sweep($run);
sweep();
is_deeply [ signals() ], [], 'once does not trigger again';

##  child exit status : zombie, reaper hook, signal, two watches  ##
added_ok('kid proc-exit kidjob signal=kid repeat');
added_ok('kid2 proc-exit kidjob signal=kid2');
my $kid = proc( 60, 'kidjob', 'ppid' => $PID );
sweep($kid);
$waited{60} = 3 << 8;
sweep( { %{$kid}, 'state' => 'defunct', 'cmd' => '' } );
@got = signals();
is scalar @got,                     2, 'a zombie has ended, both watches';
is scalar( grep {m| rc=3 |} @got ), 2, 'both see the exit status';
sweep( { %{$kid}, 'state' => 'defunct', 'cmd' => '' } );
is_deeply [ signals() ], [], 'a zombie that stays does not trigger again';

$kid = proc( 61, 'kidjob', 'ppid' => $PID );
sweep($kid);
$data{'base'}{'child_exit'}{61} = 9;    ## reaped by base.sig_chld ##
sweep();
@got = signals();
like "@got", qr| rc=137 .* sig=9 |, 'repeat : killed child, rc 128+sig';
is_deeply $data{'base'}{'child_exit'}, {}, 'child statuses are cleared';

$kid = proc( 62, 'kidjob', 'ppid' => $PID );
sweep($kid);
sweep();
like join( '', signals() ), qr| rc=unknown |,
    'a child whose status is gone stays unknown';

$data{'base'}{'child_exit'} = {};
{
    my @pids = (63);
    local $code{'base.waitpid'} = sub {
        return shift(@pids) // -1;
    };
    local $CHILD_ERROR = 5 << 8;
    $code{'base.sig_chld'}->();
}
ok exists $data{'base'}{'child_exit'}{63},
    'base.sig_chld keeps the status for the watches';

##  pid reuse, user filter  ##
$code{'system.watch.cmd.watch-remove'}->() for ();
%{ watches() } = ();
added_ok('re proc-exit reuse signal=re repeat user=1000');
sweep( proc( 70, 'reuse' ), proc( 71, 'reuse', 'uid' => 0 ) );
sweep( proc( 70, 'reuse', 'start' => 9_999 ) );
@got = signals();
is scalar @got, 1, 'same pid with another start time is another process';

##  proc-start  ##
%{ watches() } = ();
added_ok('up proc-start daemon signal=up repeat');
sweep( proc( 80, 'daemon' ) );
is_deeply [ signals() ], [], 'already running is the baseline';
sweep( proc( 80, 'daemon' ), proc( 81, 'daemon' ) );
sweep( proc( 80, 'daemon' ), proc( 81, 'daemon' ) );
is_deeply [ signals() ], ['watch.up comm=perl pid=81 uid=1000 watch=up'],
    'one start, one signal';
sweep( proc( 82, 'daemon' ) );
is scalar( () = signals() ), 1, 'repeat triggers again';
added_ok('up1 proc-start late signal=up1');
sweep( proc( 83, 'late', 'start' => $now + 1 ) );
is scalar( grep {m|^watch\.up1 |} signals() ), 1,
    'started after adding, before the first look : triggers, once';
sweep( proc( 84, 'late', 'start' => $now ) );
is scalar( grep {m|^watch\.up1 |} signals() ), 0, 'once is over';

##  file  ##
%{ watches() } = ();
my $file = "$tmp/result";
added_ok("fa file $file signal=fa");
spew( "$tmp/grow", 'x' );
added_ok("fc file $tmp/grow signal=fc on=change repeat");
added_ok("fg file $tmp/grow signal=fg size=10");
sweep();
is_deeply [ signals() ], [], 'file : nothing changed';
spew( $file,       "done\n" );
spew( "$tmp/grow", 'x' x 5 );
sweep();
@got = signals();
is_deeply [ map { (split)[0] } @got ], [qw| watch.fa watch.fc |],
    'appear and change, below the size';
like $got[0], qr|event=appear path=\S+/result size=5 watch=fa|, 'file values';
spew( "$tmp/grow", 'x' x 20 );
sweep();
is_deeply [ map { (split)[0] } signals() ], [qw| watch.fc watch.fg |],
    'grown past the size, change repeats';
unlink $file;
sweep();
spew( $file, "again\n" );
sweep();
is_deeply [ signals() ], [], 'a fired once watch stays quiet';

##  log  ##
%{ watches() } = ();
my $log = "$tmp/run.log";
spew( $log, "old ERROR line\n" );
added_ok(qq|le log $log match="ERROR \\d+" signal=err repeat|);
added_ok("lo log $log match=ERROR signal=err1");
sweep();
is_deeply [ signals() ], [], 'log : old lines do not count';
spew( $log, "fine\nERROR 1 here\nERROR 2 ü\nERROR 3 part", '>>' );
sweep();
@got = signals();
is scalar( grep {m|^watch\.err |} @got ),  2, 'repeat : one per line';
is scalar( grep {m|^watch\.err1 |} @got ), 1, 'once : first line only';
like $got[0], qr|^watch\.err line=ERROR_1_here path=|, 'no spaces';
spew( $log, "ial\n", '>>' );
sweep();
like join( '', signals() ), qr|line=ERROR_3_partial |,
    'a half written line is read when complete';
spew( "$log.new", "ERROR 4\n" );
rename "$log.new", $log;
sweep();
like join( '', signals() ), qr|line=ERROR_4 |, 'rotated : from the top';
spew( $log, "ERROR 9\n" x 20, '>>' );
sweep();
@got = signals();
is scalar @got, 13, 'at most 13 signals a poll';
like $got[-1], qr| dropped=7 |, 'the rest is counted';
$data{'system'}{'watch'}{'log_chunk'} = 16;
spew( $log, 'ERROR 5 y' x 30 . " ERROR 6\nERROR 7\n", '>>' );
sweep() for 1 .. 6;
is_deeply [ map {m|line=(\S+)|} signals() ], ['ERROR_7'],
    'a line longer than the chunk is skipped, its tail too';
delete $data{'system'}{'watch'}{'log_chunk'};

##  threshold  ##
%{ watches() } = ();
added_ok('hi threshold mem.used_percent above=90 signal=mem.high repeat');
added_ok('lo threshold disk.free_percent:/data below=10 signal=disk.low');
$data{'system'}{'mem'}{'used_percent'} = '95.00';
$data{'system'}{'disk'}{'mounts'}{'/data'}{'free_percent'} = 50;
sweep();
is_deeply [ signals() ], [], 'already beyond is the baseline';
$data{'system'}{'mem'}{'used_percent'} = '50.00';
sweep();
$data{'system'}{'mem'}{'used_percent'} = '91.50';
$data{'system'}{'disk'}{'mounts'}{'/data'}{'free_percent'} = 9;
sweep();
sweep();
is_deeply [ signals() ],
    [
    'watch.mem.high crossed=up limit=90 '
        . 'name=mem.used_percent value=91.50 watch=hi',
    'watch.disk.low crossed=down limit=10 '
        . 'name=disk.free_percent:/data value=9.00 watch=lo'
    ],
    'both directions, once per crossing';
$data{'system'}{'mem'}{'used_percent'} = '10';
sweep();
$data{'system'}{'mem'}{'used_percent'} = '99';
sweep();
is scalar( () = signals() ), 1, 'repeat crosses again';

##  valid-until  ##
%{ watches() } = ();
added_ok('vu proc-exit job signal=vu repeat valid-until=1m');
sweep( proc( 90, 'job' ) );
sweep();
is scalar( () = signals() ), 1, 'before valid-until';
sweep( proc( 91, 'job' ) );
$now += 100;
sweep();
is_deeply [ signals() ], [], 'past valid-until : no signal';
is watches()->{'vu'}{'state'}, 'expired', 'expired';

##  unless : seen [ read from the signal journal ]  ##
%{ watches() } = ();

sub journal {
    my $name = shift;
    spew(
        "$tmp/signal.journal",
        sprintf(
            "signal.%s = time:%s source:x woken:- values:-\n",
            $name, strftime( '%Y-%m-%dT%H:%M:%S', localtime time )
        )
    );
}
journal('nothing.yet');
added_ok('s1 proc-exit a1 signal=s1 unless=seen:task.over');
added_ok('s2 proc-exit a2 signal=s2 repeat unless=seen:other.thing');
sweep( proc( 100, 'a1' ), proc( 101, 'a2' ) );
journal('task.over');
sweep();
is_deeply [ map { (split)[0] } signals() ], ['watch.s2'],
    'a holding condition : no signal, the other one passes';
is watches()->{'s1'}{'state'}, 'skipped', 'once : ends as skipped';
is watches()->{'s2'}{'state'}, 'active',  'repeat stays';
journal('other.thing');
sweep( proc( 102, 'a2' ) );
sweep();
is_deeply [ signals() ], [], 'repeat : that trigger is skipped';
is watches()->{'s2'}{'state'}, 'active', 'and the watch goes on';

##  unless : an asked source, reply and guard  ##
%{ watches() } = ();
added_ok('b1 proc-exit b1 signal=b1 unless=sign-queue:empty');
sweep( proc( 110, 'b1' ) );
sweep();
my ($ask) = grep { $ARG->{'command'} eq 'coding.sign-queue' } @sent;
ok $ask, 'the source is asked';
is watches()->{'b1'}{'state'}, 'triggered', 'waiting for the answer';
is_deeply [ signals() ], [], 'no signal before the answer';
@sent = ();
$code{'events.bucket.unless.handler.reply'}->(
    {   'cmd'       => 'TRUE',
        'call_args' => { 'args' => 'sign queue empty' },
        'params'    => $ask->{'reply'}{'params'}
    }
);
is watches()->{'b1'}{'state'}, 'skipped', 'holding answer : skipped';
is_deeply [ signals() ], [], 'and silent';

added_ok('b2 proc-exit b2 signal=b2 unless=task:ABC1234=done');
@timers = ();
sweep( proc( 111, 'b2' ) );
sweep();
@sent = ();
$code{'events.bucket.unless.handler.guard'}
    ->( bless { 'data' => $timers[-1]{'data'} }, 'FakeEvent' );
is_deeply [ map { (split)[0] } signals() ], ['watch.b2'],
    'no answer is not a holding condition';
is watches()->{'b2'}{'state'}, 'fired', 'fired after the guard';

##  restart round trip  ##
%{ watches() } = ();
spew( $log, "before\n" );
added_ok(qq|r1 proc-exit pattern="long job #1 [x]?" signal=r1|);
added_ok(qq|r2 log $log match="^# (a\|b)\$" signal=r2 repeat|);
added_ok("r3 file $tmp/later signal=r3 valid-until=2d");
added_ok('r4 proc-exit held signal=r4 unless=sign-queue:empty');
sweep( proc( 120, 'a long job #1 ' ), proc( 121, 'held' ) );
sweep( proc( 120, 'a long job #1 ' ) );
@sent = ();
my %before
    = map { $ARG => watches()->{'r2'}{$ARG} } qw| match offset inode |;
start();
is_deeply [ sort keys %{ watches() } ], [qw| r1 r2 r3 r4 |], 'loaded';
is watches()->{'r1'}{'pattern'}, 'long job #1 [x]?', 'pattern intact';
is_deeply {
    map { $ARG => watches()->{'r2'}{$ARG} } qw| match offset inode |
}, \%before, 'log position intact';
spew( $log, "# a\n", '>>' );
spew( "$tmp/later", 'now' );
@sent = ();
sweep();
ok scalar( grep { $ARG->{'command'} eq 'coding.sign-queue' } @sent ),
    'a held trigger asks its unless again';
@got = signals();
is_deeply [ sort map { (split)[0] } @got ],
    [qw| watch.r1 watch.r2 watch.r3 |],
    'what happened while down is signalled';
like join( "\n", @got ), qr|pid=120 rc=unknown runtime=unknown |,
    'ended while down : rc and runtime unknown';
@sent = ();

##  undelivered signals  ##
%{ watches() } = ();
added_ok('q proc-exit qq signal=q');
sweep( proc( 130, 'qq' ) );
sweep();
my ($msg) = splice @sent;
$code{'system.watch.handler.signal_reply'}->(
    {   'cmd'       => 'FALSE',
        'call_args' => { 'args' => 'not granted' },
        'params'    => $msg->{'reply'}{'params'}
    }
);
start();
sweep();
is_deeply [ signals() ], [ $msg->{'call_args'}{'args'} ],
    'a refused signal survives a restart and is sent again';
start();
sweep();
is_deeply [ signals() ], [], 'a delivered one is gone';
sweep( proc( 131, 'qq' ) );
added_ok('q proc-exit qq signal=q');
sweep( proc( 131, 'qq' ) );
sweep();
@sent = ();
for ( 1 .. 20 ) { $now += 100; sweep(); @sent = () if $ARG < 20 }
is keys %{ $data{'system'}{'watch'}{'outbox'} }, 0, 'given up after 13';

##  list, remove, unwritable and unreadable registry  ##
like $code{'system.watch.cmd.watches'}->()->{'data'}, qr|^q : once proc-exit|,
    'watches lists';
{
    local $call = { 'args' => 'q' };
    is $code{'system.watch.cmd.watch-remove'}->()->{'mode'}, 'true',
        'removed';
    is $code{'system.watch.cmd.watch-remove'}->()->{'mode'}, 'false',
        'twice is refused';
}
is $code{'system.watch.cmd.watches'}->()->{'data'}, "no watches\n", 'empty';
{
    local $data{'system'}{'watch'}{'registry_path'} = "$tmp/no/such/file";
    is add('w proc-exit x signal=w')->{'mode'}, 'false',
        'an unwritable registry refuses the watch';
}
is keys %{ watches() }, 0, 'and keeps none';
{
    local $data{'system'}{'watch'}{'load_failed'} = TRUE;
    ok !$code{'system.watch.save'}->(),
        'a registry not read is never overwritten';
}

##  a failing check does not stop the others  ##
%{ watches() } = (
    'a' => {
        'id'      => 'a',
        'kind'    => 'proc-exit',
        'pattern' => '(',
        'signal'  => 'watch.a',
        'mode'    => 'once',
        'state'   => 'active',
        'added'   => 0
    }
);
added_ok('z threshold process.count above=5 signal=z');
$data{'process'}{'count'} = 1;
sweep();
$data{'process'}{'count'} = 9;
sweep();
is scalar( () = signals() ), 1, 'the other watch still triggers';

##  the reminder path of the shared unless check : no hooks set  ##
{
    local $data{'events'}{'unless_host'} = {};
    my $e = {
        'id'     => 'rem',
        'added'  => 0,
        'state'  => 'waiting',
        'unless' => 'seen:other.thing'
    };
    my @done;
    local $code{'events.bucket.finish'}   = sub { push @done, "$ARG[2]" };
    local $code{'events.bucket.evaluate'} = sub { push @done, 'evaluate' };
    local $code{'events.bucket.get'}
        = sub { return { 'entries' => { 'rem' => $e } } };
    $code{'events.bucket.unless.check'}->( 'owner', $e );
    delete @{$e}{qw| unless_pass unless_check |};
    $e->{'unless'} = 'seen:never.raised';
    $code{'events.bucket.unless.check'}->( 'owner', $e );
    delete @{$e}{qw| unless_pass unless_check |};
    $e->{'unless'} = 'sign-queue:empty';
    @sent = ();
    $code{'events.bucket.unless.check'}->( 'owner', $e );
    $code{'events.bucket.unless.handler.reply'}->(
        {   'cmd'       => 'TRUE',
            'call_args' => { 'args' => 'sign queue empty' },
            'params'    => $sent[-1]{'reply'}{'params'}
        }
    );
    is_deeply \@done, [qw| skipped evaluate skipped |],
        'reminders still finish and evaluate through the buckets';
    @sent = ();
    is_deeply $code{'events.bucket.unless.parse'}
        ->(' claude:5h<60,task:abc1234=done'),
        { 'unless' => 'budget:claude:5h<60,task:ABC1234=done' },
        'unless= values are normalized as before';
}

##  expiry in the sweep, room at the cap, a dying unless check  ##
%{ watches() } = ();
added_ok('x1 proc-exit nothing signal=x repeat valid-until=1m');
$now += 100;
sweep();
is watches()->{'x1'}{'state'}, 'expired', 'expires without a trigger';
%{ watches() } = ();
added_ok("n$ARG proc-exit nothing signal=n") for 1 .. 89;
is add('more proc-exit nothing signal=n')->{'mode'}, 'false',
    '89 live watches : full';
watches()->{'n7'}{'state'} = 'fired';
added_ok('more proc-exit nothing signal=n');
ok !exists watches()->{'n7'}, 'a finished watch made room';
%{ watches() } = ();
added_ok('d proc-exit dd signal=d unless=seen:some.thing');
sweep( proc( 140, 'dd' ) );
{
    local $code{'events.bucket.unless.check'} = sub { die "boom\n" };
    sweep();
}
ok !exists watches()->{'d'}{'gate'}, 'a failed check is not left pending';
sweep();
is scalar( () = signals() ), 1, 'and is asked again at the next poll';

##  the documented n7fs pattern  ##
%{ watches() } = ();
added_ok(
    q|place-complete proc-exit ^n7fs\s+place\b signal=place.complete once|);
sweep( proc( 150, 'n7fs place' ), proc( 151, 'n7fs placement-x2' ) );
is_deeply [ keys %{ watches()->{'place-complete'}{'seen'} } ],
    ['150.9000'], 'matches the name n7fs gives itself';

##  grant  ##
load_src("events.signal.$ARG") for qw| grants access |;
$data{'events'}{'signal'}{'grants_file'}
    = "$RealBin/../../cfg/zenki/events/access.signals";
ok $code{'events.signal.access'}->( 'system', 'watch.place.complete' ),
    'system may raise watch.*';
ok !$code{'events.signal.access'}->( 'system', 'claude.run.done' ),
    'and nothing else';

done_testing;

package FakeEvent;
sub w    { return $_[0] }
sub data { return $_[0]{data} }

#,,..,.,.,.,,,,..,,,.,...,.,.,.,,,,..,,,.,...,..,,...,...,.,,,..,,,.,,,.,,,..,
#C53TQWSF25OSCNPZDSBFPZZ4ZUDZXNFZ3SRAET7U6DZV6PVKH7BFWWH3YLAJRYRHPOH46A7WTERJ4
#\\\|4S7GOJ3DOWKHACLHPIHYMUGJX2IYSPKQBENDGKBBAHGZUXYUXPQ \ / AMOS7 \ YOURUM ::
#\[7]7VCRG532BEKY6QTPMC6HINBPUXXDC424O2O7V6DM5TSYR5PPTMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
