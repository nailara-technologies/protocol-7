#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS : assimilate [ data/md/design/N7FS-SPEC.md section 7 ] -- keep \
## remove \ dry-run, a failure at every stage leaves the source, a real amos
## collision [ two bmw siblings ], the image index as a source list
## [ a tiny fake sqlite db, rows marked as test data ]. temp roots only.
##
## perl bin/test-scripts/test-n7fs-assimilate.pl  N7FS_TEST_LIB=<dir> puts a
## [ mutated ] copy of the modules first

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS      qw| read_file signed_record_parse |;
use AMOS7::N7FS::Sum qw| amos_of_bytes bmw_b32 bmw384_bytes epoch_b32
    epoch_int |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_detach state_read
    state_write |;
use AMOS7::N7FS::Sign  qw| key_file_signer |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

my $box  = sandbox();
my $root = $box->{'root'};
my $hdir = $box->{'host'};
my $src  = $box->{'src'};
my $host = test_signer();
clock_real();

my %base = ( qw| root | => $root, qw| host_dir | => $hdir );
my $disk = disk_init(
    %base,
    qw| parent | => test_signer(),
    qw| name |   => 'assimilate-test',
    qw| intent | => 'n7fs assimilate test [ test data ]',
);
my %run = ( %base, qw| disk | => $disk, qw| host | => $host );

## keep this legacy-behavior suite on format 2 ; format 3 has its own suite ##
{
    my $p = state_read("$root/$disk");
    delete $p->{'_name'};
    $p->{'store_format'} = 2;
    state_write( "$root/$disk", $p,
        key_file_signer("$hdir/stores/$disk.store.key") );
}

## sources [ test data ] ##
my %content = (
    qw| a.txt | => "test data : first file\n",
    qw| b.png | => "\x89PNG\r\n\x1a\n" . ( "\x00\xff" x 300 ),
    qw| sub/c | => "test data : nested file\n",
);
mkdir "$src/sub";
write_file( "$src/$ARG", $content{$ARG} ) for keys %content;
symlink "$src/a.txt", "$src/link";

sub addr_of {
    my $bytes = shift;
    my $bmw   = bmw_b32( bmw384_bytes($bytes) );
    return ( amos_of_bytes($bytes), $bmw );
}

sub node_dir {
    my ( $bytes, $epoch ) = @ARG;
    my ( $amos,  $bmw )   = addr_of($bytes);
    return join '/', $root, $disk, epoch_b32($epoch), $amos, $bmw;
}

sub entry_for {
    my ( $r, $path ) = @ARG;
    my ($e)
        = grep { ( $ARG->{'source'} // '' ) eq $path } $r->{'entries'}->@*;
    return $e // {};
}

sub cli_n7fs {
    my @args = @ARG;
    my $out  = "$box->{'base'}/cli.stdout";
    my $err  = "$box->{'base'}/cli.stderr";
    my $pid  = fork // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDOUT, '>:raw', $out ) or exit 98;
        open( STDERR, '>:raw', $err ) or exit 98;
        exec( $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs", '-root', $root,
            '-host-dir', $hdir, @args )
            or exit 99;
    }
    waitpid $pid, 0;
    return ( $CHILD_ERROR >> 8, read_file($out), read_file($err) );
}

say ':: not attached';
{
    my $before = snapshot( $root, $hdir, $src );
    refused(
        sub { assimilate( %run, qw| paths | => [$src] ) },
        qr|not attached here|,
        'assimilate needs an attached disk'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ),
        'refused : no change on disk' );
}
disk_attach(%run);

say ':: dry run';
{
    my $before = snapshot( $root, $hdir, $src );
    my $r      = assimilate(
        %run,
        qw| paths |   => [$src],
        qw| dry_run | => TRUE,
        qw| remove |  => TRUE
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ),
        'dry run : no change on disk [ root, host dir, sources ]'
    );
    ok( entry_for( $r, "$src/a.txt" )->{'status'} eq 'would-store'
            && entry_for( $r, "$src/a.txt" )->{'then'} eq 'would-remove',
        'dry run lists what would happen'
    );
    ok( entry_for( $r, "$src/link" )->{'status'} eq 'skipped',
        'symlinks are skipped' );
}

