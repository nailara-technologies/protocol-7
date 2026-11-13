#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## review finding 6 : a separate sealing root for the unattended hourly job.
## a service root must open and write only its own disks, categories and
## holder subdirectories -- never the main root's.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault     qw| vault_init |;
use AMOS7::N7FS      qw| make_dirs read_file b32 |;
use AMOS7::N7FS::Sum qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::Receiver qw| holder_id request_sign |;
use AMOS7::N7FS::Holder;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $base = $box->{'base'};
my $vdir = "$base/vault";
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );
$ENV{'N7FS_HOST_DIR'} = $hdir;

## fast argon for the two passphrase file roots ##
my @fast = ( '-argon-m', 1024, '-argon-t', 1 );

sub cli {
    my ( $lines, @args ) = @ARG;
    my $pf = "$base/pass.$PID";
    write_file( $pf, join '', map {"$ARG\n"} @{$lines} );
    my $out = "$base/out";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<',     $pf )      or exit 98;
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, '-vault-dir', $vdir, @args, '-pass-fd', 0 )
            or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

sub open_root {
    my ( $file, $pass ) = @ARG;
    write_file( "$base/$file.pass", "$pass\n" );
    open( my $fh, '<:raw', "$base/$file.pass" ) or die $OS_ERROR;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |    => "$base/$file",
        qw| pass_fd | => fileno($fh)
    );
}

( my $rc, my $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 't', '-intent', 'x' );
my ($disk_a)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk_a );

sub add_tree {
    my ( $disk, $name, $category ) = @ARG;
    my $tree = "$src/$name";
    make_dirs($tree);
    write_file( "$tree/f$ARG", "$name file $ARG\n" ) for 1 .. 3;
    ( $rc, $out ) = cli(
        [],        'assimilate', '-disk', $disk,
        '-keep',   '-tree',      $name,   '-category',
        $category, $tree
    );
    die $out if $rc;
    return;
}

add_tree( $disk_a, 'maindata', 'default' );

## the two independent roots : the main root and the hourly service root ##
( $rc, $out ) = cli( [ 'main-pass', 'main-pass' ],
    'root', 'init', "$base/main.key", @fast );
ok( $rc == 0, 'main root created as a passphrase file' ) or say $out;
( $rc, $out )
    = cli( [ 'svc-pass', 'svc-pass' ],
    'root', 'init', "$base/svc.key", @fast );
ok( $rc == 0, 'service root created with its own passphrase' ) or say $out;
my $main = open_root( 'main.key', 'main-pass' );
my $svc  = open_root( 'svc.key',  'svc-pass' );
ok( $main->{'root_id'} ne $svc->{'root_id'},
    'the two roots are fully independent'
);
ok( ( ( stat "$base/main.key" )[2] & 0777 ) == 0600
        and ( ( stat "$base/svc.key" )[2] & 0777 ) == 0600,
    'root key files are 0600'
);

my $holder_main = "$base/holder-main";
( $rc, $out )
    = cli( ['main-pass'], 'seal', $disk_a, '-root-key',
    "$base/main.key", '-out', $holder_main, '-all-trees' );
ok( $rc == 0, 'main disk sealed under the main root' ) or say $out;
ok( -f "$root/$disk_a/.n7fs/seal-root",
    'the first seal wrote the disk seal binding'
);

( $rc, $out )
    = cli( ['svc-pass'], 'seal', $disk_a, '-root-key',
    "$base/svc.key", '-out', "$base/holder-svc", '-all-trees' );
ok( $rc != 0 && $out =~ m|sealed under another root|,
    'the service root cannot seal the main root disk'
) or say $out;

( $rc, $out )
    = cli( ['main-pass'], 'seal', $disk_a, '-root-key',
    "$base/main.key", '-out', $holder_main, '-all-trees' );
ok( $rc == 0, 'the main root still seals its bound disk' ) or say $out;

( $rc, $out ) = cli(
    ['svc-pass'],    'unseal', $disk_a,      '-root-key',
    "$base/svc.key", '-from',  $holder_main, 'maindata',
    "$base/wrong"
);
ok( $rc != 0, 'the service root cannot unseal the main root data' )
    or say $out;
( $rc, $out ) = cli(
    ['main-pass'],    'unseal', $disk_a,      '-root-key',
    "$base/main.key", '-from',  $holder_main, 'maindata',
    "$base/right"
);
ok( $rc == 0 && read_file("$base/right/f2") eq "maindata file 2\n",
    'the main root unseals its own data' )
    or say $out;

## a second disk bound to the service root ##
( $rc, $out ) = cli( [], 'init', '-name', 'svc', '-intent', 'hourly' );
my ($disk_b)
    = grep { $_ ne $disk_a && !m|^\.| }
    do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk_b );
