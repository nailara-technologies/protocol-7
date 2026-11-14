#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;
use feature qw| bitwise |;

use FindBin;
$^F = 100;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use JSON::PP;
use File::Copy         qw| copy |;
use IPC::Open3         qw| open3 |;
use Symbol             qw| gensym |;
use AMOS7::N7FS        qw| read_file write_new_file b32 unb32 |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_init root_open |;
use AMOS7::N7FS::Seal;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;
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
close $pass_in;

my $now = 1_000_000;
local $AMOS7::N7FS::CLOCK = sub { return $now };

sub open_root {
    my $path = shift;
    open( my $fh, '<:raw', $pass ) or die $OS_ERROR;
    return root_open( qw| path | => $path, qw| pass_fd | => fileno($fh) );
}

my $root   = open_root("$base/root.key");
my $signer = test_signer();
my $disk   = disk_init(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| parent |   => test_signer(),
    qw| name |     => 'head-v2',
    qw| intent |   => 'sandbox only',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $signer,
);
my @paths = map {"$box->{'src'}/node-$ARG"} 0 .. 47;
write_new_file( $paths[$ARG], "node $ARG\n" ) for 0 .. $#paths;
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
my $first     = $addresses[0];
my ($second)  = grep {
    $ARG ne $first
        and AMOS7::N7FS::Seal::_node_shard($ARG) eq
        AMOS7::N7FS::Seal::_node_shard($first)
} @addresses;
die 'no same-shard test pair' if not defined $second;

sub seal_to {
    my ( $open, $holder, @nodes ) = @_;
    return AMOS7::N7FS::Seal::seal_nodes(
        qw| root |      => $open,
        qw| holder |    => $holder,
        qw| disk |      => $disk,
        qw| disk_root | => $box->{'root'},
        qw| host_dir |  => $box->{'host'},
        qw| addresses | => \@nodes,
        qw| trees |     => [],
    );
}

sub current_head {
    my ( $open, $holder ) = @_;
    my $sub = holder_sub($holder) // die 'missing per-root holder';
    return ( AMOS7::N7FS::Seal::_head_open( $open, $sub, 1 ), $sub );
}

sub blob {
    my ( $sub, $name ) = @_;
    return read_file("$sub/$name");
}

sub cipher_body {
    my ( $bytes, $header, $exterior ) = @_;
    return
        substr( $bytes, $header,
        length($bytes) - $header - 16 - ( $exterior ? 69 : 0 ) );
}

sub long_plain {
    my ( $open, $bytes, $domain, $version, $header, $exterior ) = @_;
    my $id = substr( $bytes, 0, 32 );
    $id = substr( $bytes, 8, 16 ) . substr( $bytes, 24, 16 ) if $header == 40;
    return AMOS7::N7FS::Seal::open_sealed_bytes(
        $open->{'keys'},
        substr(
            $bytes, $header,
            length($bytes) - $header - ( $exterior ? 69 : 0 )
        ),
        $domain, $id, $version
    );
}

sub no_reuse {
    my ( $open, $left, $right, $domain, $version, $header, $exterior, $name )
        = @_;
    my $left_plain
        = long_plain( $open, $left, $domain, $version, $header, $exterior );
    my $right_plain
        = long_plain( $open, $right, $domain, $version, $header, $exterior );
    ok( $left_plain ne $right_plain
            && ( cipher_body( $left, $header, $exterior )
            ^. cipher_body( $right, $header, $exterior ) ) ne
            ( $left_plain ^. $right_plain ),
        $name
    );
}

sub reservations {
    my $open = shift;
    my $dir  = AMOS7::N7FS::Seal::_state_dir($open) . '/reservations';
    return () if not -d $dir;
    opendir( my $dh, $dir ) or die $OS_ERROR;
    my @names = grep {m|\A[1-9]\d*\z|} readdir $dh;
    closedir $dh;
    return @names;
}

