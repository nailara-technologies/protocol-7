#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 6 part 1 : relay from an intake holder, receipts bound to a head
## version, draining an intake into its own failure domain.

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

sub blobs {
    my $dir = shift;
    return holder_blobs($dir);
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
write_file( "$src/t/f$ARG", "file $ARG\n" ) for 1 .. 12;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't',
    "$src/t" );
ok( $rc == 0, 'fixture imported' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );

my ( $in, $dur ) = ( "$base/intake", "$base/durable" );
make_dirs($ARG) for $in, $dur;
## the intake shares failure domain a with its durable target ##
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'in', $in, '-domain', 'a',
    '-role', 'intake' );
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'dur', $dur, '-domain', 'a', '-owned' );
ok( $rc == 0, 'intake and durable holder registered' ) or say $out;

( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $in,   '-tree',
    't'
);
ok( $rc == 0, 'tree sealed to the intake holder' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-check', $in, '-root-key', 'vault:main' );
( $rc, $out ) = cli( ['vp'], 'placement', $disk,  '-root-key', 'vault:main' );
ok( $out =~ m|target 1 : \d+ nodes at 0| && $out =~ m|under-replicated|,
    'an intake copy counts zero' )
    or say $out;

( $rc, $out )
    = cli( ['vp'], 'relay', 'dur', 'in', '-root-key', 'vault:main' );
ok( $rc != 0 && $out =~ m|durable|, 'relay into an intake holder is refused' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'relay', 'in', 'dur', '-root-key', 'vault:main',
    '-dry-run' );
ok( $rc == 0 && $out =~ m|would relay 13 nodes| && !blobs($dur),
    'dry run plans every node and copies nothing' )
    or say $out;

## a wrong blob on the intake is refused and the target map stays empty ##
my @in_blobs = blobs($in);
my $in_sub   = holder_sub($in);
my ($victim)
    = grep { substr( read_file("$in_sub/$ARG"), 0, 5 ) eq "P7SP\x01" }
    @in_blobs;
die 'no pack on the intake' if not defined $victim;
my $good = read_file("$in_sub/$victim");
my $bad  = $good;
substr( $bad, 60, 1 ) = chr( ord( substr( $bad, 60, 1 ) ) ^ 1 );
unlink "$in_sub/$victim";
write_file( "$in_sub/$victim", $bad );
( $rc, $out )
    = cli( ['vp'], 'relay', 'in', 'dur', '-root-key', 'vault:main' );
ok( $rc != 0 && $out =~ m|does not match its name|,
    'a changed blob on the source is refused'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', $dur, '-root-key', 'vault:main' );
ok( $rc != 0, 'the target has no head after a refused relay' ) or say $out;
unlink "$in_sub/$victim";
write_file( "$in_sub/$victim", $good );

## a crash after the blobs, before the map : the rerun maps them. the head ##
## is never relayed [ one locator on every holder ] : it is the one blob   ##
## not named by its own checksum  the target is per-root too : the         ##
## interrupted copy lands in its subdir                                    ##
{
    require AMOS7::N7FS::Keys;
    require AMOS7::N7FS::Seal;
    open( my $pass, '<:raw', "$base/pass" ) or die $OS_ERROR;
    my $sroot = AMOS7::N7FS::Keys::root_open(
        qw| path |      => 'vault:main',
        qw| vault_dir | => $vdir,
        qw| pass_fd |   => fileno($pass)
    );
    make_dirs( "$dur/" . AMOS7::N7FS::Seal::root_subdir($sroot) );
}
my $dur_sub = holder_sub($dur);
foreach my $name (@in_blobs) {
    next if $name eq $victim;
    next if bmw_b32( bmw384_bytes( read_file("$in_sub/$name") ) ) ne $name;
    link "$in_sub/$name", "$dur_sub/$name" or die "link : $OS_ERROR";
}
( $rc, $out )
    = cli( ['vp'], 'relay', 'in', 'dur', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 13 nodes| && $out =~ m|with 1 trees|,
    'relay completes after an interrupted copy' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'relay', 'in', 'dur', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 0 nodes|,
    'a second relay has nothing to do'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|dur \[ a \] no fresh receipt|,
    'relayed copies wait for a receipt'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', $dur, '-root-key', 'vault:main' );
ok( $rc == 0, 'the relayed copies pass a holder check' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out !~ m|under-replicated|, 'relayed copies count after the receipt' )
    or say $out;

## new data relayed after the receipt must not count on the old one ##
make_dirs("$src/u");
write_file( "$src/u/g$ARG", "more $ARG\n" ) for 1 .. 3;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 'u',
    "$src/u" );
## unpacked : each node of u is its own content blob ##
{
    local $ENV{'N7FS_TEST_PACK_LIMIT'} = 0;
    ( $rc, $out ) = cli(
        ['vp'],       'seal', $disk, '-root-key',
        'vault:main', '-out', $in,   '-tree',
        'u'
    );
}
my $content_blobs
    = grep { substr( read_file("$in_sub/$ARG"), 0, 5 ) eq "P7SB\x01" }
    blobs($in);
ok( $content_blobs >= 4, 'the second tree is sealed as content blobs' );
( $rc, $out )
    = cli( ['vp'], 'relay', 'in', 'dur', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 4 nodes|, 'second tree relayed' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'in', '-root-key',
    'vault:main', '-dry-run' );
ok( $out =~ m|would drop 0 nodes| && $out =~ m|kept 17 nodes|,
    'an older receipt does not vouch for a newer head'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $dur, '-root-key', 'vault:main' );
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'in', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|dropped 17 nodes| && $out !~ m|kept|,
    'the intake drains into a durable holder of its own domain'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],       'holder-gc',  $in,       '-root-key',
    'vault:main', '-only-root', '-delete', '-grace',
    '0'
);
ok( $rc == 0 && $out =~ m|removed [1-9]|, 'gc frees the intake' ) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $dur,           '-tree',     't',
    "$base/rec"
);
ok( $rc == 0 && read_file("$base/rec/f7") eq "file 7\n",
    'the durable holder recovers the relayed tree'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $dur,           '-tree',     'u',
    "$base/rec-u"
);
ok( $rc == 0 && read_file("$base/rec-u/g2") eq "more 2\n",
    'and the tree relayed second' )
    or say $out;

