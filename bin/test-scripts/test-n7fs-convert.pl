#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## N7FS store format conversion [ data/md/design/N7FS-SPEC.md section 6 ]. a
## deliberately made version-1 store is converted by the production 1 -> 2
## step : signed meta is written BESIDE the old one [ a new epoch ], verified,
## then switched ; the old epoch stays byte for byte until confirmed. failures
## before the switch leave format 1. temp roots only.
##
## perl bin/test-scripts/test-n7fs-convert.pl  N7FS_TEST_LIB=<dir> puts a
## [ mutated ] copy of the modules first

use FindBin;

BEGIN {
    unshift @INC, "$FindBin::Bin/../../data/lib-path/pm";
    unshift @INC, $ENV{'N7FS_TEST_LIB'} if $ENV{'N7FS_TEST_LIB'};
}

use AMOS7::N7FS       qw| read_file plain_record_pack |;
use AMOS7::N7FS::Sum  qw| epoch_b32 epoch_int |;
use AMOS7::N7FS::Disk qw| disk_init disk_attach disk_read_id state_read
    witness_read |;
use AMOS7::N7FS::Store qw| assimilate store_verify store_nodes meta_entries
    codec |;
use AMOS7::N7FS::Convert qw| steps upgrade confirm |;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

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
    intent => 'n7fs converter test [ test data ]'
);
my %run   = ( %base, disk => $disk, host => $host );
my $dpath = "$root/$disk";

## a format-1 fixture : remove the signed initial state and write its plain
## version-1 equivalent before the first attach [ the witness then pins 1 ]
{
    my ($state_file) = glob "$dpath/.n7fs/state/*.state";
    my $p = state_read($dpath);
    delete $p->{'_name'};
    $p->{'store_format'} = 1;
    unlink $state_file or die "unlink $state_file : $OS_ERROR";
    write_file( $state_file, plain_record_pack( 'state', $p ) );
}
disk_attach(%run);

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
ok( scalar( steps( 1, 2 ) ) == 1, 'production chain 1 -> 2 : one step' );
ok( scalar( steps( 1, 3 ) ) == 2,
    'production chain 1 -> 2 -> 3 : two steps' );

my $old_epoch_dir = "$dpath/" . epoch_b32($E);
my $old_snap      = snapshot($old_epoch_dir);
my @old_meta      = meta_entries( %base, disk => $disk );

say ':: format 1 readers warn that names are unsigned';
my $old_addr = join '/', epoch_b32($E), $old[0]->{'amos'}, $old[0]->{'bmw'};
my ( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'get', $disk, $old_addr );
ok( $cli_rc == 0
        && $cli_out eq read_file( $old[0]->{'path'} . '/content' )
        && $cli_err =~ m|meta names are unsigned|,
    'get on format 1 warns and still returns verified content'
);
( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'find', $disk );
ok( $cli_rc == 0
        && $cli_out =~ m|/f0$|m
        && $cli_err =~ m|meta names are unsigned|,
    'find on format 1 warns and still lists names'
);

say ':: refusals and failures before the switch leave format 1';

sub unchanged_after {
    my ( $code, $re, $name ) = @ARG;
    my $before = snapshot( $root, $hdir );
    refused( $code, $re, $name );
    ok( snap_equal( $before, snapshot( $root, $hdir ) ),
        "$name : no change on disk" );
    ok( state_read($dpath)->{'store_format'} == 1, "$name : still format 1" );
}

unchanged_after(
    sub { upgrade( %run, epoch => $E, target => 2 ) },
    qr|belongs to this store already|,
    '-epoch at the current epoch refused [ the window is used, not -epoch ]'
);

clock_epoch( $E + 1 );
foreach my $point (qw| convert:after-node convert:before-switch |) {
    local $AMOS7::N7FS::FAULT
        = sub { die "injected fault\n" if $ARG[0] eq $point };
    unchanged_after(
        sub { upgrade( %run, target => 2 ) },
        qr|injected fault|,
        "fault at $point"
    );
}

{
    my $damaged = 0;
    local $AMOS7::N7FS::FAULT = sub {
        return if $ARG[0] ne 'convert:after-node' or $damaged++;
        my ($n) = store_nodes( $dpath, $E + 2 );
        my $p = "$n->{'path'}/content";
        chmod 0600, $p;
        write_file( $p, 'damaged' );
    };
    unchanged_after(
        sub { upgrade( %run, target => 2 ) },
        qr|content does not match its bmw|,
        'a damaged new node is caught before the switch'
    );
}

