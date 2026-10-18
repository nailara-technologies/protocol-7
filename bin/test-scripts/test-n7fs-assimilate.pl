#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS version 1 : assimilate [ data/md/design/N7FS-SPEC.md section 7 ] --
## keep \ remove \ dry-run, a failure at every stage leaves the source, a real
## amos collision [ two bmw siblings ], the image index as a source list
## [ a tiny fake sqlite db, rows marked as test data ]. temp roots only.
##
## perl bin/test-scripts/test-n7fs-assimilate.pl  N7FS_TEST_LIB=<dir> puts a
## [ mutated ] copy of the modules first

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS      qw| read_file plain_record_parse |;
use AMOS7::N7FS::Sum qw| amos_of_bytes bmw_b32 bmw384_bytes epoch_b32
    epoch_int |;
use AMOS7::N7FS::Disk  qw| disk_init disk_attach disk_detach state_read |;
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
        "$name : source " . "unchanged" );
    my $nd = node_dir( $content{$name}, $epoch );
    ok( read_file("$nd/content") eq $content{$name},
        "$name : content at <epoch>/<amos>/<bmw>/content"
    );
}
ok( -e "$src/link" && -l "$src/link", 'the symlink is untouched' );
{
    my $nd   = node_dir( $content{'b.png'}, $epoch );
    my ($mf) = glob "$nd/meta/*.meta";
    my $m    = plain_record_parse( qw| meta |, read_file($mf) );
    my $p    = $m->{'payload'};
    ok( substr( read_file($mf), 0, 5 ) eq "P7FN\x01",
        "meta : 'P7FN' " . "+ format 1" );
    ok( $p->{'name'} eq 'b.png'
            && $p->{'format'} eq 'png'
            && $p->{'size'} == length $content{'b.png'}
            && $p->{'mtime'} == ( stat "$src/b.png" )[9]
            && $p->{'import_ntime'} =~ m|\A\d{14}\z|
            && $p->{'source'}       =~ m|/src/b\.png\z|,
        'meta : name, format, size, mtime, import ntime, source'
    );
}
ok( state_read("$root/$disk")->{'epochs'}[0] == $epoch,
    'the epoch entered the state' );
ok( store_verify( %base, qw| disk | => $disk )->{'nodes'} == 3,
    'store verifies [ 3 nodes ]' );

say ':: dedup';
{
    my $r2 = assimilate( %run, qw| paths | => ["$src/a.txt"] );
    ok( entry_for( $r2, "$src/a.txt" )->{'status'} eq 'dedup',
        'same content : dedup' );
    my @meta = glob node_dir( $content{'a.txt'}, $epoch ) . '/meta/*.meta';
    ok( @meta == 2, 'a second meta record, nothing rewritten' );
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
        'keep + remove ' . 'refused'
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
            node_dir( "test data : " . "to be removed\n", $epoch )
                . '/content'
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
        "$point : " . "reported " . "failed" );
    ok( read_file($f) eq $body, "$point : source untouched" );
    my $nd = node_dir( $body, $epoch );

    if ( $point eq 'assimilate:before-publish' ) {
        ok( !-e $nd, "$point : nothing published" );
        my $amos_dir = $nd =~ s|/[^/]+\z||r;
        ok( !grep( {m|\.tmp\.|} glob("$amos_dir/*") ),
            "$point : no " . "temp left" );
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
        'damaged node ' . ': dedup fails' );
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
        "\x89PNG\r\n\x1a\n " . "test data : index one" );
    my $i2 = write_file( "$src/idx-2.png",
        "\x89PNG\r\n\x1a\n " . "test data : index two" );
    my $ins = $dbh->prepare(
        'INSERT INTO sources ' . 'VALUES ( ?, ?, ?, ?, ?, ? )' );
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
    ok( plain_record_parse( qw| meta |, read_file($mf) )
            ->{'payload'}{'index_chksum'} eq 'TESTDATAL13A1',
        'the index checksum is kept in meta'
    );
    ok( snap_equal( $db_before, snapshot($idx) ),
        'the index db is unchanged ' . '[ read-only ]'
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
        "\x89PNG\r\n\x1a\n " . "test data : outside the base" );
    my $i3 = write_file( "$src/idx-3.png",
        "\x89PNG\r\n\x1a\n " . "test data : index three" );
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

done();

#,,,.,.,.,,.,,.,.,..,,.,,,,.,,...,.,.,,,,,,,,,..,,...,..,,..,,,,,,,..,,,.,,,.,
#TS5VBAQURIJT3S676EJE73YZHOMDHI23CO6YL77NNLNWOAUJEQPR7VJ46XWKL3PI5MSK6JXA4K2XS
#\\\|4VJNYCBBFR7LUXGELYLDBS3Q53RKTCCEBA7PSADHL2GVPAE25LS \ / AMOS7 \ YOURUM ::
#\[7]S5QCNBTJQN2YFBNOWHYK2CM5SEHYGICSVRUTJ64MTZRVP43BOECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