say ':: keep [ the default ]';
my $epoch = epoch_int( clock_now() );
my $r     = assimilate( %run, qw| paths | => [$src] );
ok( $r->{'failed'} == 0, 'no failures' );
foreach my $name ( sort keys %content ) {
    my $e = entry_for( $r, "$src/$name" );
    ok( $e->{'status'} eq 'stored' && $e->{'then'} eq 'kept',
        "$name : stored, kept" );
    ok( read_file("$src/$name") eq $content{$name},
        "$name : source unchanged" );
    my $nd = node_dir( $content{$name}, $epoch );
    ok( read_file("$nd/content") eq $content{$name},
        "$name : content at <epoch>/<amos>/<bmw>/content"
    );
}
ok( -e "$src/link" && -l "$src/link", 'the symlink is untouched' );
{
    my $nd   = node_dir( $content{'b.png'}, $epoch );
    my ($mf) = glob "$nd/meta/*.meta";
    my $m    = signed_record_parse( qw| meta |, read_file($mf) );
    my $p    = $m->{'payload'};
    ok( substr( read_file($mf), 0, 5 ) eq "P7FN\x02",
        "meta : 'P7FN' + format 2" );
    ok( $p->{'name'} eq 'b.png'
            && $p->{'format'} eq 'png'
            && $p->{'size'} == length $content{'b.png'}
            && $p->{'mtime'} == ( stat "$src/b.png" )[9]
            && $p->{'import_ntime'} =~ m|\A\d{14}\z|
            && $p->{'epoch'} eq epoch_b32($epoch)
            && $p->{'disk'} eq $disk
            && $p->{'source'} =~ m|/src/b\.png\z|,
        'meta : source fields and signed location binding'
    );
}
ok( state_read("$root/$disk")->{'epochs'}[0] == $epoch,
    'the epoch entered the state' );
ok( store_verify( %base, qw| disk | => $disk )->{'nodes'} == 3,
    'store verifies [ 3 nodes ]' );

say ':: dedup and unchanged';
{
    my $nd         = node_dir( $content{'a.txt'}, $epoch );
    my $meta_count = sub {
        my @meta = glob "$nd/meta/*.meta";
        return scalar @meta;
    };

    my $before = snapshot( $root, $hdir, $src );
    my $dry    = assimilate(
        %run,
        qw| paths |   => ["$src/a.txt"],
        qw| dry_run | => TRUE,
        qw| remove |  => TRUE
    );
    ok( entry_for( $dry, "$src/a.txt" )->{'status'} eq 'would-unchanged'
            && entry_for( $dry, "$src/a.txt" )->{'then'} eq 'would-remove',
        'dry run reports the unchanged outcome'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ),
        'unchanged dry run changes nothing' );

    my $r2 = assimilate( %run, qw| paths | => ["$src/a.txt"] );
    ok( entry_for( $r2, "$src/a.txt" )->{'status'} eq 'unchanged'
            && entry_for( $r2, "$src/a.txt" )->{'then'} eq 'kept',
        'same path and meta : unchanged, kept'
    );
    ok( $meta_count->() == 1, 'repeat import adds zero meta records' );

    my $copy = write_file( "$src/a-copy.txt", $content{'a.txt'} );
    my $rc   = assimilate( %run, qw| paths | => [$copy] );
    ok( entry_for( $rc, $copy )->{'status'} eq 'dedup',
        'same content at a new path : dedup'
    );
    ok( $meta_count->() == 2, 'a new path adds one meta record' );

    my $moved = "$src/a-moved.txt";
    rename $copy, $moved or die "rename $copy : $OS_ERROR";
    my $rm = assimilate( %run, qw| paths | => [$moved] );
    ok( entry_for( $rm, $moved )->{'status'} eq 'dedup',
        'moved path : dedup' );
    ok( $meta_count->() == 3, 'moved path adds exactly one meta record' );

    ## duplicates share a node : each source compares with its own record ##
    my $rd = assimilate( %run, qw| paths | => [ "$src/a.txt", $moved ] );
    ok( entry_for( $rd, "$src/a.txt" )->{'status'} eq 'unchanged'
            && entry_for( $rd, $moved )->{'status'} eq 'unchanged',
        'repeat of duplicate sources : both unchanged'
    );
    ok( $meta_count->() == 3, 'repeat of duplicates adds zero meta records' );

    my $mtime = ( stat "$src/a.txt" )[9];
    utime $mtime + 1, $mtime + 1, "$src/a.txt" or die "utime : $OS_ERROR";
    my $rt = assimilate( %run, qw| paths | => ["$src/a.txt"] );
    ok( entry_for( $rt, "$src/a.txt" )->{'status'} eq 'dedup'
            && $meta_count->() == 4,
        'a changed mtime adds one meta record'
    );

    my $f = write_file( "$src/unchanged-remove",
        "test data : unchanged remove\n" );
    assimilate( %run, qw| paths | => [$f] );
    my $rr = assimilate( %run, qw| paths | => [$f], qw| remove | => TRUE );
    ok( entry_for( $rr, $f )->{'status'} eq 'unchanged'
            && entry_for( $rr, $f )->{'verified'}
            && entry_for( $rr, $f )->{'then'} eq 'removed'
            && !-e $f,
        'unchanged with -remove still verifies and removes the source'
    );
    my @remove_meta
        = glob node_dir( "test data : unchanged remove\n", $epoch )
        . '/meta/*.meta';
    ok( @remove_meta == 1, 'unchanged -remove adds no meta record' );
}

