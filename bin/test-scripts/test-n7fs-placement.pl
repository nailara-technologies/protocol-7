#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## stage 5 : vault holder registry, receipts, placement report and place.

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use JSON::PP;
use AMOS7::Vault     qw| vault_init |;
use AMOS7::N7FS      qw| make_dirs read_file b32 |;
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

my ( $rc, $out ) = cli( [], 'keygen', "$hdir/host.key" );
( $rc, $out ) = cli( [], 'keygen', "$hdir/parent.key" );
( $rc, $out ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $out );

## re-signs a holder's receipt with its time moved back [ unreachable grace ]
sub age_receipt {
    my ( $spec, $ntime ) = @ARG;
    require AMOS7::N7FS::Holder;
    require AMOS7::N7FS::Sign;
    my $json            = JSON::PP->new->utf8->canonical;
    my ($root_receipts) = glob "$hdir/receipts/*";
    my $path            = "$root_receipts/"
        . bmw_b32(
        bmw384_bytes(
            "p7 n7fs receipt v1\0"
                . AMOS7::N7FS::Holder::holder_canonical($spec)
        )
        ) . '.receipt';
    my $data = $json->decode( read_file($path) );
    $data->{'receipt'}{'time'} -= $ntime;
    my $signer = AMOS7::N7FS::Sign::key_file_signer("$hdir/host.key");
    $data->{'sig'}
        = b32( $signer->sign( $json->encode( $data->{'receipt'} ) ) );
    write_file( $path, $json->encode($data) );
    return;
}
( $rc, $out ) = cli( [], 'init', '-name', 't', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk );
( $rc, $out ) = cli( [], 'category', $disk, 'set', 'two', '-copies', 2 );
my $tree = "$src/t";
make_dirs($tree);
write_file( "$tree/f$ARG", "file $ARG\n" ) for 1 .. 20;
( $rc, $out ) = cli(
    [],  'assimilate', '-disk', $disk, '-keep', '-tree',
    't', '-category',  'two',   $tree
);
ok( $rc == 0, 'fixture imported in a two-copy category' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'root', 'init', 'vault:main' );

my @h = map {"$base/h$ARG"} 1 .. 4;
make_dirs($ARG) for @h;
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'one', $h[0], '-domain', 'a', '-owned' );
ok( $rc == 0, 'holder added to the vault registry' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'holder', 'add', 'two', $h[1], '-domain', 'a' );
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'three', $h[2], '-domain', 'b' );
( $rc, $out ) = cli(
    ['vp'], 'holder', 'add', 'four', $h[3], '-domain',
    'c',    '-role',  'intake'
);
( $rc, $out ) = cli( ['vp'], 'holder', 'list' );
ok( $rc == 0 && $out =~ m|^one durable a owned|m && $out =~ m|^four intake|m,
    'registry lists the holders'
);
( $rc, $out ) = cli( ['vp'], 'holder', 'add', 'bad', $h[0] );
ok( $rc != 0, 'a holder without a domain is refused' );

( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|category two target 2 : \d+ nodes at 0|,
    'report shows nothing placed yet' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $rc == 0
        && $out =~ m|would place \d+ nodes on one|
        && $out =~ m|would place \d+ nodes on three|
        && $out !~ m|on two|
        && $out !~ m|on four|,
    'plan uses two domains, owned first, skips the '
        . 'second holder in a domain and the intake holder'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
ok( $rc == 0
        && $out =~ m|placed \d+ nodes on one|
        && $out =~ m|checked one|
        && $out =~ m|checked three|,
    'place seals the missing copies and checks every holder it wrote'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|one \[ a \] counted \[ sampled receipt \]|
        && $out =~ m|covered 20, pending 0, coverage sampled|,
    'the receipt follows the head : the copies count at once'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $rc == 0 && $out !~ m|would place [1-9]|,
    'a checked copy is not placed a second time'
) or say $out;

foreach my $i ( 0 .. 2 ) {
    ## a drain relies on full-coverage receipts : check with -full ##
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', '-full', $h[$i], '-root-key',
        'vault:main' );
    say "        check $i : $out" if $rc != 0;
}
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|category two target 2 : \d+ nodes at 2| && $out !~ m|under-rep|,
    'every node reaches its target after receipts'
) or say $out;

( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $h[2],          '-tree',     't',
    "$base/rec"
);
ok( $rc == 0 && -f "$base/rec/f7", 'a placed holder recovers the tree' )
    or say $out;

( $rc, $out ) = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
ok( $rc == 0 && $out !~ m|placed|, 'a second place has nothing to do' )
    or say $out;
## draining : 'one' and 'three' each hold every node [ target 2 ] ##
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'one', '-root-key',
    'vault:main', '-dry-run' );
ok( $out =~ m|kept 20 nodes|,
    'drain keeps nodes that would fall below their target' )
    or say $out;
make_dirs("$base/h7");
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'five', "$base/h7", '-domain', 'f' );
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main',
    '-exclude', 'one' );
ok( $out =~ m|placed \d+ nodes on five|,
    'place with -exclude fills the new holder for a move' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'one', '-root-key',
    'vault:main', '-dry-run' );
ok( $out =~ m|kept|, 'a copy without a receipt does not count yet' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', "$base/h7", '-root-key',
    'vault:main' );
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'one', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|dropped [1-9]\d* nodes| && $out !~ m|kept|,
    'after a receipt elsewhere the holder drains' )
    or say $out;
## the default grace keeps them : the drained blobs are younger than a day ##
( $rc, $out )
    = cli( ['vp'], 'holder-gc', $h[0], '-root-key', 'vault:main',
    '-only-root' );
ok( $rc == 0 && $out =~ m|would remove 0| && $out =~ m|young|,
    'gc never touches a blob younger than the grace age'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],       'holder-gc',  $h[0],     '-root-key',
    'vault:main', '-only-root', '-delete', '-grace',
    '0'
);
ok( $rc == 0 && $out =~ m|removed [1-9]|, 'gc frees the drained blobs' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|category two target 2 : \d+ nodes at 2| && $out !~ m|under-rep|,
    'targets still met after drain and gc'
) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', "$base/h7",     '-tree',     't',
    "$base/rec7"
);
ok( $rc == 0 && -f "$base/rec7/f7", 'the new holder recovers the tree' )
    or say $out;

( $rc, $out ) = cli( ['vp'], 'holder', 'remove', 'three' );
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|under-replicated|, 'removing a holder shows the shortfall' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'], 'holder', 'add', 'small', "$base/h5", '-domain',
    'd',    '-quota', '10'
);
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $out !~ m|on small|, 'quota keeps a holder from filling' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'], 'holder',   'add', 'full', "$base/h6", '-domain',
    'e',    '-reserve', '1000000T'
);
make_dirs("$base/h6");
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $out !~ m|on full|,
    'a holder whose reserve exceeds its free space receives nothing' )
    or say $out;
