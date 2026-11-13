#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## review finding 2 : gc grace + trash + restore + purge, one holder
## subdirectory per root, holder-migrate [ the host lock is e317e4eb6 ].

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use AMOS7::Vault         qw| vault_init |;
use AMOS7::N7FS          qw| make_dirs read_file |;
use AMOS7::N7FS::Sum     qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Disk    qw| disk_read_id |;
use AMOS7::N7FS::Journal qw| journal_replay |;
use AMOS7::N7FS::Keys;
use AMOS7::N7FS::Seal;
use AMOS7::NTIME           qw| y_level_ntime parse_y_age y_age_str |;
use AMOS7::N7FS::Placement qw| parse_age |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

## single node blobs : every node is its own blob here ##
$ENV{'N7FS_TEST_PACK_LIMIT'} = 0;

my $box  = sandbox();
my $base = $box->{'base'};
my ( $root, $hdir, $src ) = @{$box}{qw| root host src |};
my $vdir = "$base/vault";
$ENV{'N7FS_HOST_DIR'} = $hdir;
vault_init( $vdir, 'vp', undef, t => 1, m => 1024, p => 1 );

##[ Y-level ages ]############################################################

ok( y_level_ntime(0) == 4200 * 86400 * 365
        && y_level_ntime(1) == y_level_ntime(0) / 13,
    'Y levels divide the 365-day ntime year by thirteen'
);
ok( parse_y_age('6Y3') == int( 6 * y_level_ntime(3) )
        && parse_y_age('0.5Y2') == int( 0.5 * y_level_ntime(2) )
        && !defined parse_y_age('1Y8'),
    'parse_y_age accepts integer and decimal levels 0..7 only'
);
ok( y_age_str( parse_y_age('6Y3') ) eq '6Y3',
    'y_age_str round-trips one Y term'
);
my $two_terms = parse_y_age('1Y2') + parse_y_age('4Y3');
ok( y_age_str($two_terms) eq '1Y2 4Y3',
    'y_age_str uses at most two greedy terms'
);
my ( @legacy, @warnings );
{
    local $SIG{'__WARN__'} = sub { push @warnings, @_ };
    @legacy = map { parse_age('1d') } 1 .. 2;
    parse_age('1Y2');
}
ok( @legacy == 2 && $legacy[0] == 86400 * 4200,
    'legacy age units convert to ntime'
);
ok( @warnings == 1 && $warnings[0] =~ m|deprecated unix units|,
    'legacy age units warn once per call site, Y ages do not warn'
);

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
    write_file( "$base/pass", "vp\n" );
    open( my $pass, '<:raw', "$base/pass" ) or die $OS_ERROR;
    return AMOS7::N7FS::Keys::root_open(
        qw| path |      => 'vault:main',
        qw| vault_dir | => $vdir,
        qw| pass_fd |   => fileno($pass)
    );
}

## the blob name a local address maps to right now ##
sub mapped_blob {
    my ( $root_ref, $holder, $address ) = @ARG;
    my ( undef, undef, $map )
        = AMOS7::N7FS::Seal::_context( $root_ref, $holder, 1 );
    return $map->{'nodes'}{$address}{'blob'};
}

## move every file of a per-root holder back to the flat layout ##
sub flatten {
    my $dir = shift;
    my $sub = holder_sub($dir) // die "not a per-root holder : $dir";
    opendir( my $d, $sub ) or die $OS_ERROR;
    my @e = grep { $ARG ne '.' and $ARG ne '..' } readdir $d;
    closedir $d;
    rename "$sub/$ARG", "$dir/$ARG" or die $OS_ERROR for @e;
    rmdir $sub or die $OS_ERROR;
    return $dir;
}

##[ fixture ]#################################################################

cli( [], 'keygen', "$hdir/host.key" );
cli( [], 'keygen', "$hdir/parent.key" );
( undef, my $pub ) = cli( [], 'pubkey', "$hdir/parent.key" );
write_file( "$hdir/trusted-parents", $pub );
cli( [], 'init', '-name', 't', '-intent', 'x' );
my ($disk)
    = grep { !m|^\.| } do { opendir( my $d, $root ) or die; readdir $d };
cli( [], 'attach', $disk );
cli( ['vp'], 'root', 'init', 'vault:main' );
cli( [ 'pw', 'pw' ],
    'root', 'init', "$base/root-b.key", '-argon-m', 1024, '-argon-t', 1 );
