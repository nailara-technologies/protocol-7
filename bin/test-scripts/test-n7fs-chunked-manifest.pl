#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::N7FS        qw| read_file write_new_file unb32 make_dirs |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach |;
use AMOS7::N7FS::Store qw| assimilate |;
use AMOS7::N7FS::Keys  qw| root_init root_open |;
use AMOS7::N7FS::Seal;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'}       = 0;
$ENV{'N7FS_TEST_MANIFEST_ENTRIES'} = 1;
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
    qw| name |     => 'chunked-manifest',
    qw| intent |   => 'sandbox only',
);
disk_attach(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $signer,
);
make_dirs("$box->{'src'}/a");
make_dirs("$box->{'src'}/b");
write_new_file( "$box->{'src'}/a/file", "first a\n" );
write_new_file( "$box->{'src'}/b/file", "same b\n" );
my $holder = "$base/holder";

sub import_tree {
    my $name = shift;
    return assimilate(
        qw| root |           => $box->{'root'},
        qw| host_dir |       => $box->{'host'},
        qw| disk |           => $disk,
        qw| host |           => $signer,
        qw| paths |          => [ $box->{'src'} ],
        qw| tree |           => $name,
        qw| remove |         => 0,
        qw| category_rules | => [],
        qw| protect |        => [],
    );
}

sub seal_trees {
    return AMOS7::N7FS::Seal::seal_nodes(
        qw| root |      => $root,
        qw| holder |    => $holder,
        qw| disk |      => $disk,
        qw| disk_root | => $box->{'root'},
        qw| host_dir |  => $box->{'host'},
        qw| addresses | => [],
        qw| trees |     => \@ARG,
    );
}

sub current_map {
    my ( undef, undef, $map, $sub )
        = AMOS7::N7FS::Seal::_context( $root, $holder, 1 );
    return ( $map, $sub );
}

import_tree('one');
seal_trees('one');
import_tree('two');
seal_trees('two');
my ( $first, $sub ) = current_map();
my $one = $first->{'trees'}{'one'};
my $two = $first->{'trees'}{'two'};
ok( @{ $one->{'chunks'} } >= 3
        && ref $one->{'index'} eq 'HASH'
        && !exists $first->{'nodes'}{ $one->{'manifest'} },
    'a tree is an index plus directory chunks, not a sealed manifest node'
);
ok( join( ' ', map { $ARG->{'blob'} } @{ $one->{'chunks'} } ) eq
        join( ' ', map { $ARG->{'blob'} } @{ $two->{'chunks'} } ),
    'identical directories share content-addressed chunks across trees'
);

my ( $left, $right ) = @{ $one->{'chunks'} }[ 0, 1 ];
my $left_bytes  = read_file("$sub/$left->{'blob'}");
my $right_bytes = read_file("$sub/$right->{'blob'}");
my $left_open   = eval {
    AMOS7::N7FS::Seal::open_sealed_bytes(
        $root->{'keys'},
        substr( $left_bytes, 16 ),
        qw| manifest-chunk |,
        unb32( $left->{'id'} ),
        $left->{'version'}
    );
};
my $wrong_open = eval {
    AMOS7::N7FS::Seal::open_sealed_bytes(
        $root->{'keys'},
        substr( $left_bytes, 16 ),
        qw| manifest-chunk |,
        unb32( $right->{'id'} ),
        $left->{'version'}
    );
};
ok( defined $left_open
        && !defined $wrong_open
        && $left->{'id'} ne $right->{'id'}
        && $left->{'version'} == $right->{'version'},
    'same-commit chunks have distinct checksum ids and nonces'
);

write_file( "$box->{'src'}/a/file", "second a\n" );
require AMOS7::N7FS::Tree;
AMOS7::N7FS::Tree::tree_drop(
    qw| root |     => $box->{'root'},
    qw| host_dir | => $box->{'host'},
    qw| disk |     => $disk,
    qw| host |     => $signer,
    qw| name |     => 'one',
);
import_tree('one');
my @manifest_writes;
{
    my $original = \&AMOS7::N7FS::Seal::_write_blob;
    no warnings qw| redefine |;
    local *AMOS7::N7FS::Seal::_write_blob = sub {
        push @manifest_writes, $ARG[2] if $ARG[3] eq 'manifest';
        return $original->(@ARG);
    };
    seal_trees('one');
}
my ($second)    = current_map();
my $new_one     = $second->{'trees'}{'one'};
my %old_by_path = map { $ARG->{'path'} => $ARG } @{ $one->{'chunks'} };
my %new_by_path = map { $ARG->{'path'} => $ARG } @{ $new_one->{'chunks'} };
ok( @manifest_writes == 2
        && $old_by_path{'a'}{'blob'} ne $new_by_path{'a'}{'blob'}
        && $old_by_path{'b'}{'blob'} eq $new_by_path{'b'}{'blob'}
        && $second->{'trees'}{'two'}{'index'}{'blob'} eq
        $two->{'index'}{'blob'},
    'one changed directory uploads exactly one chunk and a new index'
);

AMOS7::N7FS::Seal::unmap_nodes(
    qw| root |       => $root,
    qw| holder |     => $holder,
    qw| addresses |  => [],
    qw| live_trees | => ['two'],
    qw| tree_files | => {},
);
AMOS7::N7FS::Seal::holder_gc(
    qw| root |   => $root,
    qw| holder | => $holder,
    qw| delete | => 1,
    qw| grace |  => 0,
);
my ($shared) = current_map();
my @shared_names
    = AMOS7::N7FS::Seal::_manifest_blob_names( $shared->{'trees'}{'two'} );
ok( !exists $shared->{'trees'}{'one'}
        && !( grep { !-e "$sub/$ARG" } @shared_names ),
    'dropping one tree retains every chunk shared by the remaining tree'
);

my $damaged = $shared->{'trees'}{'two'}{'chunks'}[0];
my $good    = read_file("$sub/$damaged->{'blob'}");
substr( $good, 20, 1 ) = chr( ord( substr( $good, 20, 1 ) ) ^ 1 );
write_file( "$sub/$damaged->{'blob'}", $good );
refused(
    sub {
        AMOS7::N7FS::Seal::seal_recover(
            qw| root |   => $root,
            qw| holder | => $holder,
            qw| tree |   => 'two',
            qw| target | => "$base/damaged-restore",
        );
    },
    qr|blob address mismatch|,
    'a damaged manifest chunk is reported during tree recovery'
);
ok( !-e "$base/damaged-restore",
    'a damaged manifest chunk is never silently skipped' );

refused(
    sub {
        AMOS7::N7FS::Seal::_manifest_read( $root, $sub, undef,
            { qw| manifest | => $one->{'manifest'} } );
    },
    qr|legacy single-blob tree manifest is refused|,
    'the old single-blob manifest form is refused'
);

done();

#,,,.,.,.,,,,,.,,,,..,..,,..,,,.,,.,,,...,,.,,..,,...,...,.,,,.,.,,,.,.,.,,,.,
#2RQYZZJF4E6X3RDGOSPUKJ7YVFQT6W2VBSDNMV4I7FSIKD5LE4WK7AN5EYOG3DCUNSA6EWBM44QAU
#\\\|VDRKU3QPPPYS3WSUTDHWSTOLE3YXH3AKGSIU4HQTGI2R3GFM5UQ \ / AMOS7 \ YOURUM ::
#\[7]3XLOBD7KUJBCXIPF4NKEPYLLSEDUBWRIG5UZZ2CL4A73YGSEISBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
