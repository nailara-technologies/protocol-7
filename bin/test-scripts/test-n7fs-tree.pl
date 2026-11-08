#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## tree manifests, verified restore and category policy tests. all disks and
## sources are below one fresh File::Temp directory.

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use JSON::PP;
use Time::HiRes ();
use AMOS7::N7FS qw| read_file b32 unb32 signed_record_pack signed_record_parse
    make_dirs remove_tree |;
use AMOS7::N7FS::Sign  qw| key_file_write key_file_signer |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach disk_read_id state_read |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes store_repair |;
use AMOS7::N7FS::Journal qw| journal_replay |;
use AMOS7::N7FS::Tree qw| tree_list tree_live_addresses tree_drop tree_restore
    manifest_open manifest_entry_read |;
use AMOS7::N7FS::Category qw| category_set category_list category_report
    category_set_reference |;
use AMOS7::N7FS::Release qw| release_node store_reclaim |;
use AMOS7::N7FS::Record  qw| record_write |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";
use constant TRUE => 5;

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $host = key_file_write("$hdir/host.key");
my %base = ( root => $root, host_dir => $hdir );
clock_real();
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'tree-test',
    intent => 'tree and category tests'
);
my %run = ( %base, disk => $disk, host => $host );
disk_attach(%run);
my $id    = disk_read_id( %base, disk => $disk );
my $dpath = "$root/$disk";
my $store = key_file_signer("$hdir/stores/$disk.store.key");

sub cli_n7fs {
    my @args = @ARG;
    my $out  = "$box->{'base'}/cli.stdout";
    my $err  = "$box->{'base'}/cli.stderr";
    my $pid  = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out ) or exit 98;
        open( STDERR, '>:raw', $err ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args )
            or exit 99;
    }
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file($out), read_file($err) );
}

sub manifest_entries {
    my ( $tree, $reader ) = @ARG;
    $reader //= $id;
    my $state = state_read( $reader->{'path'} );
    my ( $fh, $head ) = manifest_open( $reader, $state, $tree );
    my @entries;
    while ( my $entry = manifest_entry_read($fh) ) {
        push @entries, $entry;
    }
    close $fh;
    return ( $head, \@entries );
}

sub by_path {
    my ( $entries, $path ) = @ARG;
    my ($entry) = grep {
        my $decoded = $ARG->{'p'} eq '' ? '' : unb32( $ARG->{'p'} );
        defined $decoded and $decoded eq $path;
    } @{$entries};
    return $entry;
}

say ':: manifest entry types, raw octets and verified restore';
my $tree_src = "$src/tree";
make_dirs("$tree_src/empty");
write_file( "$tree_src/one", "one\n" );
link "$tree_src/one", "$tree_src/hard" or die "hardlink : $OS_ERROR";
symlink 'one', "$tree_src/sym" or die "symlink : $OS_ERROR";
my $raw_name = "raw-\xFF-\x80";
write_file( "$tree_src/$raw_name", "raw bytes\n" );
chmod 04751, "$tree_src/one";
chmod 0700,  "$tree_src/empty";
my $mtime = 1700000123;
utime $mtime, $mtime, "$tree_src/one";
utime $mtime, $mtime, "$tree_src/hard";
utime $mtime, $mtime, "$tree_src/empty";
my $fifo = "$tree_src/fifo";
system( qw| mkfifo |, $fifo ) == 0 or die 'mkfifo failed';
Time::HiRes::utime( $mtime + 0.1318, $mtime + 0.1318, "$tree_src/one" );
Time::HiRes::utime( $mtime + 0.1318, $mtime + 0.1318, "$tree_src/hard" );
Time::HiRes::utime( $mtime + 0.2718, $mtime + 0.2718, $tree_src );
chmod 0555, $tree_src;
my $time_omitted = {};
AMOS7::N7FS::Tree::_restore_time( "$tree_src/sym",
    { mtime => $mtime, mtime_ns => 331800000 },
    $time_omitted, 1 );