## holder-check takes a registered name as well as a spec ##
( $rc, $out )
    = cli( ['vp'], 'holder-check', 'five', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|holder ok| && $out =~ m|receipt written|,
    'holder-check by registry name' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', 'nosuch', '-root-key', 'vault:main' );
ok( $rc != 0 && $out =~ m|no holder named nosuch|,
    'an unknown name is refused' )
    or say $out;
## rename : one registry write, a new spec carries the pin ##
( $rc, $out ) = cli( ['vp'], 'holder', 'rename', 'two', 'two-b' );
( $rc, my $listed ) = cli( ['vp'], 'holder', 'list' );
ok( $rc == 0 && $listed =~ m|^two-b durable a|m && $listed !~ m|^two |m,
    'rename keeps the entry under the new name' )
    or say $listed;
( $rc, $out ) = cli( ['vp'], 'holder', 'rename', 'two-b', 'one' );
ok( $rc != 0 && $out =~ m|exists already|,
    'rename onto a taken name is refused'
) or say $out;
make_dirs("$base/h8");
( $rc, $out ) = cli(
    ['vp'], 'holder', 'rename',   'five',
    'five', '-spec',  "$base/h8", '-root-key',
    'vault:main'
);
ok( $rc != 0 && $out =~ m|no sealed head under the new spec|,
    'a new spec without the holder\'s head is refused'
) or say $out;
system( 'cp', '-a', "$base/h7/.", "$base/h8/" ) == 0 or die;
( $rc, $out ) = cli(
    ['vp'], 'holder', 'rename',   'five',
    'five', '-spec',  "$base/h8", '-root-key',
    'vault:main'
);
ok( $rc == 0 && $out =~ m|matches the pin|,
    'a new spec reaching the same head moves the pin'
) or say $out;
( $rc, $out ) = cli(
    ['vp'], 'holder', 'rename',   'five',
    'five', '-spec',  "$base/h7", '-root-key',
    'vault:main'
);
( $rc, $listed ) = cli( ['vp'], 'holder', 'list' );
ok( $rc == 0 && $listed =~ m|^five .*h7|m, 'rename back to the first spec' )
    or say $listed;

## a second disk on the same holder : drain touches only its own disk ##
( $rc, $out ) = cli( [], 'init', '-name', 'u', '-intent', 'y' );
my ($disk2)
    = grep { !m|^\.| and $ARG ne $disk }
    do { opendir( my $d, $root ) or die; readdir $d };
( $rc, $out ) = cli( [], 'attach', $disk2 );
my $tree2 = "$src/u";
make_dirs($tree2);
write_file( "$tree2/g$ARG", "other $ARG\n" ) for 1 .. 5;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk2, '-keep', '-tree', 'u', $tree2 );
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk2,     '-root-key',
    'vault:main', '-out', "$base/h7", '-tree',
    'u'
);
ok( $rc == 0, 'second disk sealed to the same holder' ) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'five', '-root-key', 'vault:main' );
ok( $rc == 0, 'drain of the first disk on the shared holder runs' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'],       'holder-gc',  "$base/h7", '-root-key',
    'vault:main', '-only-root', '-delete'
);
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', "$base/h7",     '-tree',     'u',
    "$base/rec-u"
);
ok( $rc == 0 && -f "$base/rec-u/g3", 'the other disk\'s tree still recovers' )
    or say $out;
## one holder-writing command at a time per host ##
{
    require Fcntl;
    open( my $lock, '>>', "$hdir/holders.lock" ) or die;
    flock( $lock, Fcntl::LOCK_EX() )             or die;
    ( $rc, $out )
        = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main' );
    ok( $rc != 0 && $out =~ m|another n7fs command is writing|,
        'place waits for no one : refused while another writer holds the lock'
    ) or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'holder-gc', $h[0], '-root-key',
        'vault:main', '-only-root', '-delete' );
    ok( $rc != 0, 'gc is refused while another writer holds the lock' )
        or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', 'five', '-root-key', 'vault:main' );
    ok( $rc != 0 && $out =~ m|another n7fs command is writing|,
        'holder-check takes the holder-writer lock'
    ) or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main',
        '-dry-run' );
    ok( $rc == 0, 'a dry run needs no lock' ) or say $out;
    close $lock;
}
( $rc, $out ) = cli( ['wrong'], 'holder', 'list' );
ok( $rc != 0, 'registry needs the vault passphrase' );

## review finding 4 : a sampled receipt never vouches for a drain ##
make_dirs("$base/h9");
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'six', "$base/h9", '-domain', 'g' );
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main',
    '-exclude', 'five' );
ok( $rc == 0 && $out =~ m|placed \d+ nodes on one|,
    'a move target receives the copies' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', 'one', '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|coverage sampled|,
    'a plain check records a sampled receipt'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'five', '-root-key',
    'vault:main', '-dry-run' );
