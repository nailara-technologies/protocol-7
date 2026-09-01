#!/usr/bin/perl

use v5.24;
use strict;
use English;
use warnings;

##[ LOCAL PM LIB PATH ]#######################################################

BEGIN {
    use English;
    use File::Spec;
    use Cwd     qw| abs_path |;
    use FindBin qw| $RealBin |;
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path
        = abs_path( r2_abs( c_dir( $RealBin, $up_dir, $up_dir, $up_dir ) ) );
    my $local_lib_path = abs_path( c_dir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
    sub c_dir  { File::Spec->catdir(@ARG) }
    sub r2_abs { File::Spec->rel2abs(@ARG) }
}

##[ AMOS MODULES ]############################################################

## Page must be loaded before Feedback to break the existing circular
## dependency between AMOS7::SHM::Page and AMOS7::SHM::Feedback.
use AMOS7::SHM::Page     ();
use AMOS7::SHM::Live     qw| live_create live_write live_read |;
use AMOS7::SHM::Feedback qw| watch_fifo notify_path |;
use AMOS7::SHM           qw| shm_open |;

use POSIX qw| _exit |;

##[ TEST SETUP ]##############################################################

my $capacity = 4 * 1024;
my $pub_key  = 'LIVETEST' . sprintf( '%024X', $$ + time() );
my $priv_key = $pub_key;

my @results;

sub ok {
    my ( $name, $condition, $detail ) = @ARG;
    my $status = $condition ? 'PASS' : 'FAIL';
    push @results, [ $name, $condition ];
    print "[$status] $name";
    print " -- $detail" if defined $detail;
    print "\n";
    return $condition;
}

##[ TEST 1: create + initial read ]###########################################

my $initial_content = 'initial live-mount value';
my $mount           = live_create( $pub_key, $initial_content, $capacity,
    { 'mlock' => 0, 'notify' => 1 } );

if (!ok('live_create succeeded',
        defined $mount && !exists $mount->{'error'}
    )
) {
    exit 1;
}

my $path = $mount->{'path'};

ok( 'segment file exists after live_create', -f $path, "path=$path" );

ok( '.notify FIFO exists after live_create with notify => 1',
    -p notify_path($mount),
    "notify_path=" . notify_path($mount)
);

ok( 'live_read returns initial content exactly',
    live_read($mount) eq $initial_content,
    "got: '" . ( live_read($mount) // '<undef>' ) . "'"
);

##[ TEST 2: live_write replaces content, fresh open sees new value ]##########

my $shorter_content = 'replacement';
my $write_result    = live_write( $mount, $shorter_content );

ok( 'live_write within capacity succeeds',
    defined $write_result && !exists $write_result->{'error'},
    defined $write_result && exists $write_result->{'error'}
    ? "error=$write_result->{'error'}"
    : undef
);

my $reader_mount = shm_open( $path, { 'mode' => 'read' }, $priv_key );

my $reader_ok = ok(
    'fresh shm_open mode => read succeeds',
    defined $reader_mount && !exists $reader_mount->{'error'},
    defined $reader_mount && exists $reader_mount->{'error'}
    ? "error=$reader_mount->{'error'}"
    : undef
);

if ($reader_ok) {
    my $reader_data = live_read($reader_mount);
    ok( 'fresh live_read sees the new content',
        $reader_data eq $shorter_content,
        "got: '$reader_data'"
    );

    my $header       = AMOS7::SHM::header_read( $reader_mount->{'mmap_ptr'} );
    my $data_size_ok = defined $header
        && $header->{'data_size'} == length($shorter_content);
    ok( 'data_size shrunk to the new (shorter) content length',
        $data_size_ok,
        defined $header ? "data_size=$header->{'data_size'}" : 'no header'
    );

    my $raw_longer = substr(
        ${ $reader_mount->{'mmap_ptr'} },
        AMOS7::SHM::SHM_HEADER_SIZE(),
        length($initial_content)
    );
    ok( 'old (longer) content is not returned as current value',
        $raw_longer ne $initial_content,
        "raw_longer='$raw_longer'"
    );
}

##[ TEST 3: over-capacity write is rejected and does not corrupt ]############

my $before_reject = live_read($mount);
my $too_long      = 'X' x ( $capacity + 1 );
my $reject_result = live_write( $mount, $too_long );

ok( 'live_write beyond capacity returns an error',
    defined $reject_result && exists $reject_result->{'error'},
    defined $reject_result ? "result=$reject_result->{'error'}" : 'undef'
);

ok( 'segment content unchanged after rejected write',
    live_read($mount) eq $before_reject,
    "still: '" . live_read($mount) . "'"
);

##[ TEST 4: notify ding, proven cross-process ]###############################

pipe( my $cr, my $cw ) or die "pipe failed: $!";
$cr->autoflush(1);
$cw->autoflush(1);

my $child_pid = fork();
die "fork failed: $!" unless defined $child_pid;

if ( $child_pid == 0 ) {
    ## child: watch the notify FIFO, report back to parent ##
    close($cr);
    my $result = watch_fifo( $mount, { 'timeout' => 10 } );
    if ( defined $result && $result->{'fired'} && $result->{'bytes'} == 1 ) {
        print $cw "DINGED\n";
    } else {
        my $detail
            = defined $result
            ? "fired=$result->{'fired'} bytes=$result->{'bytes'} "
            . "timeout=$result->{'timeout'}"
            : 'undef';
        print $cw "MISSED $detail\n";
    }
    close($cw);
    _exit(0);    ## skip END cleanup so parent keeps the segment ##
}

close($cw);

## parent: give child time to open the reader, then ding ##
select( undef, undef, undef, 0.5 );

my $ding_content = 'cross-process ding value';
live_write( $mount, $ding_content );

my $child_report = <$cr>;
chomp($child_report) if defined $child_report;
close($cr);
waitpid( $child_pid, 0 );

ok( 'cross-process notify ding fired and delivered 1 byte',
    defined $child_report && $child_report eq 'DINGED',
    defined $child_report ? "report='$child_report'" : 'no report'
);

## no-notify mount has no FIFO at all ##
my $no_notify_mount
    = live_create( $pub_key . 'NN', '', $capacity, { 'mlock' => 0 } );

if (ok( 'no-notify live_create succeeded',
        defined $no_notify_mount && !exists $no_notify_mount->{'error'}
    )
) {
    ok( 'no-notify mount has no .notify FIFO',
        !-p notify_path($no_notify_mount),
        "path=" . notify_path($no_notify_mount)
    );
}

##[ TEST 5: read-only open can live_read ]####################################

my $ro_mount = shm_open( $path, { 'mode' => 'read' }, $priv_key );

my $ro_ok = ok(
    'shm_open mode => read for live_read succeeds',
    defined $ro_mount && !exists $ro_mount->{'error'},
    defined $ro_mount && exists $ro_mount->{'error'}
    ? "error=$ro_mount->{'error'}"
    : undef
);

if ($ro_ok) {
    my $ro_data = live_read($ro_mount);
    ok( 'read-only-open live_read returns current content',
        $ro_data eq $ding_content,
        "got: '$ro_data'"
    );
}

##[ SUMMARY ]#################################################################

my $failed = grep { !$_->[1] } @results;
my $total  = scalar @results;

print "\n";
if ( $failed == 0 ) {
    print "=== All $total tests passed ===\n";
    exit 0;
} else {
    print "=== $failed of $total tests failed ===\n";
    exit 1;
}

#,,,.,...,,,.,.,.,.,,,,,,,...,..,,,,.,,,,,.,,,..,,...,...,..,,,,.,.,.,.,,,,,.,
#ZS4SPVYHORHZJQRSXME6NC2DTXWL4PVBSZI3D2KGXOZ7VLLOCQHHMRAZBQ5S4R5F6DAWIGBTVRI7M
#\\\|K2CBBFGVLKVWWBJHOMTL4563WLDQDGW6F7V764QOD47WS5JDO5F \ / AMOS7 \ YOURUM ::
#\[7]NHOWDWLD5C4KMDYLXG3VNCSKQ7EZKRBED5GYTGPML3Y4WM5KSMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