( $rc, $out )
    = cli( [], 'category', $disk_b, 'set', 'logs', '-copies', 1 );
ok( $rc == 0, 'service category defined' ) or say $out;
add_tree( $disk_b, 'logs', 'logs' );
$out = '';
( $rc, $out )
    = cli( [], 'category', $disk_b, 'set', 'logs', '-seal-root', 'BAD' );
ok( $rc != 0 && $out =~ m|root must be a root id|,
    'a bad category root binding is refused'
) or say $out;
( $rc, $out )
    = cli( [], 'category', $disk_b, 'set', 'logs',
    '-seal-root', $main->{'root_id'} );
ok( $rc == 0, 'category bound to the main root id' ) or say $out;

my $holder_svc = "$base/holder-svc";
( $rc, $out ) = cli(
    ['svc-pass'],    'seal', $disk_b,     '-root-key',
    "$base/svc.key", '-out', $holder_svc, '-category',
    'logs'
);
ok( $rc != 0 && $out =~ m|sealed under another root|,
    'a main-root category refuses the service root'
) or say $out;

( $rc, $out )
    = cli( [], 'category', $disk_b, 'set', 'logs',
    '-seal-root', $svc->{'root_id'} );
ok( $rc == 0, 'category rebound to the service root' ) or say $out;
( $rc, $out ) = cli(
    ['svc-pass'],    'seal', $disk_b,     '-root-key',
    "$base/svc.key", '-out', $holder_svc, '-category',
    'logs'
);
ok( $rc == 0 && $out =~ m|sealed [1-9]|,
    'the service root seals its own category'
) or say $out;
( $rc, $out ) = cli(
    ['main-pass'],    'seal', $disk_b,      '-root-key',
    "$base/main.key", '-out', $holder_main, '-category',
    'logs'
);
ok( $rc != 0 && $out =~ m|sealed under another root|,
    'the main root cannot seal the service disk by mistake'
) or say $out;

## relay and holder-check under the wrong root refuse on their own : the ##
## other root's head has another locator and another root id             ##
my $holder_far = "$base/holder-far";
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'm1', $holder_main, '-domain', 'a' );
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'f1', $holder_far, '-domain', 'b' );
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 's1', $holder_svc, '-domain', 'a' );
( $rc, $out ) = cli( [ 'vp', 'svc-pass' ],
    'relay', 'm1', 'f1', '-root-key', "$base/svc.key" );
ok( $rc != 0 && $out =~ m|sealed head|,
    'relay with the service root finds no main-root head' )
    or say $out;
( $rc, $out ) = cli( [ 'vp', 'svc-pass' ],
    'holder-check', 'm1', '-root-key', "$base/svc.key" );
ok( $rc != 0 && $out =~ m|sealed head|,
    'holder-check with the service root refuses the main holder' )
    or say $out;
( $rc, $out ) = cli( [ 'vp', 'main-pass' ],
    'relay', 's1', 'f1', '-root-key', "$base/main.key" );
ok( $rc != 0 && $out =~ m|sealed head|,
    'the main root cannot relay the service holder' )
    or say $out;

## receiver mode : one forced line serves both roots, each only in its own ##
## r-<tag>/                                                                ##
my $remote = "$base/remote";
make_dirs($remote);
my $spec = 'ssh-receiver:fake:/holder';
( $rc, $out ) = cli( ['vp'], 'holder', 'add', 'rx', $spec, '-domain', 'b' );
ok( $rc == 0, 'receiver holder registered' ) or say $out;

( $rc, $out ) = cli( [ 'vp', 'svc-pass', 'main-pass' ],
    'holder-receiver-line', 'rx',
    '-root-key', "$base/svc.key", '-also-root-key', "$base/main.key" );
my @pairs = $out =~ m|-root-pub|g;
ok( $rc == 0
        && scalar @pairs == 2
        && $out =~ m|\Q$svc->{'root_id'}\E|
        && $out =~ m|\Q$main->{'root_id'}\E|
        && $out =~ m|\Acommand=".*",restrict\n\z|s,
    'holder-receiver-line lists both roots'
) or say $out;

my @receiver_args = (
    '-holder-id',
    holder_id($spec),
    '-root-pub',
    b32( $svc->{'signer'}->public ),
    '-head-name',
    "$svc->{'root_id'}:" . AMOS7::N7FS::Seal::_head_name($svc),
    '-root-pub',
    b32( $main->{'signer'}->public ),
    '-head-name',
    "$main->{'root_id'}:" . AMOS7::N7FS::Seal::_head_name($main),
);
copy_tree( "$FindBin::Bin/fixtur" . "es/n7fs/forced-ssh.sh",
    "$base/forced-ssh.sh" );