ok( $rc == 0
        && $out !~ m|would drop [1-9]|
        && $out =~ m|lack a full-coverage receipt|,
    'drain refuses to rely on a sampled receipt'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|one \[ a \] counted \[ sampled receipt \]|,
    'the placement report states the coverage'
) or say $out;
## a receipt without a coverage field reads as sampled ##
{
    require AMOS7::N7FS::Holder;
    require AMOS7::N7FS::Sign;
    my $json            = JSON::PP->new->utf8->canonical;
    my $spec1           = AMOS7::N7FS::Holder::holder_canonical("$base/h1");
    my ($root_receipts) = glob "$hdir/receipts/*";
    my $rpath
        = "$root_receipts/"
        . bmw_b32( bmw384_bytes( "p7 n7fs receipt v1\0" . $spec1 ) )
        . '.receipt';
    my $data = $json->decode( read_file($rpath) );
    delete $data->{'receipt'}{'coverage'};
    my $signer = AMOS7::N7FS::Sign::key_file_signer("$hdir/host.key");
    $data->{'sig'}
        = b32( $signer->sign( $json->encode( $data->{'receipt'} ) ) );
    write_file( $rpath, $json->encode($data) );
    ( $rc, $out )
        = cli( ['vp'], 'holder-drain', $disk, 'five', '-root-key',
        'vault:main', '-dry-run' );
    ok( $rc == 0
            && $out !~ m|would drop [1-9]|
            && $out =~ m|lack a full-coverage receipt|,
        'an old receipt without a coverage field reads as sampled'
    ) or say $out;
}
## a keyless scrub is a full-coverage check as well ##
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-scrub', 'one', '-root-key',
    'vault:main' );
ok( $rc == 0 && $out =~ m|coverage full|,
    'holder-check -scrub records a full receipt'
) or say $out;
## five stays counted through the disk-2 seal [ the incremental receipt ] , so
## the first move place already filled one and six : both count now
( $rc, $out )
    = cli( ['vp'], 'holder-check', 'five', '-root-key', 'vault:main' );
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|six \[ g \] counted .* covered 20, pending 0|
        && $out =~ m|one .* covered 20, pending 0, coverage full|,
    'the move targets hold their copies and place\'s own checks count them'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-scrub', 'six', '-root-key',
    'vault:main' );
ok( $rc == 0 && $out =~ m|coverage full|,
    'the second target passes a keyless scrub'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'five', '-root-key',
    'vault:main', '-dry-run' );
ok( $rc == 0 && $out =~ m|would drop [1-9]|,
    'two full receipts vouch for the drain'
) or say $out;

