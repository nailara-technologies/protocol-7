#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## review finding 2 : a home holder through only its forced receiver command.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault     qw| vault_init |;
use AMOS7::N7FS      qw| make_dirs read_file b32 |;
use AMOS7::N7FS::Sum qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::Receiver qw| holder_id request_sign |;
use AMOS7::N7FS::Sign     qw| seed_signer new_seed |;
use AMOS7::N7FS::Holder;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

## single-node blobs make one shred produce one unreferenced blob for gc ##
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
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

sub open_main_root {
    write_file( "$base/root-pass", "vp\n" );
    open( my $pass, '<:raw', "$base/root-pass" ) or die $OS_ERROR;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |      => 'vault:main',
        qw| vault_dir | => $vdir,
        qw| pass_fd |   => fileno($pass)
    );
}

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

my $disk;

sub add_tree {
    my ( $name, $category ) = @ARG;
    my $tree = "$src/$name";
    make_dirs($tree);
    write_file( "$tree/f$ARG", "$name file $ARG\n" ) for 1 .. 3;
    my ( $rc, $out ) = cli(
        [],        'assimilate', '-disk', $disk,
        '-keep',   '-tree',      $name,   '-category',
        $category, $tree
    );
    die $out if $rc;
    return $tree;
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 't', '-intent', 'x' );
($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
( $rc, $out ) = cli( [], 'category', $disk, 'set', 'two', '-copies', 2 );
add_tree( 't', 'two' );
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );
my $main_root = open_main_root();
my $tag       = AMOS7::N7FS::Seal::root_subdir($main_root);
my $head_name = AMOS7::N7FS::Seal::_head_name($main_root);

my $remote = "$base/remote";
my $local  = "$base/local";
make_dirs($ARG) for $remote, $local;
my $spec = 'ssh-receiver:fake:/holder';
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'rx', $spec, '-domain', 'b' );
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'local', $local, '-domain', 'a',
    '-owned' );

my @receiver_args = (
    '-holder-id', holder_id($spec),
    '-root-pub',  b32( $main_root->{'signer'}->public ),
    '-head-name', "$main_root->{'root_id'}:$head_name",
);
## only the disposable copy is made executable, never the tracked fixture ##
copy_tree( "$FindBin::Bin/fixtur" . "es/n7fs/forced-ssh.sh",
    "$base/forced-ssh.sh" );
chmod 0755, "$base/forced-ssh.sh" or die $OS_ERROR;
$ENV{'N7FS_SSH'}         = "$base/forced-ssh.sh";
$ENV{'FORCED_PERL'}      = $EXECUTABLE_NAME;
$ENV{'FORCED_RECEIVE'}   = "$FindBin::Bin/../n7fs-receive";
$ENV{'FORCED_DIR'}       = $remote;
$ENV{'FORCED_ARGS'}      = join ' ', @receiver_args;
$ENV{'N7FS_SSH_BACKOFF'} = '0,0,0,0,0';

( $rc, $out )
    = cli( ['vp'], 'holder-receiver-line', 'rx', '-root-key', 'vault:main' );
ok( $rc == 0
        && $out =~ m|\Acommand=".*/n7fs-receive /holder .*,restrict\n\z|
        && $out =~ m|-holder-id|
        && $out =~ m|-root-pub|,
    'the cli prints the complete restricted authorized_keys prefix'
) or say $out;

( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|placed [1-9]\d* nodes on rx| && $out =~ m|on local|,
    'place seals through the receiver and to a local holder'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', 'rx', '-root-key', 'vault:main' );
ok( $rc == 0, 'full holder-check works through get-range' ) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', 'rx', '-root-key', 'vault:main' );
ok( $rc == 0, 'sampled holder-check works in receiver mode' ) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-scrub', 'rx', '-root-key', 'vault:main' );
ok( $rc == 0, 'keyless scrub works in receiver mode' ) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $spec,          '-tree',     't',
    "$base/recovered"
);
ok( $rc == 0 && read_file("$base/recovered/f2") eq "t file 2\n",
    'seal-recover streams ranges from the receiver'
) or say $out;