chmod 0755, "$base/forced-ssh.sh" or die $OS_ERROR;
$ENV{'N7FS_SSH'}         = "$base/forced-ssh.sh";
$ENV{'FORCED_PERL'}      = $EXECUTABLE_NAME;
$ENV{'FORCED_RECEIVE'}   = "$FindBin::Bin/../n7fs-receive";
$ENV{'FORCED_DIR'}       = $remote;
$ENV{'FORCED_ARGS'}      = join ' ', @receiver_args;
$ENV{'N7FS_SSH_BACKOFF'} = '0,0,0,0,0';

my $svc_tag  = AMOS7::N7FS::Seal::root_subdir($svc);
my $main_tag = AMOS7::N7FS::Seal::root_subdir($main);
( $rc, $out ) = cli(
    ['svc-pass'],    'seal', $disk_b, '-root-key',
    "$base/svc.key", '-out', $spec,   '-category',
    'logs'
);
ok( $rc == 0 && -d "$remote/$svc_tag",
    'the service root seals into its own r-tag on the receiver' )
    or say $out;
ok( !-d "$remote/$main_tag", 'the main root tag stays untouched' );

sub receive {
    my ( $command, $input, @args ) = @ARG;
    my $pf = "$base/receive-input";
    write_file( $pf, $input // '' );
    local $ENV{'SSH_ORIGINAL_COMMAND'} = $command;
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<:raw', $pf )                    or exit 98;
        open( STDOUT, '>:raw', "$base/receive-output" ) or exit 98;
        open( STDERR, '>&',    \*STDOUT )               or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs-receive",
            "$base/remote", @args )
            or exit 99;
    }
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file("$base/receive-output") // '' );
}

my ( undef, undef, $svc_map ) = AMOS7::N7FS::Seal::_context( $svc, $spec, 1 );
my ($svc_address) = sort keys $svc_map->{'nodes'}->%*;
my $svc_blob = $svc_map->{'nodes'}{$svc_address}{'blob'};

my $day = do {
    my @t = gmtime;
    sprintf '%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3];
};
my $move = request_sign(
    $svc, $spec, 'move',
    {   qw| from | => "$svc_tag/$svc_blob",
        qw| to |   => "$svc_tag/.trash/$day/$svc_blob"
    },
    900
);
( $rc, $out )
    = receive( "move $svc_tag/$svc_blob $svc_tag/.trash/$day/$svc_blob $move",
    undef, @receiver_args );
ok( $rc == 0 && -f "$remote/$svc_tag/.trash/$day/$svc_blob",
    'a service-root signed move lands in its own trash'
) or say $out;

## the same signature cannot touch the main root's subdirectory ##
my $main_bytes = 'main root blob';
my $main_name  = bmw_b32( bmw384_bytes($main_bytes) );
( $rc, $out ) = receive( "put $main_tag/$main_name " . length($main_bytes),
    $main_bytes, @receiver_args );
my $cross = request_sign( $svc, $spec, 'delete',
    { qw| path | => "$main_tag/$main_name" }, 901 );
( $rc, $out )
    = receive( "delete $main_tag/$main_name $cross", undef, @receiver_args );
ok( $rc != 0 && -f "$remote/$main_tag/$main_name" && $out =~ m|another root|,
    'the service root signature cannot delete in the main root tag'
) or say $out;

my $restore = request_sign(
    $svc, $spec, 'move',
    {   qw| from | => "$svc_tag/.trash/$day/$svc_blob",
        qw| to |   => "$svc_tag/$svc_blob"
    },
    902
);
( $rc, $out )
    = receive(
    "move $svc_tag/.trash/$day/$svc_blob $svc_tag/$svc_blob $restore",
    undef, @receiver_args );
ok( $rc == 0 && -f "$remote/$svc_tag/$svc_blob",
    'the service blob moves back in its own tag'
) or say $out;
ok( !-e "$remote/$main_tag/$svc_blob",
    'the service blob never touches the main root tag' );

done();

#,,,,,,..,,,,,,.,,.,.,,.,,,,,,.,,,...,,,.,,,.,..,,...,...,,,.,..,,,.,,,.,,,,.,
#QE2DUK2GXGQ56BXX435R6AUDU3LGWONLY5IEEHZ24J5RC7UUT3QZVTIAMTERSU7UEYFQ57VHMEINE
#\\\|SQYXJ4HENOFIB2JVKHSUHBU4NLXQFY2WQCTXOUGGMPZAZUF42JE \ / AMOS7 \ YOURUM ::
#\[7]6HSZT5LUA2DPTW6QWFMBUFYTHUGDAFLE4D3PLJVWRRZ2RYSSZYAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
