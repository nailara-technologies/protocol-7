#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS format 3 stage 3 : hard-linked conversion, immutable content and
## assimilate -remove -prune. every disk and source is below File::Temp.

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS       qw| read_file |;
use AMOS7::N7FS::Sum  qw| epoch_b32 epoch_int |;
use AMOS7::N7FS::Sign qw| key_file_write key_file_signer |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_read_id state_read
    state_write |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes store_repair
    codec |;
use AMOS7::N7FS::Convert qw| upgrade confirm release_epoch |;
use AMOS7::N7FS::Release qw| release_node |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";
use constant TRUE  => 5;
use constant FALSE => 0;

my $box  = sandbox();
my $root = $box->{'root'};
my $hdir = $box->{'host'};
my $src  = $box->{'src'};
my $host = key_file_write("$hdir/host.key");
my %base = ( root => $root, host_dir => $hdir );
clock_real();

sub make_dirs {
    my $path  = shift;
    my @parts = split m|/|, $path;
    my $at    = index( $path, '/' ) == 0 ? '' : '.';
    foreach my $part (@parts) {
        next if not length $part;
        $at .= "/$part";
        mkdir $at, 0700 or die "mkdir $at : $OS_ERROR" if not -d $at;
    }
    return $path;
}

sub new_v2 {
    my $name = shift;
    my $disk = disk_init(
        %base,
        parent => test_signer(),
        name   => $name,
        intent => 'n7fs stage 3 tests [ test data ]'
    );
    my %run = ( %base, disk => $disk, host => $host );
    my $p   = state_read("$root/$disk");
    delete $p->{'_name'};
    $p->{'store_format'} = 2;
    state_write( "$root/$disk", $p,
        key_file_signer("$hdir/stores/$disk.store.key") );
    disk_attach(%run);
    return ( $disk, %run );
}

sub one_v2_node {
    my ( $run, $body, $name ) = @ARG;
    my $file = write_file( "$src/$name", $body );
    assimilate( %{$run}, paths => [$file] );
    my $disk = $run->{'disk'};
    my ($old)
        = store_nodes( "$root/$disk",
        state_read("$root/$disk")->{'epochs'}->@* );
    return ( $file, $old );
}

sub linked_pair {
    my ( $run, $old ) = @ARG;
    my $disk = $run->{'disk'};
    my ($new)
        = store_nodes( "$root/$disk",
        state_read("$root/$disk")->{'epochs'}->@* );
    my ( $old_content, $new_content )
        = ( "$old->{'path'}/content", "$new->{'path'}/content" );
    my @os = stat $old_content;
    my @ns = stat $new_content;
    return ( $new, $old_content, $new_content, \@os, \@ns );
}

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

say ':: hard-linked conversion and fallback';
my ( $disk, %run ) = new_v2('linked-main');
my $body = "one inode in two epochs\x00\xff\n" x 20;
my ( $file, $old ) = one_v2_node( \%run, $body, 'linked.bin' );
my $old_epoch = $old->{'epoch'};
my $u         = upgrade( %run, target => 3 );
my ( $new, $old_content, $new_content, $os, $ns )
    = linked_pair( \%run, $old );
ok( $u->{'linked'} == 1 && $u->{'copied'} == 0 && !$u->{'notes'}->@*,
    'same-filesystem conversion reports one linked and zero copied nodes'
);
ok( $os->[0] == $ns->[0] && $os->[1] == $ns->[1] && $ns->[3] == 2,
    'old and new content share st_dev and st_ino with link count two'
);
ok( ( $ns->[2] & 07777 ) == 0444,
    'newly written immutable content has mode 0444' );
ok( read_file($old_content) eq $body && read_file($new_content) eq $body,
    'both linked names read the verified original bytes' );
ok( codec(2)->{'verify_node'}
        ->( $old->{'path'}, $old, { id => disk_read_id(%run) } ),
    'the previous form still verifies inside the conversion window'
);
ok( store_verify(%run)->{'nodes'} == 1,
    'the active form verifies while its previous form is linked' );
confirm(%run);

my $before = snapshot( $old_content, $new_content );
my $other  = write_file( "$src/linked-dedup.bin", $body );
my $dedup  = assimilate( %run, paths => [$other] );
ok( $dedup->{'failed'} == 0
        && snap_equal( $before, snapshot( $old_content, $new_content ) ),
    'assimilation onto an existing linked node adds records, never rewrites'
);
my $repair_before = snapshot( $root, $hdir );
store_repair(%run);
ok( snap_equal( $repair_before, snapshot( $root, $hdir ) ),
    'repair with no crash work never rewrites linked content or records'
);

