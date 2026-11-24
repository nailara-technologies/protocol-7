#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## events zenka stage 2 : buckets -- runtime timetables with dependencies. ##
## compiles the real src modules [ stage 1 plugins included ] ; no zenka   ##
## started, no real cube : the command sender and the timers are stubs,    ##
## timers are fired by hand, times are moved by editing the entries, a     ##
## restart is simulated by clearing memory and reading the files again.    ##

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

my @sent;      ## command sends : "command | args" ##
my @logged;    ## log lines, formatted ##
my @timers;    ## add_timer calls : "handler at" ##

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
$code{'base.time'}                     = sub {time};
$code{'dependency.ok'}                 = sub {TRUE};
$code{'file.put'}                      = sub {TRUE};
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
    base.interval.next
    base.interval.rhythm.non-linear
    |;

my $plugin_dir = File::Spec->catdir( $root_path, 'src' );
opendir my $dh, $plugin_dir or die "cannot open src : $OS_ERROR";
load_module($ARG)
    for grep {m{\Aplugin\.events\.(?:action|source)\.[\w-]+\z}} readdir $dh;
closedir $dh;

my $tmp = tempdir( 'events-buckets-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
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

sub bucket_entry {
    my ( $owner, $id ) = @ARG;
    return $data{'events'}{'buckets'}{$owner}{'entries'}{$id};
}

sub state_of {
    my $e = bucket_entry(@ARG);
    return defined $e ? $e->{'state'} : 'none';
}

sub fire_timer {
    my ( $owner, $id ) = @ARG;
    $code{'events.handler.event_triggered'}->(
        FakeEvent->new(
            { 'type' => 'at', 'id' => "$owner/$id", 'at' => time }
        )
    );
}

sub restart {    ## memory gone, files stay : a new process ##
    my @keep     = ( 'bucket_dir', 'signal' );
    my %keep     = map { $ARG => $data{'events'}{$ARG} } @keep;
    my $interval = $data{'base'};
    %data                      = ( 'base' => $interval, 'events' => {%keep} );
    $data{'events'}{'setup'}   = {};
    $data{'events'}{'enabled'} = {};
    @sent                      = @logged = @timers = ();
    $code{'events.bucket.start'}->();
}

sub read_text {
    my $path = shift;
    return -f $path ? read_file($path) : '';
}

## parse_args : words, key=value, quotes ##

reset_state();
my $p = $code{'events.bucket.parse_args'}->(
    'coding t1 command="coding.list-tools a \"b\"" reason=x at=5 match.k=v');
ok( "@{ $p->{'words'} }" eq 'coding t1'
        && $p->{'pairs'}{'command'} eq 'coding.list-tools a "b"'
        && $p->{'pairs'}{'match.k'} eq 'v'
        && $p->{'pairs'}{'at'} eq '5',
    'parse : words, key=value, a quoted value with spaces and a quote'
);
ok( defined $code{'events.bucket.parse_args'}->('a k="open')->{'error'},
    'parse : an unclosed quote is an error' );
ok( defined $code{'events.bucket.parse_args'}->('a k=1 k=2')->{'error'},
    'parse : a repeated key is an error' );

## add : the owner comes from the cube alias, the bucket is created ##

reset_state();
my $r = add(
    'coding',                          'a1',
    "at=@{[ $now + 3600 ]}",           'action=send-command',
    'command="coding.list-tools x y"', 'reason="first look"'
);
ok( $r->{'mode'} eq 'true' && $r->{'data'} =~ m{added \[ waiting \]},
    'add : an entry is added and waits' )
    or say "#   $r->{'data'}";
ok( @timers == 1, 'add : a timer is set for the time' );
ok( !@sent,       'add : nothing is sent before its time' );
ok( -f "$tmp/var/bucket/coding.bucket", 'add : the bucket file is written' );
my $file = read_text("$tmp/var/bucket/coding.bucket");
ok( $file =~ m{^entry\.a1\.state = waiting$}m
        && $file =~ m{^entry\.a1\.param\.command = coding\.list-tools x y$}m,
    'add : the file is p7 config style, readable'
);
ok( !-e "$tmp/var/bucket/coding.bucket.tmp", 'add : no tmp file is left' );
ok( !( $file =~ m|[{}]| ),                   'add : no json in the file' );

## replace ##

$r = add(
    'coding',                'a1',
    "at=@{[ $now + 7200 ]}", 'action=send-command',
    'command="coding.list-tools z"'
);
ok( $r->{'data'} =~ m{replaced},
    'replace : the same id replaces a waiting entry' );
ok( bucket_entry( 'coding', 'a1' )->{'action'}{'command'} eq
        'coding.list-tools z',
    'replace : the new entry is in'
);
ok( @{ $data{'events'}{'buckets'}{'coding'}{'order'} } == 1,
    'replace : one entry, not two' );
ok( @timers == 2
        && $data{'events'}{'timers'}{'coding/a1'}{'at'}{'args'}{'at'}
        == $now + 7200,
    'replace : the timer follows the new time'
);

## each `when` ##

reset_state();
$r = add(
    'coding',             'past',
    "at=@{[ $now - 5 ]}", 'action=send-command',
    'command="coding.go 1"'
);
ok( state_of( 'coding', 'past' ) eq 'fired'
        && "@sent" eq 'cube.coding.go | 1',
    'when at : a time already past fires at once'
) or say "#   @sent";

@sent = ();
$r    = add(
    'coding',                'later',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command="coding.go 2"'
);
ok( state_of( 'coding', 'later' ) eq 'waiting' && !@sent,
    'when at : a future time waits' );
fire_timer( 'coding', 'later' );
ok( state_of( 'coding', 'later' ) eq 'fired'
        && "@sent" eq 'cube.coding.go | 2',
    'when at : its timer fires it'
);
@sent = ();
fire_timer( 'coding', 'later' );
ok( !@sent, 'exactly once : the same timer again sends nothing' );

@sent = ();
$r    = add(
    'coding',                  'aft',
    'after=bucket-wait-short', 'action=send-command',
    'command="coding.go 3"'
);
my $aft = bucket_entry( 'coding', 'aft' );
ok( $r->{'mode'} eq 'true'
        && $aft->{'at'} - time >= 20
        && $aft->{'at'} - time <= 150
        && $aft->{'after'} eq 'bucket-wait-short',
    'when after : the delay comes from base.interval.next [ stored absolute ]'
) or say '#   ' . ( $aft->{'at'} - time );
ok( $timers[-1] =~ m{events\.handler\.event_triggered \d+},
    'when after : a timer is set' );
$r = add(
    'coding',         'aft2',
    'after=nonsense', 'action=send-command',
    'command=coding.go'
);
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{not configured},
    'when after : an interval type that is not configured is refused'
);
$r = add(
    'coding',    'aft3',
    'after=300', 'action=send-command',
    'command=coding.go'
);
ok( $r->{'mode'} eq 'false',
    'when after : a literal number of seconds is refused' );

