#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 6 : root registries, sealed recovery copies and per-root relays.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use JSON::PP;
use AMOS7::Vault qw| vault_init |;
use AMOS7::N7FS  qw| make_dirs read_file unb32 |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;
use AMOS7::N7FS::Holder qw| holder_read |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;

my $box = sandbox();
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $base          = $box->{'base'};
my $missing_vault = "$base/no-vault-present";

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
        exec(
            $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs",
            '-root',          $root,
            '-host-dir',      $hdir,
            '-vault-dir',     $missing_vault,
            @args,            '-pass-fd',
            0
        ) or exit 99;
    }
    waitpid $pid, 0;
    my $rc = $CHILD_ERROR >> 8;
    open( my $fh, '<:raw', $out ) or die;
    local $INPUT_RECORD_SEPARATOR;
    return ( $rc, scalar <$fh> );
}

sub open_root {
    my ( $key, $pass, $vault_dir ) = @ARG;
    write_file( "$base/open.pass", "$pass\n" );
    open( my $fh, '<:raw', "$base/open.pass" ) or die $OS_ERROR;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |    => $key,
        qw| pass_fd | => fileno($fh),
        defined $vault_dir ? ( qw| vault_dir | => $vault_dir ) : ()
    );
}

sub sealed_registry {
    my ( $sroot, $holder ) = @ARG;
    my ( $head, $hbase ) = AMOS7::N7FS::Seal::_head_locate( $sroot, $holder );
    die "no head on $holder\n" if not defined $head;
    return ( AMOS7::N7FS::Seal::registry_open( $sroot, $head, $hbase ),
        $head, $hbase );
}

my @fast = ( '-argon-m', 1024, '-argon-t', 1 );
my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );

sub make_disk {
    my ( $name, $copies ) = @ARG;
    my %before
        = map { $ARG => 1 } do { opendir( my $d, $root ) or die; readdir $d };
    ( $rc, $out ) = cli( [], 'init', '-name', $name, '-intent', 'stage 6' );
    my ($disk)
        = grep { !$before{$ARG} and !m|^\.| }
        do { opendir( my $d, $root ) or die; readdir $d };
    die "disk $name not found\n" if not defined $disk;
    ( $rc, $out ) = cli( [], 'attach', $disk );
    ( $rc, $out )
        = cli( [], 'category', $disk, 'set', 'two', '-copies', $copies );
    my $tree = "$src/$name";
    make_dirs($tree);
    write_file( "$tree/f$ARG", "$name file $ARG\n" ) for 1 .. 3;
    ( $rc, $out ) = cli(
        [],    'assimilate', '-disk', $disk, '-keep', '-tree',
        $name, '-category',  'two',   $tree
    );
    die $out if $rc;
    return $disk;
}

my $disk_a = make_disk( 'root-a', 2 );
my $disk_b = make_disk( 'root-b', 1 );
( $rc, $out ) = cli( [ 'ap', 'ap' ], 'root', 'init', "$base/a.key", @fast );
( $rc, $out ) = cli( [ 'bp', 'bp' ], 'root', 'init', "$base/b.key", @fast );
ok( $rc == 0 && !-e $missing_vault, 'file roots need no vault directory' )
    or say $out;

my @h = map {"$base/h$ARG"} 1 .. 3;
make_dirs($ARG) for @h;
( $rc, $out ) = cli(
    ['ap'],      'holder',  'add',    'one',
    $h[0],       '-domain', 'fake-a', '-owned',
    '-root-key', "$base/a.key"
);
ok( $rc == 0, 'first file-root holder registered without a vault' )
    or say $out;
( $rc, $out ) = cli(
    ['ap'],                                  'holder',
    'add',                                   'two',
    $h[1],                                   '-domain',
    'fake-b',                                '-quota',
    '400G',                                  '-via',
    'one',                                   '-access',
    'fake-user@fake-host:2222 key=fake-key', '-root-key',
    "$base/a.key"
);
ok( $rc == 0, 'via, access and quota are registered' ) or say $out;

my $registry_path = "$base/a.key.state/registry";
my $registry_text = read_file($registry_path) // '';
ok( ( ( stat $registry_path )[2] & 0777 ) == 0600,
    'the file-root registry is 0600' );
ok( $registry_text !~ m|[{}]|
        && $registry_text =~ m|^holder\.two\.spec\s+: |m,
    'the registry is config text, not json'
);
ok( $registry_text =~ m|^holder\.two\.quota\s+: 400G$|m,
    'sizes are written in the largest exact unit'
);
my $aligned = 1;

