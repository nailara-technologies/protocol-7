#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                 ###
##  osf-cache.debian.read_inrelease + read_packages + holdings scan  ##
###                                                                 ###

## exercises the real translated module sources against small fixtures ##
## in bin/test-scripts/fixtures/osf-cache/ - no live zenka required :  ##
## - InRelease header + sha256 section parse, signature not good       ##
## - Packages streaming parse into the by_sha256 index                 ##
## - anchoring : correct expect_sha256 anchors, wrong one does not     ##
## - apt cache scan : listed .deb anchored, unlisted not               ##
## - large index streaming : generated 20k-stanza file read line-wise  ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;
use Digest::SHA ();
use File::Temp  qw| tempdir |;

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

use constant TRUE  => 5;
use constant FALSE => 0;

our %code;

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module('osf-cache.debian.read_inrelease');
compile_module('osf-cache.debian.read_packages');
compile_module('osf-cache.holdings.scan_apt_cache');

sub call_module {
    my ( $module_name, $params ) = @ARG;
    return $code{$module_name}->($params);
}

sub fixture_path {
    my $name = shift;
    return File::Spec->catfile( $RealBin, 'fixtures', 'osf-cache', $name );
}

##[ tiny assertion framework ]##################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ 1 : InRelease parse + signature verdict ]###################################

say ': InRelease parse + signature';

my $ir = call_module( 'osf-cache.debian.read_inrelease',
    { 'path' => fixture_path('fixture_InRelease') } );

ok( ref $ir eq qw| HASH | && $ir->{'mode'} eq qw| true |,
    'mode true' );

my $ir_data = $ir->{'data'} // {};

