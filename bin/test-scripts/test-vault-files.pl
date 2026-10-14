#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## tests for the vault blobs [ data/md/design/VAULT-FORMAT.md ] : round trips
## over the chunk boundaries, dedup, vault-bound names, tamper detection,
## archive import/export + export -d through the p7-vault cli. runs on
## throwaway dirs, cheap kdf -- never ~/.n/vault

use FindBin;
use File::Temp qw| tempdir |;
use IPC::Open2 qw| open2 |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault qw|
    vault_init vault_open vault_unlock
    entries_latest
    blob_import blob_export blob_verify
    blob_import_stream blob_discard
    |;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "  ok    $name" }
    else         { $fail++; say "  FAIL  $name" }
}

my %kdf = ( t => 1, m => 8192, p => 1 );    ## cheap, test only ##

my $tmp = tempdir( CLEANUP => 1 );
my $dir = "$tmp/vault";
my $v   = vault_init( $dir, 'pass phrase one', undef, %kdf );

sub write_file {
    my ( $path, $content ) = @ARG;
    open( my $fh, '>:raw', $path ) or die "cannot write $path : $OS_ERROR";
    print {$fh} $content;
    close $fh;
    return $path;
}

sub slurp {
    open( my $fh, '<:raw', $_[0] ) or die "cannot read $_[0] : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub blob_files {
    my $d = shift;
    opendir( my $dh, "$d/blobs" ) or return ();
    my @names = sort grep { not m|^\.| } readdir $dh;
    closedir $dh;
    return @names;
}

## round trips : empty, small, exactly 1 MiB, 2.5 MiB ##
my @cases = (
    [ 'empty',   '' ],
    [ 'small',   'hello vault blobs' ],
    [ 'one-mib', 'A' x 1048576 ],
    [ 'mib-and-half', ( 'B' x 1048576 ) x 2 . 'C' x ( 1048576 / 2 ) ],
);

my %name_of;
foreach my $case (@cases) {
    my ( $label, $content ) = @{$case};
    my $path = write_file( "$tmp/$label", $content );

    my ( $name, $size ) = blob_import( $v, $path );
    ok( $name =~ m|\A[A-Z2-7]{32}\z|, "$label : blob name shape" );
    ok( $size == length $content,     "$label : size reported" );
    ok( ( grep { $_ eq "$name.vlb" } blob_files($dir) ) == 1,
        "$label : one blob file" );

    open( my $out, '>:raw', "$tmp/out" ) or die $OS_ERROR;
    my $ok = eval { blob_export( $v, $name, $out ); 1 };
    close $out;
    ok( $ok,                           "$label : export completes" );
    ok( slurp("$tmp/out") eq $content, "$label : round trip" );
    ok( blob_verify( $v, $name ),      "$label : verify" );

    $name_of{$label} = $name;
}

## dedup : the same content twice is one blob ##
my $small_path = "$tmp/small";
my ( $again, $again_size ) = blob_import( $v, $small_path );
ok( $again eq $name_of{'small'}, 'dedup : same name for same content' );
ok( blob_files($dir) == @cases,  'dedup : blob count unchanged' );

## a blob of one vault fails the other's name check : names are vault-bound ##
my $dir2 = "$tmp/vault-two";
my $v2   = vault_init( $dir2, 'pass phrase two', undef, %kdf );
my ( $name2, undef ) = blob_import( $v2, $small_path );
ok( $name2 ne $name_of{'small'},
    'two vaults : same content, different names' );
ok( !blob_verify( $v, $name2 ), '  :.. the other vaults name is refused' );

## tamper : every change fails, on verify and on export ##
sub tamper {
    my ( $label, $mutate ) = @ARG;
    my $name   = $name_of{'mib-and-half'};
    my $bpath  = "$dir/blobs/$name.vlb";
    my $orig   = slurp($bpath);
    my $broken = $mutate->($orig);
    write_file( $bpath, $broken );
    ok( !blob_verify( $v, $name ), "tamper $label : verify fails" );
    my $ok = eval {
        open( my $out, '>:raw', "$tmp/out-t" ) or die $OS_ERROR;
        blob_export( $v, $name, $out );
        close $out;
        1;
    };
    ok( !$ok, "tamper $label : export dies" );
    write_file( $bpath, $orig );
    ok( blob_verify( $v, $name ), "tamper $label : restored blob verifies" );
}

