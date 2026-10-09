#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

## tests for AMOS7::NTIME against values the zenka core produced
## [ base.ntime.b32 log stamps, 2026-10-09 ]

use FindBin;
use Time::HiRes ();
BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::NTIME qw|
    ntime_now ntime_b32_now unix_to_ntime ntime_to_unix
    ntime_to_b32 b32_to_ntime b32_to_unix ntime_step_back
    |;

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "  ok    $name" }
    else         { $fail++; say "  FAIL  $name" }
}

## core vectors : stamp -> ntime [ decoded by base.ntime.BASE32_to_numerical
## semantics, confirmed with p7c localtime ]
my %core = (
    '3X23TYV4FOXZKEA' => '3226983767595.72752',
    '3X23VOWMAKXJSFI' => '3226985211394.56885',
    '3X23VOWMKGXNW4I' => '3226985211473.65425',
);
foreach my $stamp ( sort keys %core ) {
    ok( b32_to_ntime($stamp) eq $core{$stamp},   "decode $stamp" );
    ok( ntime_to_b32( $core{$stamp} ) eq $stamp, "encode $core{$stamp}" );
}
ok( abs( b32_to_unix('3X23VOWMAKXJSFI') - 1791557812.2368 ) < 0.001,
    'stamp to unix' );

## leading zeros of the fraction survive [ the '7' prefix ] ##
ok( b32_to_ntime( ntime_to_b32('3226985211394.00512') ) eq
        '3226985211394.00512',
    'fraction leading zeros'
);
ok( b32_to_ntime( ntime_to_b32('3226985211394') ) eq '3226985211394',
    'integer ntime' );

## unix <-> ntime ##
ok( unix_to_ntime( 1023228001, 0 ) eq '4200',        'one second is 4200' );
ok( unix_to_ntime( '1023228000.5', 2 ) eq '2100.00', 'precision' );
ok( ntime_to_unix('4200') == 1023228001,             'ntime to unix' );
ok( !defined unix_to_ntime('abc'),                   'rejects garbage' );
ok( !defined b32_to_ntime('3x23'),                   'rejects lower case' );

## step back borrows across the point ##
ok( ntime_step_back('100.00') eq '099.99', 'step back borrow' );

## human forms [ base.parser.duration \ cube localtime formats ] ##
my %duration = (
    4.37     => '4.37s',
    60       => '1 min',
    125.5    => q{2'05"},
    3600     => '1 hour',
    3725     => q{01h 02'05"},
    86400    => '1 day',
    90061    => q{1d 01 01'01"},
    31557600 => '1 year',
);

foreach my $secs ( sort { $a <=> $b } keys %duration ) {
    ok( AMOS7::NTIME::duration_str($secs) eq $duration{$secs},
        "duration $secs : $duration{$secs}" );
}
ok( AMOS7::NTIME::relative_str( 1000, 4600 ) eq '1 hour ago', 'past' );
ok( AMOS7::NTIME::relative_str( 4600, 1000 ) eq 'in 1 hour',  'future' );
ok( AMOS7::NTIME::localtime_str(1791557812.2368)
        =~ m|^\w{3} \w{3} +\d+ 2026 \d\d:\d\d:52 \[ \+0\.2368 \]$|,
    'cube localtime form'
);

## now ##
my $now = ntime_to_unix( ntime_now(4) );
ok( abs( $now - time ) < 2, 'now' );
## measured against the time BEFORE the call : the first harmonic call loads
## AMOS7::Assert::Truth, seconds on a cold cache
my $before = Time::HiRes::time();
ok( abs( b32_to_unix( ntime_b32_now( 4, 5 ) ) - $before ) < 1,
    'now base32, harmonic' );

say '';
say "  $pass passed, $fail failed  [ perl $^V ]";
exit( $fail ? 1 : 0 );

#,,,.,..,,.,.,,..,.,.,,.,,,,,,..,,,,.,..,,...,..,,...,...,...,.,,,..,,.,,,.,.,
#DBEIPYAG5ATJPU7OI4M7TKLIMJIE3WDBN3KLUFJVCVES3ZLIYJ57IE2OQKO5MFMJ4G4ZBVOUFYUCU
#\\\|A7YUD5R5H3PENSO5DG4NRKAAC7562YN4OGA6EEMDRBYWXDKNEA2 \ / AMOS7 \ YOURUM ::
#\[7]R3GR4DD4QO4A54IFRX4EUGYZ3CUE73F7PJPTMOJFQMIP42H524CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
