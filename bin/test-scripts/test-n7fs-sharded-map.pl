#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use JSON::PP;
use AMOS7::N7FS        qw| read_file write_new_file unb32 make_dirs |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach disk_read_id |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_init root_open |;
use AMOS7::N7FS::Seal;
use AMOS7::NTIME qw| parse_y_age |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;
my $json = JSON::PP->new->utf8->canonical;
my $box  = sandbox();
my $base = $box->{'base'};
my $pass = "$base/pass";
write_new_file( $pass, "pw\npw\n" );
open( my $pass_in, '<:raw', $pass ) or die $OS_ERROR;
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
    qw| pass_fd | => fileno($pass_in)
);
my $signer = test_signer();
my $disk   = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'sharded-map',
    qw| intent |   => 'sandbox only',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $signer,
);
my @paths = map {"$box->{'src'}/node-$ARG"} 0 .. 319;
write_new_file( $paths[$ARG], "node $ARG\n" ) for 0 .. 319;
my $import = assimilate(
    qw| root |           => $box->{'root'},
    qw| host_dir |       => $box->{'host'},
    qw| disk |           => $disk,
    qw| host |           => $signer,
    qw| paths |          => \@paths,
    qw| remove |         => 0,
    qw| category_rules | => [],
    qw| protect |        => [],
);
my @addresses = map { $ARG->{'addr'} } $import->{'entries'}->@*;
my $id = disk_read_id( qw| root | => $box->{'root'}, qw| disk | => $disk );
my $holder = "$base/holder";

sub seal {
    my ( $target, $nodes, %opt ) = @_;
    return AMOS7::N7FS::Seal::seal_nodes(
        qw| root |      => $root,
        qw| holder |    => $target,
        qw| disk |      => $disk,
        qw| disk_root | => $box->{'root'},
        qw| host_dir |  => $box->{'host'},
        qw| addresses | => $nodes,
        qw| trees |     => [],
        %opt,
    );
}

sub current_root {
    my $target = shift               // $holder;
    my $sub    = holder_sub($target) // die 'missing per-root holder';
    my $head   = AMOS7::N7FS::Seal::_head_open( $root, $sub, 1 );
    my $plain
        = AMOS7::N7FS::Seal::_map_plain( $root, $sub, undef, $head->{'map'} );
    return ( $head, $json->decode($plain), $sub );
}

seal( $holder, [ $addresses[0] ] );
my ( $head1, $root1, $sub ) = current_root();
ok( $root1->{'depth'} == 1
        && $root1->{'format'} eq 'n7fs-sharded-map-v1'
        && keys( $root1->{'shards'}->%* ) == 1
        && !exists $root1->{'nodes'},
    'the head names a root listing only the one non-empty shard'
);

## one commit seals root and shards under one writer + version : each must ##
## carry its own nonce domain, so a shard never opens as the root's domain ##
{
    my ($shard) = keys $root1->{'shards'}->%*;
    my $desc    = $root1->{'shards'}{$shard};
    my $own     = eval {
        AMOS7::N7FS::Seal::_map_plain( $root, $sub, undef, $desc,
            "map-shard-$shard" );
    };
    my $as_root = eval {
        AMOS7::N7FS::Seal::_map_plain( $root, $sub, undef, $desc, 'map' );
    };
    ok( defined $own && !defined $as_root,
        'a shard opens only under its own nonce domain, never as the root' );
}

{
    my @reads;
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::_read_blob = sub {
        push @reads, $ARG[1];
        return AMOS7::N7FS::Holder::holder_read(@ARG);
    };
    my ( undef, undef, $lazy )
        = AMOS7::N7FS::Seal::_context( $root, $holder, 1 );
    my $entry = $lazy->{'nodes'}{ $addresses[0] };
    ok( defined $entry && @reads == 2,
        'a single node read downloads only the root and one shard' );
    my @all = keys $lazy->{'nodes'}->%*;
    @all = keys $lazy->{'nodes'}->%*;
    ok( @all == 1 && @reads == 2,
        'a full scan reads no blob for unlisted empty shards' );
}

