#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## relay with several blobs in flight : all land, a failing worker maps
## nothing

use constant TRUE => 5;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault qw| vault_init |;
use AMOS7::N7FS  qw| make_dirs |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir = "$base/vault";
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );
write_file( "$base/root-pass", "vp\n" );

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

sub open_root {
    open( my $fh, '<', "$base/root-pass" ) or die;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |      => 'vault:main',
        qw| pass_fd |   => fileno($fh),
        qw| vault_dir | => $vdir,
    );
}

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], 'init', '-name', 'p', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
make_dirs("$src/t");
write_file( "$src/t/f$ARG", "parallel $ARG\n" x 50 ) for 1 .. 8;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't',
    "$src/t" );
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );
my ( $from, $to ) = ( "$base/from", "$base/to" );
make_dirs($ARG) for $from, $to;
{
    ## one small node per pack : enough blobs for two workers ##
    local $ENV{'N7FS_TEST_PACK_SIZE'} = 1;
    ( $rc, $out ) = cli(
        ['vp'],       'seal', $disk, '-root-key',
        'vault:main', '-out', $from, '-tree',
        't'
    );
}
ok( $rc == 0, 'source sealed' ) or say $out;
my @blobs = holder_blobs($from);
ok( @blobs > 4, 'the source has several blobs' );

my $root_key = open_root();
{
    local $AMOS7::N7FS::FAULT
        = sub { die "fault\n" if $ARG[0] eq 'relay:after-blob' };
    my $ok = eval {
        AMOS7::N7FS::Seal::relay_nodes(
            qw| root | => $root_key,
            qw| from | => $from,
            qw| to |   => $to
        );
        1;
    };
    ok( !$ok && $EVAL_ERROR =~ m|relay of blob \S+ failed|,
        'a failing worker makes the relay refuse'
    ) or say $EVAL_ERROR;
}
my ( undef, $head ) = AMOS7::N7FS::Seal::_context( $root_key, $to, TRUE );
ok( !defined $head, 'nothing is mapped after a failed parallel relay' );

my $r = AMOS7::N7FS::Seal::relay_nodes(
    qw| root | => $root_key,
    qw| from | => $from,
    qw| to |   => $to
);
( undef, $head, my $map )
    = AMOS7::N7FS::Seal::_context( $root_key, $to, TRUE );
my ( undef, undef, $fmap )
    = AMOS7::N7FS::Seal::_context( $root_key, $from, TRUE );
ok( defined $head && keys $map->{'nodes'}->%* == keys $fmap->{'nodes'}->%*,
    'the second relay maps every node' );

( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $to,            '-tree',     't',
    "$base/rec"
);
ok( $rc == 0 && -f "$base/rec/f8", 'the relayed copy recovers' ) or say $out;

done();

#,,.,,.,.,,,,,.,,,,.,,,,.,,..,,.,,,.,,...,.,,,..,,...,..,,,.,,.,.,..,,,,,,.,.,
#ZFDI2IWUKKNWSY2SUYB6DEI3KC5CNVWWW6FOL2P4DRYM77CABUXVFIZWIAN4B73TVEEFUV4DG3HHC
#\\\|7D6FZB6WRGI3DXAKUS63YLKWEMJRGIO322L3UFCCC3UU5NY3NLS \ / AMOS7 \ YOURUM ::
#\[7]3TCGCJYQ5673TEL24CYLM2YQW6PQ6C6EMOFXHGO7GTFM5QQ6NGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
