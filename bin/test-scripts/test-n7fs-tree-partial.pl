#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 5 : mixed-tree placement limits, partial heads and combined recovery

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault      qw| vault_init |;
use AMOS7::N7FS       qw| make_dirs read_file |;
use AMOS7::N7FS::Keys qw| root_open |;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::Sign qw| key_file_signer |;
use AMOS7::N7FS::Placement;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;
my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir = "$base/vault";
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );

sub cli {
    my ( $lines, @args ) = @ARG;
    my $pf = "$base/pass";
    write_file( $pf, join '', map {"$ARG\n"} @{$lines} );
    my $out = "$base/out";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<',     $pf )      or exit 98;
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args, '-pass-fd', 0, '-vault-dir', $vdir )
            or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die $OS_ERROR;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

sub open_root {
    write_file( "$base/root-pass", "vp\n" );
    open( my $fh, '<:raw', "$base/root-pass" ) or die $OS_ERROR;
    return root_open(
        qw| path |      => 'vault:main',
        qw| pass_fd |   => fileno($fh),
        qw| vault_dir | => $vdir,
    );
}

sub current_map {
    my ( $open, $holder ) = @ARG;
    my ( undef, undef, $map )
        = AMOS7::N7FS::Seal::_context( $open, $holder, 1 );
    return $map;
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 'partial', '-intent', 'sandbox' );
my ($disk)
    = grep { !m|^\.| }
    do { opendir( my $d, $root ) or die $OS_ERROR; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
( $rc, $out )
    = cli( [], 'category', $disk, 'set', 'vital', '-copies', 2, '-priority',
    90 );
( $rc, $out )
    = cli( [], 'category', $disk, 'set', 'bulk', '-copies', 2, '-priority',
    10 );
make_dirs("$src/mixed/vital");
make_dirs("$src/mixed/bulk");
write_file( "$src/mixed/vital/f$ARG", "vital $ARG\n" ) for 0 .. 1;
write_file( "$src/mixed/bulk/f$ARG",  "bulk $ARG\n" )  for 0 .. 7;
( $rc, $out ) = cli(
    [],      'assimilate', '-disk', $disk, '-keep', '-tree',
    'mixed', '-category',  'bulk',  "$src/mixed"
);
ok( $rc == 0, 'mixed tree imported' ) or say $out;
( $rc, $out )
    = cli( [], 'set-category', $disk, "tree:$src/mixed/vital", 'vital' );
ok( $rc == 0, 'vital files classified inside the mixed tree' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );

my $small = "$base/small";
my $big   = "$base/big";
( $rc, $out ) = cli(
    ['vp'],        'holder',  'add',    'small',
    $small,        '-domain', 'small',  '-owned',
    '-categories', 'vital',   '-quota', 300
);
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'big', $big, '-domain', 'big' );
( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|placed 2 nodes on small|,
    'D1 : place reports exactly the two planned vital files'
) or say $out;
my $open        = open_root();
my $small_map   = current_map( $open, $small );
my @small_nodes = values $small_map->{'nodes'}->%*;
my $small_bytes = 0;
$small_bytes += $ARG->{'length'} // 0 for @small_nodes;
ok( @small_nodes == 2
        && $small_bytes <= 300
        && !( grep { $ARG->{'category'} ne qw| vital | } @small_nodes ),
    'D1 : holder filters and quota bound the actual sealed map'
);
my $small_tree = $small_map->{'trees'}{'mixed'};
ok( $small_tree->{'files'} == 10
        && $small_tree->{'held'} == 2
        && $small_tree->{'state'} eq qw| partial |,
    'D1 : a filtered holder publishes a partial tree inventory'
);
my $big_map = current_map( $open, $big );
ok( $big_map->{'trees'}{'mixed'}{'files'} == 10
        && $big_map->{'trees'}{'mixed'}{'held'} == 10
        && $big_map->{'trees'}{'mixed'}{'state'} eq qw| complete |,
    'an unfiltered holder publishes the complete tree'
);

( $rc, $out )
    = cli( ['vp'], 'seal-recover', '-root-key', 'vault:main', '-from',
    $small, '-list' );
ok( $rc == 0 && $out =~ m|tree mixed .*2 of 10 files, partial|,
    'seal-recover -list reports per-holder tree completeness'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'seal-recover', '-root-key', 'vault:main', '-from', $small,
    '-tree', 'mixed', "$base/refused-partial" );
