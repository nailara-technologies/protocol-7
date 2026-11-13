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
    my $root_id = shift;
    return AMOS7::N7FS::Placement::receipt_write(
        qw| host_dir | => $hdir,
        qw| signer |   => $signer,
        qw| spec |     => $holder,
        qw| root_id |  => $root_id,
        qw| version |  => 1,
        qw| nodes |    => 1,
        qw| samples |  => 1,
        qw| coverage | => qw| full |,
    );
}

sub fresh {
    my $root_id = shift;
    return AMOS7::N7FS::Placement::receipt_fresh( $hdir, $pub, $holder,
        $root_id );
}

my $first = write_receipt($root_a);
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
my $expired_floor = AMOS7::N7FS::Placement::n7fs_now( $hdir, $root_a );
$now = $first->{'time'} - parse_y_age('13Y2');
ok( !fresh($root_a), 'setting the clock back does not revive the receipt' );
ok( AMOS7::N7FS::Placement::n7fs_now( $hdir, $root_a ) == $expired_floor,
    'the stored clock floor never runs backwards' );
my $floored = write_receipt($root_a);
ok( $floored->{'time'} == $expired_floor && fresh($root_a),
    'a receipt written after a clock setback uses the floor'
);
ok( fresh($root_b),
    'one root\'s clock floor does not age another root\'s receipt' );

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

done();

#,,,.,.,,,,,.,..,,.,,,..,,,.,,,,,,..,,,..,..,,..,,...,..,,.,,,.,.,,,,,...,..,,
#P3L4VLF4RL6Q37RZYSRU7NAPFVYGJKICNUNFYUSVQEJVGWINNZ2UAYOOELH7ARNMOJAFOVXVTZNZO
#\\\|ETYAB6IICSP7DI7HZAKIS6ZI5X3WPT46ZKLQOX624BRSAMCXX4L \ / AMOS7 \ YOURUM ::
#\[7]5N2H55QWZBCL4Y4RHQGN3P7FKOQBLIJFACEJRNX3MUR6AV4YZGDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