tamper(
    'flipped byte',
    sub {
        $_ = $_[0];
        substr( $_, 40, 1 )
            = chr( ord( substr $_, 40, 1 ) ^ 0xff );
        $_;
    }
);

tamper(
    'swapped chunks',
    sub {
        my $bin    = $_[0];
        my $header = substr $bin, 0, 9, '';
        my @frames;
        while ( length $bin ) {
            my ($len) = unpack q{N}, substr $bin, 0, 4, '';
            push @frames, substr $bin, 0, $len + 28, '';    ## nonce ct tag ##
        }
        @frames[ 0, 1 ] = @frames[ 1, 0 ];
        return $header . join '',
            map { pack( q{N}, length($_) - 28 ) . $_ } @frames;
    }
);

tamper( 'truncated last chunk',
    sub { substr $_[0], 0, length( $_[0] ) - 10 } );

tamper( 'appended bytes', sub { $_[0] . 'trailing-junk' } );

## the name is not the contents plain blake2b-256 ##
require Crypt::Digest::BLAKE2b_256;
my $plain = Crypt::Digest::BLAKE2b_256->new;
$plain->add( slurp($small_path) );
my $plain_name = substr( AMOS7::Vault::_b32( $plain->digest ), 0, 32 );
ok( $plain_name ne $name_of{'small'},
    'blob name is not the plain blake2b-256 of the content' );

## a locked handle imports nothing ##
my ( $locked, undef ) = vault_open($dir);
my $locked_ok = eval { blob_import( $locked, $small_path ); 1 };
ok( !$locked_ok, 'locked vault : import refused' );

## content changing DURING the encrypt pass : the bytes encrypted are ##
## checked against the name -- import aborts, no blob is left behind  ##
{
    my $moving = "$tmp/moving";
    open( my $mfh, '>:raw', $moving ) or die $OS_ERROR;
    print {$mfh} 'm' x 5000;
    close $mfh;
    my $real = \&AMOS7::Vault::_read_chunk;
    no warnings qw| redefine |;
    local *AMOS7::Vault::_read_chunk = sub {
        my $chunk = $real->(@_);
        substr( $chunk, 0, 1, 'X' ) if length $chunk;    ## changed now ##
        return $chunk;
    };
    use warnings qw| redefine |;
    my $died = !eval { blob_import( $v, $moving ); 1 };
    ok( $died && $@ =~ m|changed while importing|,
        'content changed during encryption : import aborts'
    );
    opendir( my $bdh, "$dir/blobs" ) or die $OS_ERROR;
    ok( !grep( {m|\.tmp\.|} readdir $bdh ), '  :.. no temp file left' );
    closedir $bdh;
}

## CLI tests : import -a / export -a / export -d through bin/p7-vault -- the
## passphrase and the confirms travel on stdin [ no tty ]
my $vault_bin = "$FindBin::Bin/../p7-vault";