say ':: keep + remove exclude each other';
{
    my $before = snapshot( $root, $hdir, $src );
    refused(
        sub {
            assimilate(
                %run,
                qw| paths |  => [$src],
                qw| keep |   => TRUE,
                qw| remove | => TRUE
            );
        },
        qr|exclude each other|,
        'keep + remove refused'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ), 'no change' );
}

say ':: remove';
{
    my $f  = write_file( "$src/remove-me", "test data : to be removed\n" );
    my $r3 = assimilate( %run, qw| paths | => [$f], qw| remove | => TRUE );
    my $e  = entry_for( $r3, $f );
    ok( $e->{'status'} eq 'stored'
            && $e->{'verified'}
            && $e->{'then'} eq 'removed',
        'stored, verified, then removed'
    );
    ok( !-e $f, 'the source is gone' );
    ok( read_file(
            node_dir( "test data : to be removed\n", $epoch ) . '/content'
        ) eq "test data : to be removed\n",
        'its content is in the store'
    );
}

say ':: a failure at any stage leaves the source';
foreach my $point (
    qw| assimilate:before-publish assimilate:after-publish
    assimilate:before-remove |
) {
    my $body = "test data : fault at $point\n";
    my $f    = write_file( "$src/fault", $body );
    local $AMOS7::N7FS::FAULT
        = sub { die "injected fault\n" if $ARG[0] eq $point };
    my $rf = assimilate( %run, qw| paths | => [$f], qw| remove | => TRUE );
    my $e  = entry_for( $rf, $f );
    ok( $e->{'status'} eq 'failed' && $rf->{'failed'} == 1,
        "$point : reported failed" );
    ok( read_file($f) eq $body, "$point : source untouched" );
    my $nd = node_dir( $body, $epoch );

    if ( $point eq 'assimilate:before-publish' ) {
        ok( !-e $nd, "$point : nothing published" );
        my $amos_dir = $nd =~ s|/[^/]+\z||r;
        ok( !grep( {m|\.tmp\.|} glob("$amos_dir/*") ),
            "$point : no temp left" );
    }
    unlink $f;
}

## the source changes after it was hashed : never removed ##
{
    my $f = write_file( "$src/changing", "test data : changing source\n" );
    local $AMOS7::N7FS::FAULT = sub {
        return if $ARG[0] ne 'assimilate:after-publish';
        open( my $fh, '>>', $f ) or die;
        print {$fh} "appended\n";
        close $fh;
    };
    my $rc = assimilate( %run, qw| paths | => [$f], qw| remove | => TRUE );
    my $e  = entry_for( $rc, $f );
    ok( $e->{'status'} eq 'failed'
            && $e->{'why'} =~ m|changed during assimilate|,
        'a changed source is detected before removal'
    );
    ok( -e $f, 'the changed source is kept' );
}

## a damaged stored node : dedup refuses to add to it, the source stays ##
{
    my $body = $content{'sub/c'};
    my $nd   = node_dir( $body, $epoch );
    chmod 0600, "$nd/content";
    my $orig = read_file("$nd/content");
    write_file( "$nd/content", "damaged\n" );
    my $f  = write_file( "$src/again", $body );
    my $rd = assimilate( %run, qw| paths | => [$f], qw| remove | => TRUE );
    ok( entry_for( $rd, $f )->{'status'} eq 'failed',
        'damaged node : dedup fails' );
    ok( read_file($f) eq $body, 'damaged node : source untouched' );
    refused(
        sub { store_verify( %base, qw| disk | => $disk ) },
        qr|content does not match its bmw|,
        'verify finds the damage'
    );
    write_file( "$nd/content", $orig );
    chmod 0400, "$nd/content";
    unlink $f;
}