## sampling draws by bytes : the large pack takes the sample ##
{
    require AMOS7::N7FS::Keys;
    require AMOS7::N7FS::Seal;
    my $bigsrc = "$src/big";
    make_dirs($bigsrc);
    write_file( "$bigsrc/s$ARG", "small $ARG\n" ) for 1 .. 50;
    write_file( "$bigsrc/large", 'L' x ( 3 * 1024 * 1024 ) );
    ( $rc, $out )
        = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree',
        'big', $bigsrc );
    my $bigholder = "$base/bigholder";
    make_dirs($bigholder);
    ( $rc, $out ) = cli(
        ['vp'],       'seal', $disk,      '-root-key',
        'vault:main', '-out', $bigholder, '-tree',
        'big'
    );
    ok( $rc == 0, 'a tree with one large file sealed' ) or say $out;
    open( my $pass, '<:raw', "$base/pass" )             or die $OS_ERROR;
    my $sroot = AMOS7::N7FS::Keys::root_open(
        qw| path |      => 'vault:main',
        qw| vault_dir | => $vdir,
        qw| pass_fd |   => fileno($pass)
    );
    my ( undef, undef, $bmap )
        = AMOS7::N7FS::Seal::_context( $sroot, $bigholder, 1 );
    my ($big) = sort {
        $bmap->{'nodes'}{$b}{'length'} <=> $bmap->{'nodes'}{$a}{'length'}
    } keys $bmap->{'nodes'}->%*;
    my ($first_small) = sort grep { $ARG ne $big } keys $bmap->{'nodes'}->%*;
    ## a position inside the large node, from the cumulative byte ranges ##
    my ( $big_at, $seen ) = ( 0, 0 );
    foreach my $a ( sort keys $bmap->{'nodes'}->%* ) {
        $big_at = $seen + 100 if $a eq $big;
        $seen += $bmap->{'nodes'}{$a}{'length'} // 0;
    }
    my $r = AMOS7::N7FS::Seal::holder_check(
        qw| root |     => $sroot,
        qw| holder |   => $bigholder,
        qw| samples |  => 4,
        qw| coverage | => 'sampled',
        ## a fixed position deep inside the large node, every roll ##
        qw| rng | => sub { pack qw| Q> |, $big_at },
    );
    ok( ( keys $r->{'by_node'}->%* ) == 1 && exists $r->{'by_node'}{$big},
        'byte-weighted sampling picks the large pack' )
        or say $out;
    $r = AMOS7::N7FS::Seal::holder_check(
        qw| root |     => $sroot,
        qw| holder |   => $bigholder,
        qw| samples |  => 4,
        qw| coverage | => 'sampled',
        ## position 5 is inside the first small node ##
        qw| rng | => sub { pack qw| Q> |, 5 },
    );
    ok( ( keys $r->{'by_node'}->%* ) == 1
            && exists $r->{'by_node'}{$first_small},
        'a low position picks a small node, not a random one'
    ) or say $out;
    ## a zero-filled blob of the right size is caught ##
    my @bblobs = sort
        keys %{ { map { $ARG->{'blob'} => 1 } values $bmap->{'nodes'}->%* } };
    my $victim = $bblobs[0];
    ## a per-root holder keeps the blobs in the root's subdirectory ##
    my $victim_f
        = "$bigholder/" . AMOS7::N7FS::Seal::root_subdir($sroot) . "/$victim";
    my $saved = read_file($victim_f);
    write_file( $victim_f, "\0" x length $saved );
    ( $rc, $out )
        = cli( ['vp'], 'holder-scrub', $bigholder, '-root-key',
        'vault:main' );
    ok( $rc == 1 && $out =~ m|bad : $victim|, 'holder-scrub catches the rot' )
        or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', '-full', $bigholder,
        '-root-key', 'vault:main' );
    ok( $rc != 0, 'holder-check -full catches the rot' ) or say $out;
    ## -sizes-only still writes a receipt, with its coverage stated ##
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', '-sizes-only', $bigholder,
        '-root-key', 'vault:main' );
    ok( $rc == 0 && $out =~ m|coverage sizes-only|,
        '-sizes-only records its coverage'
    ) or say $out;
    write_file( $victim_f, $saved );
    ( $rc, $out )
        = cli( ['vp'], 'holder-scrub', $bigholder, '-root-key',
        'vault:main' );
    ok( $rc == 0, 'the holder is clean again after the restore' )
        or say $out;
    ## register it so the finding-3 blocks below see the big tree counted ##
    ( $rc, $out )
        = cli( ['vp'], 'holder', 'add', 'xbig', $bigholder, '-domain', 'k' );
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', 'xbig', '-root-key', 'vault:main' );
}

## review finding 3 : incremental receipts  a dedicated holder : a commit  ##
## that only ADDS entries leaves the covered part unchanged -- the old     ##
## receipt stays valid for the old entries and the new ones are pending. a ##
## digest mismatch voids the whole receipt                                 ##
make_dirs("$base/h12");
my $h12 = "$base/h12";
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'twelve', $h12, '-domain', 'j' );
my $tree_a = "$src/ta";
make_dirs($tree_a);
write_file( "$tree_a/x$ARG", "alpha $ARG\n" ) for 1 .. 3;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 'ta',
    $tree_a );
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h12,  '-tree',
    'ta'
);
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $h12, '-root-key', 'vault:main' );
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|twelve \[ j \] counted : 3 nodes|
        && $out =~ m|covered 3, pending 0, coverage full|,
    'a full receipt covers the sealed holder'
) or say $out;
my $tree_b = "$src/tb";
make_dirs($tree_b);
write_file( "$tree_b/y$ARG", "beta $ARG\n" ) for 1 .. 2;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 'tb',
    $tree_b );
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h12,  '-tree',
    'tb'
);
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|twelve \[ j \] counted : 5 nodes|
        && $out =~ m|covered 3, pending 2, coverage full|,
    'an add-only commit keeps the receipt : old covered, new pending'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $rc == 0 && $out !~ m|would place [1-9]|,
    'the uncovered entries are pending : place sends no second copy' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $h12, '-root-key', 'vault:main' );
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|twelve .* covered 5, pending 0, coverage full|,
    'a new check covers the grown head' )
    or say $out;