## a target's reserve is kept as place keeps it ##
make_dirs("$base/full");
( $rc, $out ) = cli(
    ['vp'],       'holder',  'add', 'full',
    "$base/full", '-domain', 'f',   '-reserve',
    '1000000T'
);
( $rc, $out )
    = cli( ['vp'], 'relay', 'dur', 'full', '-root-key', 'vault:main' );
ok( $rc != 0 && $out =~ m|room for 0| && !blobs("$base/full"),
    'relay into a holder past its reserve is refused before copying'
) or say $out;

## over ssh : to a remote holder and back from it ##
my $fake = "$FindBin::Bin/fixtures/n7fs/fake-ssh.sh";
chmod 0755, $fake or die $OS_ERROR;
make_dirs( "$base/remote", 0700 );
write_file( "$base/ssh.log", '' );
$ENV{'N7FS_SSH'}         = $fake;
$ENV{'FAKE_SSH_LOG'}     = "$base/ssh.log";
$ENV{'FAKE_HOLDER_ROOT'} = "$base/remote";
$ENV{'N7FS_SSH_BACKOFF'} = '0,0,0,0,0';
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'rem', 'ssh:fake:/holder',
    '-domain', 'r' );
( $rc, $out )
    = cli( ['vp'], 'relay', 'dur', 'rem', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 17 nodes| && $out =~ m|with 2 trees|,
    'relay to an ssh holder' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', 'ssh:fake:/holder', '-root-key',
    'vault:main' );
ok( $rc == 0, 'the ssh holder passes a check' ) or say $out;
make_dirs("$base/back");
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'back', "$base/back", '-domain', 'k' );
( $rc, $out )
    = cli( ['vp'], 'relay', 'rem', 'back', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|relayed 17 nodes|, 'relay from an ssh holder' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', "$base/back",   '-tree',     'u',
    "$base/rec-back"
);
ok( $rc == 0 && read_file("$base/rec-back/g3") eq "more 3\n",
    'a tree relayed twice over ssh recovers' )
    or say $out;

done();

#,,.,,..,,..,,,,,,.,.,..,,..,,,,,,.,.,,.,,,..,..,,...,.,.,..,,.,,,,.,,...,..,,
#6VWO63F5UZZSECGFHIHK52A2QN32NUI4MDOAYPKU76WELIQZR5VHIX4R2R45TWDEGB6OB4UM4VHSM
#\\\|UUVVULFOABV4GYFP4UTYAJVCFXFRZ2SCUZHXPWXQZWZALSUXC27 \ / AMOS7 \ YOURUM ::
#\[7]KZ7NRLHPJQ2EZUVI4URC5W6ROHGTEPJWYOPHUIK5KJC5YLP36YBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