my $xattr_supported
    = AMOS7::N7FS::Tree::_write_xattr( "$tree_src/one", 'user.n7fs_test',
    "x\0y" );
my $r = assimilate( %run, paths => [$tree_src], tree => 'sample' );
ok( $r->{'failed'} == 0 && $r->{'tree'}{'address'},
    'assimilate -tree stores files and a manifest node'
);
ok( 1 == scalar( grep { $ARG eq 'fifo' } $r->{'tree'}{'skipped'}->@* ),
    'a fifo is listed as a skipped tree entry' );
my $state  = state_read($dpath);
my $replay = journal_replay($id);
my ($tree) = tree_list( $id, $state, $replay );
my ( $head, $entries ) = manifest_entries($tree);
my %types = map { $ARG->{'t'} => 1 } @{$entries};
ok( 5 == keys %types && grep { $ARG eq $_ }
        qw| file dir symlink hardlink skipped |,
    'manifest contains file, directory, symlink, hardlink and skipped types'
);
my $raw_entry = by_path( $entries, $raw_name );
ok( defined $raw_entry && unb32( $raw_entry->{'p'} ) eq $raw_name,
    'a non-utf-8 name round-trips as exact octets' );
ok( by_path( $entries, 'empty' )->{'t'} eq 'dir',
    'an empty directory is a manifest entry'
);
ok( by_path( $entries, 'one' )->{'t'} eq 'hardlink'
        && unb32( by_path( $entries, 'one' )->{'h'} ) eq 'hard',
    'a hardlink names the earlier manifest path'
);
ok( by_path( $entries, 'one' )->{'mode'} == 04751
        && by_path( $entries, 'one' )->{'mtime'} == $mtime,
    'mode and whole-second mtime are recorded exactly'
);
ok( $xattr_supported
    ? defined by_path( $entries, 'one' )->{'xattrs'}
    : !exists by_path( $entries, 'one' )->{'xattrs'},
    'xattrs are recorded when available and absent otherwise'
);
ok( substr( read_file("$tree_src/$raw_name"), 0, 4 ) eq 'raw ',
    'the source raw name remains readable by bytes'
);
ok( store_verify( %base, disk => $disk )->{'trees'} == 1,
    'verify authenticates the manifest and signed tree record'
);
my $target   = "$box->{'base'}/restored";
my $restored = tree_restore(
    %base,
    disk   => $disk,
    name   => 'sample',
    target => "$target/"
);
ok( $restored->{'files'} == 3 && -d "$target/empty",
    'restore reports all regular files and creates the empty directory' );
ok( read_file("$target/one") eq "one\n"
        && read_file("$target/$raw_name") eq "raw bytes\n",
    'restored file content and raw names match by bytes'
);
ok( ( ( stat "$target/one" )[2] & 07777 ) == 0751
        && ( stat "$target/one" )[9] == $mtime,
    'restore applies file mode and mtime'
);
ok( ( ( stat "$target/empty" )[2] & 07777 ) == 0700
        && ( stat "$target/empty" )[9] == $mtime,
    'restore applies directory mode and mtime after its contents'
);
ok( ( stat "$target/one" )[1] == ( stat "$target/hard" )[1],
    'restore recreates hardlinks' );
ok( readlink("$target/sym") eq 'one', 'restore recreates the symlink last' );
my @file_time = Time::HiRes::lstat("$target/one");
my @root_time = Time::HiRes::lstat($target);
my @sym_time  = Time::HiRes::lstat("$target/sym");
ok( int( ( $file_time[9] - int $file_time[9] ) * 1000000000 + 0.5 )
        == by_path( $entries, 'one' )->{'mtime_ns'},
    'file sub-second mtime survives without a double-based utime'
);
ok( int( ( $sym_time[9] - int $sym_time[9] ) * 1000000000 + 0.5 )
        == by_path( $entries, 'sym' )->{'mtime_ns'},
    'symlink mtime is restored with AT_SYMLINK_NOFOLLOW'
);
ok( ( ( $root_time[2] & 07777 ) == 0555 )
        && int( ( $root_time[9] - int $root_time[9] ) * 1000000000 + 0.5 )
        == by_path( $entries, '' )->{'mtime_ns'},
    'read-only root mode and exact root mtime are applied last'
);