my $holder_a = "$base/holder-a";
my $holder_b = "$base/holder-b";
seal_to( $root, $holder_a, $first );
my ( $head_a1, $sub_a ) = current_head( $root, $holder_a );
ok( $head_a1->{'format'} eq 'n7fs-head-v2'
        and $head_a1->{'time'} == $now
        and length( unb32( $head_a1->{'holder'} ) // '' ) == 16
        and ref $head_a1->{'map'} eq 'HASH'
        and ( $head_a1->{'map'}{'version'} // 0 ) == $head_a1->{'version'},
    'head v2 signs time, holder id and its own map descriptor'
);

for my $clone (qw| copy-a copy-b |) {
    copy( "$base/root.key", "$base/$clone.key" ) or die $OS_ERROR;
    chmod 0600, "$base/$clone.key";
    copy_tree( "$base/root.key.state", "$base/$clone.key.state" );
}
my $copy_a = open_root("$base/copy-a.key");
my $copy_b = open_root("$base/copy-b.key");
seal_to( $copy_a, $holder_b, $second );
seal_to( $copy_b, $holder_a, $second );
my ( $head_a2, undef ) = current_head( $copy_b, $holder_a );
my ( $head_b2, $sub_b ) = current_head( $copy_a, $holder_b );
ok( $head_a2->{'version'} == 2
        and $head_b2->{'version'} == 2
        and $head_a2->{'writer'} eq $head_b2->{'writer'}
        and $head_a2->{'map'}{'id'} ne $head_b2->{'map'}{'id'},
    'restored states repeat writer and version but not the keyed map id'
);

my $map_a  = blob( $sub_a, $head_a2->{'map'}{'blob'} );
my $map_b  = blob( $sub_b, $head_b2->{'map'}{'blob'} );
my $head_a = read_file( "$sub_a/" . AMOS7::N7FS::Seal::_head_name($copy_b) );
my $head_b = read_file( "$sub_b/" . AMOS7::N7FS::Seal::_head_name($copy_a) );
my $journal_a = blob( $sub_a, $head_a2->{'journal'} );
my $journal_b = blob( $sub_b, $head_b2->{'journal'} );
no_reuse( $copy_a, $head_a, $head_b, 'head', 2, 40, 1,
    'different head plaintexts never share a nonce after state restore' );
no_reuse( $copy_a, $map_a, $map_b, 'map', 2, 32, 0,
    'different map roots never share a nonce after state restore' );
no_reuse( $copy_a, $journal_a, $journal_b, 'journal', 2, 32, 0,
    'different journals never share a nonce after state restore' );

my $map_a_plain  = long_plain( $copy_a, $map_a, 'map', 2, 32, 0 );
my $map_b_plain  = long_plain( $copy_a, $map_b, 'map', 2, 32, 0 );
my $shard        = AMOS7::N7FS::Seal::_node_shard($first);
my $json         = JSON::PP->new->utf8->canonical;
my $shard_a_desc = $json->decode($map_a_plain)->{'shards'}{$shard};
my $shard_b_desc = $json->decode($map_b_plain)->{'shards'}{$shard};
my $shard_a      = blob( $sub_a, $shard_a_desc->{'blob'} );
my $shard_b      = blob( $sub_b, $shard_b_desc->{'blob'} );
ok( $shard_a_desc->{'id'} ne $shard_b_desc->{'id'},
    'same-version map shards carry different keyed ids'
);
no_reuse( $copy_a, $shard_a, $shard_b, "map-shard-$shard", 2, 32, 0,
    'different shard plaintexts never share a nonce after state restore' );
ok( substr( $map_a, 0, 32 ) eq unb32( $head_a2->{'map'}{'id'} )
        and substr( $shard_a, 0, 32 ) eq unb32( $shard_a_desc->{'id'} ),
    'map and shard exteriors carry the ids stored in their descriptors'
);

AMOS7::N7FS::Seal::_context( $copy_b, $holder_b, 1 );
my $head_name = AMOS7::N7FS::Seal::_head_name($copy_b);
write_file( "$sub_a/$head_name", $head_b );
refused(
    sub { AMOS7::N7FS::Seal::_context( $copy_b, $holder_a, 1 ) },
    qr|head belongs to another holder|,
    'a head served by the wrong known holder is refused'
);
write_file( "$sub_a/$head_name", $head_a );
ok( !reservations($copy_b),
          'successful commits remove every '
        . 'reservation at or below the state version' );

my $holder_c = "$base/holder-c";
seal_to( $root, $holder_c, $addresses[2] );
my ( $head_c1, $sub_c ) = current_head( $root, $holder_c );
$now = 10;
seal_to( $root, $holder_c, $addresses[3] );
my ( $head_c2, undef ) = current_head( $root, $holder_c );
ok( $head_c1->{'holder'} eq $head_c2->{'holder'}
        and $head_c2->{'time'} == $head_c1->{'time'} + 1,
    'a clock set back never lowers signed head time and holder id persists'
);
my $state = AMOS7::N7FS::Seal::_state_read($root);
ok( ( $state->{'holders'}{ $head_c2->{'holder'} }{'time'} // 0 )
        == $head_c2->{'time'}
        and ( $state->{'last_time'} // 0 ) == $head_c2->{'time'},
    'home state tracks holder version and signed time'
);

$now = $head_c2->{'time'} + 123;
my $recovered = AMOS7::N7FS::Seal::seal_recover(
    qw| root |   => $root,
    qw| holder | => $holder_c,
    qw| target | => "$base/recovered",
);
ok( $recovered->{'head_age'} == 123
        and $recovered->{'head_time'} == $head_c2->{'time'},
    'recovery reports the signed head age'
);

open( my $cli_pass, '<:raw', $pass ) or die $OS_ERROR;
my ( $in, $out, $err ) = ( undef, undef, gensym );
my $pid = open3(
    $in,            $out,
    $err,           "$FindBin::Bin/../n7fs",
    '-pass-fd',     fileno($cli_pass),
    '-root-key',    "$base/root.key",
    '-from',        $holder_c,
    'seal-recover', "$base/cli-recovered"
);
close $in;
my $stdout = do { local $INPUT_RECORD_SEPARATOR; <$out> }
    // '';
my $stderr = do { local $INPUT_RECORD_SEPARATOR; <$err> }
    // '';
waitpid $pid, 0;
ok( ( $CHILD_ERROR >> 8 ) == 0
        && $stdout =~ m|head 3, age \d+Y[0-7](?: \d+Y[0-7])?|,
    'seal-recover prints the head age'
) or say "$stdout$stderr";

refused(
    sub {
        AMOS7::N7FS::Seal::seal_bytes( $root->{'keys'}, 'x', 'map-typo',
            'W' x 32, 1 );
    },
    qr|unknown long-key domain|,
    'an unknown seal domain is refused'
);
refused(
    sub {
        AMOS7::N7FS::Seal::open_sealed_bytes( $root->{'keys'}, 'X' x 16,
            'vector', 'W' x 32, 1 );
    },
    qr|unknown long-key domain|,
    'an unknown open domain is refused'
);

my $old_form = read_file("$sub_c/$head_name");
substr( $old_form, 24, 16 ) = '';
my $old_sealed = substr( $old_form, 0, -69 );
$old_form
    = $old_sealed
    . "P7SH\x01"
    . $root->{'signer'}
    ->sign( "p7 n7fs sealed head exterior v1\0" . $old_sealed );
write_file( "$sub_c/$head_name", $old_form );
refused(
    sub { AMOS7::N7FS::Seal::_head_open( $root, $sub_c, 1 ) },
    qr|outer authentication failed|,
    'the old id-less head form is refused'
);

done();

#,,.,,..,,..,,,,.,,.,,.,.,.,.,,.,,,..,..,,..,,..,,...,...,..,,,,.,,,,,,,,,,.,,
#2RJ4ID4IFVYN327K2JMMNH2JYUXEWX2ELLVMNN7KE6Y7NNK6BWRB4CULHH456ROOSZ4MC4YJGKHGY
#\\\|6F6FZABVF2BDHUZDA42UCTZIEXR7TCFONRCTQ6F4ZCZBWV4P436 \ / AMOS7 \ YOURUM ::
#\[7]LR6SAJ4QNOX6ZASA5QY32UT5UXM3IKLMAKWMSL7OWAXZ3VNVNMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