say ':: amos collision : two bmw siblings [ real fixtures ]';
{
    ## found offline : two contents whose 7-char amos [ of the bmw ] are
    ## equal. asserted first, so a changed checksum path fails loudly
    my @c = map {"n7fs amos collision fixture $ARG\n"} 2042, 8794;
    my ( $a1, $b1 ) = addr_of( $c[0] );
    my ( $a2, $b2 ) = addr_of( $c[1] );
    ok( $a1 eq $a2 && $b1 ne $b2, "fixtures collide under amos $a1" );
    write_file( "$src/coll-1", $c[0] );
    write_file( "$src/coll-2", $c[1] );
    my $rc
        = assimilate( %run, qw| paths | => [ "$src/coll-1", "$src/coll-2" ] );
    ok( $rc->{'failed'} == 0, 'both stored' );
    my $amos_dir = join '/', $root, $disk, epoch_b32($epoch), $a1;
    my @sib      = grep {-d} glob "$amos_dir/*";
    ok( @sib == 2, 'two <bmw> siblings under one <amos>' );
    ok( read_file("$amos_dir/$b1/content") eq $c[0]
            && read_file("$amos_dir/$b2/content") eq $c[1],
        'each sibling holds its own content'
    );
    ok( store_verify( %base, qw| disk | => $disk )->{'nodes'} >= 6,
        'store verifies' );
}

say ':: inside the root is never a source';
{
    my $nd     = node_dir( $content{'a.txt'}, $epoch );
    my $before = snapshot( $root, $hdir );
    my $ri     = assimilate(
        %run,
        qw| paths |  => ["$nd/content"],
        qw| remove | => TRUE
    );
    ok( entry_for( $ri, "$nd/content" )->{'why'} =~ m|\Aprotected|,
        'a path inside the root is skipped' );
    ok( -e "$nd/content", 'and stays' );
}

say ':: the image index as a source list [ fake db, test data ]';
SKIP: {
    if ( not eval { require DBI; require DBD::SQLite; 1 } ) {
        say '  skip  DBD::SQLite not installed';
        last SKIP;
    }
    my $idx = "$box->{'base'}/image-index.db";
    my $dbh = DBI->connect( "dbi:SQLite:dbname=$idx", '', '',
        { RaiseError => 1 } );
    ## the sources table of src/invoke-web.index.db ##
    $dbh->do( 'CREATE TABLE sources ( image_name TEXT PRIMARY KEY, chksum '
            . 'TEXT, path TEXT, session_id TEXT, created_at TEXT, '
            . 'source_rowid INTEGER )' );
    my $i1 = write_file( "$src/idx-1.png",
        "\x89PNG\r\n\x1a\n test data : index one" );
    my $i2 = write_file( "$src/idx-2.png",
        "\x89PNG\r\n\x1a\n test data : index two" );
    my $ins
        = $dbh->prepare('INSERT INTO sources VALUES ( ?, ?, ?, ?, ?, ? )');
    ## TEST DATA : fake rows, fake checksums [ not real L13 values ] ##
    $ins->execute( 'idx-1.png', 'TESTDATAL13A1', $i1,   'test', 'test', 1 );
    $ins->execute( 'idx-2.png', 'TESTDATAL13A2', $i2,   'test', 'test', 2 );
    $ins->execute( 'gone.png',  undef, "$src/gone.png", 'test', 'test', 3 );
    $ins->execute( 'rel.png', 'TESTDATAL13A4', 'relative/rel.png', 'test',
        'test', 4 );
    $dbh->disconnect;

    my $db_before = snapshot($idx);
    my $rx        = assimilate( %run, qw| index | => $idx );
    ok( entry_for( $rx, $i1 )->{'status'} eq 'stored'
            && entry_for( $rx, $i2 )->{'status'} eq 'stored',
        'index rows stored'
    );
    ok( entry_for( $rx, "$src/gone.png" )->{'status'} eq 'skipped',
        'row without a checksum skipped' );
    ok( entry_for( $rx, 'relative/rel.png' )->{'status'} eq 'skipped',
        'relative path skipped' );
    ok( -e $i1 && -e $i2, 'index sources kept [ default ]' );
    my ($mf) = glob node_dir( read_file($i1), $epoch ) . '/meta/*.meta';
    ok( signed_record_parse( qw| meta |, read_file($mf) )
            ->{'payload'}{'index_chksum'} eq 'TESTDATAL13A1',
        'the index checksum is kept in meta'
    );
    ok( snap_equal( $db_before, snapshot($idx) ),
        'the index db is unchanged [ read-only ]'
    );

    ## index + remove : refused without a base ; rows outside it skipped ##
    my $before = snapshot( $root, $hdir, $src );
    refused(
        sub {
            assimilate( %run, qw| index | => $idx, qw| remove | => TRUE );
        },
        qr|needs an index base|,
        'index + remove without a base refused'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ),
        'refused : no change' );

    my $outside = write_file( "$box->{'base'}/outside.png",
        "\x89PNG\r\n\x1a\n test data : outside the base" );
    my $i3 = write_file( "$src/idx-3.png",
        "\x89PNG\r\n\x1a\n test data : index three" );
    $dbh = DBI->connect( "dbi:SQLite:dbname=$idx", '', '',
        { RaiseError => 1 } );
    ## TEST DATA : fake rows ##
    $dbh->do( 'INSERT INTO sources VALUES ( ?, ?, ?, ?, ?, ? )',
        undef, 'outside.png', 'TESTDATAL13A5', $outside, 'test', 'test', 5 );
    $dbh->do( 'INSERT INTO sources VALUES ( ?, ?, ?, ?, ?, ? )',
        undef, 'idx-3.png', 'TESTDATAL13A6', $i3, 'test', 'test', 6 );
    $dbh->disconnect;
    my $rb = assimilate(
        %run,
        qw| index |      => $idx,
        qw| index_base | => $src,
        qw| remove |     => TRUE
    );
    ok( entry_for( $rb, $outside )->{'why'} =~ m|outside the index base|
            && -e $outside,
        'a row outside the index base is skipped and kept'
    );
    ok( entry_for( $rb, $i3 )->{'then'} eq 'removed' && !-e $i3,
        'a row inside the base is removed after verification'
    );
}