@sent = ();
$r    = add(
    'coding',              'sig',
    'on=claude.run.done',  'match.state=ok',
    'action=send-command', 'command="coding.go 4"'
);
ok( state_of( 'coding', 'sig' ) eq 'waiting',
    'when on : waits for the signal'
);
$call = { 'args' => 'claude claude.run.done state=failed' };
$data{'events'}{'signal'}{'access_file'} = $main::access_file;
$data{'events'}{'signal'}{'grants_file'} = "$tmp/access.signals";
open $afh, '>:encoding(UTF-8)', "$tmp/access.signals" or die $OS_ERROR;
print {$afh} "   events.signal.claude = claude.*\n";
close $afh;
my $res = $code{'events.cmd.signal'}->();
ok( state_of( 'coding', 'sig' ) eq 'waiting' && !@sent,
    'when on : a signal with another value does not wake it'
) or say "#   $res->{'data'}";
$call = { 'args' => 'claude claude.run.done state=ok' };
$res  = $code{'events.cmd.signal'}->();
ok( state_of( 'coding', 'sig' ) eq 'fired'
        && "@sent" eq 'cube.coding.go | 4'
        && $res->{'data'} =~ m{1 woken},
    'when on : the matching signal fires it [ counted in the woken ]'
) or say "#   $res->{'data'} @sent";
@sent = ();
$call = { 'args' => 'claude claude.run.done state=ok' };
$code{'events.cmd.signal'}->();
ok( !@sent, 'exactly once : the same signal again sends nothing' );
ok( read_text("$tmp/var/signal.journal") =~ m{woken:coding/sig},
    'when on : the signal journal names the woken bucket entry'
);