my @map_writes;
{
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::_write_blob = sub {
        push @map_writes, $ARG[2] if $ARG[3] eq 'map';
        my ( $root_ref, $dir, $bytes ) = @ARG;
        my $name = AMOS7::N7FS::Sum::bmw_b32(
            AMOS7::N7FS::Sum::bmw384_bytes($bytes) );
        write_new_file( "$dir/$name", $bytes ) if not -e "$dir/$name";
        return $name;
    };
    my ($next_address) = grep {
        $ARG ne $addresses[0]
            and AMOS7::N7FS::Seal::_node_shard($ARG) eq
            AMOS7::N7FS::Seal::_node_shard( $addresses[0] )
    } @addresses;
    seal( $holder, [$next_address] );
}
my ( $head2, $root2 ) = current_root();
my @changed = grep {
    ( $root1->{'shards'}{$ARG}{'blob'}     // '' ) ne
        ( $root2->{'shards'}{$ARG}{'blob'} // '' )
} keys $root2->{'shards'}->%*;
ok( @map_writes == 2
        && @changed == 1
        && $head2->{'map'}{'blob'} ne $head1->{'map'}{'blob'},
    'adding one node uploads exactly one changed shard and a new root'
);

my $old = time - 3 * 86400;
utime $old, $old, "$sub/$ARG" or die $OS_ERROR for holder_blobs($holder);
AMOS7::N7FS::Seal::holder_gc(
    qw| root |   => $root,
    qw| holder | => $holder,
    qw| keep |   => [],
    qw| delete | => 1,
    qw| grace |  => 0,
);
my $day            = AMOS7::N7FS::Seal::_trash_day();
my @current_shards = map { $ARG->{'blob'} } values $root2->{'shards'}->%*;
my ($old_shard)    = keys $root1->{'shards'}->%*;
ok( ( !grep { !-e "$sub/$ARG" } $head2->{'map'}{'blob'}, @current_shards )
        && -e "$sub/.trash/$day/$head1->{'map'}{'blob'}"
        && -e "$sub/.trash/$day/$root1->{'shards'}{$old_shard}{'blob'}",
    'gc keeps every current shard and trashes the superseded root and shard'
);

my $spread_holder = "$base/spread";
seal( $spread_holder, \@addresses );
my ( undef, $spread ) = current_root($spread_holder);
ok( keys( $spread->{'shards'}->%* ) > 200,
    '320 digest-sharded nodes spread over more than 200 shards' );
ok( ( keys $spread->{'shards'}->%* ) == scalar keys(
        { map { AMOS7::N7FS::Seal::_node_shard($ARG) => 1 } @addresses }->%*
    ),
    'every root shard is the two-character bmw prefix of its node addresses'
);

my $legacy = "$base/legacy";
copy_tree( $holder, $legacy );
my $legacy_sub = holder_sub($legacy);
my $legacy_map = {
    qw| root_id |    => $root->{'root_id'},
    qw| categories | => {},
    qw| nodes |      => {},
    qw| trees |      => {},
};
my $writer       = unb32( $head2->{'writer'} );
my $legacy_plain = $json->encode($legacy_map);
my $legacy_id    = AMOS7::N7FS::Seal::_long_id( $root->{'keys'}, $writer,
    qw| map |, $legacy_plain );
my $legacy_bytes
    = $writer
    . substr( $legacy_id, 16 )
    . AMOS7::N7FS::Seal::seal_bytes( $root->{'keys'}, $legacy_plain,
    qw| map |, $legacy_id, $head2->{'version'} );
my $legacy_name = AMOS7::N7FS::Sum::bmw_b32(
    AMOS7::N7FS::Sum::bmw384_bytes($legacy_bytes) );
write_new_file( "$legacy_sub/$legacy_name", $legacy_bytes );
my $legacy_desc = {
    qw| blob |     => $legacy_name,
    qw| checksum | => AMOS7::N7FS::Sum::bmw_b32(
        AMOS7::N7FS::Sum::bmw384_bytes($legacy_plain)
    ),
    qw| id |      => AMOS7::N7FS::b32($legacy_id),
    qw| writer |  => $head2->{'writer'},
    qw| version | => $head2->{'version'},
    qw| size |    => length $legacy_bytes,
};
my $legacy_head
    = AMOS7::N7FS::Seal::_head_bytes( $root, $writer,
    $head2->{'version'}, $head2->{'holder'}, $head2->{'time'} + 1,
    $legacy_desc,        $head2->{'journal'} );
write_file( "$legacy_sub/" . AMOS7::N7FS::Seal::_head_name($root),
    $legacy_head );
refused(
    sub { AMOS7::N7FS::Seal::_context( $root, $legacy, 1 ) },
    qr|legacy single-map form is refused|,
    'the old whole-map form is refused clearly'
);

my $byte_holder = "$base/byte-trigger";
my $byte_before = AMOS7::N7FS::Seal::_state_read($root)->{'version'};
my $byte_result = seal(
    $byte_holder, [ @addresses[ 0 .. 2 ] ],
    qw| commit_bytes | => 1,
    qw| commit_age |   => parse_y_age('99Y0'),
);
ok( $byte_result->{'version'} - $byte_before == 3,
    'the byte limit commits each sealed node in this test'
);
my $time_holder = "$base/time-trigger";
my $time_before = AMOS7::N7FS::Seal::_state_read($root)->{'version'};
my $clock       = 1_000_000;
{
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::ntime_now
        = sub { return $clock += parse_y_age('4Y5') };
    my $time_result = seal(
        $time_holder, [ @addresses[ 0 .. 1 ] ],
        qw| commit_bytes | => 1024**3,
        qw| commit_age |   => '4Y5',
    );
    ok( $time_result->{'version'} - $time_before == 2,
        'the ntime limit commits before the end of a multi-node run' );
}

done();

#,,,,,.,.,.,.,,,,,.,,,,.,,,,,,.,,,,.,,.,.,...,..,,...,..,,...,.,.,...,.,,,,.,,
#CJYRST4CFSMHWZFHV53UZTFQ5S5L522MD5XYGQA6VXIIOP7CSASGHZWWNORULXMS2YHQTPGLVOOBQ
#\\\|KE27XVJ7FWW5DLVG2SWDIMVNWMVUFZGQ7HTR6TP5BNA2IXHGVST \ / AMOS7 \ YOURUM ::
#\[7]56QQ4WKQ6ZV22JXS6IWNFBSKLDQI5HSSHPUXE6PNADFPBUJCWQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
