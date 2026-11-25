#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;
## stage 3 : task \ coding zenki park task continuations in their own       ##
## events buckets. compiles the real park.*, task.* and events.* modules in ##
## one process ; the cube is a stub that hands events.* commands to the     ##
## events modules [ owner first, as the source_zenka alias does ] and       ##
## delivers replies only when the loop is pumped                            ##
## [ route-send only buffers ]. a restart drops memory and reads the files  ##
## again.                                                                   ##

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

## stubs : log, cube, timers, task persistence ##

my ( @logged, @timers, @pending, %replies, @cube_log );
our $zenka     = 'task';    ## the zenka whose code runs now ##
our $events_up = 1;         ## the events zenka reachable ##
my %disk;                   ## task queue.yaml \ history.yaml stand-in ##

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
$code{'base.time'}               = sub {time};
$code{'dependency.ok'}           = sub {TRUE};
$code{'file.put'}                = sub {TRUE};
$code{'base.ntime.b32'}          = sub {'NTIME'};
$code{'task.notice.push'}        = sub {TRUE};
$code{'base.callback.cmd_reply'} = sub {
    my ( $id, $r ) = @ARG;
    $replies{$id} = $r;
    return TRUE;
};
$code{'task.persist.save'} = sub {
    $disk{'queue'}   = Storable::dclone( $data{'task'}{'queue'}   // {} );
    $disk{'history'} = Storable::dclone( $data{'task'}{'history'} // {} );
    $disk{'order'}   = [ @{ $data{'task'}{'queue'}{'order'} // [] } ];
    return TRUE;
};
use Storable ();

## the coding zenka dir : a tmp directory ##
my $tmp = tempdir( 'task-park-XXXXXX', 'TMPDIR' => 1, 'CLEANUP' => 1 );
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

## the cube : route-send buffers, pump() delivers [ the event loop ] ##
$code{'protocol-7.route-send'} = sub {
    my $c = shift;
    push @cube_log, "$zenka> $c->{'command'} $c->{'call_args'}{'args'}";
    push @pending, { %{$c}, 'from' => $zenka };
    return TRUE;
};
$code{'protocol-7.command.send.local'} = sub {    ## events sends as itself ##
    my $c = shift;
    push @cube_log, "events> $c->{'command'} $c->{'call_args'}{'args'}";
    push @pending, { %{$c}, 'from' => 'events' };
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
    while ( my $c = shift @pending ) {
        my $cmd = $c->{'command'} =~ s{\Acube\.}{}r;
        my ( $target, $sub ) = $cmd =~ m{\A([\w-]+)\.(.+)\z};
        next if $target eq 'models';
        my $rv;
        if ( $target eq 'events' and not $events_up ) {
            ## the cube's answer [ IRW7V6A ] ##
            $rv = { 'mode' => 'false', 'data' => 'client not present' };
        } elsif ( $target eq 'events' ) {
            $rv = run_cmd( 'events', "events.cmd.$sub",
                "$c->{'from'} $c->{'call_args'}{'args'}" );
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
            $reply->{'cmd'}       = $mode;
            $reply->{'call_args'} = { 'args' => $rv->{'data'} };
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
    m{\A(?:park\.|events\.(?:plugin|source|fire|handler\.event_triggered|calc_unix|set_up_timers|action\.|access\.|signal\.|cmd\.signal\z|bucket\.|cmd\.bucket-)|plugin\.events\.(?:action|source)\.|base\.interval\.next\z|base\.interval\.rhythm\.|base\.reply\.mode_text\z)}
} @src;
load_module($ARG) for qw|
    task.cmd.park task.cmd.unpark task.park.store task.cmd.continue
    task.cmd.show task.cmd.queue
    coding.cmd.park coding.cmd.unpark coding.park.store
    base.n2u_time base.u2n_time base.round_truncate
    |;

my $access_file = "$tmp/access.zenki";
open my $afh, '>:encoding(UTF-8)', $access_file or die $OS_ERROR;
print {$afh} <<'ACC';
   access.cmd.usr.coding  =  events.bucket-add events.bucket-remove \
                             events.bucket-show task.continue
   access.cmd.usr.task    =  events.bucket-add events.bucket-remove \
                             events.bucket-show task.continue
   access.cmd.usr.usage   =  events.signal
ACC
close $afh;
my $grants_file = "$tmp/access.signals";
open my $gfh, '>:encoding(UTF-8)', $grants_file or die $OS_ERROR;
print {$gfh} "   events.signal.usage = usage.*\n";
close $gfh;

my $now = time;

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

sub new_task {    ## a task done and archived, as task.complete leaves it ##
    my ( $id, $status ) = @ARG;
    $data{'task'}{'history'}{$id} = {
        'id'          => $id,
        'status'      => $status // 'done',
        'description' => "work $id",
        'result'      => "result $id"
    };
}

sub reset_all {
    system 'rm', '-rf', "$tmp/var", "$tmp/zdir";
    %data      = ();
    @logged    = @timers = @pending = @cube_log = ();
    %replies   = ();
    %disk      = ();
    $events_up = 1;
    fresh_events();
    $data{'task'}{'queue'}   = {};
    $data{'task'}{'history'} = {};
    $data{'base'}{'interval'}{'cfg'}{'type'}{'park-wait'}
        = { 'start' => 34, 'factor' => 1.2, 'cap' => 89, 'cap_jitter' => 13 };
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

sub restart_all {    ## every zenka restarts : memory gone, files stay ##
    my $interval = $data{'base'};
    %data = ( 'base' => $interval );
    fresh_events();
    $data{'task'}{'queue'}   = Storable::dclone( $disk{'queue'}   // {} );
    $data{'task'}{'history'} = Storable::dclone( $disk{'history'} // {} );
    @pending                 = @cube_log = ();
    local $zenka = 'events';
    $code{'events.bucket.start'}->();
}

## 1. park : entry in the task bucket, recorded only on the reply ##
reset_all();
new_task('AAAAAAA');
my $rv = run_cmd( 'task', 'task.cmd.park',
    'AAAAAAA at=' . ( $now + 3600 ) . ' message="go on" reason="wait"', 7 );
ok( $rv->{'mode'} eq 'deferred',
    'park : deferred reply to a network caller' );
ok( !defined $data{'task'}{'history'}{'AAAAAAA'}{'park'},
    'park : nothing recorded before the events zenka answered'
);
pump();
my $e = entry( 'task', 'task-AAAAAAA-1' );
ok( defined $e
        && $e->{'state'} eq 'waiting'
        && $e->{'action'}{'type'} eq 'task-continue'
        && $e->{'action'}{'id'} eq 'AAAAAAA'
        && $e->{'action'}{'message'} eq 'go on'
        && $e->{'reason'} eq 'wait',
    'park : entry task-AAAAAAA-1 waits in the task bucket'
);
ok( $replies{7}{'mode'} eq 'true' && $replies{7}{'data'} =~ m{parked as},
    'park : the caller gets the deferred answer' );
ok( ( $data{'task'}{'history'}{'AAAAAAA'}{'park'}{'entry'} // '' ) eq
        'task-AAAAAAA-1' && $disk{'history'}{'AAAAAAA'}{'park'},
    'park : recorded in the task and saved'
);
$rv = run_cmd( 'task', 'task.cmd.park', 'AAAAAAA after=park-wait', 8 );
pump();
ok( $rv->{'mode'} eq 'deferred'
        && $replies{8}{'mode'} eq 'false'
        && $replies{8}{'data'} =~ m{\[ waiting \] : unpark it first}
        && !defined entry( 'task', 'task-AAAAAAA-2' ),
    'park : a parked task is refused a second park'
);

## 2. show \ queue : live state from bucket-show ##
$rv = run_cmd( 'task', 'task.cmd.show', 'AAAAAAA', 9 );
pump();
ok( $rv->{'mode'} eq 'deferred'
        && $replies{9}{'data'}
        =~ m{^parked      : task-AAAAAAA-1 waiting time }m
        && $replies{9}{'data'} =~ m{^id          : AAAAAAA}m,
    'show : the parked line comes from bucket-show'
);
$rv = run_cmd( 'task', 'task.cmd.queue', '', 10 );
pump();
ok( $replies{10}{'data'}
        =~ m{--- parked ---\nAAAAAAA parked   task-AAAAAAA-1 waiting },
    'queue : parked section with the live state'
);
$events_up = 0;
run_cmd( 'task', 'task.cmd.show', 'AAAAAAA', 11 );
pump();
ok( $replies{11}{'data'}
        =~ m{parked      : task-AAAAAAA-1 waiting time \d+  # wait \[ events zenka not reachable : task file \]},
    'show : the task file when the events zenka is down'
);
$events_up = 1;

## 3. unparked tasks : output unchanged and synchronous ##
new_task('BBBBBBB');
$rv = run_cmd( 'task', 'task.cmd.show', 'BBBBBBB', 12 );
ok( $rv->{'mode'} eq 'size' && $rv->{'data'} !~ m{parked} && !@pending,
    'show : an unparked task answers at once, no events call'
);
my %h = %{ $data{'task'}{'history'} };
delete $data{'task'}{'history'}{'AAAAAAA'};
$rv = run_cmd( 'task', 'task.cmd.queue', '', 13 );
ok( $rv->{'mode'} eq 'false'
        && $rv->{'data'} eq 'no tasks found'
        && !@pending,
    'queue : nothing parked, the listing as before'
);
%{ $data{'task'}{'history'} } = %h;

## 4. wake : the timer fires task.continue once, the park is cleared ##
entry( 'task', 'task-AAAAAAA-1' )->{'at'} = time - 1;
fire_timer( 'task', 'task-AAAAAAA-1' );
ok( ( grep {m{\Aevents> cube\.task\.continue AAAAAAA go on\z}} @cube_log )
        == 1,
    'wake : events sends task.continue with the message'
);
pump();
my $t = $data{'task'}{'queue'}{'AAAAAAA'};
ok( defined $t
        && $t->{'status'} eq 'pending'
        && $t->{'description'} eq 'go on'
        && !defined $t->{'park'}
        && !defined $data{'task'}{'history'}{'AAAAAAA'},
    'wake : the archived task is back in the queue, continued, unparked'
);
ok( entry( 'task', 'task-AAAAAAA-1' )->{'state'} eq 'fired'
        && !grep( {m{bucket-remove}} @cube_log ),
    'wake : the fired entry stays [ final ], not removed'
);
fire_timer( 'task', 'task-AAAAAAA-1' );
pump();
ok( ( grep {m{task\.continue AAAAAAA}} @cube_log ) == 1,
    'wake : exactly once' );

## 5. park again after the wake : a new entry id ##
$t->{'status'} = 'done';
run_cmd( 'task', 'task.cmd.park',
    'AAAAAAA on=usage.window.reset match.agent=kimi', 14 );
pump();
ok( defined entry( 'task', 'task-AAAAAAA-2' )
        && $replies{14}{'mode'} eq 'true',
    'park again : task-AAAAAAA-2 [ the fired id is final ]'
);
run_cmd( 'usage', 'events.cmd.signal',
    'usage usage.window.reset agent=claude' );
ok( entry( 'task', 'task-AAAAAAA-2' )->{'state'} eq 'waiting',
    'signal : a value that does not match leaves it waiting'
);
run_cmd( 'usage', 'events.cmd.signal',
    'usage usage.window.reset agent=kimi' );
pump();
ok( $data{'task'}{'queue'}{'AAAAAAA'}{'status'} eq 'pending'
        && !defined $data{'task'}{'queue'}{'AAAAAAA'}{'park'},
    'signal : the matching signal continues the task'
);

## 6. continue by hand clears the park : the entry never fires ##
reset_all();
new_task('CCCCCCC');
run_cmd( 'task', 'task.cmd.park', 'CCCCCCC at=' . ( $now + 3600 ), 15 );
pump();
$rv = run_cmd( 'task', 'task.cmd.continue', 'CCCCCCC by hand', 16 );
ok( $rv->{'mode'} eq 'true'
        && !defined $data{'task'}{'queue'}{'CCCCCCC'}{'park'},
    'continue : a parked task continues by hand, the record goes at once'
);
pump();
ok( !defined entry( 'task', 'task-CCCCCCC-1' ),
    'continue : the entry is removed from the bucket'
);

## 6a. continue a done task without park : from history, as task.continue ##
new_task('LLLLLLL');
$rv = run_cmd( 'task', 'task.cmd.continue', 'LLLLLLL more please', 42 );
ok( $rv->{'mode'} eq 'true'
        && $data{'task'}{'queue'}{'LLLLLLL'}{'status'} eq 'pending'
        && $data{'task'}{'queue'}{'LLLLLLL'}{'description'} eq 'more please'
        && !defined $data{'task'}{'history'}{'LLLLLLL'}
        && !grep( {m{bucket-}} @pending ),
    'continue : a done unparked task continues from history, no events call'
);
new_task( 'MMMMMMM', 'failed' );
$rv = run_cmd( 'task', 'task.cmd.continue', 'MMMMMMM retry', 43 );
ok( $rv->{'mode'} eq 'true'
        && $data{'task'}{'queue'}{'MMMMMMM'}{'status'} eq 'pending',
    'continue : a failed archived task too'
);
$data{'task'}{'queue'}{'NNNNNNN'}
    = { 'id' => 'NNNNNNN', 'status' => 'pending' };
$rv = run_cmd( 'task', 'task.cmd.continue', 'NNNNNNN x', 44 );
ok( $rv->{'mode'} eq 'false' && $rv->{'data'} =~ m{is pending},
    'continue : the queue path unchanged [ pending refused ]'
);
$rv = run_cmd( 'task', 'task.cmd.continue', 'ZZZZZZZ x', 45 );
ok( $rv->{'mode'} eq 'false' && $rv->{'data'} eq 'task ZZZZZZZ not found',
    'continue : unknown task not found' );

## 6b. a continue does not block the entries that depend on the fired one ##
new_task('JJJJJJJ');
new_task('KKKKKKK');
run_cmd( 'task', 'task.cmd.park', 'JJJJJJJ at=' . ( $now + 3600 ), 40 );
pump();
run_cmd( 'task', 'task.cmd.park',
    'KKKKKKK depends=task-JJJJJJJ-1 at=' . ( $now + 7200 ), 41 );
pump();
ok( $replies{41}{'mode'} eq 'true', 'depends : B parked after A' );
entry( 'task', 'task-JJJJJJJ-1' )->{'at'} = time - 1;
fire_timer( 'task', 'task-JJJJJJJ-1' );
pump();
ok( $data{'task'}{'queue'}{'JJJJJJJ'}{'status'} eq 'pending'
        && entry( 'task', 'task-KKKKKKK-1' )->{'state'} eq 'waiting',
    'depends : A woke, B still waits [ not blocked ]'
);
entry( 'task', 'task-KKKKKKK-1' )->{'at'} = time - 1;
fire_timer( 'task', 'task-KKKKKKK-1' );
pump();
ok( $data{'task'}{'queue'}{'KKKKKKK'}{'status'} eq 'pending',
    'depends : B wakes on its own time' );

## 7. unpark ##
new_task('DDDDDDD');
run_cmd( 'task', 'task.cmd.park', 'DDDDDDD after=park-wait', 17 );
pump();
ok( defined entry( 'task', 'task-DDDDDDD-1' ), 'unpark : parked first' );
$rv = run_cmd( 'task', 'task.cmd.unpark', 'DDDDDDD', 18 );
pump();
ok( $rv->{'mode'} eq 'deferred'
        && $replies{18}{'mode'} eq 'true'
        && !defined entry( 'task', 'task-DDDDDDD-1' )
        && !defined $data{'task'}{'history'}{'DDDDDDD'}{'park'},
    'unpark : entry removed, record dropped'
);
$rv = run_cmd( 'task', 'task.cmd.unpark', 'DDDDDDD', 19 );
ok( $rv->{'mode'} eq 'false' && $rv->{'data'} =~ m{not parked},
    'unpark : a task that is not parked is refused'
);

## 8. refusals ##
new_task( 'EEEEEEE', 'pending' );
$data{'task'}{'queue'}{'EEEEEEE'}
    = delete $data{'task'}{'history'}{'EEEEEEE'};
$rv = run_cmd( 'task', 'task.cmd.park', 'EEEEEEE after=park-wait', 20 );
ok( $rv->{'mode'} eq 'false' && $rv->{'data'} =~ m{expected done or failed},
    'refused : a task task.continue would refuse' );
new_task('FFFFFFF');
$rv = run_cmd( 'task', 'task.cmd.park', 'FFFFFFF message=x', 21 );
ok( $rv->{'mode'} eq 'false' && $rv->{'data'} =~ m{waits for},
    'refused : a park that waits for nothing' );
$rv = run_cmd( 'task', 'task.cmd.park', 'FFFFFFF at=1 on=x', 22 );
ok( $rv->{'mode'} eq 'false', 'refused : two whens' );
$rv = run_cmd( 'task', 'task.cmd.park', 'FFFFFFF at=never', 23 );
pump();
ok( $rv->{'mode'} eq 'deferred'
        && $replies{23}{'mode'} eq 'false'
        && $replies{23}{'data'} =~ m{not understood}
        && !defined $data{'task'}{'history'}{'FFFFFFF'}{'park'},
    'refused by events : the reason passed on, nothing recorded'
);

## 9. events down : refused, nothing recorded, no local queue ##
$events_up = 0;
run_cmd( 'task', 'task.cmd.park', 'FFFFFFF after=park-wait', 24 );
pump();
ok( $replies{24}{'mode'} eq 'false'
        && $replies{24}{'data'}
        =~ m{refused, nothing recorded : events zenka not reachable \[ client not present \]}
        && !defined $data{'task'}{'history'}{'FFFFFFF'}{'park'}
        && !defined entry( 'task', 'task-FFFFFFF-1' ),
    'events down : park refused with a clear message'
);
{
    local $code{'protocol-7.route-send'} = sub {FALSE};
    $rv = run_cmd( 'task', 'task.cmd.park', 'FFFFFFF after=park-wait', 25 );
}
ok( $rv->{'mode'} eq 'false'
        && $rv->{'data'} =~ m{not reachable : park refused},
    'no route : park refused at once'
);
$events_up = 1;
run_cmd( 'task', 'task.cmd.park', 'FFFFFFF after=park-wait', 26 );
pump();
$events_up = 0;
$rv        = run_cmd( 'task', 'task.cmd.unpark', 'FFFFFFF', 27 );
pump();
ok( $replies{27}{'mode'} eq 'false'
        && defined $data{'task'}{'history'}{'FFFFFFF'}{'park'},
    'events down : unpark refused, still parked'
);
$events_up = 1;

## 10. restart round trip : every zenka restarts, the wake still comes once ##
reset_all();
new_task('GGGGGGG');
run_cmd( 'task', 'task.cmd.park',
    'GGGGGGG at=' . ( $now + 3600 ) . ' message=later', 28 );
pump();
restart_all();
ok( ( $data{'task'}{'history'}{'GGGGGGG'}{'park'}{'entry'} // '' ) eq
        'task-GGGGGGG-1'
        && entry( 'task', 'task-GGGGGGG-1' )->{'state'} eq 'waiting',
    'restart : park record and bucket entry both survive'
);
entry( 'task', 'task-GGGGGGG-1' )->{'at'} = time - 1;
fire_timer( 'task', 'task-GGGGGGG-1' );
pump();
ok( $data{'task'}{'queue'}{'GGGGGGG'}{'status'} eq 'pending'
        && !defined $data{'task'}{'queue'}{'GGGGGGG'}{'park'},
    'restart : the wake continues the task'
);
restart_all();
pump();
ok( ( grep {m{task\.continue GGGGGGG}} @cube_log ) == 0,
    'restart after the wake : nothing fires again'
);

## 11. coding : its own bucket and file, the same continue path ##
reset_all();
new_task('HHHHHHH');
$rv = run_cmd( 'coding', 'coding.cmd.park', 'hhhhhhh at=' . ( $now + 3600 ),
    30 );
pump();
ok( defined entry( 'coding', 'coding-HHHHHHH-1' )
        && !defined entry( 'task', 'coding-HHHHHHH-1' )
        && $replies{30}{'mode'} eq 'true',
    'coding park : the entry is in the coding bucket'
);
my $file = read_file("$tmp/zdir/coding.parked");
ok( $file        =~ m{^park\.HHHHHHH\.entry = coding-HHHHHHH-1$}m
        && $file =~ m{^count\.HHHHHHH = 1$}m
        && $file !~ m|[{}]|,
    'coding park : recorded in p7 config style'
);
run_cmd( 'coding', 'coding.cmd.park', '', 31 );
pump();
ok( $replies{31}{'data'} =~ m{HHHHHHH parked   coding-HHHHHHH-1 waiting time},
    'coding park : listing without arguments, live'
);
delete $data{'coding'};    ## coding restarts : read the file again ##
ok(
    (   do {
            local $zenka = 'coding';
            $code{'coding.park.store'}->( 'get', 'HHHHHHH' );
            }
            // {}
    )->{'entry'} eq 'coding-HHHHHHH-1',
    'coding park : the record survives a coding restart'
);
entry( 'coding', 'coding-HHHHHHH-1' )->{'at'} = time - 1;
fire_timer( 'coding', 'coding-HHHHHHH-1' );
pump();
ok( ( grep {m{\Aevents> cube\.task\.continue HHHHHHH }} @cube_log ) == 1
        && entry( 'coding', 'coding-HHHHHHH-1' )->{'state'} eq 'fired'
        && $data{'task'}{'queue'}{'HHHHHHH'}{'status'} eq 'pending'
        && !defined $data{'task'}{'history'}{'HHHHHHH'},
    'coding park : the wake continues the archived task'
);
## re-park without unpark : the fired entry makes the record stale ##
$data{'task'}{'queue'}{'HHHHHHH'}{'status'} = 'done';
$rv = run_cmd( 'coding', 'coding.cmd.park', 'HHHHHHH after=park-wait', 34 );
pump();
ok(        $rv->{'mode'} eq 'deferred'
        && $replies{34}{'mode'} eq 'true'
        && defined entry( 'coding', 'coding-HHHHHHH-2' )
        && (
        do {
            local $zenka = 'coding';
            $code{'coding.park.store'}->( 'get', 'HHHHHHH' );
        }
        // {}
        )->{'entry'} eq 'coding-HHHHHHH-2',
    'coding re-park : no unpark needed after the wake'
);
run_cmd( 'coding', 'coding.cmd.unpark', 'HHHHHHH', 32 );
pump();
ok( $replies{32}{'mode'} eq 'true'
        && !defined do {
        local $zenka = 'coding';
        $code{'coding.park.store'}->( 'get', 'HHHHHHH' );
        },
    'coding unpark : record dropped [ the fired entry too ]'
);
$events_up = 0;
new_task('IIIIIII');
run_cmd( 'coding', 'coding.cmd.park', 'IIIIIII after=park-wait', 33 );
pump();
ok( $replies{33}{'mode'} eq 'false'
        && !defined do {
        local $zenka = 'coding';
        $code{'coding.park.store'}->( 'get', 'IIIIIII' );
        },
    'coding park : events down refused, nothing recorded'
);

say "\n# $pass passed, $fail failed";
exit( $fail ? 1 : 0 );

#,,..,,..,,..,,,,,,,.,,.,,.,,,.,,,.,,,.,.,,,,,..,,...,...,,.,,...,.,,,,,.,,,.,
#KU5ZDUM56TQSBEHTEGL6YAQX4DQ3GLRTOLMTUL4LTUXL6FPATPW44MAWGNGBMZEIRZTZNS7LAPOLA
#\\\|QFTH2LUF4JCCLBLO2VOTSK7FWALVGZ2WCRZGEB6BFE6YA6IXOBA \ / AMOS7 \ YOURUM ::
#\[7]ME2SY72KFR6GTI4P4WZRLZA2GDNNW46MQW5EGRJBB2NEDE26P2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
