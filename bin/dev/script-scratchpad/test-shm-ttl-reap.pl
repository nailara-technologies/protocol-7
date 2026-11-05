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

use AMOS7::SHM
    qw| shm_create pack_shm_header unpack_shm_header sweep_stale_segments
    derive_pubkey SHM_HEADER_SIZE |;
use Crypt::Misc qw| encode_b32r |;

##[ TEST SETUP ]##############################################################

my $segment_size = 4 * 1024;

sub test_pub_key {
    my $seed = substr( shift() . ( "\0" x 32 ), 0, 32 );
    my $pub  = encode_b32r( derive_pubkey($seed) );
    $pub =~ s{=+\z}{};
    return $pub;
}
my $stale_pub_key = test_pub_key('stale');
my $fresh_pub_key = test_pub_key('fresh');

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

sub clean_test_paths {
    my ($pub_key) = @ARG;
    my $path = sprintf( "/dev/shm/p7:M:%s", $pub_key );
    unlink($path)          if -f $path;
    unlink("$path.notify") if -p "$path.notify";
    return $path;
}

sub fabricate_staleness {
    my ($path) = @ARG;

    open( my $fh, '+<', $path ) or die "cannot open $path for rewrite: $!";
    binmode($fh);

    my $raw;
    my $got = read( $fh, $raw, SHM_HEADER_SIZE );
    die "short header read on $path"
        unless defined $got and $got == SHM_HEADER_SIZE;

    my $header = unpack_shm_header($raw)
        or die "cannot unpack header of $path";

    $header->{'created'} = time() - 7200;    # two hours ago

    my $packed = pack_shm_header($header);
    die "packed header wrong size"
        unless length($packed) == SHM_HEADER_SIZE;

    seek( $fh, 0, 0 )   or die "cannot seek $path: $!";
    print {$fh} $packed or die "cannot write header to $path: $!";
    close($fh)          or die "cannot close $path: $!";
}

##[ PRE-CLEAN ]###############################################################

my $stale_path = clean_test_paths($stale_pub_key);
my $fresh_path = clean_test_paths($fresh_pub_key);

##[ TEST 1: create stale segment and fabricate old created time ]#############

my $stale_mount
    = shm_create( $stale_pub_key, $segment_size, { 'mlock' => 0 } );
if ( !ok( 'created stale test segment', defined $stale_mount ) ) {
    clean_test_paths($stale_pub_key);
    clean_test_paths($fresh_pub_key);
    exit 1;
}
$stale_path = $stale_mount->{'path'};
fabricate_staleness($stale_path);
ok( 'stale segment file exists before sweep', -f $stale_path );

##[ TEST 2: create fresh segment and leave created time untouched ]###########

my $fresh_mount
    = shm_create( $fresh_pub_key, $segment_size, { 'mlock' => 0 } );
if ( !ok( 'created fresh test segment', defined $fresh_mount ) ) {
    clean_test_paths($stale_pub_key);
    clean_test_paths($fresh_pub_key);
    exit 1;
}
$fresh_path = $fresh_mount->{'path'};
ok( 'fresh segment file exists before sweep', -f $fresh_path );

##[ TEST 3: run the TTL sweep ]###############################################

my $summary = sweep_stale_segments( { 'ttl_seconds' => 3600 } );

print "\n: sweep summary\n";
for my $key (
    qw| scanned reaped skipped_fresh skipped_other_owner skipped_unreadable |)
{
    printf ":   %-22s = %d\n", $key, $summary->{$key} // 0;
}
print "\n";

##[ TEST 4: verify direct outcomes ]##########################################

ok( 'stale segment was reaped',   !-f $stale_path, "path=$stale_path" );
ok( 'fresh segment still exists', -f $fresh_path,  "path=$fresh_path" );
ok( 'summary reports at least one reaped',
    ( $summary->{'reaped'} // 0 ) >= 1,
    "reaped=$summary->{'reaped'}"
);
ok( 'summary reports at least one fresh skip',
    ( $summary->{'skipped_fresh'} // 0 ) >= 1,
    "skipped_fresh=$summary->{'skipped_fresh'}"
);
ok( 'summary scanned at least two controlled segments',
    ( $summary->{'scanned'} // 0 ) >= 2,
    "scanned=$summary->{'scanned'}"
);

##[ TEST 5: cross-user skip -- code-reading only ]############################

print "\n: cross-user skip behavior\n";
print ":   /dev/shm sticky bit : ", `stat -c '%A' /dev/shm`;
print ":   verified by code reading only in "
    . "this single-user test environment.\n";
print ":   sweep_stale_segments checks -O "
    . "(owned by effective UID) before any\n";
print ":   read or unlink attempt, so non-owned segments are counted as\n";
print ":   skipped_other_owner and never touched.\n";

##[ CLEANUP ]#################################################################

clean_test_paths($stale_pub_key);
clean_test_paths($fresh_pub_key);

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

#,,.,,,..,.,,,.,.,.,.,,,.,,..,.,.,.,,,,,.,,..,..,,...,..,,..,,...,,,,,,,.,,,,,
#D2SGKIUBIIGM43TESGZ3STRNY5ZDBY4DP4M7DSSQNZ3J3Y2XMWC2GJBA3G5SBTLOYRZEDBZ7C2P4I
#\\\|47EUCATWJXM4S2EX7GODJHHMSGKABUW3UU7ASRXFIQFUG4FGU2S \ / AMOS7 \ YOURUM ::
#\[7]DKER32VVBETVZBVFUNUD7TWMW4HMXPU2NMWUH7ZQXK6HDUBLD2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
