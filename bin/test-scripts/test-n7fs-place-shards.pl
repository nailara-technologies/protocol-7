#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## holder map lookups in shard order : a dry place under a time bound, shard
## reads about the shard count [ not the node count ], digests equal to the
## per-address form, the address set bulk build and the release index

use FindBin;
BEGIN { unshift @INC, "$FindBin::RealBin/../../data/lib-path/pm" }

use Time::HiRes qw| time |;
use Digest::BMW;
use AMOS7::N7FS        qw| make_dirs write_new_file |;
use AMOS7::N7FS::Sum   qw| bmw_b32 |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_init root_open |;
use AMOS7::N7FS::Placement;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::AddressSet;
use AMOS7::N7FS::Journal;

require "$FindBin::RealBin/fixtures/n7fs/helpers.pl";

my $nodes   = $ENV{'N7FS_TEST_SHARD_NODES'} // 4000;
my $ntrees  = 8;
my $holders = 4;
## the per-address form took 10.8 s at 4 k nodes and 4 holders ; one read per
## shard 1.4 s [ profile, 16 threads ]
my $bound = $ENV{'N7FS_TEST_SHARD_BOUND'} // 5;

## the address set : duplicates and unsorted input, one sort per bucket ##
{
    my @addresses
        = map { sprintf 'V7AAAAA/AAAAAAA/%s%s', $ARG, 'A' x 74 } map {
        my $x = $ARG;
        map { $x . $ARG } qw| B A C |
        } qw| ZZ AB AA |;
    my %set;
    tie %set, 'AMOS7::N7FS::AddressSet';
    $set{$ARG} = 5 for reverse( @addresses, @addresses );
    my @unique = do {
        my %u = map { $ARG => 1 } @addresses;
        sort keys %u;
    };
    ok( join( ',', keys %set ) eq join( ',', @unique ),
        'address set : unsorted duplicate input walks sorted and unique' );
    ok( scalar(%set) == @unique, 'address set : the count ignores repeats' );
    ok( ( grep { $set{$ARG} } @unique ) == @unique,
        'address set : every address is found'
    );
    delete $set{ $unique[1] };
    $set{ $unique[1] } = 5;
    $set{ $unique[0] } = 5;
    ok( join( ',', keys %set ) eq join( ',', @unique ),
        'address set : delete and re-insert keep the order'
    );
    my $tied = tied %set;
    ok( join( ',', map { $tied->shard_addresses($ARG) } $tied->shards ) eq
            join( ',', @unique ),
        'address set : per-shard lists in shard order'
    );
}

## the release index : a release drops exactly its own metas and references,
## also on a replay passed in without the index [ journal_write ]
{
    my $node = sub { sprintf 'V7AAAAA/AAAAAAA/%s', $ARG[0] x 77 };
    my ( $n1, $n2 ) = ( $node->('B'), $node->('C') );
    my $origin = { qw| disk | => 'AAAAAAA', qw| id | => 'x' };
    my $add    = {
        qw| nodes | => [ $n1, $n2 ],
        qw| meta |  => [
            map {
                {
                    qw| node |     => $ARG,
                        qw| name | => '20250101000000.AAAAAAAA.meta'
                }
            } $n1,
            $n2
        ],
        qw| references | => [
            map {
                {
                    qw| node |     => $ARG,
                        qw| path | => "20250101000000/AAAAAAA/"
                        . substr( $ARG, 16 ) . '/addr',
                        qw| holder | => 'h',
                        qw| name |   => 'n'
                }
            } $n1,
            $n2
        ],
    };
    my $run = sub {
        my ( $expected, @releases ) = @_;
        no warnings 'redefine';
        for my $p (
            { qw| seq | => 1, qw| add | => $add, qw| drop | => {} },
            {   qw| seq |  => 2,
                qw| add |  => {},
                qw| drop | => { qw| releases | => [@releases] }
            }
        ) {
            $p->{$ARG}{'releases'} //= [] for qw| add drop |;
            AMOS7::N7FS::Journal::_operations( $p, $expected, undef );
        }
        return $expected;
    };
    my $plain = eval { $run->( { qw| _node_keys | => {} }, $n1 ) };
    if ( not $plain ) {
        ok( 0, "release index : replay ran [ $EVAL_ERROR ]" );
    } else {
        ok( ( join ',', map { $ARG->{'node'} } values $plain->{'metas'}->%* )
                eq $n2,
            'release index : the released node leaves the live metas'
        );
        ok(
            (   join ',',
                map { $ARG->{'node'} } values $plain->{'references'}->%*
            ) eq $n2,
            'release index : the released node leaves the live references'
        );
        ok( $plain->{'ref_history'}{
                join "\0", $n1,
                "20250101000000/AAAAAAA/" . substr( $n1, 16 ) . '/addr'
            }{'released'},
            'release index : the history entry is marked released'
        );
        my $passed = eval { $run->( {}, $n2 ) };
        ok( $passed
                && (
                join ',',
                map { $ARG->{'node'} } values $passed->{'metas'}->%*
                ) eq $n1
                && !exists $passed->{'_node_keys'},
            'release index : a passed-in replay releases and keeps no index'
        );
    }
}

