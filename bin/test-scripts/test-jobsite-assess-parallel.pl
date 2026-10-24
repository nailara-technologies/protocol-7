#!/usr/bin/env perl
use v5.24;
use strict;
use English;
use warnings;

## the production runtime [ bin/Protocol-7 : use utf8 + Encode ] loads the ##
## bytes pragma transitively ; keep it so compiled modules resolve it.     ##
use bytes;

## jobsite.cfg.assess_parallel [ todo XNB ] : keep up to N assessments in   ##
## flight [ default 1 = the old strictly serial chain ] :                   ##
## - dispatch.next fills up to N, release_slot \ give_up refill             ##
## - a done reply, a timeout give-up, a trashed or stale job all release    ##
## their slot [ consume_slot ] and the queue keeps draining                 ##
## - the cycle still ends exactly once                                      ##
## [ 'all assessments complete, cycle=idle' ] -- a stray extra release is a ##
## no-op                                                                    ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

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

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %code;
our %data;

$OUTPUT_AUTOFLUSH = 1;

my $fail_count = 0;
my $pass_count = 0;

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { $pass_count++; say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

my $runtime_pragmas = q{no bytes; use English; use File::stat; use File::Spec;
    use File::Spec::Functions qw| catfile |;
    use open qw| :encoding(UTF-8) |;};
my $module_prefix = q{use constant TRUE => 5; use constant FALSE => 0;
    use Encode; sub encode_b32r { return $_[0] }};

sub compile_module {
    my ( $module_name, $prefix ) = @ARG;
    $prefix //= $module_prefix;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref
        = eval "$runtime_pragmas sub {\n$prefix\n# "
        . "line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

## ---------------------------------------------------------------------- ##
## stubs                                                                  ##

my @logged;
my @created;         ## task.create sends ##
my @written_jobs;    ## [ job_id, job ] pairs ##
my @sync_pushes;
my %job_status;      ## job_id => status ##

$code{'base.logs'} = sub { push @logged, [@ARG]; return };
$code{'base.log'}  = sub { push @logged, [@ARG]; return };
$code{'base.s_warn'}
    = sub { push @logged, [ 'warn', sprintf( shift, @ARG ) ]; return };

$code{'jobsite.job.read'} = sub {
    my $job_id = shift // '';
    return { 'id' => $job_id, 'status' => $job_status{$job_id} };
};

$code{'jobsite.job.write'} = sub {
    my ( $job_id, $job ) = @ARG;
    push @written_jobs, [ $job_id, $job ];
    return TRUE;
};

$code{'jobsite.state.persist'} = sub { return TRUE };

$code{'jobsite.sync.push'} = sub {
    push @sync_pushes, [@ARG];
    return TRUE;
};

$code{'protocol-7.route-send'} = sub {
    my $send = shift // {};
    push @created, $send if $send->{'command'} eq 'task.create';
    return 1;
};

$code{'event.add_timer'} = sub {
    my $timer = shift // {};
    return bless { %{$timer}, 'active' => 1 }, 'TestTimer';
};

sub TestTimer::cancel    { $_[0]->{'active'} = 0; return }
sub TestTimer::is_active { return $_[0]->{'active'} }
sub TestTimer::w         { return $_[0] }

my @perl_warnings;
local $SIG{__WARN__} = sub { push @perl_warnings, @ARG };

## real modules under test ##
compile_module($_) for qw| jobsite.dispatch.next jobsite.dispatch.consume_slot
    jobsite.dispatch.release_slot jobsite.dispatch.arm_watchdog
    jobsite.dispatch.give_up |;

## ---------------------------------------------------------------------- ##
## helpers                                                                ##

sub reset_dispatch_state {
    $data{'jobsite'} = {
        'cfg' => {
            'assess_parallel' => 3,
            'assess_timeout'  => 777,
        },
        'cycle'         => 'assessing',
        'pending_count' => 0,
        'tasks'         => {},
        'assess_timer'  => {},
        'assess_queue'  => [],
        'sync'          => {},
    };
    @created      = ();
    @written_jobs = ();
    @sync_pushes  = ();
    %job_status   = ();
    return;
}

sub queue_entry {
    my $job_id = shift;
    return { 'job_id' => $job_id, 'desc' => "assess $job_id", 'gen' => 0 };
}

sub arm_three_jobs {
    my @ids = @ARG;
    $job_status{$ARG} = 'new' for @ids;
    for my $job_id (@ids) {
        $data{'jobsite'}{'tasks'}{$job_id}
            = { 'stage' => 'queued', 'task_id' => '', 'queue_gen' => 1 };
    }
    push $data{'jobsite'}{'assess_queue'}->@*, map { queue_entry($ARG) } @ids;
    $data{'jobsite'}{'pending_count'} += scalar @ids;
    return;
}

sub in_flight_count {
    return scalar keys %{ $data{'jobsite'}{'assess_timer'} };
}

sub idle_log_count {
    return scalar grep {
        $ARG->[0] == 1
            and ( $ARG->[1] // '' ) eq 'all assessments complete, cycle=idle'
    } @logged;
}

## ---------------------------------------------------------------------- 1 ##
## : parallel 3 fills three slots at once                                   ##

say "\n :. dispatch.next fills up to N";

reset_dispatch_state();
arm_three_jobs(qw| JOB000A JOB000B JOB000C |);
arm_three_jobs(qw| JOB000D JOB000E JOB000F |);

$code{'jobsite.dispatch.next'}->();

ok( scalar @created == 3,   'three jobs dispatched at once [ parallel 3 ]' );
ok( in_flight_count() == 3, 'three watchdog slots armed' );
ok( scalar $data{'jobsite'}{'assess_queue'}->@* == 3,
    'queue keeps its tail' );
ok( $data{'jobsite'}{'pending_count'} == 6, 'pending_count untouched' );

## ---------------------------------------------------------------------- 2 ##
## : a done reply releases its slot, one refill                             ##

say "\n :. release_slot refills one";

@logged = ();
my $released = $code{'jobsite.dispatch.release_slot'}->('JOB000A');

ok( $released == TRUE,    'release_slot TRUE for the slot-holding job' );
ok( scalar @created == 4, 'one refill dispatched' );
ok( ( $created[-1]{'reply'}{'params'}{'job_id'} // '' ) eq 'JOB000D',
    'refill took the next queue entry' );
ok( in_flight_count() == 3,                 'back to three in flight' );
ok( $data{'jobsite'}{'pending_count'} == 5, 'pending_count decremented' );

## ---------------------------------------------------------------------- 3 ##
## : a timeout give-up releases its slot and refills                        ##

say "\n :. give_up on timeout releases + refills";

$code{'jobsite.dispatch.give_up'}->('JOB000B');

ok( ( grep { $ARG->[0] eq 'JOB000B' } @written_jobs ),
    'give_up marked the job on disk' );
ok( $data{'jobsite'}{'tasks'}{'JOB000B'}{'stage'} eq 'timeout',
    'gave-up job stage cleared for a later rescan'
);
ok( scalar @created == 5, 'timeout released the slot, one refill' );
ok( ( $created[-1]{'reply'}{'params'}{'job_id'} // '' ) eq 'JOB000E',
    'refill took the next queue entry' );
ok( $data{'jobsite'}{'pending_count'} == 4, 'pending_count decremented' );
ok( in_flight_count() == 3,                 'three in flight again' );

## ---------------------------------------------------------------------- 4 ##
## : a trashed job's entry releases its slot at dispatch time               ##

say "\n :. trashed job entry releases its slot";

$job_status{'JOB000F'} = 'trash';    ## user trashed it while queued ##
@logged = ();
$code{'jobsite.dispatch.release_slot'}->('JOB000C');

## C released [ 4 -> 3 ], F skipped at dispatch [ 3 -> 2 ], no refill ##
ok( $data{'jobsite'}{'pending_count'} == 2,
    'done release + trashed skip both consumed their slot' );
ok( scalar @created == 5, 'trashed entry never dispatched' );
ok( scalar $data{'jobsite'}{'assess_queue'}->@* == 0, 'queue drained' );
ok( in_flight_count() == 2,                           'two still in flight' );
ok(
    (   grep {
                    ( $ARG->[1] // '' ) =~ m{skipping stale queue entry}
                and ( $ARG->[3] // '' ) eq 'trash'
        } @logged
    ),
    'trash skip logged'
);

## ---------------------------------------------------------------------- 5 ##
## : stale generation entry releases its slot too                           ##

say "\n :. stale generation entry releases its slot";

$data{'jobsite'}{'pending_count'}    = 1;
$data{'jobsite'}{'tasks'}{'JOB000G'} = { 'queue_gen' => 2 };
$data{'jobsite'}{'assess_queue'}     = [];
$job_status{'JOB000G'}               = 'new';
push $data{'jobsite'}{'assess_queue'}->@*,
    { 'job_id' => 'JOB000G', 'desc' => 'stale', 'gen' => 1 };

$code{'jobsite.dispatch.next'}->();

ok( $data{'jobsite'}{'pending_count'} == 0, 'stale entry consumed its slot' );
ok( scalar @created == 5,                   'stale entry never dispatched' );

## ---------------------------------------------------------------------- 6 ##
## : the cycle ends exactly once                                            ##

say "\n :. cycle ends exactly once";

$code{'jobsite.dispatch.release_slot'}->('JOB000D');
ok( $data{'jobsite'}{'pending_count'} == 0,
    'second-to-last release lands pending at 0'
);
ok( $data{'jobsite'}{'cycle'} eq 'idle', 'cycle idle' );
ok( idle_log_count() == 1, "'all assessments complete' logged exactly once" );
ok( scalar @sync_pushes == 1, 'results pushed once' );

## a stray extra release is a no-op ##
$code{'jobsite.dispatch.consume_slot'}->();
$code{'jobsite.dispatch.release_slot'}->('JOB000D');
ok( $data{'jobsite'}{'pending_count'} == 0,
    'stray release keeps pending at 0'
);
ok( idle_log_count() == 1,               'still exactly one cycle-end log' );
ok( $data{'jobsite'}{'cycle'} eq 'idle', 'cycle stays idle' );

## ---------------------------------------------------------------------- 7 ##
## : default 1 keeps the old strictly serial chain                          ##

say "\n :. assess_parallel 1 = serial";

reset_dispatch_state();
$data{'jobsite'}{'cfg'}{'assess_parallel'} = 1;
arm_three_jobs(qw| JOB000H JOB000I JOB000J |);

$code{'jobsite.dispatch.next'}->();

ok( scalar @created == 1,   'serial : one dispatch per call' );
ok( in_flight_count() == 1, 'serial : one slot armed' );
$code{'jobsite.dispatch.release_slot'}->('JOB000H');
ok( scalar @created == 2,
    'serial : release dispatches exactly the following one' );

## ---------------------------------------------------------------------- ##
## summary                                                                ##

my @struct_warnings = grep {
    m{uninitialized|Use of|ref\(\) on|Not an? \w+ ref|Redundant|Missing}i
} @perl_warnings;
ok( scalar @struct_warnings == 0,
    'no perl warnings from the compiled modules' );

say '';
say "passed : $pass_count  failed : $fail_count";
exit( $fail_count ? 1 : 0 );

#,,,.,,.,,...,.,,,..,,.,.,.,,,,.,,,..,.,.,,..,.,.,...,...,..,,,..,..,,,,.,.,,,
#2QPVHGMUJ6ENBRTVKJSIFF6C467FPIKWARGCOQSW2IXHSDFIO3JRVBPSV63C57XV4XXJ6Q3DAOIFY
#\\\|RPWK3BCKDCUCQRTB25KNRB2I7AEWFCNNDPJZU6UT56MNJPWR4F7 \ / AMOS7 \ YOURUM ::
#\[7]SSYOJL7A2ZX7RAMKI6RLFG2GJMFHDSY4335KHXORYS3IC3BC4KDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
