#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS format 2 : delegated-store-key signatures, location binding, downgrade
## refusal, and host-side key requirements. every disk and key lives below
## File::Temp directories. perl bin/test-scripts/test-n7fs-format2.pl

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS qw| read_file signed_record_pack signed_record_parse
    plain_record_pack make_dirs remove_tree |;
use AMOS7::N7FS::Sum  qw| epoch_b32 epoch_int |;
use AMOS7::N7FS::Sign qw| verify key_file_write key_file_signer new_seed |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_read_id disk_status
    state_read state_write witness_read |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes meta_entries |;
use AMOS7::N7FS::Convert qw| upgrade |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

my $box    = sandbox();
my $root   = $box->{'root'};
my $hdir   = $box->{'host'};
my $src    = $box->{'src'};
my $parent = test_signer();
my $host   = key_file_write("$hdir/host.key");
my %base   = ( root => $root, host_dir => $hdir );
clock_real();

sub cli_n7fs {
    my ( $host_dir, @args ) = @ARG;
    my $out = "$box->{'base'}/cli.stdout";
    my $err = "$box->{'base'}/cli.stderr";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out ) or exit 98;
        open( STDERR, '>:raw', $err ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $host_dir, @args )
            or exit 99;
    }
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file($out), read_file($err) );
}

sub replace_bytes {
    my ( $path, $bytes ) = @ARG;
    chmod 0600, $path;
    write_file( $path, $bytes );
}

sub record_label {
    my $bytes = shift;
    my $len   = unpack 'n', substr( $bytes, 5, 2 );
    return substr( $bytes, 7, $len );
}

my $store_seed = new_seed();
my $disk       = disk_init(
    %base,
    parent     => $parent,
    store_seed => $store_seed,
    name       => 'format2-test',
    intent     => 'n7fs format 2 security tests [ test data ]'
);
my %run   = ( %base, disk => $disk, host => $host );
my $dpath = "$root/$disk";
disk_attach(%run);
my $source = write_file( "$src/one.txt", "test data : signed one\n" );
assimilate( %run, paths => [$source] );

my $id           = disk_read_id( %base, disk => $disk );
my $state        = state_read( $dpath, $id->{'store_pub'} );
my $epoch        = $state->{'epochs'}[0];
my ($node)       = store_nodes( $dpath, $epoch );
my $node_path    = $node->{'path'};
my ($meta_file)  = glob "$node_path/meta/*.meta";
my ($state_file) = reverse sort glob "$dpath/.n7fs/state/*.state";
my $address = join '/', epoch_b32($epoch), $node->{'amos'}, $node->{'bmw'};
my $store   = key_file_signer("$hdir/stores/$disk.store.key");

say ':: fresh disks and records are signed format 2';
ok( $state->{'store_format'} == 2, 'new disk state is store format 2' );
my $state_bytes = read_file($state_file);
my $state_rec   = signed_record_parse( 'state', $state_bytes );
ok( substr( $state_bytes, 0, 5 ) eq "P7FT\x02"
        && record_label($state_bytes) eq 'p7 n7fs state:0001',
    'state has format byte 2 and the :0001 label'
);
ok( $state_rec->{'signer_pub'} eq $id->{'store_pub'} && verify(
        $id->{'store_pub'}, $state_rec->{'signed'},
        $state_rec->{'sig'}
    ),
    'state verifies with the store key from the parent-signed id'
);
my $meta_bytes = read_file($meta_file);
my $meta_rec   = signed_record_parse( 'meta', $meta_bytes );
my $meta       = $meta_rec->{'payload'};
ok( substr( $meta_bytes, 0, 5 ) eq "P7FN\x02"
        && record_label($meta_bytes) eq 'p7 n7fs meta:0001',
    'meta has format byte 2 and the :0001 label'
);
ok( $meta_rec->{'signer_pub'} eq $id->{'store_pub'} && verify(
        $id->{'store_pub'}, $meta_rec->{'signed'}, $meta_rec->{'sig'}
    ),
    'meta verifies with the same delegated store key'
);
ok( $meta->{'disk'} eq $disk
        && $meta->{'epoch'} eq epoch_b32($epoch)
        && $meta->{'amos'} eq $node->{'amos'}
        && $meta->{'bmw'} eq $node->{'bmw'},
    'meta binds disk, epoch, amos and bmw'
);
ok( witness_read(%run)->{'store_format'} == 2,
    'the host witness records highest store format 2'
);
ok( store_verify( %base, disk => $disk )->{'nodes'} == 1,
    'the fresh signed node verifies' );