say ':: the host side is never a source';
{
    my $before = snapshot($hdir);
    my $rh = assimilate( %run, qw| paths | => [$hdir], qw| remove | => TRUE );
    my @taken
        = grep { $ARG->{'status'} ne 'skipped' } $rh->{'entries'}->@*;
    ok( !@taken && $rh->{'entries'}->@*,
        'every host dir file is skipped [ keys, witness, mounts ]' );
    ok( snap_equal( $before, snapshot($hdir) ), 'the host dir is unchanged' );

    my $key = write_file( "$src/parent.key", "test data : a key file\n" );
    my $rk  = assimilate(
        %run,
        qw| paths |   => [$key],
        qw| remove |  => TRUE,
        qw| protect | => [$key]
    );
    ok( entry_for( $rk, $key )->{'why'} =~ m|\Aprotected| && -e $key,
        'a configured key file is never taken' );
}

say ':: not attached after detach';
disk_detach(%run);
{
    my $before = snapshot( $root, $hdir, $src );
    refused(
        sub {
            assimilate( %run, qw| paths | => [$src], qw| remove | => TRUE );
        },
        qr|not attached here|,
        'detached : refused'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir, $src ) ), 'no change' );
}

say ':: get and find [ detached ]';
disk_attach(%run);
my $empty = write_file( "$src/empty.bin", '' );
mkdir "$src/amb-one";
mkdir "$src/amb-two";
my $amb1
    = write_file( "$src/amb-one/same.txt", "test data : ambiguous one\n" );
my $amb2
    = write_file( "$src/amb-two/same.txt", "test data : ambiguous two\n" );
my $get_import = assimilate( %run, qw| paths | => [ $empty, $amb1, $amb2 ] );
my $empty_addr = entry_for( $get_import, $empty )->{'addr'};
my $amb1_addr  = entry_for( $get_import, $amb1 )->{'addr'};
my $amb2_addr  = entry_for( $get_import, $amb2 )->{'addr'};
my $png_addr   = entry_for( $r,          "$src/b.png" )->{'addr'};
my $a_addr     = entry_for( $r,          "$src/a.txt" )->{'addr'};
disk_detach(%run);

my ( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, $png_addr );
ok( $cli_rc == 0 && $cli_out eq $content{'b.png'} && $cli_err eq '',
    'get : binary stdout round trip [ detached ]' );

( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, 'b.png' );
ok( $cli_rc == 0 && $cli_out eq $content{'b.png'},
    'get : a unique meta name resolves'
);

( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, $empty_addr );
ok( $cli_rc == 0 && $cli_out eq '' && $cli_err eq '',
    'get : empty stdout round trip' );