ok( $rc != 0
        && $out =~ m|tree mixed is partial .*2 of 10 files|
        && !-e "$base/refused-partial",
    'restore by name refuses a partial holder before writing'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],     'seal-recover', '-root-key', 'vault:main',
    '-from',    $small,         '-tree',     'mixed',
    '-partial', "$base/partial-list"
);
my @small_missing = $out =~ m|^: missing (.+)$|mg;
ok( $rc == 1
        && @small_missing == 8
        && !( grep {m|\Avital/|} @small_missing )
        && !-e "$base/partial-list",
    '-partial lists exactly the eight missing bulk paths and exits one'
) or say $out;

my @all_addresses = sort keys $big_map->{'nodes'}->%*;
my @half_a        = @all_addresses[ 0 .. 4 ];
my @half_b        = @all_addresses[ 5 .. 9 ];
my $half_a        = "$base/half-a";
my $half_b        = "$base/half-b";
foreach my $part ( [ $half_a, \@half_a ], [ $half_b, \@half_b ] ) {
    AMOS7::N7FS::Seal::seal_nodes(
        qw| root |           => $open,
        qw| holder |         => $part->[0],
        qw| disk |           => $disk,
        qw| disk_root |      => $root,
        qw| host_dir |       => $hdir,
        qw| addresses |      => $part->[1],
        qw| trees |          => [],
        qw| tree_manifests | => ['mixed'],
    );
}
my $half_map = current_map( $open, $half_a );
ok( $half_map->{'trees'}{'mixed'}{'held'} == 5
        && $half_map->{'trees'}{'mixed'}{'state'} eq qw| partial |,
    'manifest-only selection seals only the explicitly planned half'
);
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $half_a,        '-from',     $half_b,
    '-tree', 'mixed',        "$base/combined"
);
my $combined_ok = $rc == 0;
$combined_ok &&= read_file("$base/combined/vital/f$ARG") eq "vital $ARG\n"
    for 0 .. 1;
$combined_ok &&= read_file("$base/combined/bulk/f$ARG") eq "bulk $ARG\n"
    for 0 .. 7;
ok( $combined_ok,
    'two holders that each hold half restore one complete tree' )
    or say $out;

make_dirs("$src/crash");
write_file( "$src/crash/f$ARG", "crash $ARG\n" ) for 0 .. 5;
( $rc, $out ) = cli(
    [],      'assimilate', '-disk', $disk, '-keep', '-tree',
    'crash', '-category',  'bulk',  "$src/crash"
);
ok( $rc == 0, 'six-file crash tree imported' ) or say $out;
my $crash = "$base/crash-holder";
{
    local $AMOS7::N7FS::FAULT = sub {
        die "injected first-commit crash\n"
            if $ARG[0] eq qw| seal:after-head |;
    };
    my $result = eval {
        AMOS7::N7FS::Seal::seal_nodes(
            qw| root |         => $open,
            qw| holder |       => $crash,
            qw| disk |         => $disk,
            qw| disk_root |    => $root,
            qw| host_dir |     => $hdir,
            qw| addresses |    => [],
            qw| trees |        => ['crash'],
            qw| commit_bytes | => 1,
        );
    };
    ok( !defined $result && $EVAL_ERROR =~ m|injected first-commit crash|,
        'D4 : the crash follows the first file commit' );
}
my $crash_map  = current_map( $open, $crash );
my $crash_tree = $crash_map->{'trees'}{'crash'};
ok( $crash_tree->{'files'} == 6
        && $crash_tree->{'held'} == 1
        && $crash_tree->{'state'} eq qw| partial |,
    'D4 : the first published head says partial one of six'
);
refused(
    sub {
        AMOS7::N7FS::Seal::seal_recover(
            qw| root |   => $open,
            qw| holder | => $crash,
            qw| tree |   => 'crash',
            qw| target | => "$base/crash-refused",
        );
    },
    qr|tree crash is partial .*1 of 6 files|,
    'D4 : recovery refuses the incomplete published tree up front'
);
( $rc, $out ) = cli(
    ['vp'],     'seal-recover', '-root-key', 'vault:main',
    '-from',    $crash,         '-tree',     'crash',
    '-partial', "$base/crash-partial"
);
my @crash_missing = $out =~ m|^: missing (.+)$|mg;
ok( $rc == 1 && @crash_missing == 5 && !-e "$base/crash-partial",
    'D4 : -partial names the five files absent after the crash'
    )
    or say "rc $rc, missing "
    . scalar(@crash_missing)
    . ", target "
    . ( -e "$base/crash-partial" ? 1 : 0 )
    . "\n$out";