if ( $EFFECTIVE_USER_ID != 0 ) {
    my $owner_target  = "$box->{'base'}/owners-unprivileged";
    my $owner_restore = tree_restore(
        %base,
        disk   => $disk,
        name   => 'sample',
        target => $owner_target,
        owners => TRUE
    );
    ok( $owner_restore->{'omitted'}{'owners'} > 0
            && $owner_restore->{'omitted'}{'privileged_modes'} > 0
            && ( ( stat "$owner_target/one" )[2] & 06000 ) == 0,
        'unprivileged -owners counts omitted owners and strips setuid'
    );
} else {
    ok( 1, 'unprivileged -owners assertion not applicable as root' );
}
if ($xattr_supported) {
    my $xattrs = AMOS7::N7FS::Tree::_read_xattrs("$target/one");
    ok( defined $xattrs && $xattrs->{'user.n7fs_test'} eq "x\0y",
        'xattr names and binary values round-trip' );
} else {
    ok( 1, 'xattr restore not available on this source filesystem' );
}
refused(
    sub {
        tree_restore(
            %base,
            disk   => $disk,
            name   => 'sample',
            target => $target
        );
    },
    qr|not empty|,
    'restore refuses an existing nonempty target'
);
my $dry_target = "$box->{'base'}/dry";
my $dry        = tree_restore(
    %base,
    disk    => $disk,
    name    => 'sample',
    target  => $dry_target,
    dry_run => TRUE
);
ok( $dry->{'dry_run'} && !-e $dry_target,
    'dry-run verifies but creates no target'
);
my ( $cli_rc, $cli_out ) = cli_n7fs( 'trees', $disk );
ok( $cli_rc == 0 && $cli_out =~ m|\Asample \S+|,
    'trees lists the live name and manifest address'
);

say ':: forged manifest paths and crash behavior';