add_tree( 'second', 'two' );
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $spec, '-tree',
    'second'
);
ok( $rc == 0, 'seal publishes a newer signed head through put-head' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'relay', 'rx', 'local', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 3 nodes|,
    'relay reads a receiver source and writes a local target' )
    or say $out;

add_tree( 'third', 'two' );
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk,  '-root-key',
    'vault:main', '-out', $local, '-tree',
    'third'
);
( $rc, $out )
    = cli( ['vp'], 'relay', 'local', 'rx', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 3 nodes|,
    'relay writes a receiver target from a local source' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'relay', 'rx', 'local', '-root-key', 'vault:main',
    '-list' );
ok( $rc == 0 && $out =~ m|listed|,
    'a relay list is replaced only by a signed put-list request' )
    or say $out;

## flatten only the root's live files : migrate puts them back with signed ##
## rename requests, the head last as on a local holder                     ##
opendir( my $subdh, "$remote/$tag" ) or die $OS_ERROR;
my @flat = grep { $ARG ne '.' and $ARG ne '..' } readdir $subdh;
closedir $subdh;
for my $name (@flat) {
    die 'unexpected trash before migrate' if not -f "$remote/$tag/$name";
    rename "$remote/$tag/$name", "$remote/$name" or die $OS_ERROR;
}
rmdir "$remote/$tag" or die $OS_ERROR;
( $rc, $out )
    = cli( ['vp'], 'holder-migrate', 'rx', '-root-key', 'vault:main',
    '-delete' );
ok( $rc == 0 && -d "$remote/$tag" && $out =~ m|moved|,
    'holder-migrate uses signed flat-to-root rename requests'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', 'rx', '-root-key', 'vault:main' );
ok( $rc == 0, 'the migrated receiver holder checks clean' ) or say $out;

my ( undef, undef, $map )
    = AMOS7::N7FS::Seal::_context( $main_root, $spec, 1 );
my ($address) = sort keys $map->{'nodes'}->%*;
my $blob = $map->{'nodes'}{$address}{'blob'};
( $rc, $out )
    = cli( ['vp'], 'shred', $disk, '-root-key', 'vault:main',
    '-out', $spec, $address );
ok( $rc == 0, 'shred advances the receiver head' ) or say $out;
my $old = time - 3 * 86400;
utime $old, $old, "$remote/$tag/$blob" or die $OS_ERROR;
( $rc, $out )
    = cli( ['vp'], 'holder-gc', 'rx', '-root-key', 'vault:main',
    '-delete', '-grace', '0' );
my @t   = gmtime;
my $day = sprintf '%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3];
ok( $rc == 0 && -f "$remote/$tag/.trash/$day/$blob",
    'gc moves an old unreferenced blob with a signed move'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-trash-restore', 'rx',
    '-root-key', 'vault:main', $blob );
ok( $rc == 0 && -f "$remote/$tag/$blob",
    'trash restore uses a signed move in the other direction' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-gc', 'rx', '-root-key', 'vault:main',
    '-delete', '-grace', '0' );
utime $old, $old, "$remote/$tag/.trash/$day" or die $OS_ERROR;
( $rc, $out )
    = cli( ['vp'], 'holder-trash-purge', 'rx',
    '-root-key', 'vault:main', '-older', '0', '-delete' );
ok( $rc == 0 && !-d "$remote/$tag/.trash/$day",
    'purge-day removes the old trash only with a root signature' )
    or say $out;

## direct signed delete : an unsigned put may add, never remove ##
my $bytes = 'receiver delete fixture';
my $name  = bmw_b32( bmw384_bytes($bytes) );
( $rc, $out )
    = receive( "put $tag/$name " . length($bytes), $bytes, @receiver_args );
AMOS7::N7FS::Holder::holder_authorize( $spec, $main_root );
AMOS7::N7FS::Holder::holder_delete( $spec, "$tag/$name" );
ok( !-e "$remote/$tag/$name",
    'holder_delete has only a signed receiver form' );

## an existing legacy registration switches after its head reads back ##
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'legacy', 'ssh:fake:/holder', '-domain',
    'c' );
