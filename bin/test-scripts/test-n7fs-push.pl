#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 6 part 2 : fan-out. home lists, a sending holder pushes without any
## key, the receiver accepts only new blobs that match their name, home
## adopts.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault     qw| vault_init |;
use AMOS7::N7FS      qw| make_dirs read_file |;
use AMOS7::N7FS::Sum qw| bmw384_bytes bmw_b32 |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir = "$base/vault";
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );

sub run {
    my ( $lines, $program, @args ) = @ARG;
    my $pf = "$base/pass";
    write_file( $pf, join '', map {"$ARG\n"} @{$lines} );
    my $out = "$base/out";
    my $pid = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDIN,  '<',     $pf )      or exit 98;
        open( STDOUT, '>:raw', $out )     or exit 98;
        open( STDERR, '>&',    \*STDOUT ) or exit 98;
        exec( $EXECUTABLE_NAME, $program, @args ) or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

sub cli {
    my ( $lines, @args ) = @ARG;
    return run( $lines, "$FindBin::Bin/../n7fs", '-root', $root, '-host-dir',
        $hdir, @args, '-pass-fd', 0, '-vault-dir', $vdir );
}

sub blobs {
    my $dir = shift;
    opendir( my $d, $dir ) or return ();
    return sort grep {m|\A[A-Z2-7]{77}\z|} readdir $d;
}

## receive directly, as the forced command would run ##
sub receive {
    my ( $dir, $command, $input, @extra ) = @ARG;
    my $pf = "$base/recv-in";
    write_file( $pf, $input // '' );
    local $ENV{'SSH_ORIGINAL_COMMAND'} = $command;
    my $pid = fork // die;
    if ( $pid == 0 ) {
        open( STDIN,  '<:raw', $pf )              or exit 98;
        open( STDOUT, '>:raw', "$base/recv-out" ) or exit 98;
        open( STDERR, '>&',    \*STDOUT )         or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs-receive",
            $dir, @extra )
            or exit 99;
    }
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file("$base/recv-out") // '' );
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 't', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
make_dirs("$src/t");
write_file( "$src/t/f$ARG", "file $ARG\n" ) for 1 .. 8;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't',
    "$src/t" );
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );

my ( $hub, $far ) = ( "$base/hub", "$base/far" );
make_dirs($ARG) for $hub, $far;
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'hub', $hub, '-domain', 'a', '-owned' );
( $rc, $out ) = cli( ['vp'], 'holder', 'add', 'far', $far, '-domain', 'b' );
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $hub,  '-tree',
    't'
);
ok( $rc == 0, 'sealed once, to the hub' ) or say $out;
## far gets a head first, so gc there has something to protect ##
( $rc, $out )
    = cli( ['vp'], 'relay', 'hub', 'far', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 9 nodes|,
    'first tree relayed through home'
) or say $out;

## the second tree goes out by push ##
make_dirs("$src/u");
write_file( "$src/u/g$ARG", "more $ARG\n" ) for 1 .. 3;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 'u',
    "$src/u" );
{
    local $ENV{'N7FS_TEST_PACK_LIMIT'} = 0;
    ( $rc, $out ) = cli(
        ['vp'],       'seal', $disk, '-root-key',
        'vault:main', '-out', $hub,  '-tree',
        'u'
    );
}
my $before = () = blobs($far);
( $rc, $out )
    = cli( ['vp'], 'relay', 'hub', 'far', '-root-key', 'vault:main',
    '-list' );
my ($list) = $out =~ m|(relay-list\.[A-Z2-7]{13})|;
ok( $rc == 0 && $out =~ m|listed 4 blobs| && defined $list && -f "$hub/$list",
    'home writes a relay list onto the hub'
) or say $out;
ok( scalar( () = blobs($far) ) == $before, 'listing copies nothing' );

( $rc, $out )
    = cli( ['vp'], 'relay', 'hub', 'far', '-root-key', 'vault:main',
    '-adopt' );
ok( $rc == 0 && $out =~ m|relayed 0 nodes| && $out =~ m|4 nodes wait|,
    'adopt before the push maps nothing and says what waits'
) or say $out;

$ENV{'N7FS_SSH'}       = "$FindBin::Bin/fixtures/n7fs/forced-ssh.sh";
$ENV{'FORCED_PERL'}    = $EXECUTABLE_NAME;
$ENV{'FORCED_RECEIVE'} = "$FindBin::Bin/../n7fs-receive";
$ENV{'FORCED_DIR'}     = $far;
chmod 0755, $ENV{'N7FS_SSH'};
( $rc, $out ) = run( [], "$FindBin::Bin/../n7fs-push", $hub, $list, 'far' );
ok( $rc == 0 && $out =~ m|sent 4 blobs|, 'the hub pushes without any key' )
    or say $out;
( $rc, $out ) = run( [], "$FindBin::Bin/../n7fs-push", $hub, $list, 'far' );
ok( $rc == 0 && $out =~ m|sent 0 blobs| && $out =~ m|4 already there|,
    'a second push skips what arrived' )
    or say $out;

( $rc, $out )
    = cli( ['vp'], 'holder-gc', $far, '-root-key', 'vault:main',
    '-only-root', '-delete' );
ok( $rc == 0 && scalar( () = blobs($far) ) >= $before + 4,
    'gc keeps pushed blobs that wait for adoption'
) or say $out;