my $png_out = "$box->{'base'}/get-b.png";
( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'get', $disk, $png_addr, '-out', $png_out );
ok( $cli_rc == 0
        && read_file($png_out) eq $content{'b.png'}
        && $cli_out =~ m|verified|,
    'get -out : binary file round trip'
);

( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'get', $disk, $png_addr, '-out', $png_out );
ok( $cli_rc != 0
        && $cli_err =~ m|exists|
        && read_file($png_out) eq $content{'b.png'},
    'get -out : refuses to overwrite'
);

my $empty_out = "$box->{'base'}/get-empty.bin";
( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'get', $disk, $empty_addr, '-out', $empty_out );
ok( $cli_rc == 0 && -f $empty_out && read_file($empty_out) eq '',
    'get -out : empty file round trip' );

{
    my $content_path = node_dir( $content{'b.png'}, $epoch ) . '/content';
    my $orig         = read_file($content_path);
    chmod 0600, $content_path;
    write_file( $content_path, "tampered\x00\xff" );
    my $refused_out = "$box->{'base'}/refused.bin";
    ( $cli_rc, $cli_out, $cli_err )
        = cli_n7fs( 'get', $disk, $png_addr, '-out', $refused_out );
    ok( $cli_rc != 0
            && $cli_err =~ m|content does not match|
            && $cli_out eq ''
            && !-e $refused_out
            && !glob("$refused_out.tmp.*"),
        'get -out : tamper refused, no output or temp file left'
    );
    ( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, $png_addr );
    ok( $cli_rc != 0 && $cli_out eq '',
        'get stdout : tamper refused before output' );
    write_file( $content_path, $orig );
    chmod 0400, $content_path;
}

( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, 'same.txt' );
ok( $cli_rc != 0
        && $cli_out eq ''
        && $cli_err =~ m|several nodes|
        && $cli_err =~ m|\Q$amb1_addr\E|
        && $cli_err =~ m|\Q$amb2_addr\E|,
    'get : an ambiguous name is refused with both addresses'
);

( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'find', $disk, '-name', 'a\.txt\z' );
my @find_lines = grep {length} split m|\n|, $cli_out;
ok( $cli_rc == 0
        && @find_lines == 1
        && $find_lines[0] =~ m|\A\Q$a_addr\E \d+ txt \S*/a\.txt\z|,
    'find : name filter and newest record per node + source'
);

( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'find', $disk, '-all', '-name', 'a\.txt\z' );
@find_lines = grep {length} split m|\n|, $cli_out;
ok( $cli_rc == 0
        && @find_lines == 2
        && !grep( { !m|\[ \d{14} \]\z| } @find_lines ),
    'find -all : every record with its import ntime'
);

( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'find', $disk, '-format', 'png' );
ok( $cli_rc == 0
        && $cli_out =~ m|^\Q$png_addr\E \d+ png \S*/b\.png$|m
        && $cli_out !~ m|a\.txt|,
    'find : format filter'
);

my ( undef, $png_amos, $png_bmw ) = split m|/|, $png_addr;
( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'find', $disk, '-chksum', $png_amos );
ok( $cli_rc == 0 && $cli_out =~ m|\A\Q$png_addr\E |,
    'find : amos checksum prefix' );
( $cli_rc, $cli_out, $cli_err )
    = cli_n7fs( 'find', $disk, '-chksum', substr( $png_bmw, 0, 17 ) );
ok( $cli_rc == 0 && $cli_out =~ m|\A\Q$png_addr\E |,
    'find : bmw checksum prefix' );

( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'find', $disk, '-name', '[' );
ok( $cli_rc != 0 && $cli_out eq '' && $cli_err =~ m|invalid -name regex|,
    'find : an invalid regex is a clean refusal' );

done();

#,,..,...,.,.,.,,,.,,,..,,...,...,.,.,.,,,,.,,..,,...,...,,..,,,,,...,.,,,.,,,
#IA3AGCNMCFNQUX7QMUYKIKQQ5WRMCLI3GNKYHIMBMTYFFJXYFEFRXFYZMJOZ3CDT6EKXRH3XL56RO
#\\\|PD3KE6KRIIRWHDZNPXVXFFRBZLUKY33DFSSSFN5RWIABNTLZGZT \ / AMOS7 \ YOURUM ::
#\[7]SSXFGKPP64FE5GVEEJYD2NNNPQF6FR3WOUNYFIGHQER7D325LWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
