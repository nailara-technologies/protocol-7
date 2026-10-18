#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS version 1 : the converter proof
## [ data/md/design/N7FS-SPEC.md section 6 ]. a deliberately made version-1
## store is converted by a TEST-ONLY version-2 step : the new form is written
## BESIDE the old one [ a new epoch ], verified, then switched ; the old epoch
## stays byte for byte until confirmed. failures before the switch leave
## format 1.
##
## format 2 exists only in this file [ codec + step registered here ] : meta
## records in record format 2 with 'node_format' => 2, plus a 'format' key
## file per node. temp roots only.
##
## perl bin/test-scripts/test-n7fs-convert.pl  N7FS_TEST_LIB=<dir> puts a
## [ mutated ] copy of the modules first

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use Digest::BMW;
use AMOS7::N7FS qw| b32 random_bytes read_file write_new_file
    write_new_file_stream make_dirs plain_record_pack plain_record_parse
    refuse |;
use AMOS7::N7FS::Sum  qw| bmw_b32 amos_of_bmw bmw384_fh epoch_b32 epoch_int |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach state_read |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes
    register_codec codec |;
use AMOS7::N7FS::Convert qw| register_step steps upgrade confirm |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

##[ TEST-ONLY FORMAT 2 ]######################################################

our $BREAK = 0;    ## 1 : the v2 writer damages the first node it writes ##

sub v2_write_meta {
    my ( $dir, $meta ) = @ARG;
    my $name = sprintf '%s.%s.meta', $meta->{'import_ntime'},
        b32( random_bytes(5) );
    write_new_file( "$dir/meta/$name",
        plain_record_pack( 'meta', { %{$meta}, node_format => 2 }, 2 ) );
    return $name;
}

sub v2_write_node {
    my ( $dir, $node ) = @ARG;
    open( my $src, '<:raw', $node->{'content_path'} )
        or die "open : $OS_ERROR\n";
    my $damage = $BREAK ? $BREAK-- : 0;
    write_new_file_stream(
        "$dir/content",
        sub {
            local $INPUT_RECORD_SEPARATOR;
            print { $ARG[0] } <$src>, ( $damage ? 'damage' : '' ) or die;
        },
        0400
    );
    close $src;
    write_new_file( "$dir/format", "2\n" );
    make_dirs( "$dir/meta", 0700 );
    v2_write_meta( $dir, $ARG ) for $node->{'metas'}->@*;
    return TRUE;
}

sub v2_read_node {
    my $dir = shift;
    my @metas;
    opendir( my $dh, "$dir/meta" ) or refuse( 'no meta in %s', $dir );
    foreach my $name ( sort grep {m|\.meta\z|} readdir $dh ) {
        my $rec = plain_record_parse( 'meta', read_file("$dir/meta/$name") );
        refuse( 'meta %s : not ' . 'record format 2', $name )
            if $rec->{'format'} != 2;
        push @metas, $rec->{'payload'};
    }
    return { content_path => "$dir/content", metas => \@metas };
}