sub forged_restore {
    my ( $entries, $name ) = @ARG;
    my $json = JSON::PP->new->utf8->canonical;
    my $bytes
        = $json->encode( { manifest => 1, created => $tree->{'created'} } )
        . "\n";
    $bytes .= $json->encode($ARG) . "\n" for @{$entries};
    my $path = "$box->{'base'}/$name.manifest";
    write_file( $path, $bytes );
    local *AMOS7::N7FS::Tree::tree_list     = sub { return $tree };
    local *AMOS7::N7FS::Tree::manifest_open = sub {
        open( my $fh, '<:raw', $path ) or die "open forged : $OS_ERROR";
        my $line = <$fh>;
        return ( $fh, $json->decode($line) );
    };
    return tree_restore(
        %base,
        disk   => $disk,
        name   => 'sample',
        target => "$box->{'base'}/$name"
    );
}
my $base_entry = {
    p     => b32(''),
    t     => 'dir',
    mode  => 0700,
    uid   => 0,
    gid   => 0,
    mtime => $mtime
};
for my $attack (
    [ absolute => '/etc/n7fs-escape' ],
    [ dotdot   => '../n7fs-escape' ],
) {
    my ( $name, $path ) = @{$attack};
    refused(
        sub {
            forged_restore(
                [ $base_entry, { %{$base_entry}, p => b32($path) } ], $name );
        },
        $name eq 'dotdot' ? qr|unsafe| : qr|absolute|,
        "forged $name path refuses"
    );
}
my $outside = "$box->{'base'}/outside";
make_dirs($outside);
refused(
    sub {
        forged_restore(
            [   $base_entry,
                {   %{$base_entry},
                    p => b32('a'),
                    t => 'symlink',
                    l => b32($outside)
                },
                {   %{$base_entry},
                    p => b32('a/evil'),
                    t => 'symlink',
                    l => b32('x')
                },
            ],
            'symlink-escape'
        );
    },
    qr|symlink parent|,
    'a symlink followed by a child symlink cannot escape the restore root'
);
refused(
    sub {
        forged_restore(
            [   $base_entry,
                {   %{$base_entry},
                    p => b32('a'),
                    t => 'symlink',
                    l => b32($outside)
                },
                {   %{$base_entry},
                    p => b32('b'),
                    t => 'hardlink',
                    h => b32('a/evil')
                },
            ],
            'hardlink-escape'
        );
    },
    qr|symlink parent|,
    'a hardlink target below a manifest symlink refuses'
);
refused(
    sub { forged_restore( [ $base_entry, $base_entry ], 'duplicate' ) },
    qr|duplicate path|,
    'duplicate manifest paths refuse before restore'
);
{
    local $AMOS7::N7FS::FAULT = sub {
        return if $_[0] ne 'restore:before-symlink';
        my ($tmp) = glob "$box->{'base'}/parent-race.tmp.*";
        remove_tree("$tmp/a");
        symlink $outside, "$tmp/a" or die 'parent race fixture';
    };
    refused(
        sub {
            forged_restore(
                [   $base_entry,
                    { %{$base_entry}, p => b32('a'), t => 'dir' },
                    {   %{$base_entry},
                        p => b32('a/evil'),
                        t => 'symlink',
                        l => b32('x')
                    },
                ],
                'parent-race'
            );
        },
        qr|not a real directory|,
        'parent replacement after preflight cannot redirect a symlink'
    );
}
ok( !-e "$outside/evil"
        && !-e '/etc/n7fs-escape'
        && !-e "$box->{'base'}/n7fs-escape",
    'path attacks wrote nothing outside their target'
);
{
    local $AMOS7::N7FS::FAULT = sub {
        die "injected restore crash\n" if $_[0] eq 'restore:before-publish';
    };
    refused(
        sub {
            tree_restore(
                %base,
                disk   => $disk,
                name   => 'sample',
                target => "$box->{'base'}/crash"
            );
        },
        qr|injected restore crash|,
        'an injected crash before publish fails the restore'
    );
}
ok( !-e "$box->{'base'}/crash"
        && !scalar( glob "$box->{'base'}/crash.tmp.*" ),
    'crash cleanup removes a temp tree containing read-only directories'
);

say ':: tampering, unjournaled records and live tree pins';
my $one_addr = by_path( $entries, 'hard' )->{'a'};
my $one_node = AMOS7::N7FS::Tree::_address($one_addr);
my $one_content
    = AMOS7::N7FS::Store::node_path( $dpath, $one_node ) . '/content';
my $content_bytes = read_file($one_content);
chmod 0600, $one_content;
write_file( $one_content, 'bad' );
refused(
    sub { store_verify( %base, disk => $disk ) },
    qr|content does not match|,
    'a corrupted content node fails verify'
);
write_file( $one_content, $content_bytes );
chmod 0444, $one_content;
my $tree_file  = $tree->{'full_path'};
my $tree_bytes = read_file($tree_file);
substr( $tree_bytes, -1, 1 ) = chr( ord( substr( $tree_bytes, -1, 1 ) ) ^ 1 );
chmod 0600, $tree_file;
write_file( $tree_file, $tree_bytes );
refused(
    sub { store_verify( %base, disk => $disk ) },
    qr|store signature does not verify|,
    'a tampered tree record fails verify'
);
my $tree_payload = signed_record_parse( 'tree', $tree_bytes )->{'payload'};
write_file( $tree_file,
    signed_record_pack( 'tree', $tree_payload, $store, 3 ) );
