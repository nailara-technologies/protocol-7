#!/usr/bin/perl

use v5.24;
use strict;
use English;
use warnings;

##[ LOCAL PM LIB PATH ]#######################################################

BEGIN {
    use English;
    use File::Spec;
    use Cwd     qw| abs_path |;
    use FindBin qw| $RealBin |;
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path
        = abs_path( r2_abs( c_dir( $RealBin, $up_dir, $up_dir, $up_dir ) ) );
    my $local_lib_path = abs_path( c_dir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path )               if -d $local_lib_path;
    sub c_dir  { File::Spec->catdir(@ARG) }
    sub r2_abs { File::Spec->rel2abs(@ARG) }
}

##[ AMOS MODULES ]############################################################

use AMOS7::SHM::Transport qw| shm_announce shm_receive |;
use AMOS7::SHM            qw| shm_open |;
use AMOS7::SHM::Page      qw| data_offset |;
use AMOS7::CHKSUM         qw| amos_chksum |;

use POSIX qw| _exit |;

##[ TEST SETUP ]##############################################################

my $page_size = 4096;
my $payload   = "AMOS7::SHM::Transport cross-process test payload.\n"
    . ( "1234567890" x 2048 );    ## spans multiple pages at 4096 ##

my $content_size   = length($payload);
my $expected_pages = int( ( $content_size + $page_size - 1 ) / $page_size );

## structural key fixtures, same pattern as every prior SHM test script ##
my $owner_privkey = 'OWNERTEST' . sprintf( '%031X', time() + $$ );
my $owner_pubkey  = substr( $owner_privkey, 0, 32 );

my $reader_privkey = 'READERTEST' . sprintf( '%030X', time() + $$ + 1 );
my $reader_pubkey  = substr( $reader_privkey, 0, 32 );

my $intruder_privkey = 'INTRUDERTEST' . sprintf( '%028X', time() + $$ + 2 );
my $intruder_pubkey  = substr( $intruder_privkey, 0, 32 );

my $checksum = amos_chksum( \$payload );

my @results;

sub ok {
    my ( $name, $condition, $detail ) = @ARG;
    my $status = $condition ? 'PASS' : 'FAIL';
    push @results, [ $name, $condition ];
    print "[$status] $name";
    print " -- $detail" if defined $detail;
    print "\n";
    return $condition;
}

##[ TEST 1: announce creates a matching descriptor ]##########################

my $descriptor = shm_announce(
    {   'owner_pubkey'  => $owner_pubkey,
        'owner_privkey' => $owner_privkey,
        'reader_pubkey' => $reader_pubkey,
        'content_ref'   => \$payload,
        'checksum'      => $checksum,
        'page_size'     => $page_size,
        'sub_path'      => 'transport-test',
        'mlock'         => 0,
    }
);

if (!ok('shm_announce succeeded',
        defined $descriptor && !exists $descriptor->{'error'}
    )
) {
    exit 1;
}

my $desc_ok = 1;
$desc_ok &&= $descriptor->{'total_pages'} == $expected_pages;
$desc_ok &&= $descriptor->{'content_size'} == $content_size;
$desc_ok &&= $descriptor->{'checksum'} eq $checksum;
$desc_ok &&= $descriptor->{'page_size'} == $page_size;
$desc_ok &&= $descriptor->{'owner_pubkey'} eq $owner_pubkey;
$desc_ok &&= $descriptor->{'sub_path'} eq 'transport-test';

ok( 'descriptor fields match announce inputs',
    $desc_ok,
    "pages=$descriptor->{'total_pages'} size=$descriptor->{'content_size'}" );

##[ TEST 2: granted reader receives exact content, checksum verified ]########

my $received = shm_receive(
    {   'shm_path'       => $descriptor->{'shm_path'},
        'reader_privkey' => $reader_privkey,
        'checksum_fn'    => \&amos_chksum,
    }
);

my $rx_ok = ok(
    'single-process reader receives payload with ok => TRUE',
    defined $received
        && exists $received->{'ok'}
        && $received->{'ok'}
        && !exists $received->{'error'},
    defined $received && exists $received->{'error'}
    ? "error=$received->{'error'}"
    : undef
);

if ($rx_ok) {
    ok( 'single-process reassembled content is byte-identical',
        ${ $received->{'content_ref'} } eq $payload,
        "pages=$received->{'pages'}"
    );
}

##[ TEST 3: cross-process reader receives from a separate process ]###########

pipe( my $cr, my $cw ) or die "pipe failed: $!";
$cr->autoflush(1);
$cw->autoflush(1);

my $child_pid = fork();
die "fork failed: $!" unless defined $child_pid;

if ( $child_pid == 0 ) {
    ## child: receive as reader, report result to parent ##
    close($cr);
    my $child_rx = shm_receive(
        {   'owner_pubkey'   => $owner_pubkey,
            'sub_path'       => 'transport-test',
            'reader_privkey' => $reader_privkey,
            'checksum_fn'    => \&amos_chksum,
        }
    );

    my $ok
        = defined $child_rx
        && exists $child_rx->{'ok'}
        && $child_rx->{'ok'}
        && ${ $child_rx->{'content_ref'} } eq $payload;

    if ($ok) {
        print $cw "CROSS_OK $child_rx->{'pages'}\n";
    } else {
        my $detail
            = defined $child_rx
            ? "ok=$child_rx->{'ok'} error=$child_rx->{'error'}"
            : 'undef';
        print $cw "CROSS_FAIL $detail\n";
    }
    close($cw);
    _exit(0);    ## skip END cleanup in child ##
}