sub v2_verify_node {
    my ( $dir, $addr ) = @ARG;
    refuse( 'node %s : not format 2', $dir )
        if ( read_file("$dir/format") // '' ) ne "2\n";
    open( my $fh, '<:raw', "$dir/content" )
        or refuse( 'no content ' . 'in %s', $dir );
    my ( $digest, $size ) = bmw384_fh($fh);
    close $fh;
    refuse( 'node %s : content does not match its bmw', $dir )
        if bmw_b32($digest) ne $addr->{'bmw'};
    refuse( 'node %s : bmw does not match its amos', $dir )
        if amos_of_bmw( $addr->{'bmw'} ) ne $addr->{'amos'};
    my $node = v2_read_node($dir);
    refuse( 'node %s : no meta', $dir ) if not $node->{'metas'}->@*;

    foreach my $m ( $node->{'metas'}->@* ) {
        refuse( 'node %s : meta mismatch', $dir )
            if $m->{'node_format'} != 2
            or $m->{'size'} != $size
            or $m->{'bmw'} ne $addr->{'bmw'};
    }
    return $size;
}

sub register_format_2 {
    $AMOS7::N7FS::RECORD_FORMAT{'meta'}{2} = TRUE;
    register_codec(
        2,
        {   write_node  => \&v2_write_node,
            read_node   => \&v2_read_node,
            verify_node => \&v2_verify_node,
            write_meta  => \&v2_write_meta,
        }
    );
    register_step(
        1,
        sub {
            my ( $node, $step ) = @ARG;
            $node->{'metas'} = [
                map {
                    { %{$ARG}, converted_from => $step->{'from'} }
                } $node->{'metas'}->@*
            ];
            return $node;
        }
    );
}

##[ A VERSION-1 STORE ]#######################################################

my $box  = sandbox();
my $root = $box->{'root'};
my $hdir = $box->{'host'};
my $src  = $box->{'src'};
my $host = test_signer();

my $E = epoch_int( clock_real() );
clock_epoch($E);

my %base = ( root => $root, host_dir => $hdir );
my $disk = disk_init(
    %base,
    parent => test_signer(),
    name   => 'convert-test',
    intent => 'n7fs converter proof [ test data ]'
);
my %run   = ( %base, disk => $disk, host => $host );
my $dpath = "$root/$disk";
disk_attach(%run);

my @bodies = (
    "test data : convert one\n",
    "test data : convert two\n" x 50,
    "n7fs amos collision fixture 2042\n",
    "n7fs amos collision fixture 8794\n",
);
for my $i ( 0 .. $#bodies ) { write_file( "$src/f$i", $bodies[$i] ) }
assimilate( %run, paths => [$src] );

my @old = store_nodes( $dpath, $E );
ok( @old == 4, 'version-1 store with 4 nodes [ incl. an amos collision ]' );
ok( state_read($dpath)->{'store_format'} == 1, 'state : format 1' );

my $old_epoch_dir = "$dpath/" . epoch_b32($E);
my $old_snap      = snapshot($old_epoch_dir);

say ':: no step registered : nothing to convert';
{
    my $before = snapshot( $root, $hdir );
    my $r      = upgrade(%run);
    ok( $r->{'from'} == 1 && $r->{'to'} == 1,
        'format 1 is ' . 'the newest known'
    );
    ok( snap_equal( $before, snapshot( $root, $hdir ) ), 'no change' );
}

register_format_2();
ok( scalar( steps( 1, 2 ) ) == 1, 'chain 1 -> 2 : one step' );
refused(
    sub { steps( 1, 3 ) },
    qr|no converter chain|,
    'no chain ' . 'to format 3'
);

say ':: refusals and failures before the switch leave format 1';

sub unchanged_after {
    my ( $code, $re, $name ) = @ARG;
    my $before = snapshot( $root, $hdir );
    refused( $code, $re, $name );
    ok( snap_equal( $before, snapshot( $root, $hdir ) ),
        "$name : no change " . "on disk" );
    ok( state_read($dpath)->{'store_format'} == 1, "$name : still format 1" );
}

unchanged_after(
    sub { upgrade( %run, epoch => $E ) },
    qr|belongs to this store already|,
    '-epoch at the current epoch refused [ the window is used, not -epoch ]'
);

clock_epoch( $E + 1 );
foreach my $point (qw| convert:after-node convert:before-switch |) {
    local $AMOS7::N7FS::FAULT
        = sub { die "injected fault\n" if $ARG[0] eq $point };
    unchanged_after(
        sub { upgrade(%run) },
        qr|injected fault|,
        "fault at $point"
    );
}

{
    local $BREAK = 1;
    unchanged_after(
        sub { upgrade(%run) },
        qr|content does not match its bmw|,
        'a damaged new node is caught before the switch'
    );
}

say ':: the upgrade : it lands in next, not in the current epoch';
my $r = upgrade(%run);
ok( $r->{'from'} == 1 && $r->{'to'} == 2 && $r->{'nodes'} == 4,
    'format 1 -> 2 : 4 nodes' );
ok( $r->{'epoch'} == $E + 2,
    'written into next [ the current epoch holds data ]' );
my $st = state_read($dpath);
ok( $st->{'store_format'} == 2 && "@{ $st->{'epochs'} }" eq $E + 2,
    'state : format 2 in the next epoch' );
ok( $st->{'previous'}{'store_format'} == 1
        && "@{ $st->{'previous'}{'epochs'} }" eq $E
        && !$st->{'confirmed'},
    'state : the old form kept as previous, unconfirmed'
);
ok( snap_equal( $old_snap, snapshot($old_epoch_dir) ),
    'the old epoch is byte-identical' );

my @new = store_nodes( $dpath, $E + 2 );
ok( join( ' ', map {"$ARG->{'amos'}/$ARG->{'bmw'}"} @new ) eq
        join( ' ', map {"$ARG->{'amos'}/$ARG->{'bmw'}"} @old ),
    'the same addresses in the new epoch'
);
ok( !grep(
        { read_file("$ARG->{'path'}/content") ne
                read_file(
                $old_epoch_dir . "/$ARG->{'amos'}/$ARG->{'bmw'}/content" ) }
        @new ),
    'the same content'
);
ok( v2_read_node( $new[0]{'path'} )->{'metas'}[0]{'converted_from'} == 1,
    'the step ran [ converted_from ]' );
refused(
    sub { codec(1)->{'verify_node'}->( $new[0]{'path'}, $new[0] ) },
    qr|not node format 1|,
    'the v1 reader refuses a v2 node'
);
refused(
    sub { codec(2)->{'verify_node'}->( $old[0]{'path'}, $old[0] ) },
    qr|not format 2|,
    'the v2 reader refuses a v1 node'
);
ok( store_verify( %base, disk => $disk )->{'nodes'} == 4,
    'store verifies as ' . 'format 2' );

say ':: after the switch';
{
    my $f = write_file( "$src/later", "test data : after the upgrade\n" );
    assimilate( %run, paths => [$f] );
    my @n = grep {
        read_file("$ARG->{'path'}/content") eq "test data : after "
            . "the upgrade\n"
    } store_nodes( $dpath, $E + 2 );
    ok( @n == 1, 'new content goes to the new epoch' );
    ok( read_file("$n[0]{'path'}/format") eq "2\n", 'in format 2' );
}
unchanged_after_v2(
    sub { upgrade(%run) },
    qr|awaits confirm|,
    'no second upgrade before confirm'
);

{
    my $p    = "$new[0]{'path'}/content";
    my $orig = read_file($p);
    chmod 0600, $p;
    write_file( $p, 'damaged' );
    unchanged_after_v2(
        sub { confirm(%run) },
        qr|content does not match|,
        'confirm re-verifies and refuses damage'
    );
    write_file( $p, $orig );
    chmod 0400, $p;
}

my $c = confirm(%run);
ok( $c->{'format'} == 2 && $c->{'nodes'} == 5, 'confirmed [ 5 nodes ]' );
ok( state_read($dpath)->{'confirmed'},         'state : confirmed' );
ok( snap_equal( $old_snap, snapshot($old_epoch_dir) ),
    'the old epoch is still there, unchanged [ release is later ]'
);

say ':: the window : the old form stays, and is released only when it leaves';
{
    ## the clock is at $E+1 : the window is { $E, $E+1, $E+2 } -- the old form
    ## [ epoch $E ] is still previous : readable, not releasable
    ok( scalar( store_nodes( $dpath, $E ) ) == 4,
        'the old form is still readable while previous'
    );
    refused(
        sub { upgrade(%run) },
        qr|still in the window|,
        'the next upgrade refuses while the old form is in the window'
    );
    ok( -d $old_epoch_dir && ref state_read($dpath)->{'previous'} eq 'HASH',
        'the refusal changed nothing [ the old form stays ]' );

    clock_epoch( $E + 2 );    ## window { $E+1, $E+2, $E+3 } : $E left ##
    my $rel = upgrade(%run);
    ok( $rel->{'from'} == 2 && $rel->{'to'} == 2,
        'no newer format : the release runs, the upgrade is a no-op' );
    ok( !-e $old_epoch_dir,
        'the old epoch is released once it leaves the window' );
    my $st_r = state_read($dpath);
    ok( ref $st_r->{'previous'} ne 'HASH', 'the state forgets the old form' );
    ok( store_verify( %base, disk => $disk )->{'nodes'} == 5,
        'the store verifies [ the active epoch only ]'
    );
}

sub unchanged_after_v2 {
    my ( $code, $re, $name ) = @ARG;
    my $before = snapshot( $root, $hdir );
    refused( $code, $re, $name );
    ok( snap_equal( $before, snapshot( $root, $hdir ) ),
        "$name : no change " . "on disk" );
}

done();

#,,,,,..,,,.,,,.,,,,.,...,,.,,,,,,.,.,,,.,.,,,..,,...,...,...,,..,,,.,.,,,,,,,
#CD7EF74WVZXGIR6XQX3UYY2DTPTFCN7W7GKDOXIK2THRH4AT2TH6BKLYYVBCAYTWDTCRCJZ3KH5X2
#\\\|D2KLSCGHL3YYPMFTAJDLDQXOOIPPUO25RWYJQPKPVI6XHY26XXO \ / AMOS7 \ YOURUM ::
#\[7]77PYYTIGCOXQS2FQOI4Q3WP3A3HAGN5INH5MKZEK6QZUL3SLN6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
