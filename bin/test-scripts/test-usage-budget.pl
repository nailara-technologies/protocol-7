#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## budget aware placement : the budget gate of events buckets, the park   ##
## budget= key, the usage watch [ usage.threshold \ usage.window.reset ]  ##
## and usage.plan. compiles the real src modules ; no zenka started, no   ##
## real cube, no real claude \ kimi : route-send, the command sender and  ##
## the timers are stubs, usage.status answers are injected by hand as the ##
## usage zenka would send them, a restart clears memory and reads files.  ##

use File::Spec;
use File::Temp qw| tempdir |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;
use Date::Parse;
use POSIX qw| strftime |;

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
$OUTPUT_AUTOFLUSH = 1;

sub ok {
    my ( $cond, $name ) = @ARG;
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

sub load_module {
    my $name = shift;
    $code{$name}
        = compile_source(
        read_file( File::Spec->catfile( $root_path, 'src', $name ) ) );
}

## stubs : log, command sender, timers, dependency check ##

my @sent;          ## command sends : "command | args" ##
my @logged;        ## log lines, formatted ##
my @timers;        ## add_timer calls : "handler at" ##
my @routed;        ## route-send calls : the hash as given ##
my @timer_args;    ## add_timer calls : the hash as given ##

sub fmt_log {
    my @a     = @ARG;
    my $level = $a[0] =~ m|\A\d+\z| && @a > 1 ? shift @a : 1;
    my $fmt   = shift @a;
    return "[$level] " . ( @a ? sprintf( $fmt, @a ) : $fmt );
}

$code{'base.log'}  = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.logs'} = sub { push @logged, fmt_log(@ARG); TRUE };
$code{'base.s_warn'}
    = sub { push @logged, 'warn ' . sprintf( shift, @ARG ); TRUE };
$code{'base.time'}             = sub {time};
$code{'dependency.ok'}         = sub {TRUE};
$code{'file.put'}              = sub {TRUE};
$code{'protocol-7.route-send'} = sub { push @routed, shift; return TRUE };
$code{'protocol-7.command.send.local'} = sub {
    my $c = shift;
    push @sent,
        join ' | ', $c->{'command'},
        $c->{'call_args'} ? ( $c->{'call_args'}{'args'} // '-' ) : '-';
    return TRUE;
};

{

    package FakeTimer;
    sub new       { bless { 'active' => 1, 'args' => $_[1] }, $_[0] }
    sub cancel    { $_[0]{'active'} = 0 }
    sub is_active { $_[0]{'active'} }
    sub now       { $main::now_called++ }
}
our $now_called = 0;
$code{'event.add_timer'} = sub {
    my $args = shift;
    push @timers, join ' ', $args->{'handler'}, $args->{'at'} // '-';
    push @timer_args, $args;
    return FakeTimer->new($args);
};

{

    package FakeEvent;
    sub new  { bless { data => $_[1] }, $_[0] }
    sub w    { $_[0] }
    sub data { $_[0]->{'data'} }
}

load_module($ARG) for qw|
    events.plugin.registry
    events.plugin.known
    events.source.arm_all
    events.source.disarm
    events.fire
    events.handler.event_triggered
    events.calc_unix_table
    events.set_up_timers
    events.action.tile_apply
    events.action.overlay_apply
    events.access.grants
    events.signal.grants
    events.access.route_ok
    events.signal.access
    events.signal.raise
    events.signal.encode
    events.signal.journal_write
    events.signal.decode
    events.cmd.signal
    events.bucket.parse_args
    events.bucket.path
    events.bucket.journal
    events.bucket.save
    events.bucket.load
    events.bucket.get
    events.bucket.cycle
    events.bucket.finish
    events.bucket.evaluate
    events.bucket.handler.start
    events.bucket.start
    events.bucket.action_route
    events.cmd.bucket-add
    events.cmd.bucket-remove
    events.cmd.bucket-clear
    events.cmd.bucket-show
    events.bucket.gate.parse
    events.bucket.gate.holds
    events.bucket.gate.check
    events.bucket.gate.close
    events.bucket.gate.arm
    events.bucket.gate.wake
    events.bucket.gate.describe
    events.bucket.gate.handler.reply
    events.bucket.gate.handler.retry
    events.bucket.gate.handler.guard
    base.reply.mode_text
    park.parse_args
    park.request
    park.describe
    usage.signal.raise
    usage.watch.thresholds
    usage.watch.observe
    usage.watch.arm
    usage.handler.window_reset
    usage.handler.provider_result
    usage.format.plan
    usage.pace.state
    base.interval.next
    base.interval.rhythm.non-linear
    |;

my $plugin_dir = File::Spec->catdir( $root_path, 'src' );
opendir my $dh, $plugin_dir or die "cannot open src : $OS_ERROR";
load_module($ARG)
    for grep {m{\Aplugin\.events\.(?:action|source)\.[\w-]+\z}} readdir $dh;
closedir $dh;

my $tmp = tempdir( 'usage-budget-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
our $access_file = "$tmp/access.zenki";
open my $afh, '>:encoding(UTF-8)', $access_file or die $OS_ERROR;
print {$afh} <<'ACC';
   access.cmd.usr.coding  =  events.bucket-add events.bucket-show \
                             task.continue coding.* boom.now
   access.cmd.usr.task    =  events.bucket-add task.continue \
                             task.* v7-zenki.start_once
   access.cmd.usr.*       =  heart
ACC
close $afh;

my $now = time;

sub reset_state {
    %data                                     = ();
    @sent                                     = @logged = @timers = ();
    $data{'events'}{'bucket_dir'}             = "$tmp/var";
    $data{'events'}{'signal'}{'access_file'}  = $main::access_file;
    $data{'events'}{'signal'}{'journal_path'} = "$tmp/var/signal.journal";
    $data{'events'}{'setup'}                  = {};
    $data{'events'}{'enabled'}                = {};
    $data{'base'}{'interval'}{'cfg'}{'type'}{'bucket-wait-short'}
        = { 'start' => 34, 'factor' => 1.2, 'cap' => 89, 'cap_jitter' => 13 };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'bucket-wait'}
        = { 'minutes' => 13 };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'budget-gate-margin'}
        = { 'start' => 21, 'factor' => 1, 'cap' => 21, 'cap_jitter' => 0 };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'budget-gate'}
        = { 'start' => 55, 'factor' => 1.6, 'cap' => 987, 'cap_jitter' => 0 };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'usage-reset-margin'}
        = { 'start' => 13, 'factor' => 1, 'cap' => 13, 'cap_jitter' => 0 };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'usage-requery'}
        = { 'start' => 34, 'factor' => 1.6, 'cap' => 377, 'cap_jitter' => 0 };
    $data{'base'}{'interval'}{'cfg'}{'type'}{'budget-gate-answer'}
        = { 'start' => 89, 'factor' => 1, 'cap' => 89, 'cap_jitter' => 0 };
    @routed = ();
    system 'rm', '-rf', "$tmp/var";
    return;
}