## dropping a covered entry voids the receipt : the covered digest no longer
## matches, and the holder counts zero until its next check
( $rc, $out ) = cli( [], 'trees', $disk );
my ($mani_a) = $out =~ m|^ta (\S+)|m;
require AMOS7::N7FS::Disk;
require AMOS7::N7FS::Seal;
my $tree_id = AMOS7::N7FS::Disk::disk_read_id(
    qw| root | => $root,
    qw| disk | => $disk
);
my ($file_a) = AMOS7::N7FS::Seal::_manifest_files( $tree_id, $mani_a );
( $rc, $out )
    = cli( ['vp'], 'shred', $disk, '-root-key',
    'vault:main', '-out', $h12, $file_a );
ok( $rc == 0, 'a shred drops one entry from the holder\'s map' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|twelve \[ j \] no fresh receipt : 4 nodes|,
    'a dropped covered entry voids the receipt'
) or say $out;
ok( $out =~ m|twelve .* covered 0, pending 4|,
    'a void receipt counts no copy of its old covered entries' )
    or say $out;
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h12,  '-tree',
    'ta'
);
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $h12, '-root-key', 'vault:main' );
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|twelve .* covered 5, pending 0, coverage full|,
    'resealing the dropped entry and a new check restore the count'
) or say $out;
## an old receipt without the covered digest binds the exact head version :
## the same add-only commit that kept the new receipt now voids it
{
    my $json            = JSON::PP->new->utf8->canonical;
    my ($root_receipts) = glob "$hdir/receipts/*";
    my $rpath           = "$root_receipts/"
        . bmw_b32(
        bmw384_bytes(
            "p7 n7fs receipt v1\0"
                . AMOS7::N7FS::Holder::holder_canonical($h12)
        )
        ) . '.receipt';
    my $data = $json->decode( read_file($rpath) );
    delete $data->{'receipt'}{$_} for qw| covered covered_nodes |;
    my $signer = AMOS7::N7FS::Sign::key_file_signer("$hdir/host.key");
    $data->{'sig'}
        = b32( $signer->sign( $json->encode( $data->{'receipt'} ) ) );
    write_file( $rpath, $json->encode($data) );
    ( $rc, $out )
        = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
    ok( $out =~ m|twelve \[ j \] counted : 5 nodes|
            && $out =~ m|covered 5, pending 0|,
        'an old receipt at the exact head version still counts every entry'
    ) or say $out;
    my $tree_c = "$src/tc";
    make_dirs($tree_c);
    write_file( "$tree_c/z1", "gamma 1\n" );
    ( $rc, $out )
        = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 'tc',
        $tree_c );
    ( $rc, $out ) = cli(
        ['vp'],       'seal', $disk, '-root-key',
        'vault:main', '-out', $h12,  '-tree',
        'tc'
    );
    ( $rc, $out )
        = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
    ok( $out =~ m|twelve \[ j \] no fresh receipt : 6 nodes|,
        'an old receipt without a digest keeps the exact-version rule'
    ) or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', '-full', $h12, '-root-key',
        'vault:main' );
    ( $rc, $out )
        = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
    ok( $out =~ m|twelve .* covered 6, pending 0, coverage full|,
        'a new receipt covers the grown head again' )
        or say $out;
}

## finding 3 : place ends with a holder-check of every holder it wrote ;
## -no-check leaves the copies pending instead
my $h11 = "$base/h11";
make_dirs($h11);
( $rc, $out )
    = cli( ['vp'], 'holder', 'add', 'eleven', $h11, '-domain', 'i' );
my $tree5 = "$src/t5";
make_dirs($tree5);
write_file( "$tree5/q$ARG", "grace $ARG\n" ) for 1 .. 3;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't5', $tree5 );
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key',
    'vault:main', '-exclude', 'one', '-no-check' );
ok( $rc == 0 && $out =~ m|placed 3 nodes on eleven| && $out !~ m|checked|,
    '-no-check places without the holder-check' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|eleven \[ i \] no fresh receipt|,
    '-no-check leaves the new copies pending'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $rc == 0 && $out !~ m|would place [1-9]|,
    'pending copies are not re-placed'
) or say $out;
my $tree6 = "$src/t6";
make_dirs($tree6);
write_file( "$tree6/r$ARG", "checked $ARG\n" ) for 1 .. 2;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't6', $tree6 );
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key',
    'vault:main', '-exclude', 'one' );
