#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }
use JSON::PP;
use AMOS7::NTIME     qw| parse_y_age |;
use AMOS7::N7FS      qw| b32 make_dirs read_file |;
use AMOS7::N7FS::Sum qw| bmw384_bytes bmw_b32 |;
use AMOS7::N7FS::Placement;

require "$FindBin::Bin/fixtures/n7fs/helpers.pl";

my $box    = sandbox();
my $hdir   = $box->{'host'};
my $holder = "$box->{'base'}/holder";
make_dirs($holder);
my $signer = test_signer();
my $pub    = $signer->public;
my $root_a = bmw_b32( bmw384_bytes('receipt root a') );
my $root_b = bmw_b32( bmw384_bytes('receipt root b') );
my $json   = JSON::PP->new->utf8->canonical;
my $now    = AMOS7::N7FS::ntime_now();
local $AMOS7::N7FS::CLOCK = sub { return $now };

sub write_receipt {
    my ( $root_id, $accept_clock ) = @ARG;
    return AMOS7::N7FS::Placement::receipt_write(
        qw| host_dir |     => $hdir,
        qw| signer |       => $signer,
        qw| spec |         => $holder,
        qw| root_id |      => $root_id,
        qw| accept_clock | => $accept_clock ? 1 : 0,
        qw| version |      => 1,
        qw| nodes |        => 1,
        qw| samples |      => 1,
        qw| coverage |     => qw| full |,
    );
}

sub fresh {
    my $root_id = shift;
    return AMOS7::N7FS::Placement::receipt_fresh( $hdir, $pub, $holder,
        $root_id );
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

my $old_path
    = "$hdir/receipts/"
    . bmw_b32( bmw384_bytes( "p7 n7fs receipt v1\0" . $holder ) )
    . '.receipt';
write_file( $old_path, read_file($path_a) );
my $root_old = bmw_b32( bmw384_bytes('old path root') );
ok( !fresh($root_old),
    'an old-path receipt reads as missing, never crashes' );
unlink $old_path;

my $good = read_file($path_a);
my $data = $json->decode($good);
$data->{'receipt'}{'time'} = $now + parse_y_age('1Y5') + 1;
$data->{'sig'} = b32( $signer->sign( $json->encode( $data->{'receipt'} ) ) );
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
my $root_c = bmw_b32( bmw384_bytes('receipt root c') );
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

#,,.,,,.,,..,,,,,,,.,,,.,,.,,,.,.,...,,.,,,,.,..,,...,..,,...,,,,,,.,,,.,,...,
#JM43CMFPBRILMHLZ5YQJOPA53E532BSX2Y3U5OLNNU324MP6SEKJ6CVN4LZ573EAW3Z7ZFVI6PXCK
#\\\|MADGECAHZB6YRU7RDTSLJ547QBELD5Y3K4IFIVPPYBGZC2B3UIL \ / AMOS7 \ YOURUM ::
#\[7]LBGXHXFGYOHC4R7ZWCRPOZBPPGVZKXKVOONQUIW277Z4XFBPRICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