## the synthetic store : real assimilate, 4 local holders in 4 domains ##
my $box  = sandbox();
my $base = $box->{'base'};
write_new_file( "$base/pass", "pw\npw\n" );
open( my $pass_in, '<:raw', "$base/pass" ) or die $OS_ERROR;
root_init(
    qw| path |    => "$base/root.key",
    qw| pass_fd | => fileno($pass_in),
    qw| m |       => 1024,
    qw| t |       => 1,
    qw| p |       => 1,
);
seek $pass_in, 0, 0 or die $OS_ERROR;
my $root = root_open(
    qw| path |    => "$base/root.key",
    qw| pass_fd | => fileno($pass_in),
);
my $signer = test_signer();
my $disk   = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'place-shards',
    qw| intent |   => 'sandbox only',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $signer,
);
my $t0 = time;

foreach my $t ( 0 .. $ntrees - 1 ) {
    my $dir = "$box->{'src'}/t$t";
    make_dirs($dir);
    write_new_file( "$dir/n-$ARG", "node $t $ARG\n" )
        for 0 .. $nodes / $ntrees - 1;
    assimilate(
        qw| root |           => $box->{'root'},
        qw| host_dir |       => $box->{'host'},
        qw| disk |           => $disk,
        qw| host |           => $signer,
        qw| paths |          => [$dir],
        qw| tree |           => sprintf( 'tree-%02d', $t ),
        qw| remove |         => 0,
        qw| category_rules | => [],
        qw| protect |        => [],
    );
}
say sprintf '  assimilate %d nodes : %.1f s', $nodes, time - $t0;
my %common = (
    qw| root |      => $root,
    qw| disk |      => $disk,
    qw| disk_root | => $box->{'root'},
    qw| host_dir |  => $box->{'host'},
);
my %all;
foreach my $k ( 1 .. $holders ) {
    make_dirs("$base/holder$k");
    my %h = (
        "h$k" => {
            qw| spec |   => "$base/holder$k",
            qw| role |   => qw| durable |,
            qw| domain | => "d$k",
            qw| owned |  => 1,
        }
    );
    %all = ( %all, %h );
    AMOS7::N7FS::Placement::holders_save( \%h, qw| root | => $root );
    $t0 = time;
    my $r = AMOS7::N7FS::Placement::place_missing(
        %common,
        qw| samples |    => 1,
        qw| commit_age | => '99Y0',
    );
    my $bad = grep { not $ARG->{'ok'} } values %{ $r->{'results'} },
        values %{ $r->{'checks'} };
    ok( ( $r->{'sealed'}{"h$k"} // 0 ) == $nodes && !$bad,
        "holder h$k holds every node" );
    say sprintf '  place h%d : %.1f s', $k, time - $t0;
}
AMOS7::N7FS::Placement::holders_save( \%all, qw| root | => $root );

## shard decodes, counted where every map shard is opened ##
my $reads = 0;
{
    no warnings 'redefine';
    my $plain = \&AMOS7::N7FS::Seal::_map_plain;
    *AMOS7::N7FS::Seal::_map_plain = sub {
        $reads++ if ( $ARG[4] // '' ) =~ m|\Amap-shard-|;
        return $plain->(@ARG);
    };
}
my $shards = 0;
my %maps;
foreach my $k ( 1 .. $holders ) {
    my ( undef, undef, $map )
        = AMOS7::N7FS::Seal::_context( $root, "$base/holder$k", 1 );
    $maps{"h$k"} = $map;
    $shards += keys $map->{'_shards'}->%*;
}
say "  map shards over $holders holders : $shards";

## the per-address form, as it was : equal covered lists and digests ##
sub old_covered {
    my ( $map, $version ) = @_;
    return sort grep { ( $map->{'nodes'}{$ARG}{'added'} // 0 ) <= $version }
        keys %{ $map->{'nodes'} // {} };
}

sub old_digest {
    my ( $map, $version ) = @_;
    my $digest = Digest::BMW->new(384);
    my $first  = 1;
    foreach my $address ( old_covered( $map, $version ) ) {
        my $e = $map->{'nodes'}{$address};
        $digest->add("\n") if not $first;
        $digest->add(
            join "\0",
            $address,
            $e->{'blob'}   // '',
            $e->{'offset'} // 0,
            $e->{'length'} // 0,
            $e->{'chunks'} // 0,
            $e->{'node'}   // ''
        );
        $first = 0;
    }
    return bmw_b32( $digest->digest );
}

{
    my $map = $maps{'h1'};
    my ( undef, $head )
        = AMOS7::N7FS::Seal::_context( $root, "$base/holder1", 1 );
    foreach
        my $version ( 0, int( $head->{'version'} / 2 ), $head->{'version'} ) {
        ok( join( ',',
                AMOS7::N7FS::Placement::receipt_covered( $map, $version ) )
                eq join( ',', old_covered( $map, $version ) ),
            "covered list equal to the per-address form at v$version"
        );
        ok( AMOS7::N7FS::Placement::receipt_digest( $map, $version ) eq
                old_digest( $map, $version ),
            "covered digest equal to the per-address form at v$version"
        );
    }
    my $census = AMOS7::N7FS::Placement::_map_census( $map, undef );
    my $used   = 0;
    $used += $map->{'nodes'}{$ARG}{'length'} // 0
        for keys $map->{'nodes'}->%*;
    ok( $census->{'count'} == $nodes && $census->{'used'} == $used,
        'census count and used equal the per-address sums'
    );
}

## the timed dry run ##
$reads = 0;
$t0    = time;
my $dry = AMOS7::N7FS::Placement::place_missing(
    %common,
    qw| dry_run |           => 1,
    qw| only_category |     => ['default'],
    qw| only_holder |       => ['h1'],
    qw| unreachable_grace | => 1,
);
my $took = time - $t0;
say sprintf '  dry place : %.2f s, %d shard reads, unplaced %d, plan %s',
    $took, $reads, $dry->{'unplaced'},
    join( ',',
    map {"$ARG=$dry->{'plan'}{$ARG}"} sort keys $dry->{'plan'}->%* )
    || '-';
ok( $dry->{'unplaced'} == 0 && !( grep {$ARG} values $dry->{'plan'}->%* ),
    'dry place : every node already placed' );
ok( $took < $bound,
    sprintf 'dry place under %s s at %d nodes [ %.2f s ]',
    $bound, $nodes, $took
);
ok( $reads <= $shards * 1.25 + 16,
    "dry place reads about one shard each [ $reads reads, $shards shards ]" );
## the per-address form decoded about 4 shards per node and holder ##
ok( $reads < $nodes * $holders / 2,
    'dry place reads far fewer shards than node lookups' );

## the placement report reads each shard once too ##
$reads = 0;
my $report = AMOS7::N7FS::Placement::placement_report(%common);
ok( $reads <= $shards * 1.25 + 16,
    "placement report reads about one shard each [ $reads reads ]" );

## holder-check : one pass for sizes, weights and digest ##
{
    my ( undef, undef, $map )
        = AMOS7::N7FS::Seal::_context( $root, "$base/holder1", 1 );
    my $one = keys $map->{'_shards'}->%*;
    $reads = 0;
    my $check = AMOS7::N7FS::Seal::holder_check(
        qw| root |     => $root,
        qw| holder |   => "$base/holder1",
        qw| coverage | => qw| sampled |,
        qw| samples |  => 4,
    );
    ok( $reads <= $one * 1.25 + 16,
        "holder-check reads about one shard "
            . "each [ $reads reads, $one shards ]"
    );
    ok( $check->{'nodes'} == $nodes
            && $check->{'covered'} eq old_digest( $map, $check->{'version'} )
            && $check->{'covered_nodes'} == $nodes,
        'holder-check digest and counts equal the per-address form'
    );
}

done();

#,,,.,,..,.,.,,.,,,,,,...,...,..,,...,,..,..,,..,,...,...,...,,,,,..,,..,,.,,,
#HQLN5PKG34LPORIGQXTSFPBYXZ3IHIBK2UNVHIMCHIG472S6C73RFT7YNB5NFGEZW52FO6MZOE7BG
#\\\|AAE3CSML7ROWYETGIEDFCOUINMA2KZIWGNAQWRBKIX3YHFXDPCO \ / AMOS7 \ YOURUM ::
#\[7]XVVWD37EYRDZEBLLCUAHXX5YDNKSET2J5JF6USSPMGVVMUBUQOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