foreach my $block ( split m|\n\n|, $registry_text ) {
    my @separators = map { index( $ARG, ':' ) }
        grep {length} split m|\n|, $block;
    $aligned = 0 if grep { $ARG != $separators[0] } @separators;
}
ok( $aligned, 'separators are vertically aligned within every block' );
my $equals = $registry_text =~ s|\s+:\s+|=|gr;
write_file( $registry_path, $equals );
( $rc, $out ) = cli( ['ap'], 'holder', 'list', '-root-key', "$base/a.key" );
ok( $rc == 0
        && $out =~ m|^one .*fake-a|m
        && $out =~ m|access=fake-user\@fake-host:2222 key=fake-key|,
    'the reader accepts equals separators and access hints'
) or say $out;
write_file( $registry_path, $registry_text );

( $rc, $out ) = cli( ['ap'], 'place', $disk_a, '-root-key', "$base/a.key" );
ok( $rc == 0 && !-e $missing_vault,
    'place works under a file root with no vault present' )
    or say $out;
( $rc, $out )
    = cli( ['ap'], 'placement', $disk_a, '-root-key', "$base/a.key" );
ok( $rc == 0, 'placement reads the file-root registry' ) or say $out;
( $rc, $out )
    = cli( ['ap'], 'relay', 'one', 'two', '-root-key', "$base/a.key" );
ok( $rc == 0 && !-e $missing_vault,
    'relay works under a file root with no vault present' )
    or say $out;
( $rc, $out )
    = cli( ['ap'], 'holder-drain', $disk_a, 'one', '-root-key',
    "$base/a.key", '-dry-run' );
ok( $rc == 0, 'holder-drain needs no vault for a file root' ) or say $out;
( $rc, $out )
    = cli( ['ap'], 'holder-prune', 'one', '-root-key',
    "$base/a.key", '-dry-run' );
ok( $rc == 0, 'holder-prune needs no vault for a file root' ) or say $out;

my $a = open_root( "$base/a.key", 'ap' );
my ( $reg_one, undef, undef ) = sealed_registry( $a, $h[0] );
my ( $reg_two, undef, undef ) = sealed_registry( $a, $h[1] );
ok( ( keys %{$reg_one} ) == 2
        && ( keys %{$reg_two} ) == 2
        && $reg_one->{'two'}{'via'} eq 'one'
        && $reg_two->{'two'}{'access'} =~ m|fake-host|,
    'both holders carry the complete sealed config registry'
);

( $rc, $out ) = cli(
    ['ap'], 'holder',  'add',    'three',
    $h[2],  '-domain', 'fake-c', '-root-key',
    "$base/a.key"
);
ok( $rc == 0, 'a registry change succeeds' ) or say $out;
( $reg_one, undef, undef ) = sealed_registry( $a, $h[0] );
( $reg_two, undef, undef ) = sealed_registry( $a, $h[1] );
ok( exists $reg_one->{'three'} && exists $reg_two->{'three'},
    'a registry change reaches every existing holder head'
);
( $rc, $out )
    = cli( ['ap'], 'seal', $disk_a, '-root-key', "$base/a.key",
    '-out', $h[2], '-all-trees' );
ok( $rc == 0, 'the new holder receives its first head' ) or say $out;
my ( $reg_three, undef, undef ) = sealed_registry( $a, $h[2] );
ok( ( keys %{$reg_three} ) == 3,
    'a new holder receives the complete registry on its first seal' );

make_dirs("$base/clean");
write_file( "$base/clean/root.key", read_file("$base/a.key") );
chmod 0600, "$base/clean/root.key";
make_dirs("$base/clean-host");
( $rc, $out ) = cli(
    ['ap'],             '-host-dir',
    "$base/clean-host", 'seal-recover',
    '-root-key',        "$base/clean/root.key",
    '-from',            $h[0],
    '-holders'
);
ok( $rc == 0
        && $out =~ m|^one |m
        && $out =~ m|^two |m
        && $out =~ m|^three |m
        && $out =~ m|fake-host|,
    'a clean machine and one holder print all other holders'
) or say $out;
ok( !-e "$base/clean/root.key.state/registry",
    'printing the sealed registry does not import it'
);
( $rc, $out ) = cli(
    ['ap'],             '-host-dir',
    "$base/clean-host", 'seal-recover',
    '-root-key',        "$base/clean/root.key",
    '-from',            $h[0],
    '-import-holders'
);
ok( $rc == 0 && -f "$base/clean/root.key.state/registry",
    'import-holders writes the clean file-root authority'
) or say $out;
( $rc, $out ) = cli(
    ['ap'],             '-host-dir',
    "$base/clean-host", 'seal-recover',
    '-root-key',        "$base/clean/root.key",
    '-from',            $h[0],
    '-all-holders',     '-list'
);
ok( $rc == 0
        && $out =~ m|\Q$h[0]\E|
        && $out =~ m|\Q$h[1]\E|
        && $out =~ m|\Q$h[2]\E|,
    'all-holders uses the imported sealed holder list'
) or say $out;