sub p7vault {
    my ( $input, @args ) = @ARG;
    my $pid
        = open2( my $read, my $write, $^X, $vault_bin, '-d', $dir, @args );
    binmode $write;
    print {$write} $input;
    close $write;
    my $out = do { local $INPUT_RECORD_SEPARATOR; <$read> }
        // '';
    close $read;
    waitpid $pid, 0;
    $out =~ s|\e\[[0-9;]*m||g;
    return ( $out, $? >> 8 );
}

sub tree_files {
    my ( $base, $rel ) = @ARG;
    my @out;
    opendir( my $dh, $base ) or die "cannot read $base : $OS_ERROR";
    foreach my $name ( sort grep { not m|^\.| } readdir $dh ) {
        my $path = length $rel ? "$rel/$name" : $name;
        if ( -d "$base/$name" ) {
            push @out, tree_files( "$base/$name", $path );
        } else {
            push @out, $path;
        }
    }
    closedir $dh;
    return @out;
}

## import -a : a small tree with nested dirs, the webp files excluded ##
my $tree = "$tmp/tree";
mkdir $tree               or die $OS_ERROR;
mkdir "$tree/nested"      or die $OS_ERROR;
mkdir "$tree/nested/deep" or die $OS_ERROR;
write_file( "$tree/one.txt",               'first file' );
write_file( "$tree/nested/two.txt",        'second file' );
write_file( "$tree/nested/deep/three.bin", 'third file' );
write_file( "$tree/nested/photo.webp",     'webp one' );
write_file( "$tree/nested/deep/pic.webp",  'webp two' );

my ( $out, $rc )
    = p7vault( "pass phrase one\n", 'import', '-a', $tree, '-x', '*.webp' );
ok( $rc == 0 && $out =~ m|stored|, 'import -a : the archive is stored' );

my ($list) = entries_latest($v);
my ($arec) = grep { ( $ARG->{'archive'} // '' ) eq qw| tar | }
    map { $ARG->{'record'} } @{$list};
ok( defined $arec, 'import -a : archive entry recorded' );
ok( ( $arec->{'excludes'} // [] )->@* == 1,
    'import -a : the exclusion is recorded'
);
ok( ( $arec->{'origins'} // [] )->@* == 1,
    'import -a : one origin [ the directory ]'
);

## the archive blob decrypts to a tar stream : no webp, the rest inside ##
open( my $tfh, '>:raw', "$tmp/archive.tar" ) or die $OS_ERROR;
blob_export( $v, $arec->{'blob'}, $tfh );
close $tfh;
my $tar = slurp("$tmp/archive.tar");
ok( substr( $tar, 257, 5 ) eq 'ustar', 'archive blob decrypts : tar magic' );
ok( index( $tar, '.webp' ) == -1, 'import -a : webp excluded from the tar' );
ok( index( $tar, 'three.bin' ) != -1,
    'import -a : nested files inside the tar'
);

## export -a into a temp dir : file lists and content match the original ##
my $restore = "$tmp/restore";
( $out, $rc ) = p7vault( "pass phrase one\ny\n", 'export', 'tree', $restore );
ok( $rc == 0 && $out =~ m|exported|, 'export -a : extracted' );
my @want = grep { !m|\.webp\z| } tree_files( $tree, '' );
my @got  = tree_files( "$restore/tree", '' );
ok( "@got" eq "@want", 'export -a : the file lists match' );
my $same = grep { slurp("$restore/tree/$_") eq slurp("$tree/$_") } @want;
ok( $same == scalar @want, 'export -a : the contents match' );

## export -d : three files under a prefix to a new location ##
my $pfx = "$tmp/pfx";
mkdir $pfx       or die $OS_ERROR;
mkdir "$pfx/sub" or die $OS_ERROR;
write_file( "$pfx/a.txt",     'alpha' );
write_file( "$pfx/sub/b.txt", 'beta' );
write_file( "$pfx/sub/c.bin", 'gamma' );
( $out, $rc ) = p7vault(
    "pass phrase one\n", 'import',
    "$pfx/a.txt",        "$pfx/sub/b.txt",
    "$pfx/sub/c.bin"
);
ok( $rc == 0 && $out =~ m|stored|, 'import : three files under the prefix' );

my $dest = "$tmp/dest";
( $out, $rc )
    = p7vault( "pass phrase one\ny\n", 'export', '-d', $pfx, $dest );
ok( $rc == 0 && $out =~ m|exported 3, skipped 0|,
    'export -d : all three exported' );
ok( slurp("$dest/a.txt") eq 'alpha'
        && slurp("$dest/sub/b.txt") eq 'beta'
        && slurp("$dest/sub/c.bin") eq 'gamma',
    'export -d : the contents landed relative to the prefix'
);
ok( ( ( stat "$dest/sub" )[2] & 0777 ) == 0700,
    'export -d : a new parent directory is 0700'
);

## export -d refuses nothing silently : a second run asks per file, 'n' ##
## skips                                                                ##
( $out, $rc )
    = p7vault( "pass phrase one\ny\nn\nn\nn\n", 'export', '-d', $pfx, $dest );
ok( $rc != 0 && $out =~ m|exported 0, skipped 3|,
    'export -d : existing files are skipped unasked-overwritten' );

## import -a pre-check : unreadable paths refuse before anything is stored, ##
## -x excluding them passes, -i skips them as exact names                   ##
## [ as root every path is readable : skipped ]                             ##
SKIP_UNREADABLE: {
    if ( $EUID == 0 ) {
        say '  skip  import -a pre-check [ root reads everything ]';
        last SKIP_UNREADABLE;
    }
    my $locked = "$tmp/locked";
    mkdir $locked           or die $OS_ERROR;
    mkdir "$locked/closed"  or die $OS_ERROR;
    mkdir "$locked/open[1]" or die $OS_ERROR;
    write_file( "$locked/fine.txt",          'readable' );
    write_file( "$locked/closed/inside.txt", 'behind a closed dir' );
    write_file( "$locked/open[1]/secret",    'no read permission' );
    write_file( "$locked/open[1]/ok.txt",    'readable too' );
    chmod 0000, "$locked/open[1]/secret";
    chmod 0000, "$locked/closed";

    my $count = sub {
        my ($l) = entries_latest($v);
        return scalar grep { ( $ARG->{'archive'} // '' ) eq qw| tar | }
            map { $ARG->{'record'} } @{$l};
    };
    my @blobs_before = blob_files($dir);
    my $before       = $count->();

    ( $out, $rc ) = p7vault( "pass phrase one\n", 'import', '-a', $locked );
    ok( $rc != 0 && $out =~ m|2 paths not readable|,
        'import -a : unreadable paths refuse the import'
    );
    ok( $out =~ m|locked/closed\b| && $out =~ m|locked/open\[1\]/secret|,
        'import -a : the unreadable paths are listed' );
    ok( $count->() == $before && blob_files($dir) == @blobs_before,
        'import -a : refused before any entry or blob is written'
    );

    ( $out, $rc ) = p7vault( "pass phrase one\n",
        'import', '-a', $locked, '-x', 'closed', '-x', '*/secret' );
    ok( $rc == 0 && $out =~ m|stored|,
        'import -a : -x excluding the unreadable paths passes' );

    ( $out, $rc ) = p7vault(
        "pass phrase one\n", 'import', '-a', "$locked/",
        '-i', '-t', 'locked-skip'
    );
    ok( $rc == 0
            && $out =~ m|2 paths not readable -- skipped|
            && $out =~ m|stored|,
        'import -a -i : skipped and stored [ trailing slash dir ]'
    );
    my ($l)    = entries_latest($v);
    my ($srec) = grep { ( $ARG->{'title'} // '' ) eq 'locked-skip' }
        map { $ARG->{'record'} } @{$l};
    ok( defined $srec
            && join( ',', @{ $srec->{'skipped'} // [] } ) eq
            'locked/closed,locked/open[1]/secret',
        'import -a -i : the skipped names are recorded'
    );

    if ( defined $srec ) {
        open( my $sfh, '>:raw', "$tmp/skip.tar" ) or die $OS_ERROR;
        blob_export( $v, $srec->{'blob'}, $sfh );
        close $sfh;
        my @members = `tar -tf $tmp/skip.tar`;
        chomp @members;
        ok( ( grep { $ARG eq 'locked/open[1]/ok.txt' } @members )
                && !( grep {m{secret|closed}} @members ),
            'import -a -i : bracket name kept, skipped paths left out'
        );
    }
    ( $out, $rc ) = p7vault(
        "pass phrase one\ny\n", 'export',
        'locked-skip',          "$tmp/skip-restore"
    );
    ok( $rc == 0
            && $out =~ m|2 paths not in the archive|
            && $out =~ m|locked/open\[1\]/secret|,
        'export : the skipped paths are named'
    );
    chmod 0700, "$locked/closed";
    chmod 0600, "$locked/open[1]/secret";
}

## blob_discard : a failed archive's stream blob goes, names are checked ##
{
    open( my $in, '<', \'stream bytes of a failed tar' ) or die $OS_ERROR;
    my ($name) = blob_import_stream( $v, $in );
    close $in;
    ok( -e "$dir/blobs/$name.vlb", 'blob_discard : stream blob written' );
    ok( blob_discard( $v, $name ) && !-e "$dir/blobs/$name.vlb",
        'blob_discard : removed' );
    ok( blob_discard( $v,  $name ), 'blob_discard : gone already is TRUE' );
    ok( !blob_discard( $v, '../vault.key' ) && !blob_discard( $v, undef ),
        'blob_discard : malformed names refused' );
}

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,,.,,.,,,..,,.,,,,.,.,.,..,,,,.,,,.,,..,,..,..,,...,...,.,.,,..,,,,,.,.,.,.,
#CZYRIAXQE46HKDNZR57ZA7BMAYHAXYETF4ZJXXYLF7JDDVGJB6KM3PR5GOMFQD2JMGYKW7X3KNBXI
#\\\|T7KOBJ27BRTS3VHUHZYO66QK4WQ3A636UDCY7KRQOPZZBZD2Q5B \ / AMOS7 \ YOURUM ::
#\[7]FDHGQQSX7EFQOY3RF7V2F42B3CCEMXZMGMKVLE4KOZZXGSOSAADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