my $release = release_node(
    %run,
    address => $u->{'nodes'}
    ? do {
        join '/', epoch_b32( $new->{'epoch'} ), $new->{'amos'}, $new->{'bmw'};
        }
    : '',
    force => TRUE
);
ok( scalar( $release->{'copies'}->@* ) == 1,
    'active release still names the previous form holding the linked bytes' );
ok( !-e $new_content
        && ( stat $old_content )[3] == 1
        && read_file($old_content) eq $body,
    'active release drops only one name and the old inode remains readable'
);
ok( store_verify(%run)->{'nodes'} == 0,
    'active release verifies with the previous form outside the active set' );

my ( $copy_disk, %copy_run ) = new_v2('linked-fallback');
my ( undef, $copy_old )
    = one_v2_node( \%copy_run, "copy fallback\n", 'copy-fallback.txt' );
my $copy_u;
{
    local $AMOS7::N7FS::Store::LINK = sub { return 0 };
    $copy_u = upgrade( %copy_run, target => 3 );
}
my ( undef, $copy_old_content, $copy_new_content, $cos, $cns )
    = linked_pair( \%copy_run, $copy_old );
ok( $copy_u->{'copied'} == 1
        && $copy_u->{'linked'} == 0
        && $copy_u->{'notes'}->@* == 1,
    'a failed link falls back per node and records a counted note'
);
ok( $cos->[1] != $cns->[1]
        && read_file($copy_new_content) eq "copy fallback\n"
        && ( $cns->[2] & 07777 ) == 0444,
    'fallback creates an independent, read-only, verified content file'
);
confirm(%copy_run);
my $copy_state     = state_read("$root/$copy_disk");
my $copy_new_epoch = $copy_state->{'epochs'}[0];
my $copy_old_nlink = ( stat $copy_old_content )[3];
release_epoch( %copy_run, epoch => $copy_old->{'epoch'}, now => TRUE );
ok( !-e $copy_old_content
        && -e $copy_new_content
        && ( stat $copy_new_content )[3] == 1,
    'release-epoch removes only previous directory entries on copy fallback'
);
ok( store_verify(%copy_run)->{'nodes'} == 1,
    'active content verifies after previous epoch release' );

my ( $device_disk, %device_run ) = new_v2('different-device');
one_v2_node( \%device_run, 'different device', 'different-device.txt' );
my $device_u = do {
    local $AMOS7::N7FS::Store::DEVICE = sub {
        return $ARG[0] =~ m|/content\z| ? 1 : 2;
    };
    upgrade( %device_run, target => 3 );
};
ok( $device_u->{'linked'} == 0
        && $device_u->{'copied'} == 1
        && $device_u->{'notes'}[0] =~ m|different filesystem|
        && store_verify(%device_run)->{'nodes'} == 1,
    'different st_dev forces counted copy fallback without calling link'
);

my ( $epoch_disk, %epoch_run ) = new_v2('linked-epoch-release');
my $epoch_body = "linked epoch release\n";
my ( undef, $epoch_old )
    = one_v2_node( \%epoch_run, $epoch_body, 'epoch-release.txt' );
upgrade( %epoch_run, target => 3 );
confirm(%epoch_run);
my ( $epoch_new, $epoch_old_content, $epoch_new_content )
    = linked_pair( \%epoch_run, $epoch_old );
ok( ( stat $epoch_new_content )[3] == 2,
    'epoch release fixture starts with two links'
);
release_epoch( %epoch_run, epoch => $epoch_old->{'epoch'}, now => TRUE );
ok( !-e $epoch_old_content
        && ( stat $epoch_new_content )[3] == 1
        && read_file($epoch_new_content) eq $epoch_body,
    'release-epoch drops the old link while active bytes stay readable'
);
ok( store_verify(%epoch_run)->{'nodes'} == 1,
    'linked active content verifies after previous epoch release' );