refused(
    sub { plain_record_pack( 'meta', $meta, 2 ) },
    qr|requires a signature|,
    'the codec cannot emit a plain format-2 meta record'
);

say ':: a tampered meta byte fails every named and exact read';
{
    my $bad = $meta_bytes;
    my $pos = index $bad, '"name"';
    die 'meta fixture has no name field' if $pos < 0;
    substr( $bad, $pos + 2, 1 ) = 'x';
    replace_bytes( $meta_file, $bad );
    refused(
        sub { meta_entries( %base, disk => $disk ) },
        qr|store signature does not verify|,
        'find refuses tampered signed meta'
    );
    my ( $rc, $out, $err ) = cli_n7fs( $hdir, 'get', $disk, 'one.txt' );
    ok( $rc != 0 && $out eq '' && index( $err, $node_path ) >= 0,
        'get by name fails loudly and names the node'
    );
    ( $rc, $out, $err ) = cli_n7fs( $hdir, 'get', $disk, $address );
    ok( $rc != 0 && $out eq '' && index( $err, $node_path ) >= 0,
        'get by exact address also fails through node_verify'
    );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|store signature does not verify|,
        'verify refuses tampered signed meta'
    );
    replace_bytes( $meta_file, $meta_bytes );
}

say ':: a tampered state byte is refused';
{
    my $bad = $state_bytes;
    my $pos = index $bad, '"epochs"';
    die 'state fixture has no epochs field' if $pos < 0;
    substr( $bad, $pos + 3, 1 ) = 'x';
    replace_bytes( $state_file, $bad );
    refused(
        sub { state_read( $dpath, $id->{'store_pub'} ) },
        qr|store signature does not verify|,
        'state signature covers the payload'
    );
    replace_bytes( $state_file, $state_bytes );
}

say ':: a valid signature from another key is not trusted';
{
    my $forged = signed_record_pack( 'meta', $meta, test_signer(), 2 );
    replace_bytes( $meta_file, $forged );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|foreign store key|,
        'meta signed by another key is refused'
    );
    replace_bytes( $meta_file, $meta_bytes );

    $forged = signed_record_pack( 'state', $state_rec->{'payload'},
        test_signer(), 2 );
    replace_bytes( $state_file, $forged );
    refused(
        sub { state_read( $dpath, $id->{'store_pub'} ) },
        qr|foreign store key|,
        'state signed by another key is refused'
    );
    replace_bytes( $state_file, $state_bytes );

    $forged
        = signed_record_pack( 'state',
        { %{ $state_rec->{'payload'} }, store_format => 1 },
        $store, 2 );
    replace_bytes( $state_file, $forged );
    refused(
        sub { state_read( $dpath, $id->{'store_pub'} ) },
        qr|record format does not match store format|,
        'a signed record cannot claim the plain store format'
    );
    replace_bytes( $state_file, $state_bytes );
}

say ':: signed meta cannot move to another node';
{
    my $other_source
        = write_file( "$src/two.txt", "test data : signed two\n" );
    assimilate( %run, paths => [$other_source] );
    my @nodes   = store_nodes( $dpath, $epoch );
    my ($other) = grep { $ARG->{'path'} ne $node_path } @nodes;
    my $planted = "$other->{'path'}/meta/99999999999999.COPIEDAA.meta";
    write_file( $planted, $meta_bytes );
    refused(
        sub { meta_entries( %base, disk => $disk ) },
        qr|does not match its location|,
        'find refuses meta copied to another content node'
    );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|does not match its location|,
        'verify names the node with copied meta'
    );
    unlink $planted or die "unlink $planted : $OS_ERROR";
}