say ':: the upgrade : it lands in next, not in the current epoch';
my $r = upgrade( %run, target => 2 );
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
ok( witness_read(%run)->{'store_format'} == 2,
    'the upgrade appends a highest-format witness observation' );
ok( snap_equal( $old_snap, snapshot($old_epoch_dir) ),
    'the old epoch is byte-identical' );

my @new = store_nodes( $dpath, $E + 2 );
ok( join( ' ', map {"$ARG->{'amos'}/$ARG->{'bmw'}"} @new ) eq
        join( ' ', map {"$ARG->{'amos'}/$ARG->{'bmw'}"} @old ),
    'the same content addresses in the new epoch'
);
ok( !grep(
        { read_file("$ARG->{'path'}/content") ne
                read_file(
                $old_epoch_dir . "/$ARG->{'amos'}/$ARG->{'bmw'}/content" ) }
        @new ),
    'the same content bytes'
);

my @new_meta = meta_entries( %base, disk => $disk );
my %old_by
    = map { join( "\0", $ARG->{'source'}, $ARG->{'import_ntime'} ) => $ARG }
    @old_meta;
my $meta_ok = @new_meta == @old_meta;
foreach my $m (@new_meta) {
    my $key = join "\0", $m->{'source'}, $m->{'import_ntime'};
    my $old = $old_by{$key};
    $meta_ok = 0 if not defined $old or not $m->{'converted_from_unsigned'};
    next if not defined $old;
    foreach my $field ( keys %{$old} ) {
        next if $field =~ m{\A(?:epoch|address|node_path)\z};
        $meta_ok = 0
            if ( $old->{$field} // '' ) ne ( $m->{$field} // '' );
    }
}
ok( $meta_ok,
          'all meta fields and import ntimes survive '
        . '; every record is marked unsigned-origin' );

my $id      = disk_read_id( %base, disk => $disk );
my $context = { id => $id };
refused(
    sub {
        codec(1)->{'verify_node'}->( $new[0]{'path'}, $new[0], $context );
    },
    qr|signed|,
    'the v1 reader refuses a signed v2 node'
);
refused(
    sub {
        codec(2)->{'verify_node'}->( $old[0]{'path'}, $old[0], $context );
    },
    qr|unsigned|,
    'the v2 reader refuses a plain v1 node'
);
ok( store_verify( %base, disk => $disk )->{'nodes'} == 4,
    'store verifies as format 2' );

( $cli_rc, $cli_out, $cli_err ) = cli_n7fs( 'find', $disk, '-all' );
my $converted_lines = grep {m|converted_from_unsigned|} split m|\n|, $cli_out;
ok( $cli_rc == 0 && $cli_err eq '' && $converted_lines == 4,
    'find -all shows converted_from_unsigned on every converted record'
);

say ':: after the switch';
{
    my $f = write_file( "$src/later", "test data : after the upgrade\n" );
    assimilate( %run, paths => [$f] );
    my @n = grep {
        read_file("$ARG->{'path'}/content") eq "test data : after "
            . "the upgrade\n"
    } store_nodes( $dpath, $E + 2 );
    ok( @n == 1, 'new content goes to the new epoch' );
    my ($mf) = glob "$n[0]{'path'}/meta/*.meta";
    ok( substr( read_file($mf), 0, 5 ) eq "P7FN\x02",
        'new meta is signed format 2' );
}
unchanged_after_v2(
    sub { upgrade( %run, target => 2 ) },
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
        sub { upgrade( %run, target => 2 ) },
        qr|still in the window|,
        'the next upgrade refuses while the old form is in the window'
    );
    ok( -d $old_epoch_dir && ref state_read($dpath)->{'previous'} eq 'HASH',
        'the refusal changed nothing [ the old form stays ]' );

    clock_epoch( $E + 2 );    ## window { $E+1, $E+2, $E+3 } : $E left ##
    my $rel = upgrade( %run, target => 2 );
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
        "$name : no change on disk" );
}

done();

#,,,.,.,,,.,,,.,.,,.,,,.,,,,.,.,.,.,.,,.,,,,.,.,.,...,...,,..,.,.,.,,,,.,,,,.,
#2DD7H7VIM4GA4FQTUQ756TQQQGVYGTLBC7QFHG6U3ZGC5UQRSSOS5UM33HPLZZGY3MTPHRYZIEUAI
#\\\|5F4NR45PENAOM3GQVPVYOAX2FYRUWWSLDLRR5V3ZZWPT73XQKBV \ / AMOS7 \ YOURUM ::
#\[7]EB77UWF4GO36IZV3KJR5HIHL3JHF2ZROCJKNJCGV6X4VIE4ONKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