my $fresh = record_write(
    $id, $store, 'tree', 'trees', 'tree',
    {   disk     => $disk,
        name     => 'unjournaled',
        manifest => $tree->{'manifest'},
        created  => $tree->{'created'}
    }
);
refused(
    sub { store_verify( %base, disk => $disk ) },
    qr|unlisted tree record|,
    'an unjournaled signed tree record fails verify'
);
unlink $fresh->{'full_path'} or die 'remove unjournaled tree';
ok( store_verify( %base, disk => $disk ),
    'restored signed tree record verifies'
);
refused(
    sub { release_node( %run, address => $one_addr ) },
    qr|live references or trees.*tree:sample|s,
    'release refuses while a tree holds a node'
);
my $reclaim = store_reclaim( %run, dry_run => TRUE );
ok( !scalar(
        grep { $ARG->{'address'} eq $one_addr } $reclaim->{'released'}->@*
    ),
    'reclaim does not select a tree-held node'
);
my $held = tree_live_addresses( $id, $state, journal_replay($id) );
ok( $held->{$one_addr}{'sample'} && $held->{ $tree->{'manifest'} }{'sample'},
    'trees pin both file content and their own manifest node'
);

say ':: category versions, assignments and effective policy';
my $cat1 = category_set(
    %run,
    name     => 'work',
    copies   => 2,
    priority => 4,
    want     => ['laptop']
);
my $cat2 = category_set(
    %run,
    name             => 'work',
    copies           => 3,
    local_encryption => 'cascade'
);
my @definitions = category_list( $id, journal_replay($id) );
ok( @definitions == 3
        && $definitions[2]->{'copies'} == 3
        && $definitions[2]->{'priority'} == 4
        && $definitions[2]->{'local_encryption'} eq 'cascade',
    'category versions retain fields and latest definition wins'
);
ok( 2 == keys journal_replay($id)->{'category_history'}->%*,
    'category history keeps both signed versions'
);
category_set(
    %run,
    name         => 'strict',
    copies       => 7,
    priority     => 9,
    replica      => 'full',
    foreign_work => 'no',
    layer        => 'private',
    want         => ['archive']
);
my $same_a = write_file( "$src/same-a", 'same bytes' );
my $same_b = write_file( "$src/same-b", 'same bytes' );
assimilate( %run, paths => [$same_a], category => 'work' );
assimilate( %run, paths => [$same_b], category => 'strict' );
my $report_replay = journal_replay($id);
my ($same_ref)
    = grep { $ARG->{'holder'} eq $same_a }
    values $report_replay->{'references'}->%*;
my $report = category_report( $id, $report_replay, $same_ref->{'node'} );
ok( 2 == $report->{'references'}->@*
        && $report->{'effective'}{'copies'} == 7
        && $report->{'effective'}{'priority'} == 9
        && $report->{'effective'}{'local_encryption'} eq 'cascade'
        && join( ',', $report->{'effective'}{'want'}->@* ) eq 'archive,'
        . 'laptop',
    'effective policy is strictest over deduplicated references'
);
category_set_reference(
    %run,
    target   => $same_ref->{'node'},
    category => 'work'
);
$report = category_report( $id, journal_replay($id), $same_ref->{'node'} );
ok( 2 == scalar(
        grep { $ARG->{'category'} eq 'work' } $report->{'references'}->@*
    ),
    'later per-reference assignments supersede earlier ones'
);
my $rule_file = write_file( "$src/rule-file", 'rule bytes' );
assimilate(
    %run,
    paths          => [$rule_file],
    category_rules => [ '*=strict', '*=work' ]
);
my ($rule_ref)
    = grep { $ARG->{'holder'} eq $rule_file }
    values journal_replay($id)->{'references'}->%*;
my $rule_report
    = category_report( $id, journal_replay($id), $rule_ref->{'node'} );
ok( $rule_report->{'references'}[0]{'category'} eq 'strict',
    'the first matching category-rule wins' );