say ':: signed meta cannot move to another disk';
{
    ## the same test key on both disks isolates location from signer checks ##
    my $disk2 = disk_init(
        %base,
        parent     => $parent,
        store_seed => $store_seed,
        name       => 'format2-other-disk',
        intent     => 'cross-disk binding test [ test data ]'
    );
    my %run2 = ( %base, disk => $disk2, host => $host );
    disk_attach(%run2);
    assimilate( %run2, paths => [$source] );
    my $id2     = disk_read_id( %base, disk => $disk2 );
    my $state2  = state_read( "$root/$disk2", $id2->{'store_pub'} );
    my ($node2) = store_nodes( "$root/$disk2", $state2->{'epochs'}->@* );
    my $planted = "$node2->{'path'}/meta/99999999999999.COPIEDAA.meta";
    write_file( $planted, $meta_bytes );
    refused(
        sub { store_verify( %base, disk => $disk2 ) },
        qr|disk does not match its location|,
        'the same signed meta is refused under another disk id'
    );
    unlink $planted or die "unlink $planted : $OS_ERROR";
}

say ':: signed meta cannot move to another epoch';
{
    my $clone_box = sandbox();
    my $clone     = "$clone_box->{'root'}/$disk";
    copy_tree( $dpath, $clone );
    my $clone_state = state_read( $clone, $id->{'store_pub'} );
    my $next_epoch  = $epoch + 1;
    my $next_dir    = "$clone/" . epoch_b32($next_epoch) . "/$node->{'amos'}";
    make_dirs($next_dir);
    copy_tree( $node_path, "$next_dir/$node->{'bmw'}" );
    state_write(
        $clone,
        {   %{$clone_state},
            epochs => [ $clone_state->{'epochs'}->@*, $next_epoch ]
        },
        $store
    );
    refused(
        sub {
            store_verify(
                root     => $clone_box->{'root'},
                host_dir => $clone_box->{'host'},
                disk     => $disk
            );
        },
        qr|epoch does not match its location|,
        'the old signed meta is refused in a copied epoch'
    );
}

say ':: unsigned meta in a format 2 node fails loudly';
{
    my $plain = { %{$meta}, node_format => 1 };
    delete $plain->{'epoch'};
    my $planted = "$node_path/meta/99999999999999.UNSIGNED.meta";
    write_file( $planted, plain_record_pack( 'meta', $plain ) );
    refused(
        sub { meta_entries( %base, disk => $disk ) },
        qr|unsigned.*format 2|,
        'find refuses an unsigned planted meta'
    );
    refused(
        sub { store_verify( %base, disk => $disk ) },
        qr|unsigned.*format 2|,
        'verify refuses the same unsigned meta'
    );
    unlink $planted or die "unlink $planted : $OS_ERROR";
}

say ':: plain state downgrade is refused while a signed state remains';
{
    my $p = state_read( $dpath, $id->{'store_pub'} );
    delete $p->{'_name'};
    $p->{'store_format'} = 1;
    my $plain_file = "$dpath/.n7fs/state/99999999999999.state";
    write_file( $plain_file, plain_record_pack( 'state', $p ) );
    refused(
        sub { state_read( $dpath, $id->{'store_pub'} ) },
        qr|unsigned state after a signed state|,
        'a newer plain state cannot downgrade a directory with signed states'
    );
    unlink $plain_file or die "unlink $plain_file : $OS_ERROR";
}