@sent = ();
$r = add( 'coding', 'plain', 'action=send-command', 'command="coding.go 5"' );
ok( state_of( 'coding', 'plain' ) eq 'fired'
        && "@sent" eq 'cube.coding.go | 5',
    'when none : due at once'
);
$r = add( 'coding', 'two', 'at=1', 'on=x', 'action=send-command',
    'command=coding.go' );
ok( $r->{'mode'} eq 'false', 'when : two of at, after, on are refused' );

## dependencies ##

reset_state();
@sent = ();
$r    = add(
    'coding',    'c',
    'depends=b', 'action=send-command',
    'command="coding.go c"'
);
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{'b' is not in the bucket},
    'depends : an entry that is not in the bucket is refused'
);
add('coding',                'a',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command="coding.go a"'
);
add('coding',    'b',
    'depends=a', 'action=send-command',
    'command="coding.go b"'
);
add('coding',      'c',
    'depends=a,b', 'action=send-command',
    'command="coding.go c"'
);
ok( state_of( 'coding', 'b' ) eq 'waiting'
        && state_of( 'coding', 'c' ) eq 'waiting'
        && !@sent,
    'depends : dependants wait while their dependency waits'
);
fire_timer( 'coding', 'a' );
ok( "@sent" eq 'cube.coding.go | a cube.coding.go | b cube.coding.go | c',
    'depends : fired in dependency order' )
    or say "#   @sent";
ok( state_of( 'coding', 'c' ) eq 'fired', 'depends : all fired' );

