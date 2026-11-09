#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## sealing root keys held in a p7-vault, converted to and from passphrase
## files.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault qw| vault_init |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $base = $box->{'base'};
my $vdir = "$base/vault";
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vault-pass', undef, t => 1, m => 1024, p => 1 );

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
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", @args, '-pass-fd', 0,
            '-vault-dir', $vdir )
            or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

my @common = ( '-root',    $root, '-host-dir', $hdir );
my @fast   = ( '-argon-m', 1024, '-argon-t', 1 );
my ( $rc, $out ) = cli( [], @common, 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], @common, 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], @common, 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );
( $rc, $out ) = cli( [], @common, 'init', '-name', 't', '-intent', 'x' );
my ($disk) = grep { !m|^\.| } do { opendir my $d, $root or die; readdir $d };
( $rc, $out ) = cli( [], @common, 'attach', $disk );
write_file( "$src/a", 'first file' );
( $rc, $out ) = cli(
    [],      @common, 'assimilate', '-disk', $disk, '-keep',
    '-tree', 'tr',    $src
);
ok( $rc == 0, 'fixture tree imported' );

( $rc, $out ) = cli( ['vault-pass'], @common, 'root', 'init', 'vault:main' );
ok( $rc == 0,                 'root created inside the vault' );
ok( $out !~ m|[A-Z2-7]{100}|, 'no key material on output' );
( $rc, $out ) = cli( ['vault-pass'], @common, 'root', 'init', 'vault:main' );
ok( $rc != 0 && $out =~ m|already holds|, 'duplicate vault root refused' );
( $rc, $out ) = cli( ['wrong'], @common, 'root', 'init', 'vault:other' );
ok( $rc != 0 && $out =~ m|does not unlock|,
    'wrong vault passphrase refused' );

my $holder = "$base/holder";
( $rc, $out ) = cli(
    ['vault-pass'], @common,      'seal', $disk,
    '-root-key',    'vault:main', '-out', $holder,
    '-all-trees'
);
ok( $rc == 0, 'sealed with a vault root' ) or say $out;
my @listed = do {
    opendir my $d, $hdir or die;
    grep {m|seal-roots|} readdir $d;
};
ok( scalar @listed, 'vault root state lives under the host directory' );

my $file = "$base/root.key";
( $rc, $out ) = cli( [ 'vault-pass', 'file-pass', 'file-pass' ],
    @common, 'root', 'convert', 'vault:main', $file, @fast );
ok( $rc == 0 && -f $file, 'vault root converted to a passphrase file' )
    or say $out;
my $before = join ',', sort do { opendir my $d, $holder or die; readdir $d };
( $rc, $out ) = cli(
    ['file-pass'], @common, 'unseal', $disk,
    '-root-key',   $file,   '-from',  $holder,
    'tr',          "$base/r1"
);
ok( $rc == 0 && read_file_all("$base/r1/a") eq 'first file',
    'data sealed under the vault opens with the converted file'
) or say $out;
ok( $before eq join(
        ',',
        sort do { opendir my $d, $holder or die; readdir $d }
    ),
    'conversion and unseal changed nothing on the holder'
);
my $vstate = ( glob "$hdir/seal-roots/*.state/state" )[0];
my $fstate = "$file.state/state";
ok( -f $fstate, 'state carried to the file' );
ok( read_file_all($vstate) =~ m|"writer":"([^"]+)"|
        && read_file_all($fstate) !~ m|"writer":"\Q$1\E"|,
    'the converted key does not share a writer id'
);
( $rc, $out )
    = cli( ['nope'], @common, 'root', 'convert', $file, "$base/x", @fast );
ok( $rc != 0, 'wrong file passphrase refused on convert' );
( $rc, $out ) = cli( [ 'file-pass', 'vault-pass' ],
    @common, 'root', 'convert', $file, 'vault:second' );
ok( $rc == 0, 'file converted back into the vault' ) or say $out;
( $rc, $out ) = cli(
    ['vault-pass'], @common,        'seal', $disk,
    '-root-key',    'vault:second', '-out', $holder,
    '-all-trees'
);
ok( $rc == 0 && $out =~ m|sealed 0 new|, 'second name is the same root' )
    or say $out;
( $rc, $out ) = cli( ['x'], @common, 'root', 'init', 'vault:bad;name' );
ok( $rc != 0, 'invalid vault name refused' );

sub read_file_all {
    open( my $fh, '<:raw', shift ) or return '';
    local $INPUT_RECORD_SEPARATOR;
    return scalar <$fh>;
}

done();

#,,,,,..,,,..,,.,,,.,,..,,.,.,...,,,,,,,.,..,,..,,...,...,..,,,,.,,,.,..,,,.,,
#SNTY4EXQCJYPRIRVNYV5LWHEVH5LVALUSEMZPVLO2PCOUHIASXVZTIGV6COMNBTY3QVX44FNR3P2M
#\\\|ZVSBVCQ77ZME6AFD6SPBFZ57OQV2E4AU6QVXL257O7KTM4DG7FY \ / AMOS7 \ YOURUM ::
#\[7]7QQ6RUNYIMF4HU64MGEX4XJZR4DXK5BXTX4Z4UUGQG5WDMFB3WAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