ok( ( $ir_data->{'origin'} // '' ) eq qw| FixtureOS |, 'origin parsed' );
ok( ( $ir_data->{'suite'} // '' ) eq qw| stable |,    'suite parsed' );
ok( ( $ir_data->{'codename'} // '' ) eq qw| fixture |,
    'codename parsed' );
ok( ( $ir_data->{'date'} // '' ) eq 'Fri, 02 Oct 2026 20:13:57 UTC',
    'date parsed' );
ok( ( $ir_data->{'valid_until'} // '' ) eq 'Fri, 09 Oct 2026 20:13:57 UTC',
    'valid-until parsed' );

my $ir_files = $ir_data->{'files'} // {};

ok( scalar keys %$ir_files == 1, 'exactly one sha256 section entry' );

my $ir_entry = $ir_files->{'main/binary-amd64/Packages'} // {};

ok( ( $ir_entry->{'sha256'} // '' ) eq
        '24c60d4a6fec60219a55287ef6f17168316c6e510647c4e8e9f0739fc255d7c8',
    'Packages relpath anchored to fixture sha256'
);
ok( ( $ir_entry->{'size'} // 0 ) == 1001, 'Packages size parsed' );

ok( ( $ir_data->{'signature'} // '' ) ne qw| good |,
    'fixture signature is not good [ bad or unverified ]' );
ok( defined $ir_data->{'signature'}
        && $ir_data->{'signature'} =~ m{^(?:bad|unverified)$},
    "signature verdict is '$ir_data->{'signature'}'"
);

my $ir_missing = call_module( 'osf-cache.debian.read_inrelease',
    { 'path' => fixture_path('no-such-file') } );

ok( ref $ir_missing eq qw| HASH | && $ir_missing->{'mode'} eq qw| false |,
    'missing file returns mode false' );

##[ 2 : Packages streaming parse + sha256 index ]###############################

say ': Packages streaming parse';

my $packages_path = fixture_path('fixture_Packages');
my $packages_sha
    = Digest::SHA::sha256_hex( do { local $INPUT_RECORD_SEPARATOR = undef;
        open my $pfh, '<', $packages_path or die $OS_ERROR;
        my $c = <$pfh>; close($pfh); $c } );

my $pr = call_module( 'osf-cache.debian.read_packages',
    { 'path' => $packages_path } );

ok( ref $pr eq qw| HASH | && $pr->{'mode'} eq qw| true |,
    'mode true' );

my $pr_data = $pr->{'data'} // {};

ok( ( $pr_data->{'entries'} // 0 ) == 3, 'three stanzas indexed' );
ok( ( $pr_data->{'file_sha256'} // '' ) eq $packages_sha,
    'computed file sha256 matches reference digest' );
ok( ( $pr_data->{'anchored'} // 1 ) == 0,
    'anchored 0 without expect_sha256' );

my $by_sha = $pr_data->{'by_sha256'} // {};
ok( scalar keys %$by_sha == 3, 'index holds three sha256 keys' );

my $hello = $by_sha->{'9430868357b8099bf1ea4a4d2696a2df9ef23f4ce00967b07f73d0943e09db14'}
    // {};

ok( ( $hello->{'package'} // '' ) eq qw| hello |
        && ( $hello->{'version'} // '' ) eq '2.12.3-1'
        && ( $hello->{'architecture'} // '' ) eq qw| amd64 |
        && ( $hello->{'filename'} // '' ) eq
        'pool/main/h/hello/hello_2.12.3-1_amd64.deb'
        && ( $hello->{'size'} // '' ) eq qw| 96 |,
    'hello entry : package, version, arch, filename, size'
);

ok( exists $by_sha->{'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899'}
        && ( $by_sha->{'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899'}
            // {} )->{'package'} eq qw| goodbye |,
    'goodbye entry indexed by its sha256'
);

##[ 3 : anchoring against the InRelease hash ]##################################

say ': anchoring';

my $pr_anchored = call_module( 'osf-cache.debian.read_packages',
    {   'path'          => $packages_path,
        'expect_sha256' => $ir_entry->{'sha256'},
    } );

ok( $pr_anchored->{'mode'} eq qw| true |
        && $pr_anchored->{'data'}{'anchored'} == 1,
    'anchored 1 when computed sha256 matches the InRelease entry' );

my $pr_wrong = call_module( 'osf-cache.debian.read_packages',
    {   'path'          => $packages_path,
        'expect_sha256' => ( 'f' x 64 ),
    } );

ok( $pr_wrong->{'mode'} eq qw| true |
        && $pr_wrong->{'data'}{'anchored'} == 0,
    'anchored 0 on tampered expect_sha256' );

my $packages_sha512 = Digest::SHA::sha512_hex(
    do { local $INPUT_RECORD_SEPARATOR = undef;
        open my $pfh, '<', $packages_path or die $OS_ERROR;
        my $c = <$pfh>; close($pfh); $c } );

my $pr_512 = call_module( 'osf-cache.debian.read_packages',
    {   'path'          => $packages_path,
        'expect_sha256' => $packages_sha512,
    } );

ok( $pr_512->{'mode'} eq qw| true |
        && $pr_512->{'data'}{'anchored'} == 1,
    'anchored 1 when the index carries a sha512-only entry' );

##[ 4 : holdings scan over a fixture cache dir ]################################

say ': holdings scan';

my $tmp_dir = tempdir( CLEANUP => 1 );

foreach my $deb_name ( qw|
    fake-hello_2.12.3-1_amd64.deb
    igt-gpu-tools_2.5-1_amd64.deb
    | )
{
    symlink fixture_path($deb_name), "$tmp_dir/$deb_name"
        or die "symlink failed : $OS_ERROR";
}

my $scan = call_module( 'osf-cache.holdings.scan_apt_cache',
    { 'dir' => $tmp_dir, 'index' => $by_sha } );

ok( ref $scan eq qw| HASH | && $scan->{'mode'} eq qw| true |,
    'mode true' );

my $scan_data = $scan->{'data'} // {};
my %by_name   = map { $ARG->{'name'} => $ARG } $scan_data->{'files'}->@*;

ok( scalar keys %by_name == 2, 'two .deb files scanned' );

my $hello_deb = $by_name{'fake-hello_2.12.3-1_amd64.deb'} // {};
ok( ( $hello_deb->{'anchored'} // 0 ) == 1
        && ( $hello_deb->{'package'} // '' ) eq qw| hello |
        && ( $hello_deb->{'version'} // '' ) eq '2.12.3-1',
    'listed .deb anchored with index package + version'
);

my $igt_deb = $by_name{'igt-gpu-tools_2.5-1_amd64.deb'} // {};
ok( ( $igt_deb->{'anchored'} // 1 ) == 0
        && ( $igt_deb->{'package'} // '' ) eq qw| igt-gpu-tools |
        && ( $igt_deb->{'version'} // '' ) eq '2.5-1',
    'unlisted .deb not anchored, name parsed from file name'
);

ok( ( $scan_data->{'anchored_count'} // 0 ) == 1,
    'anchored_count is 1' );
ok( ( $scan_data->{'total_bytes'} // 0 )
        == ( $hello_deb->{'size'} // 0 ) + ( $igt_deb->{'size'} // 0 ),
    'total_bytes is the sum of both files' );
ok( ( $scan_data->{'anchored_bytes'} // 0 ) == ( $hello_deb->{'size'} // 0 ),
    'anchored_bytes is the listed .deb only' );

my $scan_missing = call_module( 'osf-cache.holdings.scan_apt_cache',
    { 'dir' => "$tmp_dir/no-such-dir", 'index' => $by_sha } );

ok( ref $scan_missing eq qw| HASH |
        && $scan_missing->{'mode'} eq qw| false |,
    'missing cache dir returns mode false' );

##[ 5 : large index streaming path ]#############################################

say ': large index streaming';

my $large_path   = "$tmp_dir/large_Packages";
my $large_stanzas = 20000;
{
    open( my $lfh, '>', $large_path ) or die $OS_ERROR;
    foreach my $n ( 1 .. $large_stanzas ) {
        printf $lfh "Package: generated-%05d\n", $n;
        print $lfh "Version: 1.0-$n\n",
            "Architecture: amd64\n",
            "Filename: pool/main/g/generated/generated_$n\_amd64.deb\n",
            "Size: 1000\n",
            "SHA256: ",
            substr( Digest::SHA::sha256_hex("payload-$n"), 0, 64 ),
            "\n\n";
    }
    close($lfh);
}

my $large_sha = Digest::SHA::sha256_hex(
    do { local $INPUT_RECORD_SEPARATOR = undef;
        open my $lfh, '<', $large_path or die $OS_ERROR;
        my $c = <$lfh>; close($lfh); $c } );

my $lr = call_module( 'osf-cache.debian.read_packages',
    { 'path' => $large_path } );

ok( $lr->{'mode'} eq qw| true |
        && $lr->{'data'}{'entries'} == $large_stanzas,
    "$large_stanzas stanzas streamed and indexed" );
ok( ( $lr->{'data'}{'file_sha256'} // '' ) eq $large_sha,
    'large file sha256 matches reference digest' );
ok( scalar keys %{ $lr->{'data'}{'by_sha256'} } == $large_stanzas,
    'large index holds one key per stanza' );

my $large_index = $lr->{'data'}{'by_sha256'};

my $lr_anchored = call_module( 'osf-cache.debian.read_packages',
    {   'path'          => $large_path,
        'expect_sha256' => $large_sha,
    } );

ok( $lr_anchored->{'data'}{'anchored'} == 1,
    'large file anchored with its own hash' );

my $large_scan = call_module( 'osf-cache.holdings.scan_apt_cache',
    { 'dir' => $tmp_dir, 'index' => $large_index } );

ok( $large_scan->{'mode'} eq qw| true |,
    'holdings scan runs against large index' );

##[ summary ]###################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,..,.,,,,,,,,..,..,,...,.,.,.,,,...,...,..,,...,...,,,,,.,.,.,.,,,,,..,,
#EY5TBQX2VLWRM43MGJ7SGWEF3K7DFDQZLHYYMGXBVEJ3BPTJLJ3UOOGFHXFSI7OYEAYZ2MQ4P6LUQ
#\\\|22BMHMIJFSLOESXIB55JCC2WQSNIYMJOE5V6RKGLYXNVFYPLRBC \ / AMOS7 \ YOURUM ::
#\[7]BTGXGL3UMXKYNXVVR3KID2TISRQ3HWMV5627U3MQOK4TFR43VUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