say ':: link and copy crash points';
foreach my $point (
    qw| convert:before-link convert:after-link
    convert:before-copy convert:after-copy |
) {
    my ( $cdisk, %crun ) = new_v2("crash-$point");
    my ( undef, $cold )
        = one_v2_node( \%crun, "crash $point\n", "crash-$point.txt" );
    my $old_content = "$cold->{'path'}/content";
    my $inject      = sub {
        local $AMOS7::N7FS::Store::LINK = sub { return 0 }
            if $point =~ m|copy|;
        local $AMOS7::N7FS::FAULT
            = sub { die "conversion crash\n" if $ARG[0] eq $point };
        upgrade( %crun, target => 3 );
    };
    refused( $inject, qr|conversion crash|, "fault injected at $point" );
    ok( ( stat $old_content )[3] == 1
            && !-e "$root/$cdisk/" . epoch_b32( $cold->{'epoch'} + 1 ),
        "$point cleans the partial epoch and drops any new link"
    );
    my $retry = do {
        local $AMOS7::N7FS::Store::LINK = sub { return 0 }
            if $point =~ m|copy|;
        upgrade( %crun, target => 3 );
    };
    ok( $retry->{'nodes'} == 1 && store_verify(%crun)->{'nodes'} == 1,
        "retry after $point finishes and verifies" );
}

my ( $repair_disk, %repair_run ) = new_v2('linked-repair');
my ( undef, $repair_old )
    = one_v2_node( \%repair_run, "linked repair\n", 'linked-repair.txt' );
{
    local $AMOS7::N7FS::FAULT = sub {
        die "baseline crash\n" if $ARG[0] eq 'journal:before-write';
    };
    refused(
        sub { upgrade( %repair_run, target => 3 ) },
        qr|baseline crash|,
        'crash after linked publish and state switch'
    );
}
store_repair(%repair_run);
my ( undef, $repair_old_content, $repair_new_content )
    = linked_pair( \%repair_run, $repair_old );
ok( ( stat $repair_new_content )[3] == 2
        && store_verify(%repair_run)->{'nodes'} == 1,
    'repair adopts and verifies linked content without rewriting it'
);

my ( $tamper_disk, %tamper_run ) = new_v2('linked-tamper');
my ( undef, $tamper_old )
    = one_v2_node( \%tamper_run, 'original', 'linked-tamper.txt' );
{
    local $AMOS7::N7FS::FAULT = sub {
        return if $ARG[0] ne 'convert:after-link';
        my ($content)
            = glob "$root/$tamper_disk/"
            . epoch_b32( $tamper_old->{'epoch'} + 1 )
            . "/$tamper_old->{'amos'}/$tamper_old->{'bmw'}.tmp.*/content";
        chmod 0600, $content;
        write_file( $content, 'tampered' );
    };
    refused(
        sub { upgrade( %tamper_run, target => 3 ) },
        qr|content does not match its bmw|,
        'linked content is checksummed after linking exactly like a copy'
    );
}

say ':: prune refusal, dry-run and boundaries';
my ( $prune_disk, %prune_run ) = new_v2('prune-main');
upgrade( %prune_run, target => 3 );
confirm(%prune_run);
my $tree = "$src/prune-tree";
make_dirs("$tree/a/b");
make_dirs("$tree/nonempty");
make_dirs("$tree/was-empty");
my $p1 = write_file( "$tree/a/b/one", 'prune one' );
my $p2 = write_file( "$tree/a/b/two", 'prune two' );
write_file( "$tree/nonempty/keep", 'keep' );
refused(
    sub { assimilate( %prune_run, paths => [$tree], prune => TRUE ) },
    qr|-prune needs -remove|,
    'prune without remove refuses clearly'
);
my $dry_before = snapshot( $root, $hdir, $src );
my $dry        = assimilate(
    %prune_run,
    paths   => [$tree],
    remove  => TRUE,
    prune   => TRUE,
    dry_run => TRUE
);
ok( join( "\n", $dry->{'pruned'}->@* ) eq "$tree/a/b\n$tree/a\n$tree/nonempty"
        && snap_equal( $dry_before, snapshot( $root, $hdir, $src ) ),
    'dry-run lists empty descendants in post-order and changes nothing'
);
my $pruned = assimilate(
    %prune_run,
    paths  => [$tree],
    remove => TRUE,
    prune  => TRUE
);
ok( !-e "$tree/a" && !-e "$tree/nonempty" && -d $tree,
    'prune removes every emptied descendant and keeps the named root' );
ok( -d "$tree/was-empty",
    'a directory that was empty before the import is kept' );
ok( join( "\n", $pruned->{'pruned'}->@* ) eq
        "$tree/a/b\n$tree/a\n$tree/nonempty",
    'the report names each directory actually pruned'
);
ok( store_verify(%prune_run)->{'nodes'} == 3,
    'pruned sources remain verified in the store'
);

my $off = "$src/prune-off";
make_dirs("$off/empty");
my $off_file = write_file( "$off/empty/file", 'off by default' );
assimilate( %prune_run, paths => [$off], remove => TRUE );
ok( -d "$off/empty", 'empty directories remain when prune is off' );