my $before_unknown = snapshot( $root, $hdir );
refused(
    sub { assimilate( %run, paths => [$same_a], category => 'missing' ) },
    qr|unknown category|,
    'an unknown assimilate category refuses'
);
refused(
    sub {
        category_set_reference(
            %run,
            target   => $same_ref->{'node'},
            category => 'missing'
        );
    },
    qr|unknown category|,
    'an unknown set-category name refuses'
);
ok( snap_equal( $before_unknown, snapshot( $root, $hdir ) ),
    'unknown categories change nothing' );
( $cli_rc, $cli_out ) = cli_n7fs( 'category', $disk, 'list' );
ok( $cli_rc == 0
        && $cli_out =~ m|default local-encryption=none|
        && $cli_out =~ m|work local-encryption=cascade copies=3|,
    'category list shows the built-in default and stored versions'
);
( $cli_rc, $cli_out )
    = cli_n7fs( 'category', $disk, 'set', 'notice',
    '-local-encryption', 'cascade' );
ok( $cli_rc == 0 && $cli_out =~ m|stored policy only ; no encryption|,
    'cascade output says it is not enforced yet' );

say ':: tree drop releases pins but removes no bytes';
my $before_drop = read_file($one_content);
my $dropped     = tree_drop( %run, name => 'sample' );
ok( $dropped->{'seq'}
        && !journal_replay($id)->{'trees'}{'sample'}
        && read_file($one_content) eq $before_drop,
    'tree-drop is journaled and removes no content bytes'
);
my @one_holders = map { $ARG->{'holder'} }
    grep { $ARG->{'node'} eq $one_addr and not $ARG->{'dropped'} }
    values journal_replay($id)->{'references'}->%*;
AMOS7::N7FS::Store::reference_drop(
    %run,
    address => $one_addr,
    holder  => $ARG
) for @one_holders;
my $released = release_node( %run, address => $one_addr );
ok( $released->{'seq'} && !-e $one_content,
    'after tree-drop and reference drops, release can remove the node' );
ok( store_verify( %base, disk => $disk ), 'the final store verifies' );
assimilate( %run, paths => [$tree_src], tree => 'sample' );
my $forced = release_node( %run, address => $one_addr, force => TRUE );
ok( 1 == $forced->{'trees'}->@*
        && $forced->{'trees'}[0] eq 'sample'
        && !journal_replay($id)->{'trees'}{'sample'},
    'forced release journals a drop for every tree holding the node'
);
ok( store_verify( %base, disk => $disk ),
    'forced release of tree-held content leaves a verifying store' );

say ':: incomplete sources still complete a verifiable tree';
my $problem_disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'tree-problems',
    intent => 'source skip tests'
);
my %problem_run = ( %base, disk => $problem_disk, host => $host );
disk_attach(%problem_run);
my $problem_id  = disk_read_id( %base, disk => $problem_disk );
my $problem_src = "$src/problems";
make_dirs("$problem_src/unreadable-dir");

for my $name (qw| good changed vanished unreadable appeared |) {
    write_file( "$problem_src/$name", "$name\n" ) if $name ne 'appeared';
}
write_file( "$problem_src/unreadable-dir/inside", 'inside' );
chmod 0000, "$problem_src/unreadable";
chmod 0000, "$problem_src/unreadable-dir";
{
    local $AMOS7::N7FS::FAULT = sub {
        return if $_[0] ne 'tree:before-walk';
        write_file( "$problem_src/changed", "changed after import\n" );
        unlink "$problem_src/vanished" or die 'vanish fixture';
        write_file( "$problem_src/appeared", "appeared\n" );
    };
    my $problems = assimilate(
        %problem_run,
        paths => [$problem_src],
        tree  => 'problems'
    );
    ok( $problems->{'failed'} > 0
            && $problems->{'tree'}{'skipped_errors'} == 5
            && $problems->{'tree'}{'address'},
        'changed, vanished, unreadable, appeared and directory errors count'
    );
}
ok( store_verify( %base, disk => $problem_disk ),
    'ordinary source failures leave no unjournaled imports'
);
my $problem_replay = journal_replay($problem_id);
my ($problem_tree)
    = tree_list( $problem_id, state_read("$root/$problem_disk"),
    $problem_replay );