{
    my $original = \&AMOS7::N7FS::Seal::_manifest_read;
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::_manifest_read = sub {
        my ( $head, @entries ) = $original->(@ARG);
        return ( $head, reverse @entries );
    };
    refused(
        sub {
            AMOS7::N7FS::Seal::seal_recover(
                qw| root |   => $open,
                qw| holder | => $big,
                qw| tree |   => 'mixed',
                qw| target | => "$base/wrong-manifest",
            );
        },
        qr|rebuilt tree manifest does not match : mixed|,
        'D11 : a wrongly rebuilt manifest fails the end-to-end digest check'
    );
}
ok( !-e "$base/wrong-manifest", 'D11 : manifest failure writes no restore' );

( $rc, $out ) = cli( [], 'init', '-name', 'd6', '-intent', 'sandbox' );
my ($d6)
    = grep { !m|^\.| && $ARG ne $disk }
    do { opendir( my $d, $root ) or die $OS_ERROR; readdir $d };
( $rc, $out ) = cli( [], 'attach', $d6 );
( $rc, $out ) = cli( [], 'category', $d6, 'set', 'three', '-copies', 3 );
make_dirs("$src/d6");
write_file( "$src/d6/f$ARG", "d6 $ARG\n" ) for 0 .. 2;
( $rc, $out ) = cli(
    [],   'assimilate', '-disk', $d6, '-keep', '-tree',
    'd6', '-category',  'three', "$src/d6"
);
ok( $rc == 0, 'D6 fixture imported' ) or say $out;
my %d6_holders = map {
    my $name = $ARG;
    $name => {
        qw| spec |   => "$base/$name",
        qw| role |   => qw| durable |,
        qw| domain | => $name,
        qw| owned |  => 0,
    }
} qw| a-fail b-good c-good |;
my $host_signer = key_file_signer("$hdir/host.key");
my ( @seal_attempts, @check_attempts, $d6_result );
{
    my $seal_original  = \&AMOS7::N7FS::Seal::seal_nodes;
    my $check_original = \&AMOS7::N7FS::Seal::holder_check;
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Placement::holders_load = sub { return \%d6_holders };
    local *AMOS7::N7FS::Seal::seal_nodes        = sub {
        my %opt = @ARG;
        push @seal_attempts, $opt{'holder'};
        die "injected holder failure\n" if $opt{'holder'} eq "$base/a-fail";
        return $seal_original->(@ARG);
    };
    local *AMOS7::N7FS::Seal::holder_check = sub {
        my %opt = @ARG;
        push @check_attempts, $opt{'holder'};
        return $check_original->(@ARG);
    };
    $d6_result = AMOS7::N7FS::Placement::place_missing(
        qw| root |           => $open,
        qw| disk |           => $d6,
        qw| disk_root |      => $root,
        qw| host_dir |       => $hdir,
        qw| host_pub |       => $host_signer->public,
        qw| exclude |        => [],
        qw| check_coverage | => qw| sampled |,
    );
}
ok( !$d6_result->{'results'}{'a-fail'}{'ok'}
        && $d6_result->{'results'}{'a-fail'}{'error'}
        =~ m|injected holder failure|
        && $d6_result->{'results'}{'b-good'}{'sealed'} == 3
        && $d6_result->{'results'}{'c-good'}{'sealed'} == 3,
    'D6 : one holder failure does not abort later holders'
);
ok( @seal_attempts == 3
        && @check_attempts == 3
        && $d6_result->{'checks'}{'b-good'}{'ok'}
        && $d6_result->{'checks'}{'c-good'}{'ok'},
    'D6 : every attempted holder is checked and every written holder passes'
);

done();

#,,..,..,,,,,,,,.,...,.,.,,.,,,,.,,.,,..,,.,.,..,,...,...,,.,,..,,,..,,..,,.,,
#SIUEJWW3OR5CUVQ2AI2V4L3YTM2QVKXNOOSDRAUZ7UJELPKQOSVLJSHIL4TX66K2DFTG43HYPO6TG
#\\\|WE57AALQTXL57O2E56B7PSSCR4EEMCYSUZKBDRNAIWKF2RYACKA \ / AMOS7 \ YOURUM ::
#\[7]UXL2QFMW7VBFRA5UVYL2VTASCATO7UTLCACTBZYCD3PEQFNFXGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