my $tree = "$src/t";
make_dirs($tree);
write_file( "$tree/f$ARG", "file $ARG\n" ) for 1 .. 6;
cli( [], 'assimilate', '-disk', $disk, '-keep', '-tree', 't', $tree );
my ($address) = do {
    my $id     = disk_read_id( qw| root | => $root, qw| disk | => $disk );
    my $replay = journal_replay($id);
    sort keys $replay->{'nodes'}->%*;
};
my $main_root = open_main_root();
my $sub_tag   = AMOS7::N7FS::Seal::root_subdir($main_root);

##[ grace : gc never touches a young blob ]###################################

my $h1 = "$base/h1";
make_dirs($h1);
cli(['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h1,   '-tree',
    't'
);
ok( -d "$h1/$sub_tag", 'a fresh holder starts in the per-root layout' );
my $h1_blob = mapped_blob( $main_root, $h1, $address );
cli( ['vp'], 'shred', $disk, '-root-key', 'vault:main',
    '-out', $h1, $address );
my ( $rc, $out )
    = cli( ['vp'], 'holder-gc', $h1, '-root-key',
    'vault:main', '-delete', '-grace', '6Y3' );
ok( $rc == 0 && $out =~ m|young| && -e "$h1/$sub_tag/$h1_blob",
    'gc skips a blob younger than a Y-level grace age'
) or say $out;

##[ trash : gc moves, restore brings back, purge drops only old days ]########

## age the blob three days : past any grace ##
my $old = time - 3 * 86400;
utime $old, $old, "$h1/$sub_tag/$h1_blob" or die $OS_ERROR;
( $rc, $out )
    = cli( ['vp'], 'holder-gc', $h1, '-root-key', 'vault:main', '-delete' );
my ($day) = $out =~ m|removed 1 unreferenced blobs| ? _today() : ();
ok( $rc == 0 && defined $day && -e "$h1/$sub_tag/.trash/$day/$h1_blob",
    'gc moves an old unreferenced blob to .trash/<day>/'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-gc', $h1, '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|would remove 0|,
    'a second gc finds nothing to trash'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-trash-restore', $h1,
    '-root-key', 'vault:main', $h1_blob );
ok( $rc == 0 && -e "$h1/$sub_tag/$h1_blob", 'restore brings the blob back' )
    or say $out;

## an old trash day and a fresh one : purge drops only the old ##
cli( ['vp'], 'shred', $disk, '-root-key', 'vault:main',
    '-out', $h1, $address );
utime $old, $old, "$h1/$sub_tag/$h1_blob" or die $OS_ERROR;
( $rc, $out )
    = cli( ['vp'], 'holder-gc', $h1, '-root-key', 'vault:main', '-delete' );
die 're-trash failed' if $rc != 0;
my $fake_blob = bmw_b32( bmw384_bytes('old trash bytes') );
make_dirs("$h1/$sub_tag/.trash/2026-01-01");
write_file( "$h1/$sub_tag/.trash/2026-01-01/$fake_blob", 'old trash bytes' );
my $older = time - 30 * 86400;
utime $older, $older, "$h1/$sub_tag/.trash/2026-01-01" or die $OS_ERROR;
( $rc, $out )
    = cli( ['vp'], 'holder-trash-purge', $h1, '-root-key', 'vault:main' );
ok( $rc == 0
        && $out =~ m|would purge 1|
        && -d "$h1/$sub_tag/.trash/2026-01-01",
    'purge is a dry run by default and counts only old days'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-trash-purge', $h1,
    '-root-key', 'vault:main', '-delete' );
ok( $rc == 0
        && !-d "$h1/$sub_tag/.trash/2026-01-01"
        && -d "$h1/$sub_tag/.trash/$day",
    'purge removes only days older than the receipt age'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-trash-restore', $h1,
    '-root-key', 'vault:main', '-all-since', $day );
ok( $rc == 0 && -e "$h1/$sub_tag/$h1_blob",
    'restore -all-since brings the day back'
) or say $out;

##[ a blob present only in trash counts as missing ]##########################

my $h2 = "$base/h2";
make_dirs($h2);
cli(['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h2,   '-tree',
    't'
);
my $h2_blob = mapped_blob( $main_root, $h2, $address );
make_dirs( "$h2/$sub_tag/.trash/" . _today() );
rename "$h2/$sub_tag/$h2_blob",
    "$h2/$sub_tag/.trash/" . _today() . "/$h2_blob"
    or die $OS_ERROR;
( $rc, $out ) = cli( ['vp'], 'holder-check', $h2, '-root-key', 'vault:main' );
ok( $rc != 0, 'holder-check fails while a mapped blob sits in trash' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-scrub', $h2, '-root-key', 'vault:main' );
ok( $rc == 1 && $out =~ m|missing : $h2_blob|,
    'scrub reports a trash-only blob as missing'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-trash-restore', $h2,
    '-root-key', 'vault:main', $h2_blob );
( $rc, $out ) = cli( ['vp'], 'holder-check', $h2, '-root-key', 'vault:main' );
ok( $rc == 0, 'the holder checks clean after the restore' ) or say $out;

##[ two roots on one holder : gc of one never touches the other ]#############

my $h3 = "$base/h3";
make_dirs($h3);
cli(['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h3,   '-tree',
    't'
);
## a disk binds to one root [ review finding 6 ] : root B seals its own ##
## disk onto the same holder, each root into its own r-<tag>/           ##
cli( [], 'init', '-name', 'b', '-intent', 'x' );
my ($disk_b)
    = grep { $_ ne $disk && !m|^\.| }
    do { opendir( my $d, $root ) or die; readdir $d };
cli( [], 'attach', $disk_b );
cli( [], 'assimilate', '-disk', $disk_b, '-keep', '-tree', 't', $tree );
cli([ 'pw', 'pw' ],     'seal', $disk_b, '-root-key',
    "$base/root-b.key", '-out', $h3,     '-tree',
    't'
);
my @subs = sort grep { m|\Ar-[A-Z2-7]{7}\z| and -d "$h3/$ARG" }
    do { opendir( my $d, $h3 ) or die; readdir $d };
my ($sub_a) = grep { $ARG eq $sub_tag } @subs;
my ($sub_b) = grep { $ARG ne $sub_tag } @subs;
ok( @subs == 2 && defined $sub_a && defined $sub_b,
    'two roots, two subdirectories' )
    or say $out;
my $b_count = scalar holder_blobs("$h3/$sub_b");
cli( ['vp'], 'shred', $disk, '-root-key', 'vault:main',
    '-out', $h3, $address );
( $rc, $out )
    = cli( ['vp'], 'holder-gc', $h3,
    '-root-key', 'vault:main', '-delete', '-grace', '0' );
ok( $rc == 0 && scalar( holder_blobs("$h3/$sub_b") ) == $b_count,
    'gc of root A never touches root B\'s blobs' )
    or say $out;
( $rc, $out ) = cli(
    [ 'pw', 'pw' ], 'seal-recover', '-root-key', "$base/root-b.key",
    '-from',        $h3,            '-tree',     't',
    "$base/rec-b"
);
ok( $rc == 0 && read_file("$base/rec-b/f1") eq "file 1\n",
    'root B still recovers after root A\'s gc'
) or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-gc', $h3, '-root-key', 'vault:main' );
ok( $rc == 0, 'per-root gc needs no -only-root' ) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-gc', $h3,
    '-root-key', 'vault:main', '-only-root' );
ok( $rc == 0 && $out =~ m|redundant|,
    '-only-root is accepted and warned redundant on a per-root holder' )
    or say $out;

##[ migrate : flat to per-root, idempotent, resumable ]#######################

my $h4 = "$base/h4";
make_dirs($h4);
cli(['vp'],       'seal', $disk, '-root-key',
    'vault:main', '-out', $h4,   '-tree',
    't'
);
flatten($h4);
( $rc, $out ) = cli( ['vp'], 'holder-check', $h4, '-root-key', 'vault:main' );
ok( $rc == 0, 'a flat-layout holder still checks as today' ) or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-gc', $h4, '-root-key', 'vault:main' );
ok( $rc != 0 && $out =~ m|only-root|,
    'the flat layout still requires -only-root' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-migrate', $h4, '-root-key', 'vault:main' );
ok( $rc == 0 && $out =~ m|would move [1-9]|,
    'migrate is a dry run by default'
) or say $out;
## interrupted after the blobs, before the head : mid-move, reads fail ##
## until the rerun completes the move [ the documented window ]        ##
{
    local $ENV{'N7FS_TEST_FAULT'} = 'migrate:after-blobs';
    ( $rc, $out )
        = cli( ['vp'], 'holder-migrate', $h4,
        '-root-key', 'vault:main', '-delete' );
}
ok( $rc != 0 && -d "$h4/$sub_tag",
    'an interrupted migrate stops after the blobs, before the head' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-check', $h4, '-root-key', 'vault:main' );
ok( $rc != 0 && $out =~ m|mapped blob is missing|,
    'mid-migration reads fail until the rerun'
) or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-migrate', $h4,
    '-root-key', 'vault:main', '-delete' );
ok( $rc == 0 && $out =~ m|moved|, 'the resumed migrate finishes' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-check', $h4, '-root-key', 'vault:main' );
ok( $rc == 0, 'the migrated holder checks clean' ) or say $out;
( $rc, $out ) = cli(
    ['vp'],  'seal-recover', '-root-key', 'vault:main',
    '-from', $h4,            '-tree',     't',
    "$base/rec-4"
);
ok( $rc == 0 && read_file("$base/rec-4/f2") eq "file 2\n",
    'the migrated holder recovers the tree' )
    or say $out;
( $rc, $out )
    = cli( ['vp'], 'holder-migrate', $h4,
    '-root-key', 'vault:main', '-delete' );
ok( $rc == 0 && $out =~ m|already in the per-root layout|,
    'migrate is idempotent' )
    or say $out;
( $rc, $out ) = cli( ['vp'], 'holder-gc', $h4, '-root-key', 'vault:main' );
ok( $rc == 0, 'gc after migrate is structural, no -only-root' )
    or say $out;

##[ the same over fake ssh ]##################################################

my $fake = "$FindBin::Bin/fixtures/n7fs/fake-ssh.sh";
chmod 0755, $fake or die $OS_ERROR;
my $remote = "$base/remote";
make_dirs( $remote, 0700 );
my $log = "$base/ssh.log";
write_file( $log, '' );
my $spec = 'ssh:fake:/holder';
$ENV{'N7FS_SSH'}         = $fake;
$ENV{'FAKE_SSH_LOG'}     = $log;
$ENV{'FAKE_HOLDER_ROOT'} = $remote;
$ENV{'N7FS_SSH_BACKOFF'} = '0,0,0,0,0';

my $h5_blob;
{
    local $ENV{'FAKE_HOLDER_ROOT'} = $remote;
    ( $rc, $out ) = cli(
        ['vp'],       'seal', $disk, '-root-key',
        'vault:main', '-out', $spec, '-tree',
        't'
    );
    ok( $rc == 0, 'sealed over fake ssh' ) or say $out;
    $h5_blob = mapped_blob( $main_root, $spec, $address );
    cli( ['vp'], 'shred', $disk, '-root-key', 'vault:main',
        '-out', $spec, $address );
    ( $rc, $out )
        = cli( ['vp'], 'holder-gc', $spec,
        '-root-key', 'vault:main', '-delete', '-grace', '0' );
    ok( $rc == 0 && -e "$remote/$sub_tag/.trash/" . _today() . "/$h5_blob",
        'ssh gc moves the blob into the remote trash' )
        or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'holder-trash-restore', $spec,
        '-root-key', 'vault:main', $h5_blob );
    ok( $rc == 0 && -e "$remote/$sub_tag/$h5_blob",
        'ssh restore brings the blob back'
    ) or say $out;
    make_dirs("$remote/$sub_tag/.trash/2026-01-01");
    write_file( "$remote/$sub_tag/.trash/2026-01-01/$fake_blob",
        'old trash bytes' );
    utime $older, $older, "$remote/$sub_tag/.trash/2026-01-01"
        or die $OS_ERROR;
    ( $rc, $out )
        = cli( ['vp'], 'holder-trash-purge', $spec,
        '-root-key', 'vault:main', '-delete' );
    ok( $rc == 0 && !-d "$remote/$sub_tag/.trash/2026-01-01",
        'ssh purge removes the old day' )
        or say $out;
    ( $rc, $out )
        = cli( ['vp'], 'holder-check', $spec, '-root-key', 'vault:main' );
    ok( $rc == 0, 'the ssh holder checks clean at the end' ) or say $out;
}

sub _today {
    my @t = gmtime;
    return sprintf '%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3];
}

done();

#,,,,,,..,,,,,,,,,..,,..,,...,,,,,,,,,,,,,,,,,..,,...,...,,,,,,,.,,,.,,,,,..,,
#MXE4DSM55N2F5PFEUNCX2TWZWRQ63ETV5XNIY5FNMDXXHPJAZCHK45FD2XMHLXJU24GBUDYOIHC4M
#\\\|U3HEKUEIRW2243FY2JSVDSFIZ66NLF3UWWOJ3WXGIJR277CW5QP \ / AMOS7 \ YOURUM ::
#\[7]LKC3E4OQC5U4Y45LF5ZBHLGQLH5Z5FXUDFOLFJAYGECZGTVWB2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