my ( undef, $problem_entries )
    = manifest_entries( $problem_tree, $problem_id );
for my $name (qw| changed vanished unreadable appeared unreadable-dir |) {
    my $entry = by_path( $problem_entries, $name );
    ok( defined $entry
            && $entry->{'t'} eq 'skipped'
            && length $entry->{'why'},
        "$name is a named skipped manifest entry"
    );
}
my $problem_target  = "$box->{'base'}/problem-restored";
my $problem_restore = tree_restore(
    %base,
    disk   => $problem_disk,
    name   => 'problems',
    target => $problem_target
);
ok( read_file("$problem_target/good") eq "good\n"
        && !-e "$problem_target/changed"
        && !-e "$problem_target/appeared",
    'restore completes good content without materializing skipped sources'
);
chmod 0700, "$problem_src/unreadable-dir";
my $before_duplicate = snapshot( $root, $hdir );
refused(
    sub {
        assimilate(
            %problem_run,
            paths => [$problem_src],
            tree  => 'problems'
        );
    },
    qr|duplicate live tree|,
    'duplicate tree refusal happens before another import'
);
ok( snap_equal( $before_duplicate, snapshot( $root, $hdir ) ),
    'duplicate tree refusal changes no store state'
);
chmod 0000, "$problem_src/unreadable-dir";
( $cli_rc, $cli_out ) = cli_n7fs(
    'assimilate',  '-disk', $problem_disk, '-tree',
    'problem-cli', $problem_src
);
ok( $cli_rc != 0 && $cli_out =~ m|skipped source errors 2|,
    'CLI prints the skipped count and returns nonzero after completing'
);
chmod 0700, "$problem_src/unreadable-dir";
ok( store_verify( %base, disk => $problem_disk ),
    'the nonzero CLI assimilation still verifies'
);

say ':: unjournaled records quarantine, retry and restore';
for my $case (
    [ tree       => 'tree:after-record' ],
    [ category   => 'category:after-record' ],
    [ assignment => 'assignment:after-record' ],
    [ tree_drop  => 'tree-drop:after-record' ],
    [ journal    => 'journal:before-write' ],
) {
    my ( $kind, $point ) = @{$case};
    my $case_disk = disk_init(
        %base,
        parent => test_signer(),
        name   => "crash-$kind",
        intent => 'record crash repair'
    );
    my %case_run = ( %base, disk => $case_disk, host => $host );
    disk_attach(%case_run);
    my $case_id  = disk_read_id( %base, disk => $case_disk );
    my $case_src = "$src/crash-$kind";
    make_dirs($case_src);
    write_file( "$case_src/file", "$kind content\n" );
    assimilate( %case_run, paths => [$case_src], tree => 'sample' );
    category_set( %case_run, name => 'work' ) if $kind eq 'assignment';
    my ($case_ref) = values journal_replay($case_id)->{'references'}->%*;
    my $operation = sub {
        return assimilate( %case_run, paths => [$case_src], tree => 'crash' )
            if $kind eq 'tree' or $kind eq 'journal';
        return category_set( %case_run, name => 'crashed' )
            if $kind eq 'category';
        return assimilate(
            %case_run,
            paths    => [$case_src],
            category => 'work'
        ) if $kind eq 'assignment';
        return tree_drop( %case_run, name => 'sample' );
    };
    {
        local $AMOS7::N7FS::FAULT = sub {
            die "injected $kind crash\n" if $_[0] eq $point;
        };
        refused(
            $operation,
            qr|injected .* crash|,
            "$kind crash injected between record and journal"
        );
    }
    refused( sub { store_verify( %base, disk => $case_disk ) },
        qr|unlisted|, "$kind crash is loud before repair" );
    my $repair = store_repair(%case_run);
    ok( 1 == $repair->{'quarantined'}->@*
            && -f $repair->{'quarantined'}[0]{'quarantine'},
        "$kind unjournaled record is kept in quarantine"
    );
    ok( store_verify( %base, disk => $case_disk ),
        "$kind verify passes after quarantine"
    );
    $operation->();
    ok( store_verify( %base, disk => $case_disk ),
        "$kind retry verifies without adopting the quarantined record" );
    if ( $kind eq 'tree_drop' ) {
        refused(
            sub {
                tree_restore(
                    %base,
                    disk   => $case_disk,
                    name   => 'sample',
                    target => "$box->{'base'}/restore-$kind"
                );
            },
            qr|no live tree|,
            'tree-drop retry leaves no live tree to restore'
        );
    } else {
        my $restore_name
            = ( $kind eq 'tree' or $kind eq 'journal' ) ? 'crash' : 'sample';
        my $case_restore = tree_restore(
            %base,
            disk   => $case_disk,
            name   => $restore_name,
            target => "$box->{'base'}/restore-$kind"
        );
        ok( read_file("$box->{'base'}/restore-$kind/file") eq
                "$kind content\n",
            "$kind verify-repair-verify-retry-verify chain restores"
        );
    }
}