## the command sender fails for the boom route ##
{
    my $orig = $code{'protocol-7.command.send.local'};
    $code{'protocol-7.command.send.local'} = sub {
        my $c = shift;
        die "boom : the command failed\n"
            if $c->{'command'} eq 'cube.boom.now';
        return $orig->( $c, @ARG );
    };
}

## helpers : a command as the cube delivers it [ source first ] ##

sub cmd {
    my ( $name, $args ) = @ARG;
    local $call = { 'args' => $args };
    my $rv = eval { $code{"events.cmd.$name"}->() };
    return $rv if not $EVAL_ERROR;
    say "# DIE $name : $EVAL_ERROR";
    return { 'mode' => 'false', 'data' => "died : $EVAL_ERROR" };
}

sub add { return cmd( 'bucket-add', join ' ', @ARG ) }

sub entry { return $data{'events'}{'buckets'}{ $_[0] }{'entries'}{ $_[1] } }

sub show { return cmd( 'bucket-show', shift )->{'data'} // '' }

## the usage zenka answering a gate read : as base.reply.mode_text sees it ##
sub answer {
    my ( $route, $mode, $text ) = @ARG;
    my $reply = {
        'params' => $route->{'reply'}{'params'},
        $mode eq 'size'
        ? ( 'cmd' => 'SIZE', 'data' => \$text )
        : ( 'cmd' => uc $mode, 'call_args' => { 'args' => $text } )
    };
    return $code{ $route->{'reply'}{'handler'} }->($reply);
}

sub timers_of {
    my $h = shift;
    return
        grep { $ARG->{'handler'} eq "events.bucket.gate.handler.$h" }
        @timer_args;
}

sub fired_continue {
    return scalar grep {m{\Acube\.task\.continue \| }} @sent;
}

sub read_text {
    my $path = shift;
    return -f $path ? read_file($path) : '';
}

sub restart {    ## memory gone, files stay : a new process ##
    my %keep = map { $ARG => $data{'events'}{$ARG} } qw| bucket_dir signal |;
    my $interval = $data{'base'};
    %data                      = ( 'base' => $interval, 'events' => {%keep} );
    $data{'events'}{'setup'}   = {};
    $data{'events'}{'enabled'} = {};
    @sent = @logged = @timers = @timer_args = @routed = ();
    $code{'events.bucket.start'}->();
}

my $gated = 'action=task-continue id=T1 message=go';

## start : the gate is checked parse-wise on add ##

reset_state();
my $r = add( 'task', 'g0', $gated, 'budget=claude:5h~60' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{budget :},
    'start : a malformed budget is refused on add'
);
$r = add( 'task', 'g0', $gated, 'budget=claude:5h<160' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{over 100},
    'start : a percent over 100 is refused' );
$r = add( 'task', 'n1', $gated );
ok( $r->{'mode'} eq 'true' && fired_continue() == 1 && !@routed,
    'start : an entry without budget fires as before, no usage read'
);

## send : a met gated entry asks usage, once ##

@sent = ();
$r    = add( 'task', 'g1', $gated, 'budget="claude:5h < 60"' );
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{\[ waiting \]},
    'send : a gated entry with its when met stays waiting'
) or say "#   $r->{'data'}";
ok( @routed == 1
        && $routed[0]{'command'} eq 'usage.status'
        && $routed[0]{'call_args'}{'args'} eq 'compact claude'
        && $routed[0]{'reply'}{'handler'} eq
        'events.bucket.gate.handler.reply',
    'send : usage.status compact claude is asked [ deferred reply ]'
);
ok( !fired_continue(), 'send : nothing fires before the answer' );
ok( entry( 'task', 'g1' )->{'budget'} eq 'claude:5h<60',
    'send : the budget is kept normalised' );
