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

##[ AMOS MODULE ]#############################################################

use AMOS7::SHM qw| shm_create shm_open |;

##[ TEST SETUP ]##############################################################

my $priv_key     = 'TESTPRIVKEY0123456789ABCDEF0123456789ABCDEF';
my $pub_key      = substr( $priv_key, 0, 32 );
my $test_data    = 'Protocol-7 read-only open mode test payload';
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

##[ CLEANUP HELPER ]##########################################################

my $created_path;

sub cleanup {
    return unless defined $created_path && -f $created_path;
    unlink($created_path);
}

##[ TEST 1: Create segment and write data ]###################################

my $create_opts  = { 'mlock' => 0 };
my $mount_create = shm_create( $pub_key, $segment_size, $create_opts );

if ( !ok( 'shm_create succeeded', defined $mount_create ) ) {
    cleanup();
    exit 1;
}

$created_path = $mount_create->{'path'};

# Write test data into the data region, past the 512-byte header
substr( ${ $mount_create->{'mmap_ptr'} }, 512, length($test_data) )
    = $test_data;

my $written_back
    = substr( ${ $mount_create->{'mmap_ptr'} }, 512, length($test_data) );
ok( 'create-time write/read ' . 'roundtrip',
    $written_back eq $test_data,
    "got: '$written_back'"
);

##[ TEST 2: Open read-only and read data back ]###############################

my $ro_mount = shm_open( $created_path, { 'mode' => 'read' }, $priv_key );

my $ro_ok = ok(
    'shm_open mode => read succeeds without error',
    defined $ro_mount && !exists $ro_mount->{'error'},
    defined $ro_mount && exists $ro_mount->{'error'}
    ? "error=$ro_mount->{'error'}"
    : undef
);

if ($ro_ok) {
    my $ro_data
        = substr( ${ $ro_mount->{'mmap_ptr'} }, 512, length($test_data) );
    ok( 'read-only open sees exact ' . 'written content',
        $ro_data eq $test_data,
        "got: '$ro_data'"
    );
}

##[ TEST 3: Writing through read-only-opened mmap does not silently succeed ]#

if ($ro_ok) {
    my $original
        = substr( ${ $ro_mount->{'mmap_ptr'} }, 512, length($test_data) );
    my $overwrite = 'ROGUE_WRITE_ATTEMPT_SHOULD_NOT_PERSIST';

    my $died = 0;
    eval {
        substr( ${ $ro_mount->{'mmap_ptr'} }, 512, length($overwrite) )
            = $overwrite;
        1;
    } or do {
        $died = 1;
    };

    my $after
        = substr( ${ $ro_mount->{'mmap_ptr'} }, 512, length($test_data) );
    my $did_not_silently_succeed = $died || ( $after eq $original );

    ok( 'read-only mmap write is refused or dies',
        $did_not_silently_succeed, "died=$died, after='$after'" );
}

##[ TEST 4: Default mode (no mode option) still opens successfully ]##########

my $rw_mount = shm_open( $created_path, {}, $priv_key );

my $rw_ok = ok(
    'shm_open with no mode option succeeds',
    defined $rw_mount && !exists $rw_mount->{'error'},
    defined $rw_mount
        && exists $rw_mount->{'error'} ? "error=$rw_mount->{'error'}" : undef
);

if ($rw_ok) {
    my $rw_data
        = substr( ${ $rw_mount->{'mmap_ptr'} }, 512, length($test_data) );
    ok( 'default mode sees exact written content',
        $rw_data eq $test_data,
        "got: '$rw_data'"
    );
}

##[ TEST 5: Explicit non-read mode still opens successfully ]#################

my $rw_mount2 = shm_open( $created_path, { 'mode' => 'write' }, $priv_key );

my $rw2_ok = ok(
    'shm_open with mode => write succeeds',
    defined $rw_mount2 && !exists $rw_mount2->{'error'},
    defined $rw_mount2 && exists $rw_mount2->{'error'}
    ? "error=$rw_mount2->{'error'}"
    : undef
);

if ($rw2_ok) {
    my $rw_data2
        = substr( ${ $rw_mount2->{'mmap_ptr'} }, 512, length($test_data) );
    ok( 'non-read mode sees exact written content',
        $rw_data2 eq $test_data,
        "got: '$rw_data2'"
    );
}

##[ SUMMARY ]#################################################################

cleanup();

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

#,,,.,.,.,,..,,,,,.,,,..,,..,,,..,.,,,,..,.,.,..,,...,...,..,,..,,..,,,..,,,.,
#5AZU7TFEFFDZBDZNPSP22T7ENFGR5SSFKIIZWBGGTLTEYKF5UJOXJXLBALM6A7VWSTFIODX6XNBRG
#\\\|WIJL6ETM4VTEV4WYHYILODU6KMEXWDPBIKVPDRECHR46WY774I4 \ / AMOS7 \ YOURUM ::
#\[7]DQRF4QPPD5ITOB6KXYBAV3XZKJKKNGEUBETD5OURRAIPIFQG6YBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
