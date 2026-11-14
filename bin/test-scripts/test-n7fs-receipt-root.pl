#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use JSON::PP;
use AMOS7::NTIME      qw| parse_y_age |;
use AMOS7::N7FS       qw| b32 make_dirs read_file |;
use AMOS7::N7FS::Sum  qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Sign qw| verify |;
use AMOS7::N7FS::Placement;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box    = sandbox();
my $hdir   = $box->{'host'};
my $holder = "$box->{'base'}/holder";
make_dirs($holder);
my $host_signer = test_signer();
my $root_a      = bmw_b32( bmw384_bytes('receipt root a') );
my $root_b      = bmw_b32( bmw384_bytes('receipt root b') );
my $root_c      = bmw_b32( bmw384_bytes('receipt root c') );
my $root_old    = bmw_b32( bmw384_bytes('old path root') );
my %roots       = map {
    my $id = $ARG;
    $id => {
        qw| signer |  => test_signer(),
        qw| root_id | => $id,
        qw| path |    => "$box->{'base'}/$id.key",
    }
} $root_a, $root_b, $root_c, $root_old;
my $host_as_root = {
    qw| signer |  => $host_signer,
    qw| root_id | => $root_a,
    qw| path |    => "$box->{'base'}/host-as-root.key",
};
my $json = JSON::PP->new->utf8->canonical;
my $now  = AMOS7::N7FS::ntime_now();
local $AMOS7::N7FS::CLOCK = sub { return $now };

sub write_receipt {
    my ( $root_id, $accept_clock ) = @ARG;
    return AMOS7::N7FS::Placement::receipt_write(
        qw| host_dir |     => $hdir,
        qw| root |         => $roots{$root_id},
        qw| spec |         => $holder,
        qw| accept_clock | => $accept_clock ? 1 : 0,
        qw| version |      => 1,
        qw| nodes |        => 1,
        qw| samples |      => 1,
        qw| coverage |     => qw| full |,
    );
}