say ':: large xattr lists and explicit attribute failures';
if ($xattr_supported) {
    my $many    = write_file( "$src/many-xattrs", 'attrs' );
    my $written = 0;
    for my $n ( 0 .. 79 ) {
        my $name = sprintf 'user.n7fs_%02d_%s', $n, 'x' x 70;
        $written++ if AMOS7::N7FS::Tree::_write_xattr( $many, $name, 'v' );
    }
    my ( $attrs, $errors ) = AMOS7::N7FS::Tree::_read_xattrs($many);
    ok( $written == 80 && keys( %{$attrs} ) == 80 && !@{$errors},
        'an xattr name list larger than 4096 bytes is fully read'
    );
    my @st = Time::HiRes::lstat($many);
    $st[13] = $many;
    my $stats = { xattr_errors => 0 };
    {
        local *AMOS7::N7FS::Tree::_read_xattrs = sub {
            return (
                {},
                [
                    {   name => 'user.bad',
                        why  => 'injected read error'
                    }
                ]
            );
        };
        my $entry = AMOS7::N7FS::Tree::_source_stat( \@st, $stats );
        ok( $entry->{'xattr_errors'}[0]{'why'} eq 'injected read error'
                && $stats->{'xattr_errors'} == 1,
            'a specific xattr read failure is recorded and counted'
        );
    }
} else {
    ok( 1, 'large xattr list not supported here' );
    ok( 1, 'xattr error reporting not supported here' );
}

## the cli path of repair : nothing adopted must still report and exit clean
( $cli_rc, $cli_out ) = cli_n7fs( 'repair', $disk );
ok( $cli_rc == 0 && $cli_out =~ m|repair|,
    'cli repair with nothing to adopt'
);

done();

#,,,.,...,.,,,,..,,.,,.,.,,,.,..,,.,,,...,..,,..,,...,...,..,,.,.,,,,,,.,,.,.,
#2MNNJNJFPW6HUKUTIZ6EY4HSB7WUDDMJYY25EFCCSL7ALUMXO6GYDAGBIN2JFAMB6LKLOSDAGAMPY
#\\\|YN5VFWOYZ642PZBNY3GEL4XQOQ3VFXFMGYQDPXKPJWRRCZTBOU6 \ / AMOS7 \ YOURUM ::
#\[7]CKOO6HKUMTXS3H45AFJHRQJ7QHEEETZNNDWOYHS2SDAJSFWEBUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