## a dependency that fails blocks the dependants ##
reset_state();
@sent = ();
add( 'coding', 'f', 'action=send-command', 'command=boom.now' );
ok( state_of( 'coding', 'f' ) eq 'failed'
        && bucket_entry( 'coding', 'f' )->{'result'} =~ m{boom},
    'failed : an action that dies is failed with the reason'
);
add('coding',    'g',
    'depends=f', 'action=send-command',
    'command="coding.go g"'
);
ok( state_of( 'coding', 'g' ) eq 'blocked'
        && bucket_entry( 'coding', 'g' )->{'result'}
        =~ m{dependency 'f' failed : boom}
        && !@sent,
    'blocked : the dependant is blocked with the reason, never sent'
) or say '#   ' . ( bucket_entry( 'coding', 'g' )->{'result'} // '' );
add('coding',    'h',
    'depends=g', 'action=send-command',
    'command="coding.go h"'
);
ok( state_of( 'coding', 'h' ) eq 'blocked',
    'blocked : a blockade passes on' );
ok( read_text("$tmp/var/bucket.journal") =~ m{state:failed}
        && read_text("$tmp/var/bucket.journal") =~ m{state:blocked},
    'journal : failed and blocked are appended'
);

## cycles ##
reset_state();
add('coding',                'x',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
add( 'coding', 'y', 'depends=x', 'action=send-command', 'command=coding.go' );
$r = add(
    'coding',                'x',
    "at=@{[ $now + 3600 ]}", 'depends=y',
    'action=send-command',   'command=coding.go'
);
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{cycle : x -> y -> x},
    'cycle : refused at add, the cycle is shown' )
    or say "#   $r->{'data'}";
$r = add(
    'coding',                'x',
    "at=@{[ $now + 3600 ]}", 'depends=x',
    'action=send-command',   'command=coding.go'
);
ok( $r->{'data'} =~ m{cycle : x -> x},
    'cycle : an entry depending on itself'
);
ok( bucket_entry( 'coding', 'x' )->{'depends'}->@* == 0,
    'cycle : the old entry is kept' );

## remove, clear, replace of a fired entry ##
reset_state();
add('coding',                'p',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command="coding.go p"'
);
add('coding',    'q',
    'depends=p', 'action=send-command',
    'command="coding.go q"'
);
$r = cmd( 'bucket-remove', 'coding p' );
ok( $r->{'mode'} eq 'true' && state_of( 'coding', 'p' ) eq 'none',
    'remove : the entry is gone' );
ok( state_of( 'coding', 'q' ) eq 'blocked'
        && bucket_entry( 'coding', 'q' )->{'result'} =~ m{no longer exists},
    'remove : a dependant is blocked [ its dependency is gone ]'
);
ok( cmd( 'bucket-remove', 'coding nope' )->{'mode'} eq 'false',
    'remove : an unknown id fails' );
add( 'coding', 'done', 'action=send-command', 'command="coding.go d"' );
$r = add( 'coding', 'done', 'action=send-command', 'command="coding.go e"' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{has fired},
    'replace : a fired entry is final' );
add('coding',                'w1',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
@timers = ();
$r      = cmd( 'bucket-clear', 'coding' );
ok( $r->{'data'} =~ m{^2 entries cleared}
        && state_of( 'coding', 'done' ) eq 'fired'
        && state_of( 'coding', 'w1' ) eq 'none'
        && state_of( 'coding', 'q' ) eq 'none',
    'clear : everything not fired goes, fired stays'
) or say "#   $r->{'data'}";

## show ##
reset_state();
add('coding',                's1',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go',     'reason="look later"'
);
add('coding',     's2',
    'depends=s1', 'on=sig.x',
    'match.k=v',  'action=send-command',
    'command=coding.go'
);
$r = cmd( 'bucket-show', 'coding' );
ok( $r->{'data'} =~ m{s1\s+waiting\s+time .* \[ in \d+ s \]\s+# look later}
        && $r->{'data'}
        =~ m{s2\s+waiting\s+signal sig\.x \[ k=v \] ; depends s1}
        && $r->{'data'} =~ m{not replayed},
    'show : entries, states, what each waits for, the replay note'
) or say "#   $r->{'data'}";

## limit ##
reset_state();
$data{'events'}{'bucket_limit'} = 3;
add('coding',                "l$ARG",
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
) for 1 .. 3;
$r = add(
    'coding',                'l4',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{full \[ 3 entries \]},
    'limit : an entry over the cap is refused' );
ok( add('coding',                'l1',
        "at=@{[ $now + 3600 ]}", 'action=send-command',
        'command=coding.go'
    )->{'mode'} eq 'true',
    'limit : replacing an entry at the cap is fine'
);
reset_state();
$data{'events'}{'bucket_limit'} = 2;
add( 'coding', 'old', 'action=send-command', 'command=coding.go' );
add('coding',                'new',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
$r = add(
    'coding',                'newer',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
ok( $r->{'mode'} eq 'true' && state_of( 'coding', 'old' ) eq 'none',
    'limit : at the cap the oldest fired '
        . 'entry is dropped [ the journal keeps it ]'
) or say "#   $r->{'data'}";

## the start timer handler loads the buckets once ##
reset_state();
add('coding',                'hs',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
%{ $data{'events'}{'buckets'} } = ();
$code{'events.bucket.handler.start'}->();
ok( state_of( 'coding', 'hs' ) eq 'waiting'
        && $data{'events'}{'bucket_started'},
    'start : the timer handler loads the bucket files'
);
{
    my $n = @timers;
    $code{'events.bucket.handler.start'}->();
    ok( @timers == $n, 'start : a second start changes nothing' );
}

## persistence : a round trip across a restart ##
reset_state();
@sent = ();
add('coding',                  'r1',
    "at=@{[ $now + 3600 ]}",   'action=send-command',
    'command="coding.go r 1"', 'reason="two words"',
    'missed=keep'
);
add('coding',     'r2',
    'depends=r1', 'on=sig.y',
    'match.a=b',  'action=task-continue',
    'id=task-7',  'message="carry on now"'
);
add( 'coding', 'r3', 'action=send-command', 'command="coding.done 1"' );
my $before       = bucket_entry( 'coding', 'r1' );
my %b            = %{$before};
my $order_before = join ',',
    @{ $data{'events'}{'buckets'}{'coding'}{'order'} };
@sent = ();
restart();
my $after = bucket_entry( 'coding', 'r1' );
ok( defined $after
        && $after->{'state'} eq 'waiting'
        && $after->{'at'} == $b{'at'}
        && $after->{'action'}{'command'} eq 'coding.go r 1'
        && $after->{'reason'} eq 'two words'
        && $after->{'missed'} eq 'keep',
    'persist : a waiting entry comes back as it was'
);
my $r2 = bucket_entry( 'coding', 'r2' );
ok( $r2->{'state'} eq 'waiting'
        && "@{ $r2->{'depends'} }" eq 'r1'
        && $r2->{'match'}{'a'} eq 'b'
        && $r2->{'on'} eq 'sig.y'
        && $r2->{'action'}{'message'} eq 'carry on now',
    'persist : depends, match, on and action params come back'
);
ok( join( ',', @{ $data{'events'}{'buckets'}{'coding'}{'order'} } ) eq
        $order_before,
    'persist : the order is kept'
);
ok( state_of( 'coding', 'r3' ) eq 'fired' && !@sent,
    'persist : a fired entry is not fired again at start'
);
ok( scalar( grep { $ARG =~ m{events\.handler\.event_triggered} } @timers )
        == 1,
    'persist : the future time is armed again'
);
fire_timer( 'coding', 'r1' );
ok( state_of( 'coding', 'r1' ) eq 'fired'
        && "@sent" eq 'cube.coding.go | r 1',
    'persist : the armed timer fires the restored entry'
);

## a restart in the middle of firing : never run twice ##
reset_state();
add('coding',                'm1',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command="coding.go m"'
);
bucket_entry( 'coding', 'm1' )->{'state'} = 'due';
$code{'events.bucket.save'}->('coding');
restart();
ok( state_of( 'coding', 'm1' ) eq 'failed'
        && !@sent
        && bucket_entry( 'coding', 'm1' )->{'result'} =~ m{interrupted},
    'exactly once : an entry found `due` at start is failed, never run again'
);

## missed ##
reset_state();
add('coding',                'mf',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command="coding.go mf"'
);
add('coding',                 'mk',
    "at=@{[ $now + 3600 ]}",  'action=send-command',
    'command="coding.go mk"', 'missed=keep'
);
add('coding',     'dep',
    'depends=mk', 'action=send-command',
    'command="coding.go dep"'
);
add('coding',                'fut',
    "at=@{[ $now + 7200 ]}", 'action=send-command',
    'command="coding.go fut"'
);
bucket_entry( 'coding', $ARG )->{'at'} = $now - 60 for qw| mf mk |;
$code{'events.bucket.save'}->('coding');
@sent = ();
restart();
ok( state_of( 'coding', 'mf' ) eq 'fired'
        && "@sent" eq 'cube.coding.go | mf'
        && bucket_entry( 'coding', 'mf' )->{'result'} =~ m{missed while down},
    'missed : missed=fire [ default ] fires once on start'
) or say "#   @sent";
ok( state_of( 'coding', 'mk' ) eq 'missed',
    'missed : missed=keep is kept as missed'
);
ok( state_of( 'coding', 'dep' ) eq 'blocked'
        && bucket_entry( 'coding', 'dep' )->{'result'}
        =~ m{dependency 'mk' missed},
    'missed : a dependant of a kept missed entry is blocked'
);
ok( state_of( 'coding', 'fut' ) eq 'waiting',
    'missed : a future time keeps waiting'
);
ok( read_text("$tmp/var/bucket.journal") =~ m{state:missed},
    'missed : journaled' );
@sent = ();
restart();
ok( !@sent && state_of( 'coding', 'mf' ) eq 'fired',
    'missed : a second start does not fire again'
);

## the journal and a leftover tmp file are never loaded as buckets ##
reset_state();
add( 'coding', 'j1', 'action=send-command', 'command=boom.now' );
add('coding',                'j2',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command="coding.go j2"'
);
my $journal_before = read_text("$tmp/var/bucket.journal");
ok( $journal_before =~ m{state:failed},
    'journal : holds the failed entry before the restarts' );
open my $tfh, '>:encoding(UTF-8)', "$tmp/var/bucket/" . "coding.bucket.tmp"
    or die $OS_ERROR;
print {$tfh}
    "entry.t1.state = waiting\nentry.t1.when = none\nentry.t1.met = "
    . "1\nentry.t1.action = send-command\nentry.t1.param.command = "
    . "coding.go tmp\n";
close $tfh;
@sent = ();
restart();
restart();
ok( index( read_text("$tmp/var/bucket.journal"), $journal_before ) == 0,
    'journal : still starts with the earlier lines after two restarts'
);
ok( !defined $data{'events'}{'buckets'}{'journal'}
        && !defined $data{'events'}{'buckets'}{'coding.bucket.tmp'},
    'journal : not loaded as a bucket'
);
ok( !@sent && !defined bucket_entry( 'coding', 't1' ),
    'tmp : a leftover tmp file is neither loaded nor fired'
);

## cap pruning keeps a dependency the new entry names ##
reset_state();
$data{'events'}{'bucket_limit'} = 2;
add( 'coding', 'old', 'action=send-command', 'command=coding.go' );
add('coding',                'keep',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
$r = add(
    'coding',              'dep',
    'depends=old',         "at=@{[ $now + 3600 ]}",
    'action=send-command', 'command=coding.go'
);
ok( $r->{'mode'} eq 'false' && state_of( 'coding', 'old' ) eq 'fired',
    'limit : a fired entry the new one depends on is not pruned'
) or say "#   $r->{'data'}";

## signals while down are not replayed ##
reset_state();
add('coding',    'sg',
    'on=net.up', 'action=send-command',
    'command="coding.go sg"'
);
restart();
ok( state_of( 'coding', 'sg' ) eq 'waiting' && !@sent,
    'signals : an entry still waits after a restart [ nothing replayed ]' );

## owner isolation ##
reset_state();
add('coding',                'iso',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command=coding.go'
);
add('task',                  'iso',
    "at=@{[ $now + 3600 ]}", 'action=send-command',
    'command="task.show 1"'
);
ok( state_of( 'coding', 'iso' ) eq 'waiting'
        && state_of( 'task', 'iso' ) eq 'waiting'
        && bucket_entry( 'coding', 'iso' )->{'action'}{'command'} ne
        bucket_entry( 'task', 'iso' )->{'action'}{'command'},
    'isolation : the same id in two buckets are two entries'
);
ok( -f "$tmp/var/bucket/coding.bucket" && -f "$tmp/var/bucket/task.bucket",
    'isolation : one file per bucket' );
$r = cmd( 'bucket-show', 'task' );
ok( $r->{'data'} =~ m{task\.show} || $r->{'data'} =~ m{iso},
    'isolation : show lists the caller\'s entries'
);
ok( $r->{'data'} !~ m{coding},
    'isolation : show of task never shows coding entries' );
cmd( 'bucket-remove', 'task iso' );
ok( state_of( 'coding', 'iso' ) eq 'waiting',
    'isolation : a remove from task leaves coding\'s entry' );
cmd( 'bucket-clear', 'task' );
ok( state_of( 'coding', 'iso' ) eq 'waiting',
    'isolation : a clear from task leaves coding\'s bucket' );
ok( cmd( 'bucket-remove', 'task iso' )->{'mode'} eq 'false',
    'isolation : task has no entry of coding\'s to remove'
);
$r = cmd( 'bucket-show', '' );
ok( $r->{'mode'} eq 'false', 'isolation : no source zenka, no bucket' );
$r = add(
    'coding',     'sneak',
    'owner=task', 'action=send-command',
    'command=coding.go'
);
ok( !defined bucket_entry( 'task', 'sneak' )
        && defined bucket_entry( 'coding', 'sneak' ),
    'isolation : an owner= value is only an action parameter, never the owner'
);

## access : the command must be one the owner may send ##
reset_state();
$r = add(
    'coding',              'acc',
    'action=send-command', 'command="v7-zenki.restart cube"'
);
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{may not send 'v7-zenki\.restart'}
        && !@sent,
    'access : a command the owner is not granted is refused at add'
);
$r = add( 'coding', 'acc', 'action=send-command', 'command=coding.anything' );
ok( $r->{'mode'} eq 'true', 'access : a `zenka.*` grant covers the command' );
$r = add( 'nobody', 'acc', 'action=send-command', 'command=heart' );
ok( $r->{'mode'} eq 'false',
    'access : an unlisted zenka has only the wildcard list' );

## task-continue ##
reset_state();
@sent = ();
$r    = add(
    'coding',               'tc',
    'action=task-continue', 'id=task-42',
    'message="go on with step two"'
);
ok( $r->{'mode'} eq 'true'
        && "@sent" eq 'cube.task.continue | task-42 go on with step two',
    'task-continue : sends task.continue <id> <message>'
) or say "#   @sent $r->{'data'}";
$r = add( 'coding', 'tc2', 'action=task-continue', 'id=task-43' );
ok( state_of( 'coding', 'tc2' ) eq 'failed'
        && bucket_entry( 'coding', 'tc2' )->{'result'}
        =~ m{'message' parameter},
    'task-continue : a missing message fails the entry with the reason'
);
$r = add(
    'coding',      'tc3',
    'on=run.done', 'action=task-continue',
    'id=task-44',  'message=wake'
);
@sent = ();
$call = { 'args' => 'claude claude.run.done' };
$data{'events'}{'signal'}{'access_file'} = $main::access_file;
$code{'events.cmd.signal'}->();
ok( "@sent" eq '',
    'task-continue : a signal of another name does not wake it' );
$call = { 'args' => 'claude run.done' };
$code{'events.plugin.registry'}->()->{'source'}{'signal'}{'wake'}
    ->( 'claude', 'run.done', {} );
ok( "@sent" eq 'cube.task.continue | task-44 wake',
    'task-continue : parked on a signal, woken by it'
);
$r = add( 'task', 'tc4', 'action=task-continue', 'id=task-1', 'message=m' );
ok( $r->{'mode'} eq 'true',
    'task-continue : the task zenka may park its own continuation' );
$r = add( 'coding', 'bad', 'action=playlist-show-entry' );
ok( $r->{'mode'} eq 'false' && $r->{'data'} =~ m{no command to check},
    'action : a type without a checkable command is not for buckets'
);
$r = add( 'coding', 'bad2', 'action=nothing-here' );
ok( $r->{'mode'} eq 'false'
        && $r->{'data'} =~ m{no action plugin 'nothing-here'},
    'action : an unknown type is refused with the known ones'
);

## the plugins : bucket-dependency is registered, stage 1 sources intact ##
my $reg = $code{'events.plugin.registry'}->();
ok( exists $reg->{'source'}{'bucket-dependency'}
        && exists $reg->{'source'}{'signal'}
        && exists $reg->{'source'}{'timetable'}
        && exists $reg->{'action'}{'task-continue'},
    'plugins : bucket-dependency and '
        . 'task-continue are registered beside stage 1'
);

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,,,,,,,,,.,,.,.,,,.,..,,,..,,..,,.,,.,.,,,,,..,,...,...,..,,,,,,,..,,..,,..,
#NZLMV2HVB4LKOTGKNLAJ62VMWALDB5CQJVZBVDEKM2JQFRSCIGW2YEFBPVD35AYYZBW6YV5CK3BA4
#\\\|TIBBAUHZK5IGSTIWYU34AGGGEIFN3RTHRFA6X6FATGY2WPQWUL7 \ / AMOS7 \ YOURUM ::
#\[7]IT6W6DA2534PCFESSDM5QRPPNYA3RVIVJ25ZTNMEPJ3LRUEUWGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