$code{'events.bucket.evaluate'}->('task');
ok( @routed == 1, 'send : evaluate again asks no second time [ in flight ]' );
ok( show('task') =~ m{budget claude:5h<60 \[ asking usage \]},
    'send : bucket-show shows the gate in flight'
);
my $file = read_text("$tmp/var/bucket/task.bucket");
ok( $file =~ m{^entry\.g1\.budget = claude:5h<60$}m && $file !~ m|[{}]|,
    'send : the budget is saved, p7 config style' );

## a result : an open gate fires ##

answer( $routed[0], 'size', "claude 7d 30.0 90000\nclaude 5h 42.5 3600" );
ok( entry( 'task', 'g1' )->{'state'} eq 'fired' && fired_continue() == 1,
    'result : an open gate fires the entry once' );
ok( show('task') =~ m{g1\s+fired}, 'result : bucket-show shows it fired' );
answer( $routed[0], 'size', "claude 5h 42.5 3600" );
ok( fired_continue() == 1, 'result : a repeated answer fires nothing' );

## events out : a closed gate waits, usage signals reopen it ##

@sent = @routed = @timers = @timer_args = ();
add( 'task', 'g2', $gated, 'budget=claude:5h<60' );
answer( $routed[0], 'size', "claude 5h 72.0 3600\nclaude 7d 50.0 90000" );
my $e = entry( 'task', 'g2' );
ok( $e->{'state'} eq 'waiting'
        && $e->{'gate'} eq 'closed'
        && !fired_continue(),
    'events : a closed gate does not fail the entry, it waits'
);
ok( abs( $e->{'gate_at'} - ( time + 3600 + 21 ) ) <= 2,
    'events : re-check at the reset of the reading plus a margin'
);
my @retry = timers_of('retry');
ok( @retry == 1 && abs( $retry[0]{'after'} - 3621 ) <= 2,
    'events : the re-check timer is armed [ after, not delay ]'
);
ok( show('task')
        =~ m{g2 .*budget claude:5h<60 \[ closed : claude 5h 72\.0 % used},
    'events : bucket-show shows the closed gate and its reading'
) or say '#   ' . show('task');
ok( read_text("$tmp/var/bucket/task.bucket")
        =~ m{^entry\.g2\.gate = closed$}m,
    'events : the closed gate is saved'
);
my $woken = $code{'events.signal.raise'}->(
    'usage', 'usage.threshold',
    { 'provider' => 'claude', 'window' => '5h', 'crossed' => 'up' }
);
ok( !@{$woken} && @routed == 1,
    'events : a threshold crossed up does not reopen it' );
$woken = $code{'events.signal.raise'}->(
    'usage', 'usage.window.reset', { 'provider' => 'kimi', 'window' => '5h' }
);
ok( !@{$woken} && @routed == 1,
    'events : a reset of another provider does not reopen it' );
$woken = $code{'events.signal.raise'}->(
    'usage', 'usage.threshold',
    { 'provider' => 'claude', 'window' => '5h', 'crossed' => 'down' }
);
ok( "@{$woken}" eq 'task/g2' && @routed == 2 && !fired_continue(),
    'events : crossed down of the provider reads the gate again, no fire'
);
answer( $routed[1], 'size', "claude 5h 55.0 1800" );
ok( entry( 'task', 'g2' )->{'state'} eq 'fired' && fired_continue() == 1,
    'events : the read after the signal opens and fires it'
);

@sent = @routed = ();
add( 'task', 'g3', $gated, 'budget=claude:7d<=40' );
answer( $routed[0], 'size', "claude 7d 50.0 90000" );
$woken = $code{'events.signal.raise'}->(
    'usage', 'usage.window.reset',
    { 'provider' => 'claude', 'window' => '7d' }
);
ok( "@{$woken}" eq 'task/g3' && @routed == 2,
    'events : usage.window.reset of the provider reads it again' );
answer( $routed[1], 'size', "claude 7d 10.0 600000" );
ok( entry( 'task', 'g3' )->{'state'} eq 'fired',
    'events : <= holds after the reset'
);

## child crash : unreadable usage closes, never fails ##

@sent = @routed = @timer_args = ();
add( 'task', 'g4', $gated, 'budget=kimi:5h<50' );
answer( $routed[0], 'false', 'client not present' );
$e = entry( 'task', 'g4' );
ok( $e->{'state'} eq 'waiting'
        && $e->{'gate'} eq 'closed'
        && $e->{'gate_reading'}
        =~ m{usage not readable \[ client not present},
    'crash : usage not reachable : closed with the reason'
);
ok( abs( $e->{'gate_at'} - ( time + 55 ) ) <= 2,
    'crash : no reset known : re-check on the budget-gate rhythm' );
$code{'events.bucket.gate.handler.retry'}
    ->( FakeEvent->new( ( timers_of('retry') )[-1]{'data'} ) );
ok( @routed == 2, 'crash : the re-check timer reads usage again' );
answer( $routed[1], 'size', "kimi error token expired" );
ok( entry( 'task', 'g4' )->{'gate_reading'} eq 'usage : token expired',
    'crash : a provider error row is unreadable : closed'
);
answer( $routed[1], 'size', "kimi 7d 10.0 600" );
@routed = ();
$code{'events.bucket.gate.handler.retry'}
    ->( FakeEvent->new( ( timers_of('retry') )[-1]{'data'} ) );
answer( $routed[0], 'size', "kimi 7d 10.0 600" );
ok( entry( 'task', 'g4' )->{'gate_reading'} eq 'usage : no kimi 5h row',
    'crash : no row for the window : closed' );
{
    local $code{'protocol-7.route-send'} = sub {FALSE};
    @timer_args = ();
    $code{'events.bucket.gate.handler.retry'}->(
        FakeEvent->new(
            {   'owner' => 'task',
                'id'    => 'g4',
                'added' => entry( 'task', 'g4' )->{'added'}
            }
        )
    );
    ok( entry( 'task', 'g4' )->{'gate_reading'} eq
            'usage zenka not reachable'
            && timers_of('retry') == 1
            && !timers_of('guard'),
        'crash : no route at all : closed, re-check armed'
    );
}

## crash : usage dies mid-read, no answer ever comes : the guard ##

@sent = @routed = @timer_args = ();
add( 'task', 'g6', $gated, 'budget=claude:5h<60' );
my @guard = timers_of('guard');
ok( @guard == 1 && $guard[0]{'after'} == 89,
    'crash : a read arms an answer guard'
);
$code{'events.bucket.gate.handler.guard'}
    ->( FakeEvent->new( $guard[0]{'data'} ) );
$e = entry( 'task', 'g6' );
ok( $e->{'state'} eq 'waiting'
        && $e->{'gate'} eq 'closed'
        && $e->{'gate_reading'} eq 'no answer from usage'
        && !defined $e->{'gate_check'}
        && timers_of('retry') == 1,
    'crash : no answer : the guard closes the gate, re-check armed'
);
answer( $routed[0], 'size', "claude 5h 1.0 100" );
ok( !fired_continue() && entry( 'task', 'g6' )->{'gate'} eq 'closed',
    'crash : a late answer after the guard is dropped'
);
@timer_args = ();
my $g6 = entry( 'task', 'g6' );
$code{'events.bucket.gate.handler.retry'}->(
    FakeEvent->new(
        { 'owner' => 'task', 'id' => 'g6', 'added' => $g6->{'added'} }
    )
);
@guard = timers_of('guard');
answer( $routed[-1], 'size', "claude 5h 1.0 100" );
ok( @guard == 1, 'crash : the next read arms a fresh guard' );
$code{'events.bucket.gate.handler.guard'}
    ->( FakeEvent->new( $guard[0]{'data'} ) );
ok( entry( 'task', 'g6' )->{'state'} eq 'fired' && fired_continue() == 1,
    'crash : the answered read fires, its stale guard does nothing'
);

## interrupt : a stale answer [ entry replaced or removed ] is dropped ##

@sent = @routed = ();
add( 'task', 'g5', $gated, 'budget=claude:5h<60' );
my $old_route = $routed[0];
add( 'task', 'g5', $gated, 'budget=claude:5h<60' );
ok( @routed == 2, 'interrupt : the replaced entry asks again' );
answer( $old_route, 'size', "claude 5h 1.0 100" );
ok( !fired_continue() && entry( 'task', 'g5' )->{'state'} eq 'waiting',
    'interrupt : the answer for the replaced entry fires nothing'
);
cmd( 'bucket-remove', 'task g5' );
answer( $routed[-1], 'size', "claude 5h 1.0 100" );
ok( !fired_continue(),
    'interrupt : an answer for a removed entry is dropped' );

## restart resume : closed gates re-arm, a passed re-check reads again ##

reset_state();
add( 'task', 'r1', $gated, 'budget=claude:5h<60' );
answer( $routed[0], 'size', "claude 5h 90.0 7200" );
add( 'task', 'r2', $gated, 'budget=claude:7d<60' );
answer( $routed[1], 'size', "claude 7d 90.0 9000" );
add( 'task', 'r3', $gated, 'budget=claude:5h<60' );    ## in flight ##
entry( 'task', 'r2' )->{'gate_at'} = time - 10;        ## passed while down ##
$code{'events.bucket.save'}->('task');
restart();
ok( entry( 'task', 'r1' )->{'state'} eq 'waiting'
        && entry( 'task', 'r1' )->{'gate'} eq 'closed'
        && grep( { $ARG->{'handler'} eq 'events.bucket.gate.handler.retry' }
        @timer_args ) == 1,
    'restart : a closed gate stays closed, its re-check armed again'
);
my %asked = map { $ARG->{'reply'}{'params'}{'id'} => 1 } @routed;
ok( $asked{'r2'} && $asked{'r3'} && !$asked{'r1'},
    'restart : a passed re-check and a check in flight read usage again' );
ok( !grep( { entry( 'task', $ARG )->{'state'} ne 'waiting' } qw| r1 r2 r3 | ),
    'restart : no gated entry fails as interrupted'
);

## park : budget= passes into the bucket-add line ##

my $req = $code{'park.request'}->(
    {   'prefix'  => 'task',
        'task_id' => 'ABC1234',
        'count'   => 1,
        'pairs'   => { 'after' => 'bucket-wait', 'budget' => 'claude:5h<60' }
    }
);
ok( !defined $req->{'error'}
        && $req->{'args'} =~ m{ budget="claude:5h<60"}
        && $req->{'record'}{'budget'} eq 'claude:5h<60',
    'park : budget= goes into the bucket-add line and the record'
);
ok( $code{'park.describe'}->( $req->{'record'} ) =~ m{budget claude:5h<60},
    'park : describe shows the budget' );
my $line = $req->{'args'};
$line =~ s{\Atask-ABC1234-1 }{};
reset_state();
$r = add( 'task', 'task-ABC1234-1', $line );
ok( $r->{'mode'} eq 'true'
        && entry( 'task', 'task-ABC1234-1' )->{'budget'} eq 'claude:5h<60',
    'park : events accepts the line park built'
) or say "#   $r->{'data'}";

## usage watch : thresholds and resets as signals ##

%data = ();
@sent = @timers = @timer_args = ();
reset_state();
my @queries;
$code{'usage.query'} = sub { push @queries, [@ARG]; return 'q1' };
my $signals = sub {
    return [
        map  {s{\Acube\.events\.signal \| }{}r}
        grep {m{\Acube\.events\.signal}} @sent
    ];
};
my $now0 = time;
my $rows = sub {
    my ( $pct5, $ep5 ) = @ARG;
    return {
        'rows' => [
            {   'window'      => '5h',
                'used_pct'    => $pct5,
                'reset_epoch' => $ep5,
                'resets_in'   => $ep5 - time
            },
            {   'window'      => '7d',
                'used_pct'    => 20,
                'reset_epoch' => $now0 + 400000,
                'resets_in'   => 400000
            }
        ]
    };
};
$code{'usage.watch.observe'}->( 'claude', $rows->( 48, $now0 + 3000 ) );
ok( !@{ $signals->() }, 'watch : the first reading is the baseline' );
ok( grep( { $ARG->{'handler'} eq 'usage.handler.window_reset' } @timer_args )
        == 2,
    'watch : a reset timer per window'
);
my ($t5) = grep { $ARG->{'data'}{'window'} eq '5h' } @timer_args;
ok( abs( $t5->{'after'} - 3013 ) <= 2,
    'watch : the timer fires a margin after the reset' );
$code{'usage.watch.observe'}->( 'claude', $rows->( 52, $now0 + 3000 ) );
ok( "@{ $signals->() }" eq 'usage.threshold crossed=up percent=50 '
        . 'provider=claude used=52.0 window=5h',
    'watch : 48 -> 52 raises usage.threshold 50 up'
) or say "#   @{ $signals->() }";
@sent = ();
$code{'usage.watch.observe'}->( 'claude', $rows->( 80, $now0 + 3000 ) );
ok( "@{ $signals->() }" =~ m{percent=75 .*crossed=up|crossed=up percent=75},
    'watch : 52 -> 80 raises 75 up' );
@sent = ();
$code{'usage.watch.observe'}->( 'claude', $rows->( 40, $now0 + 3000 ) );
ok( @{ $signals->() } == 2 && !grep( {m{crossed=up}} @{ $signals->() } ),
    'watch : 80 -> 40 raises 50 and 75 down' );
@sent = ();
$data{'usage'}{'cfg'}{'thresholds'} = '30, 95';
$code{'usage.watch.observe'}->( 'claude', $rows->( 29, $now0 + 3000 ) );
ok( scalar( "@{ $signals->() }" =~ m{percent=30 } ),
    'watch : thresholds from config' );

## the reset timer : raised once, queried again, re-armed ##

@sent = @timer_args = @queries = ();
$code{'usage.handler.window_reset'}->( FakeEvent->new( $t5->{'data'} ) );
ok( "@{ $signals->() }" eq 'usage.window.reset provider=claude window=5h',
    'reset : the timer raises usage.window.reset' );
ok( @queries == 1 && "@{ $queries[0][0] }" eq 'claude',
    'reset : the provider is queried again'
);
ok( @timer_args == 1 && $timer_args[0]{'after'} == 34,
    'reset : a re-query is armed on the usage-requery rhythm'
);
{
    local $data{'usage'}{'cfg'}{'requery_max'} = 3;
    @queries = @timer_args = ();
    $code{'usage.handler.window_reset'}->( FakeEvent->new( $t5->{'data'} ) )
        for 1 .. 4;
    ok( @queries == 2 && @timer_args == 2,
        'reset : the re-query stops after requery_max reads' );
}
@sent = ();
$code{'usage.handler.window_reset'}->( FakeEvent->new( $t5->{'data'} ) );
ok( !@{ $signals->() }, 'reset : the same reset is raised once only' );
$code{'usage.watch.observe'}->( 'claude', $rows->( 2, $now0 + 21000 ) );
ok( !grep( {m{window\.reset}} @{ $signals->() } ),
    'reset : the new window seen : no second reset signal'
);
my ($t5b) = grep {
            $ARG->{'handler'} eq 'usage.handler.window_reset'
        and $ARG->{'data'}{'epoch'} == $now0 + 21000
} @timer_args;
ok( defined $t5b, 'reset : the timer of the next window is armed' );

## missed by the timer : the next reading raises the reset ##

%data = ();
reset_state();
@sent = ();
$code{'usage.watch.observe'}->( 'kimi', $rows->( 10, time - 60 ) );
$code{'usage.watch.observe'}->( 'kimi', $rows->( 1,  time + 18000 ) );
ok( "@{ $signals->() }" eq 'usage.window.reset provider=kimi window=5h',
    'reset : a reset the timer missed is raised on the next reading'
);

## provider_result feeds the watch ##

@sent = ();
$data{'usage'}{'requests'}{'q9'} = {
    'order'   => ['claude'],
    'pending' => 2,
    'results' => {},
    'started' => time
};
$code{'usage.handler.provider_result'}->(
    {   'ok'     => TRUE,
        'params' => { 'req_id' => 'q9', 'provider' => 'claude' },
        'result' => $rows->( 33, time + 3000 )
    }
);
ok( defined $data{'usage'}{'watch'}{'state'}{'claude'}{'5h'},
    'watch : every provider result is observed' );

## usage.plan ##

my $plan = $code{'usage.format.plan'}->(
    {   'order'   => [ 'claude', 'kimi' ],
        'results' => {
            'claude' => {
                'ok'     => TRUE,
                'result' => {
                    'rows' => [
                        {   'window'    => '7d',
                            'used_pct'  => 40,
                            'resets_in' => 5 * 86400
                        },
                        {   'window'    => '5h',
                            'used_pct'  => 25,
                            'resets_in' => 7200
                        }
                    ]
                }
            },
            'kimi' => { 'ok' => FALSE, 'error' => 'token expired' }
        }
    }
);
ok( $plan =~ m{5h  :  75\.0 % left : resets in 2\.0 h}
        && $plan =~ m{7d  :  60\.0 % left : resets in 120\.0 h},
    'plan : percent left and hours to reset per window'
) or say "# $plan";
ok( $plan        =~ m{5h windows before the 7d reset : 25}
        && $plan =~ m{share per 5h window : 2\.4 % of the 7d}
        && $plan =~ m{share per day : 12\.0 % of the 7d}
        && $plan =~ m{last window is shortened to 3\.0 h},
    'plan : 5h windows left and the share per window and day'
) or say "# $plan";
## the owner's case : 16 h to the 7d reset, the 5h window resets in 4.7 h ##
my $plan2 = $code{'usage.format.plan'}->(
    {   'order'   => ['claude'],
        'results' => {
            'claude' => {
                'ok'     => TRUE,
                'result' => {
                    'rows' => [
                        {   'window'    => '7d',
                            'used_pct'  => 65,
                            'resets_in' => 16 * 3600
                        },
                        {   'window'    => '5h',
                            'used_pct'  => 17,
                            'resets_in' => int( 4.7 * 3600 )
                        }
                    ]
                }
            }
        }
    }
);
ok( $plan2 =~ m{5h windows before the 7d reset : 4}
        && $plan2 =~ m{share per 5h window : 8\.8 % of the 7d},
    'plan : the running window counts once, then whole 5h slots'
) or say "# $plan2";
## pace : 4 % of the 7d used in the first hour of a window, 4 h left ##
my $t0 = time;
$data{'usage'}{'pace'}{'records'} = {
    'claude' => {
        'epoch5h' => $t0 + 4 * 3600,
        'start7d' => 61,
        'start5h' => 22,
        'start'   => $t0 - 3600
    }
};
my $pace_req = sub {
    my ( $used7d, $used5h ) = @ARG;
    return $code{'usage.format.plan'}->(
        {   'order'   => ['claude'],
            'now'     => $t0,
            'results' => {
                'claude' => {
                    'ok'     => TRUE,
                    'result' => {
                        'rows' => [
                            {   'window'    => '7d',
                                'used_pct'  => $used7d,
                                'resets_in' => 16 * 3600
                            },
                            {   'window'    => '5h',
                                'used_pct'  => $used5h // 40,
                                'resets_in' => 4 * 3600
                            }
                        ]
                    }
                }
            }
        }
    );
};
my $fast = $pace_req->(65);
ok( $fast
        =~ m{this window : 4\.0 % of the 7d, 18\.0 % of the 5h used in 1\.0 h}
        && $fast =~ m{pace now : 18\.0 %/h of the 5h \[ 4\.0 %/h of the 7d \]}
        && $fast
        =~ m{pace fits : 6\.5 %/h of the 5h \[ 1\.4 %/h of the 7d \] : slow down to about x0\.36},
    'pace : too fast for the share -> slow down with the factor'
) or say "# $fast";
ok( $fast        =~ m|^ :       \[:{10} {16}\] used$|m
        && $fast =~ m|^ : share used : \[:{11} {15}\]  41 %$|m
        && $fast !~ m{\e},
    'bars : window used and share used, plain characters'
) or say "# $fast";
## the owner's case 2026-11-25 : 4 % of the 7d left, 0.9 h to the week's ##
## end, 4.4 h to the 5h reset -- the nearer horizon decides              ##
$data{'usage'}{'pace'}{'records'}{'claude'} = {
    'epoch5h' => $t0 + 4.4 * 3600,
    'start7d' => 92,
    'start5h' => 0,
    'start'   => $t0 - 0.6 * 3600,
    'k'       => 9
};
my $last = $code{'usage.format.plan'}->(
    {   'order'   => ['claude'],
        'now'     => $t0,
        'results' => {
            'claude' => {
                'ok'     => TRUE,
                'result' => {
                    'rows' => [
                        {   'window'    => '7d',
                            'used_pct'  => 96,
                            'resets_in' => int( 0.9 * 3600 )
                        },
                        {   'window'    => '5h',
                            'used_pct'  => 35,
                            'resets_in' => int( 4.4 * 3600 )
                        }
                    ]
                }
            }
        }
    }
);
ok( $last =~ m{horizon : 0\.9 h \[ the 7d reset comes first \]}
        && $last
        =~ m{pace fits : 41\.1 %/h of the 5h \[ 4\.4 %/h of the 7d \] : slow down to about x0\.70},
    'pace : the nearer reset is the horizon [ the week ends first ]'
) or say "# $last";
ok( $last =~ m{share used : .*  48 %},
    'share used : against the fixed budget with the stored ratio' )
    or say "# $last";
delete $data{'usage'}{'pace'}{'records'}{'claude'}{'k'};
$data{'usage'}{'pace'}{'records'}{'claude'} = {
    'epoch5h' => $t0 + 4 * 3600,
    'start7d' => 61,
    'start5h' => 22,
    'start'   => $t0 - 3600
};
my $slow = $pace_req->( 61.5, 24 );
ok( $slow =~ m{pace now : 2\.0 %/h of the 5h}
        && $slow =~ m{: room to speed up x},
    'pace : well under the share -> room to speed up'
) or say "# $slow";
delete $data{'usage'}{'pace'}{'records'}{'claude'};
ok( $pace_req->(65) !~ m{pace},
    'pace : no window start record, no pace line' );
$data{'usage'}{'pace'}{'records'}{'claude'} = {
    'epoch5h' => $t0 + 4 * 3600,
    'start7d' => 61,
    'start5h' => 30,
    'start'   => $t0 - 3600
};
my $capped = $pace_req->( 63, 90 );
ok( $capped =~ m{pace fits : 2\.5 %/h of the 5h} && $capped =~ m{slow down},
    'pace : the 5h percent left caps the fitting rate' )
    or say "# $capped";

ok( $plan =~ m{ 7d  :.*\n.*\n : 5h  :},
    'plan : the 7d window first, then the 5h window' )
    or say "# $plan";
ok( $plan =~ m{\.: kimi plan :\.\n :\n : token expired},
    'plan : a failed provider shows its error'
);
ok( $plan !~ m|[{}]|, 'plan : no json' );

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,,,...,,..,...,.,.,..,,,.,,,..,,.,,..,,,..,..,,...,...,..,,,,.,,,,,..,,..,,
#SB7DBOAFZR3JZFJTBNZVGQ2XUG3BPMO55AO33WWX672KZUNTOUMG5CULVUSA2HF3VRLJAIX7SMCEK
#\\\|GYOHY6LMEQET372CD2JC5U6SLWH7DFCTOH2JOAWE2SCA5RN3XZF \ / AMOS7 \ YOURUM ::
#\[7]VUSRAKLC2ULTA2M2KLJSACSBSBVLEPXVRYMU3RKUYNRNRMZI7AAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