my ( undef, $registry_head, $registry_base ) = sealed_registry( $a, $h[0] );
my $desc         = $registry_head->{'registry'};
my $blob         = holder_read( $registry_base, $desc->{'blob'} );
my $wrong_domain = eval {
    AMOS7::N7FS::Seal::open_sealed_bytes(
        $a->{'keys'}, substr( $blob, 32 ),
        qw| map |,    unb32( $desc->{'id'} ),
        $desc->{'version'}
    );
};
ok( !defined $wrong_domain && $EVAL_ERROR,
    'a registry blob never opens under the map domain' );

my $far = "$base/far";
make_dirs($far);
( $rc, $out ) = cli(
    ['ap'], 'holder',  'add',      'far',
    $far,   '-domain', 'fake-far', '-root-key',
    "$base/a.key"
);
( $rc, $out ) = cli(
    ['bp'], 'holder',  'add',        'one',
    $h[0],  '-domain', 'fake-b-one', '-root-key',
    "$base/b.key"
);
( $rc, $out ) = cli(
    ['bp'], 'holder',  'add',        'far',
    $far,   '-domain', 'fake-b-far', '-root-key',
    "$base/b.key"
);
( $rc, $out )
    = cli( ['bp'], 'seal', $disk_b, '-root-key', "$base/b.key",
    '-out', $h[0], '-all-trees' );
ok( $rc == 0, 'a second root shares the source and target specs' )
    or say $out;
( $rc, $out )
    = cli( ['ap'], 'relay', 'one', 'far', '-root-key',
    "$base/a.key", '-list' );
ok( $rc == 0, 'the first root writes its relay list' ) or say $out;
( $rc, $out )
    = cli( ['bp'], 'relay', 'one', 'far', '-root-key',
    "$base/b.key", '-list' );
ok( $rc == 0, 'the second root writes its relay list' ) or say $out;
my @lists   = glob "$h[0]/relay-list.*";
my @pending = glob "$hdir/relay-pending/*.json";
ok( @lists == 2 && @pending == 2 && $lists[0] ne $lists[1],
    'two roots keep separate relay lists and pending names'
);
my @pending_blobs = sort
    map { join ',', @{ JSON::PP::decode_json( read_file($ARG) )->{'blobs'} } }
    @pending;
ok( $pending_blobs[0] ne $pending_blobs[1],
    'the two pending files retain their own root\'s blob names' );

## a vault root keeps the note as authority and still seals the config copy ##
my $vdir = "$base/sandbox-vault";
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );
$missing_vault = $vdir;
my $disk_v = make_disk( 'vault-root', 1 );
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );
( $rc, $out ) = cli(
    ['vp'], 'holder',  'add',        'vault-one',
    $h[1],  '-domain', 'fake-vault', '-root-key',
    'vault:main'
);
( $rc, $out )
    = cli( ['vp'], 'seal', $disk_v, '-root-key', 'vault:main',
    '-out', $h[1], '-all-trees' );
ok( $rc == 0, 'a vault root seals with its registry in the note' )
    or say $out;
my $v = open_root( 'vault:main', 'vp', $vdir );
my ( $reg_vault, undef, undef ) = sealed_registry( $v, $h[1] );
ok( exists $reg_vault->{'vault-one'} && !-e "$v->{'path'}.state/registry",
    'a vault root has no file authority but seals the registry copy'
);

done();

#,,..,,.,,.,,,.,.,.,.,,,.,.,.,,,.,.,.,.,,,...,..,,...,...,,.,,...,,..,...,...,
#AOQCNO4DV7U3WQ7XZAQLECTCEXZY337HRHRAU3ZQKCHUNJDOQZPIDNE6MSJW56FIRWOXRHGJBG7GI
#\\\|HA3SY4MCT4XZMK44R54FE3S4Z47INHUZXGOISLNOVT7P6O5TAS6 \ / AMOS7 \ YOURUM ::
#\[7]GVQ6PFY2JPYDOXBIXWOROSCIGV6FP2PY2V43CZACACRTGTG2DUDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