ok( $rc == 0
        && $out =~ m|placed 2 nodes on eleven|
        && $out =~ m|checked eleven|,
    'place checks every holder it wrote, and the receipt covers all of it'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|eleven .* covered 5, pending 0, coverage sampled|,
    'the check follows the head, pending entries included'
) or say $out;

## an unreachable holder with a fresh receipt keeps counting its covered
## entries for the grace : no re-placement, and it never counts for drain
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h[1], '-tree',
    't5'
);
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $h[1], '-root-key',
    'vault:main' );
rename $h11, "$base/h11.away" or die "rename away : $OS_ERROR";
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|eleven \[ i \] unreachable, counted \[ receipt \d+.|
        && $out =~ m|eleven .* covered 5, pending 0, coverage sampled|,
    'within the grace the covered entries keep counting'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $rc == 0 && $out !~ m|would place [1-9]|,
    'nothing is re-placed while the grace holder is counted' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'two-b', '-root-key',
    'vault:main', '-dry-run' );
ok( $rc == 0 && $out !~ m|would drop [1-9]| && $out =~ m|kept 3 nodes|,
    'drain never trusts an unreachable holder, grace or not'
) or say $out;
## past the grace the same receipt counts zero again
require AMOS7::NTIME;
age_receipt( $h11, AMOS7::NTIME::parse_y_age('2Y2') );
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|eleven \[ i \] unreachable : |,
    'after the grace the receipt no longer counts'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'place', $disk, '-root-key', 'vault:main', '-dry-run' );
ok( $rc == 0 && $out =~ m|would place 2 nodes on one|,
    'after the grace the sole copies are re-placed elsewhere'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main',
    '-unreachable-grace', '3Y2' );
ok( $out =~ m|eleven \[ i \] unreachable, counted|,
    '-unreachable-grace extends the counting window'
) or say $out;
rename "$base/h11.away", $h11 or die "rename back : $OS_ERROR";
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $h11, '-root-key', 'vault:main' );
ok( $rc == 0, 'the holder answers again and a new check covers it' )
    or say $out;

## drain never trusts a partially covered holder for its uncovered entries : a
## full receipt for version V proves exactly what V covered
my $tree7 = "$src/t7";
make_dirs($tree7);
write_file( "$tree7/s$ARG", "partial $ARG\n" ) for 1 .. 2;
( $rc, $out )
    = cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't7', $tree7 );
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h11,  '-tree',
    't7'
);
( $rc, $out ) = cli(
    ['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h[1], '-tree',
    't7'
);
( $rc, $out ) = cli( ['vp'], 'placement', $disk, '-root-key', 'vault:main' );
ok( $out =~ m|eleven .* covered 5, pending 2, coverage full|,
    'entries added after the receipt stay uncovered'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $h[1], '-root-key',
    'vault:main' );
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'two-b', '-root-key',
    'vault:main', '-dry-run' );
ok( $rc == 0 && $out =~ m|would drop 3| && $out =~ m|kept 2 nodes|,
    'drain trusts the covered entries only, never the uncovered ones'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-check', '-full', $h11, '-root-key', 'vault:main' );
( $rc, $out )
    = cli( ['vp'], 'holder-drain', $disk, 'two-b', '-root-key',
    'vault:main', '-dry-run' );
ok( $rc == 0 && $out =~ m|would drop 5|,
    'once checked, the same holder vouches for the whole drain' )
    or say $out;

done();

#,,..,...,,.,,,..,,..,...,...,.,,,...,,,.,...,..,,...,...,.,,,,,.,,,,,,.,,,,.,
#B7G7PTUGGSZQHEKMQVFLEK5CKZYSL7D6WZPTU7RS6ZR3Q3G5KNKCOKS3RYV2FS3TUD4L65A36XU4O
#\\\|XQQCAC75DST23DUTOX2NYJTWPEA33F37MYLQKRA7OXWENYN443R \ / AMOS7 \ YOURUM ::
#\[7]DUQI6GUPAE5DAE4GCCT4BDF46B32Z3N3SECQI3JFAVIXR4LIZQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
