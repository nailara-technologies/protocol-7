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
    my $up_dir         = File::Spec->updir;
    my $data_pm_path   = qw| data/lib-path/pm |;
    my $root_path      = abs_path( r2_abs( c_dir( $RealBin, $up_dir, $up_dir, $up_dir ) ) );
    my $local_lib_path = abs_path( c_dir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
    sub c_dir  { File::Spec->catdir(@ARG) }
    sub r2_abs { File::Spec->rel2abs(@ARG) }
}

##[ AMOS MODULE ]#############################################################

use AMOS7::SHM qw| shm_create |;

##[ TEST SETUP ]##############################################################

my $pub_key     = 'TESTCLEANUP0123456789ABCDEF0123';
my $segment_size = 4 * 1024;
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

##[ TEST 1: Normal exit triggers END cleanup ]################################

{
    my $path = sprintf( "/dev/shm/p7:M:%s", $pub_key );
    unlink($path)             if -f $path;
    unlink("$path.notify")    if -p "$path.notify";

    my $pid = fork();
    die "fork failed: $!" unless defined $pid;

    if ( $pid == 0 ) {
        ## child : create segment, optionally a notify FIFO, then exit normally ##
        my $mount = shm_create( $pub_key, $segment_size, { 'mlock' => 0 } );
        exit 1 unless defined $mount;

        my $path = $mount->{'path'};
        print "CHILD_NORMAL path=$path\n";

        # also create a phase-3 notify FIFO to verify it is cleaned too
        my $notify_path = $path . '.notify';
        system( 'mkfifo', $notify_path ) == 0 or warn "mkfifo failed: $?";

        exit 0;
    }

    ## parent : wait for child, then inspect /dev/shm ##
    waitpid( $pid, 0 );

    my $shm_exists  = -f $path;
    my $fifo_exists = -p "$path.notify";

    ok(
        'normal exit removes SHM segment',
        !$shm_exists,
        $shm_exists ? "segment still exists: $path" : undef
    );
    ok(
        'normal exit removes notify FIFO',
        !$fifo_exists,
        $fifo_exists ? "FIFO still exists: $path.notify" : undef
    );
}

##[ TEST 2: SIGTERM triggers END cleanup ]####################################

{
    my $term_path = sprintf( "/dev/shm/p7:M:%s", $pub_key . 'TERM' );
    unlink($term_path)             if -f $term_path;
    unlink("$term_path.notify")    if -p "$term_path.notify";

    my $pid = fork();
    die "fork failed: $!" unless defined $pid;

    if ( $pid == 0 ) {
        ## child : create segment, confirm it exists, then sleep until TERM ##
        my $mount
            = shm_create( $pub_key . 'TERM', $segment_size, { 'mlock' => 0 } );
        exit 1 unless defined $mount;

        my $path = $mount->{'path'};
        print "CHILD_TERM path=$path\n";

        # create notify FIFO for this case too
        my $notify_path = $path . '.notify';
        system( 'mkfifo', $notify_path ) == 0 or warn "mkfifo failed: $?";

        # signal readiness then sleep until TERM arrives
        sleep(30);
        exit 0;
    }

    ## parent : give child time to create, then send TERM ##
    sleep(1);

    # verify child created the files before signalling
    my $pre_shm  = -f $term_path;
    my $pre_fifo = -p "$term_path.notify";

    ok(
        'TERM test segment exists before signal',
        $pre_shm,
        $pre_shm ? undef : "missing: $term_path"
    );
    ok(
        'TERM test FIFO exists before signal',
        $pre_fifo,
        $pre_fifo ? undef : "missing: $term_path.notify"
    );

    kill( 'TERM', $pid );
    waitpid( $pid, 0 );

    my $post_shm  = -f $term_path;
    my $post_fifo = -p "$term_path.notify";

    ok(
        'SIGTERM removes SHM segment',
        !$post_shm,
        $post_shm ? "segment still exists: $term_path" : undef
    );
    ok(
        'SIGTERM removes notify FIFO',
        !$post_fifo,
        $post_fifo ? "FIFO still exists: $term_path.notify" : undef
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

#,,,.,.,.,,,.,,..,,..,,,.,,.,,.,,,,.,,...,,,,,..,,...,...,.,.,,..,...,,,.,,..,
#D7NEORLDZ7DCYART2FD4VTA2OUIMNAPVQ4TMEN3CEBNABM73TRVMLAZZ4TTG4T32IXDRGMVNJO6VU
#\\\|5BQJWC4MEDNNNGBZWSVGOFCMLGAO5LKKIJRP5SJSYHNNZG2QLAN \ / AMOS7 \ YOURUM ::
#\[7]WL5OIFYUYPQPQ2IAHFZVKABEUV6S7PXPDQFR36XQWR5QGY3VAQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