say ':: deleted signed states are still limited by the host witness';
{
    my $backup = "$box->{'base'}/state-backup";
    copy_tree( "$dpath/.n7fs/state", $backup );
    my $p = state_read( $dpath, $id->{'store_pub'} );
    delete $p->{'_name'};
    $p->{'store_format'} = 1;
    unlink glob "$dpath/.n7fs/state/*.state";
    my $plain_file = "$dpath/.n7fs/state/99999999999999.state";
    write_file( $plain_file, plain_record_pack( 'state', $p ) );

    ok( state_read( $dpath, $id->{'store_pub'} )->{'store_format'} == 1,
        'state_read alone has no witness on a first-contact host'
    );
    refused(
        sub { disk_status(%run) },
        qr|below the witnessed highest 2|,
        'the host witness refuses the downgrade '
            . 'after signed states are deleted'
    );

    foreach my $command (
        [ 'get',    $disk, $address ],
        [ 'find',   $disk ],
        [ 'verify', $disk ],
    ) {
        my ( $rc, $out, $err ) = cli_n7fs( $hdir, $command->@* );
        ok( $rc != 0 && $err =~ m|below the witnessed highest 2|,
            "$command->[0] also enforces an available host witness"
        );
    }
    my $allowed = disk_status( %run, allow_rollback => TRUE );
    ok( $allowed->{'state'}{'store_format'} == 1,
        '-allow-rollback explicitly permits the lower format' );
    my ( $rc, $out, $err )
        = cli_n7fs( $hdir, 'status', $disk, '-allow-rollback' );
    ok( $rc == 0
            && $out =~ m|format\s+1|
            && $err =~ m|meta names are unsigned|,
        'status on format 1 warns that names are unsigned'
    );

    remove_tree("$dpath/.n7fs/state");
    copy_tree( $backup, "$dpath/.n7fs/state" );
}

say ':: readers need no store secret ; '
    . 'writers refuse before changing anything';
{
    my $key      = "$hdir/stores/$disk.store.key";
    my $key_save = "$box->{'base'}/store-key.saved";
    rename $key, $key_save or die "rename $key : $OS_ERROR";

    foreach my $command (
        [ 'get',    $disk, $address ],
        [ 'find',   $disk ],
        [ 'verify', $disk ],
        [ 'status', $disk ],
    ) {
        my ( $rc, $out, $err ) = cli_n7fs( $hdir, $command->@* );
        ok( $rc == 0 && $err eq '',
            "$command->[0] works without the store key" );
    }

    my $host2 = "$box->{'base'}/host2";
    mkdir $host2 or die "mkdir $host2 : $OS_ERROR";
    key_file_write("$host2/host.key");
    foreach my $command (
        [ 'get',    $disk, $address ],
        [ 'find',   $disk ],
        [ 'verify', $disk ],
        [ 'status', $disk ],
    ) {
        my ( $rc, $out, $err ) = cli_n7fs( $host2, $command->@* );
        ok( $rc == 0 && $err eq '',
            "$command->[0] works on a second host with no store key" );
    }

    my $no_key_source = write_file( "$src/no-key.txt", 'no key' );
    my $before        = snapshot( $root, $hdir, $src );
    refused(
        sub { assimilate( %run, paths => [$no_key_source] ) },
        qr|no delegated store key|,
        'assimilate without the store key refuses'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ),
        'failed assimilate changed nothing' );
    $before = snapshot( $root, $hdir );
    refused(
        sub { upgrade(%run) },
        qr|no delegated store key|,
        'upgrade without the store key refuses even as a no-op'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir ) ),
        'failed upgrade changed nothing' );

    rename $key_save, $key or die "restore $key : $OS_ERROR";
}

ok( store_verify( %base, disk => $disk )->{'nodes'} == 2,
    'all restored records verify again' );

done();

#,,,,,,..,,..,..,,.,.,,.,,..,,..,,...,..,,,,,,..,,...,...,..,,,.,,.,.,,..,...,
#2FKFLESSJAOUNRXGUMPVWE252DQUAPP6QFUNSWGUATUKD5R7YKAW732OHVSHDRSSKSZSGMGDHI6R2
#\\\|U2QOGPIVV5SBPR5UT4N4DPGFMNVGSOCUSZYEJNFXTQ7EVKVAEGR \ / AMOS7 \ YOURUM ::
#\[7]APLY72RIM4ITKR4CTTWFCJJA46HL3USS32T7AAFLDU2LT6IGTQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