close($cw);
my $child_report = <$cr>;
chomp($child_report) if defined $child_report;
close($cr);
waitpid( $child_pid, 0 );

ok( 'cross-process reader receives exact payload and verifies checksum',
    defined $child_report && $child_report =~ m{^CROSS_OK},
    defined $child_report ? "report='$child_report'" : 'no report'
);

##[ TEST 4: ungranted key is denied access and sees no content ]##############

my $intruder_rx = shm_receive(
    {   'shm_path'       => $descriptor->{'shm_path'},
        'reader_privkey' => $intruder_privkey,
        'checksum_fn'    => \&amos_chksum,
    }
);

ok( 'ungranted reader gets ok => FALSE',
    defined $intruder_rx
        && exists $intruder_rx->{'ok'}
        && !$intruder_rx->{'ok'},
    defined $intruder_rx ? "ok=$intruder_rx->{'ok'}" : 'undef'
);

ok( 'ungranted reader error is access_denied',
    defined $intruder_rx
        && exists $intruder_rx->{'error'}
        && $intruder_rx->{'error'} eq 'access_denied',
    defined $intruder_rx && exists $intruder_rx->{'error'}
    ? "error=$intruder_rx->{'error'}"
    : 'no error key'
);

ok( 'ungranted reader receives no content_ref',
    defined $intruder_rx && !exists $intruder_rx->{'content_ref'},
    defined $intruder_rx && exists $intruder_rx->{'content_ref'}
    ? 'content_ref was present'
    : undef
);

##[ TEST 5: corrupted content is detected as checksum_mismatch ]##############

my $corrupt_payload  = "CORRUPT-TEST-" x 500;
my $corrupt_checksum = amos_chksum( \$corrupt_payload );

my $corrupt_descriptor = shm_announce(
    {   'owner_pubkey'  => $owner_pubkey,
        'owner_privkey' => $owner_privkey,
        'reader_pubkey' => $reader_pubkey,
        'content_ref'   => \$corrupt_payload,
        'checksum'      => $corrupt_checksum,
        'page_size'     => $page_size,
        'sub_path'      => 'transport-corrupt',
        'mlock'         => 0,
    }
);

my $corrupt_ok = ok(
    'corruption-test announce succeeded',
    defined $corrupt_descriptor && !exists $corrupt_descriptor->{'error'},
    defined $corrupt_descriptor && exists $corrupt_descriptor->{'error'}
    ? "error=$corrupt_descriptor->{'error'}"
    : undef
);

if ($corrupt_ok) {
    ## open as owner and poke one byte in the data region ##
    my $owner_mount = shm_open(
        $corrupt_descriptor->{'shm_path'},
        { 'mode' => 'write' },
        $owner_privkey
    );

    if ( defined $owner_mount && !exists $owner_mount->{'error'} ) {
        ## owner open is read-only via shm_open; obtain a writable mmap ##
        my $shm_path = $corrupt_descriptor->{'shm_path'};
        open( my $fh, '+<', $shm_path ) or die "cannot open $shm_path: $!";
        binmode($fh);
        my $size          = -s $shm_path;
        my $writable_mmap = AMOS7::SHM::mmap_file( $fh, $size );
        die "mmap failed for $shm_path" unless defined $writable_mmap;
        close($fh);

        my $offset = data_offset();
        substr( $$writable_mmap, $offset, 1 ) = 'X';

        my $corrupt_rx = shm_receive(
            {   'shm_path'       => $corrupt_descriptor->{'shm_path'},
                'reader_privkey' => $reader_privkey,
                'checksum_fn'    => \&amos_chksum,
            }
        );

        ok( 'corrupted payload reports checksum_mismatch',
            defined $corrupt_rx
                && exists $corrupt_rx->{'ok'}
                && !$corrupt_rx->{'ok'}
                && exists $corrupt_rx->{'error'}
                && $corrupt_rx->{'error'} eq 'checksum_mismatch',
            defined $corrupt_rx && exists $corrupt_rx->{'error'}
            ? "error=$corrupt_rx->{'error'}"
            : 'undef'
        );
    } else {
        ok( 'corruption-test owner open failed', 0,
            'could not open segment' );
    }
}

##[ SUMMARY ]#################################################################

my $failed = grep { !$_->[1] } @results;
my $total  = scalar @results;

print "\n";
if ( $failed == 0 ) {
    print "=== All $total tests passed ===\n";
    exit 0;
} else {
    print "=== $failed of $total tests failed ===\n";
    exit 1;
}

#,,,,,,..,,..,.,,,.,.,,,,,.,.,,.,,.,,,..,,,..,.,.,...,...,.,,,...,.,,,...,...,
#C5OOB5OF6UWJG2GBVMGDEB6HHX4CHB6JQ6SUNT673G6QMLPPNB2QXBUI7JIKFLTJZ6IYYGVD5BRMC
#\\\|G46N6WX27DHYCPKBFRDKDRLIIBXD2JVH2DOXYOBOBDFE4CCIL2M \ / AMOS7 \ YOURUM ::
#\[7]MOSXU4ZECOHDBM2H6EPFX5PAS67YJUZ3YYX3RIFBVJXEL3XLSOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