sub fresh {
    my ( $root_id, $verify_root ) = @ARG;
    return AMOS7::N7FS::Placement::receipt_fresh( $hdir,
        $verify_root // $roots{$root_id}, $holder );
}

my $first = write_receipt($root_a);
ok( $first->{'local_time'} == $now && $first->{'time'} == $now,
    'a receipt records both the floor time and the real local clock'
);
write_receipt($root_b);
my $path_a = AMOS7::N7FS::Placement::_receipt_path( $hdir, $holder, $root_a );
my $path_b = AMOS7::N7FS::Placement::_receipt_path( $hdir, $holder, $root_b );
ok( $path_a ne $path_b
        && $path_a =~ m|/receipts/\Q$root_a\E/|
        && $path_b =~ m|/receipts/\Q$root_b\E/|,
    'one holder has a separate receipt path for each root'
);
ok( fresh($root_a) && fresh($root_b),
    'checking a second root leaves both receipts fresh' );

my $good   = read_file($path_a);
my $data   = $json->decode($good);
my $sig    = AMOS7::N7FS::unb32( $data->{'sig'} );
my $signed = "p7 n7fs receipt v2\0" . $json->encode( $data->{'receipt'} );
ok( $data->{'pub'} eq b32( $roots{$root_a}{'signer'}->public )
        && verify( $roots{$root_a}{'signer'}->public, $signed, $sig )
        && !verify( $host_signer->public,             $signed, $sig ),
    'the receipt signature verifies with the root and fails with the host key'
);
ok( !fresh( $root_a, $host_as_root ),
    'receipt freshness refuses host-key verification' );

my $other_host = "$box->{'base'}/other-host";
make_dirs( "$other_host/receipts/$root_a", 0700 );
my $other_path
    = AMOS7::N7FS::Placement::_receipt_path( $other_host, $holder, $root_a );
write_file( $other_path, $good );
ok( AMOS7::N7FS::Placement::receipt_fresh(
        $other_host, $roots{$root_a}, $holder
    ),
    'the same root verifies its receipt from a second host directory'
);

$data->{'receipt'}{'nodes'}++;
write_file( $path_a, $json->encode($data) );
ok( !fresh($root_a), 'an altered receipt payload is refused' );
$data          = $json->decode($good);
$data->{'pub'} = b32( $host_signer->public );
$data->{'sig'} = b32( $host_signer->sign($signed) );
write_file( $path_a, $json->encode($data) );
ok( !fresh($root_a), 'a host-signed forgery is refused' );
$data->{'sig'}
    = b32( $host_signer->sign( $json->encode( $data->{'receipt'} ) ) );
write_file( $path_a, $json->encode($data) );
ok( !fresh($root_a), 'an old host-signed receipt reads as missing' );
write_file( $path_a, $good );

my $old_path
    = "$hdir/receipts/"
    . bmw_b32( bmw384_bytes( "p7 n7fs receipt v1\0" . $holder ) )
    . '.receipt';
write_file( $old_path, $good );
ok( !fresh($root_old),
    'an old-path receipt reads as missing, never crashes' );
unlink $old_path;

$data                      = $json->decode($good);
$data->{'receipt'}{'time'} = $now + parse_y_age('1Y5') + 1;
$data->{'sig'}             = b32(
    $roots{$root_a}{'signer'}->sign(
        "p7 n7fs receipt v2\0" . $json->encode( $data->{'receipt'} )
    )
);
write_file( $path_a, $json->encode($data) );
ok( !fresh($root_a), 'a receipt later than now plus 1Y5 is not fresh' );
write_file( $path_a, $good );

$now = $first->{'time'} + $AMOS7::N7FS::Placement::RECEIPT_AGE + 1;
ok( !fresh($root_a), 'the receipt expires when the clock passes 3Y2' );
my $floor_before_read = read_file("$hdir/clock-floor/$root_a");
AMOS7::N7FS::Placement::n7fs_now( $hdir, $root_a );
ok( read_file("$hdir/clock-floor/$root_a") eq $floor_before_read,
    'a receipt read under a later clock does not raise the floor'
);
my $expired_floor = $floor_before_read + 0;
$now = $first->{'time'} - parse_y_age('13Y2');
my @clock_warnings;
{
    local $SIG{'__WARN__'} = sub { push @clock_warnings, @_ };
    ok( fresh($root_a),
        'a read-only floor leaves freshness at the stored floor time' );
}
ok( grep( {m|local clock is .* behind the floor ; using the floor|}
        @clock_warnings ),
    'a clock behind the floor warns loudly'
);
ok( AMOS7::N7FS::Placement::n7fs_now( $hdir, $root_a ) == $expired_floor,
    'the stored clock floor never runs backwards' );
my $floored = write_receipt($root_a);
ok( $floored->{'time'} == $expired_floor
        && $floored->{'local_time'} == $now
        && fresh($root_a),
    'a floored receipt records the setback alongside its effective time'
);

ok( fresh($root_b),
    'one root\'s clock floor does not age another root\'s receipt' );
$now = $first->{'time'};
write_receipt($root_c);
$now += parse_y_age('1Y1');
refused(
    sub { write_receipt($root_c) },
    qr|clock step .* exceeds 1Y2|,
    'an implausible forward floor jump is refused'
);
my $accepted = write_receipt( $root_c, 1 );
ok( $accepted->{'time'} == $now,
    '-accept-clock explicitly permits the forward floor jump' );

my $before_failure = read_file($path_a);
local $AMOS7::N7FS::FAULT = sub {
    my $point = shift;
    die "injected receipt rename failure\n"
        if $point eq 'receipt:before-rename';
};
my $ok = eval { write_receipt($root_a); 1 };
ok( !$ok && read_file($path_a) eq $before_failure,
    'a failed receipt write leaves the old receipt in place'
);

sub clock_floor_cli {
    my @args = @ARG;
    open( my $fh, '-|', $EXECUTABLE_NAME, "$FindBin::Bin/../n7fs",
        '-host-dir', $hdir, 'clock-floor', $root_c, @args )
        or die $OS_ERROR;
    local $INPUT_RECORD_SEPARATOR;
    my $output = <$fh> // '';
    close $fh;
    return ( $CHILD_ERROR >> 8, $output );
}
my ( $floor_rc, $floor_out ) = clock_floor_cli('-show');
ok( $floor_rc == 0 && $floor_out =~ m|floor \Q$now\E|,
    'clock-floor -show reports the stored floor'
) or say $floor_out;
( $floor_rc, $floor_out ) = clock_floor_cli('-reset');
ok( $floor_rc == 0
        && !-e "$hdir/clock-floor/$root_c"
        && AMOS7::N7FS::Placement::n7fs_now( $hdir, $root_c ) == $now,
    'clock-floor -reset clears the frozen floor'
) or say $floor_out;

done();

#,,,.,.,.,.,.,...,,..,,,,,,.,,,,.,,,,,...,,.,,..,,...,...,,..,,..,,..,.,.,,,.,
#ICZFDLU4CXKJKRAGVTSNUZ6WKSFJAUTNVEDF3DPERQ5VQGYNPMTX2SRRXVSKYCK3RUXDVTLUV3CA4
#\\\|IVJSV6PGPLZ77MAUGZABG4EA7NJL4NS4CDDNK5QPHIAMYIRXA5O \ / AMOS7 \ YOURUM ::
#\[7]THUNUPG22RVZLGPSLGLPC7OQLXCXZ77CVLSFKZMFBRN4PTLA3CDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