( $rc, $out )
    = cli( ['vp'], 'holder', 'receiver', 'legacy', '-root-key',
    'vault:main' );
ok( $rc == 0 && $out =~ m|switched legacy to ssh-receiver:fake:/holder|,
    'the registry switches an existing holder to receiver mode'
) or say $out;

## direct refusal checks come last : their high counters must not block the ##
## ordinary workflow above                                                  ##
make_dirs("$remote/$tag/.trash/2020-01-01");
write_file( "$remote/$tag/.trash/2020-01-01/$name", $bytes );
$old = time - 30 * 86400;
utime $old, $old, "$remote/$tag/.trash/2020-01-01";
my $purge_path = "$tag/.trash/2020-01-01";
( $rc, $out ) = receive( 'rm -rf /', undef, @receiver_args );
ok( $rc != 0 && -d $remote, 'a full shell command is refused' ) or say $out;
( $rc, $out ) = receive( "purge-day $purge_path", undef, @receiver_args );
ok( $rc != 0 && -d "$remote/$purge_path", 'an unsigned purge is refused' )
    or say $out;
my $wrong_signer = seed_signer( new_seed() );
my $wrong_root   = {
    qw| signer |  => $wrong_signer,
    qw| root_id | => $main_root->{'root_id'},
};
my $wrong = request_sign( $wrong_root, $spec, 'purge-day',
    { qw| path | => $purge_path }, 1000 );
( $rc, $out )
    = receive( "purge-day $purge_path $wrong", undef, @receiver_args );
ok( $rc != 0 && -d "$remote/$purge_path",
    'a wrongly signed purge is refused'
) or say $out;
my $valid = request_sign( $main_root, $spec, 'purge-day',
    { qw| path | => $purge_path }, 1000 );
( $rc, $out )
    = receive( "purge-day $purge_path $valid", undef, @receiver_args );
ok( $rc == 0 && !-d "$remote/$purge_path",
    'a valid signed purge is accepted'
) or say $out;
( $rc, $out )
    = receive( "purge-day $purge_path $valid", undef, @receiver_args );
ok( $rc == 8 && $out =~ m|replayed holder request|,
    'the identical purge record is refused as a replay'
) or say $out;

## a signed request cannot make a corrupted outer head signature valid ##
my $head_path  = "$remote/$tag/$head_name";
my $head_bytes = read_file($head_path);
my $version    = unpack qw| Q> |, substr( $head_bytes, 0, 8 );
my $writer_raw = substr( $head_bytes, 8, 16 );
my $writer     = b32($writer_raw);
substr( $head_bytes, -1, 1 ) = chr( ord( substr( $head_bytes, -1, 1 ) ) ^ 1 );
my $head_args = {
    qw| path |    => "$tag/$head_name",
    qw| size |    => length $head_bytes,
    qw| digest |  => bmw_b32( bmw384_bytes($head_bytes) ),
    qw| version | => $version + 1,
    qw| writer |  => $writer,
};
my $head_token
    = request_sign( $main_root, $spec, 'put-head', $head_args, 1001 );
( $rc, $out )
    = receive(
    "put-head $tag/$head_name " . length($head_bytes) . " $head_token",
    $head_bytes, @receiver_args );
ok( $rc == 3 && $out =~ m|outer signature|,
    'a bad head is refused even with a signed request' )
    or say $out;

done();

#,,,.,.,.,..,,,..,,..,.,,,.,,,,..,...,..,,.,.,..,,...,.,.,,,.,,,.,,,,,.,,,,,.,
#EYQLIUSEVXD2RSAYSIMTHEWFOV3D7XIRN33DPZZDWVYJ7QQMFPGIGMBDR7BBCEWBNYDMNM73YEDDM
#\\\|YHGO5LLSDF3BMA6FMQYPK7NBYAZYRJZ42PYKC4HXVVEUOUDE4D3 \ / AMOS7 \ YOURUM ::
#\[7]46F64WI2RRBDT2UA4YYF7M7TUBIARG5JPEERYRZR5YWSLRBZRMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