my $links   = "$src/prune-links";
my $outside = "$src/prune-outside";
make_dirs("$links/d");
make_dirs($outside);
write_file( "$links/d/file", 'symlink boundary' );
symlink $outside, "$links/d/link" or die "symlink : $OS_ERROR";
my $followed     = FALSE;
my $linked_prune = do {
    local $AMOS7::N7FS::FAULT = sub {
        $followed = TRUE
            if $ARG[0] eq 'assimilate:before-prune'
            and $ARG[1] eq "$links/d/link";
    };
    assimilate(
        %prune_run,
        paths  => [$links],
        remove => TRUE,
        prune  => TRUE
    );
};
ok( -l "$links/d/link"
        && -d $outside
        && !$followed
        && !$linked_prune->{'pruned'}->@*,
    'a symlink is never followed and makes its parent non-empty'
);

my $nested = "$src/prune-nested";
make_dirs("$nested/child/empty");
write_file( "$nested/child/empty/file", 'nested named root' );
assimilate(
    %prune_run,
    paths  => [ $nested, "$nested/child" ],
    remove => TRUE,
    prune  => TRUE
);
ok( -d "$nested/child" && !-e "$nested/child/empty",
    'a nested named directory is kept while its empty descendant is pruned' );

my $race = "$src/prune-race";
make_dirs("$race/d");
write_file( "$race/d/file", 'nonempty at rmdir' );
{
    local $AMOS7::N7FS::FAULT = sub {
        return if $ARG[0] ne 'assimilate:before-prune';
        write_file( "$race/d/arrived", 'concurrent data' );
    };
    my $race_result = assimilate(
        %prune_run,
        paths  => [$race],
        remove => TRUE,
        prune  => TRUE
    );
    ok( -d "$race/d" && -e "$race/d/arrived",
        'a directory non-empty at removal time is left by rmdir semantics' );
}

say ':: prune crashes, retry and repair';
foreach my $point (qw| assimilate:before-prune assimilate:after-prune |) {
    foreach my $recovery (qw| retry repair |) {
        my $crash_tree = "$src/prune-crash-$point-$recovery";
        make_dirs("$crash_tree/a/b");
        write_file( "$crash_tree/a/b/file", "$point $recovery" );
        {
            local $AMOS7::N7FS::FAULT = sub {
                die "prune crash\n" if $ARG[0] eq $point;
            };
            refused(
                sub {
                    assimilate(
                        %prune_run,
                        paths  => [$crash_tree],
                        remove => TRUE,
                        prune  => TRUE
                    );
                },
                qr|prune crash|,
                "fault injected at $point [ $recovery ]"
            );
        }
        if ( $recovery eq 'retry' ) {
            my $again = assimilate(
                %prune_run,
                paths  => [$crash_tree],
                remove => TRUE,
                prune  => TRUE
            );
            ok( -d $crash_tree && !-e "$crash_tree/a/b/file",
                "retry after $point keeps leftover empty directories"
            );
        } else {
            store_repair(%prune_run);
            ok( store_verify(%prune_run),
                "repair finishes store recovery after $point" );
            assimilate(
                %prune_run,
                paths  => [$crash_tree],
                remove => TRUE,
                prune  => TRUE
            );
            ok( -d $crash_tree,
                "a later prune after $point never removes the named root" );
        }
    }
}

my ( $cli_disk, %cli_run ) = new_v2('linked-cli');
one_v2_node( \%cli_run, 'cli counts', 'cli-counts.txt' );
my ( $rc, $out, $err ) = cli_n7fs( 'upgrade', $cli_disk );
ok( $rc == 0 && $out =~ m|\[ 1 linked, 0 copied \]| && $err eq '',
    'upgrade cli prints linked versus copied counts'
);

done();

#,,..,..,,.,.,.,,,,.,,,.,,,.,,..,,.,.,,,.,.,.,.,.,...,...,,.,,,..,,,,,.,,,,..,
#YDJ7LTS5K527C3AZ7QHYAJ23TEHYBOROWRAVMLFZDWWRX3B4Z372BOHHL7UPB3GNMDO27S44QDCVM
#\\\|GRJZ7ADKTFFL6UVPTTYXEWNRUJ6PXPIHNWIZBBQGTJMJ7SMP2VK \ / AMOS7 \ YOURUM ::
#\[7]X3M6M4FF7LXXHWFKC6R6PWWUYFV6SGN32DFPUQC7WFZSBYLOVMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