( $rc, $out )
    = cli( ['vp'], 'relay', 'hub', 'far', '-root-key', 'vault:main',
    '-adopt' );
ok( $rc == 0 && $out =~ m|relayed 4 nodes in 0 blobs| && $out !~ m|wait|,
    'home adopts the pushed nodes without copying' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', $far, '-root-key', 'vault:main' );
ok( $rc == 0, 'the target passes a check' ) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $far,           '-tree',     'u',
    "$base/rec"
);
ok( $rc == 0 && read_file("$base/rec/g2") eq "more 2\n",
    'the pushed tree recovers from the target'
) or say $out;

## the receiver on its own ##
my $box2 = "$base/recv";
make_dirs($box2);
my $bytes = "some ciphertext\n";
my $name  = bmw_b32( bmw384_bytes($bytes) );
( $rc, $out ) = receive( $box2, "put $name " . length $bytes, $bytes );
ok( $rc == 0 && read_file("$box2/$name") eq $bytes,
    'a blob matching its name is accepted'
) or say $out;
my $other = bmw_b32( bmw384_bytes('x') );
( $rc, $out ) = receive( $box2, "put $other " . length $bytes, $bytes );
ok( $rc == 3 && !-e "$box2/$other",
    'bytes not matching the name are refused' )
    or say $out;
my ($head)
    = grep { bmw_b32( bmw384_bytes( read_file("$hub/$ARG") ) ) ne $ARG }
    blobs($hub);
( $rc, $out )
    = receive( $box2, "put $head " . -s "$hub/$head",
    read_file("$hub/$head") );
ok( $rc == 3 && !-e "$box2/$head", 'a head can never be written' )
    or say $out;
( $rc, $out )
    = receive( $box2, "put $name " . ( 1 + length $bytes ), "$bytes!" );
ok( $rc == 4 && read_file("$box2/$name") eq $bytes,
    'an existing blob is never replaced'
) or say $out;
( $rc, $out ) = receive( $box2, "rm $name" );
ok( $rc != 0 && -e "$box2/$name", 'any other request is refused' )
    or say $out;
( $rc, $out ) = receive( $box2, "put $name 999", 'short' );
( $rc, $out ) = receive( $box2, 'put ../x 1',    'x' );
ok( $rc != 0, 'a path is not a blob name' ) or say $out;
my $more = "more ciphertext\n";
( $rc, $out )
    = receive( $box2,
    'put ' . bmw_b32( bmw384_bytes($more) ) . ' ' . length $more,
    $more, '-max-bytes', 20 );
ok( $rc == 5, 'a full holder refuses a put' ) or say $out;
( $rc, $out ) = receive( $box2, "has $name $other" );
ok( $rc == 0 && $out eq "$name " . length($bytes) . "\n",
    'has lists only the named blobs present' )
    or say $out;
opendir( my $dh, $box2 ) or die;
ok( !grep( {m|^\.receive|} readdir $dh ), 'no temporaries are left' );

## stale temporaries : a has request sweeps what is older than 1 hour ##
my $stale_name = bmw_b32( bmw384_bytes('stale') );
my $old_tmp    = "$box2/.receive.$stale_name.1111";
my $new_tmp    = "$box2/.receive.$stale_name.2222";
write_file( $old_tmp, 'abandoned' );
write_file( $new_tmp, 'in flight' );
my $now = time;
utime $now - 7200, $now - 7200, $old_tmp;
utime $now,        $now,        $new_tmp;
( $rc, $out ) = receive( $box2, "has $stale_name" );
ok( $rc == 0 && !-e $old_tmp && -e $new_tmp,
    'a has request sweeps only temporaries older than an hour' )
    or say $out;
unlink $new_tmp;

## -max-bytes counts transfers in progress, not only finished blobs ##
my $tmp_name = bmw_b32( bmw384_bytes('temp') );
write_file( "$box2/.receive.$tmp_name.3333", '0123456789' );
my $fill      = "fill the holder\n";
my $fill_name = bmw_b32( bmw384_bytes($fill) );
( $rc, $out ) = receive( $box2, "put $fill_name " . length $fill,
    $fill, '-max-bytes', length($bytes) + length $fill );
ok( !-e "$box2/$fill_name", 'finished blobs alone fit under the cap' )
    or say $out;
( $rc, $out ) = receive( $box2, "put $fill_name " . length $fill,
    $fill, '-max-bytes', length($bytes) + 10 + length($fill) - 1 );
ok( $rc == 5 && !-e "$box2/$fill_name",
    'a temporary in progress counts against the cap' )
    or say $out;
unlink "$box2/.receive.$tmp_name.3333";

done();

#,,.,,.,,,,.,,,,,,,,,,.,,,..,,.,.,,.,,..,,,,,,..,,...,...,..,,.,,,,,,,,..,,,,,
#CVGF2JVFA6H7ELQOZC3ODMZWUZTNQMIMQVSUTH363WP6YRGGADK5QKWWAOR4YFVGILCCUI4B2QLFE
#\\\|TFE465YBUDK65UCICK3UVQG224X7445THWFSILALQWQCSI2MKUG \ / AMOS7 \ YOURUM ::
#\[7]KSX6RCQQJFOYYXDEJANMGCXSBHVFTSJNI5J4L2ZSJLSRR3WMN4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
