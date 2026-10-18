## [:< ##

package AMOS7::N7FS::Sum;    ################################################

## N7FS version 1 : checksums and epochs.
##
## - bmw : BMW384 [ Digest::BMW ], base32 without padding -> 77 chars,
## streamed. the full-width 'long bmw' of the spec
## - amos : the 7-char amos-7 checksum [ AMOS7::CHKSUM::amos_chksum ] taken
## over the BASE32 TEXT of the BMW384 digest -- never over raw bytes :
## amos_chksum decodes non-utf8 input as utf-8 [ lossy for binary data ] and
## needs the whole input in memory. so 'amos of the content' is 'amos of the
## content's bmw' here [ a deviation, recorded in the store state as sum rule
## 'amos7-of-bmw384-b32' -- a converter can change it ].  `amos-chksum < file`
## does NOT reproduce an address
## - l13 : there is NO BMW-L13 in an AMOS7 MODULE -- it exists as
## src/base.chk-sum.bmw.L13-str [ zenka code ] and as a script copy in
## bin/bmw-L13 [ L13_checksum, not importable ]. id.l13 holds a clearly tagged
## STAND-IN until L13 moves into a module : $L13_TAG + the first 13 base32
## chars of BMW384. replace through a converter step, never silently
## - epoch : mirrors src/base.ntime.epoch_dec + base.ntime.epoch_timestamp
## [ a port of the formula -- keep both in step ] : epoch = ntime / ( 4200 *
## 86400 * 365 / 13 ) mod 385280 ; the path form base32 of pack( 'w', 99999999
## - int epoch ) -> 'V7' + 5 chars
## [ 7 chars, the same shape as an amos -- position decides ]

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::N7FS::Sum-VERSION.0000001 |;

@EXPORT_OK = qw|
    bmw384_bytes
    bmw384_fh
    bmw_b32
    amos_of_bmw
    amos_of_bytes
    l13_standin
    epoch_num
    epoch_int
    epoch_b32
    epoch_from_b32
    epoch_prev
    epoch_next
    epoch_window
    $AMOS_RULE
    $BMW_RULE
    $L13_TAG
    |;

use Digest::BMW;
use AMOS7::N7FS qw| b32 refuse |;

our $AMOS_RULE = qw| amos7-of-bmw384-b32 |;
our $BMW_RULE  = qw| bmw384-b32 |;
our $L13_TAG   = qw| stand-in:bmw384-b32-head13: |;

our $BMW_RE  = qr{\A[A-Z2-7]{77}\z};
our $AMOS_RE = qr{\A[A-Z2-7]{7}\z};

## loaded on first use : AMOS7::CHKSUM pulls the truth assertion chain ##
sub _amos_loaded {
    state $loaded = eval { require AMOS7::CHKSUM; 1 } ? TRUE : FALSE;
    refuse('AMOS7::CHKSUM not loadable [ Digest::BMW, List::MoreUtils ? ]')
        if not $loaded;
    return $loaded;
}

sub bmw384_bytes {
    my $ctx = Digest::BMW->new(384);
    $ctx->add(shift);
    return $ctx->digest;
}

## streamed in 1 MiB reads ; returns ( digest, bytes read )
sub bmw384_fh {
    my $fh   = shift;
    my $ctx  = Digest::BMW->new(384);
    my $size = 0;
    while (1) {
        my $got = sysread( $fh, my $buf, 1048576 );
        refuse( 'read failed : %s', $OS_ERROR ) if not defined $got;
        last                                    if $got == 0;
        $ctx->add($buf);
        $size += $got;
    }
    return ( $ctx->digest, $size );
}

sub bmw_b32 {
    my $digest = shift // '';
    refuse('bmw digest is not 48 bytes') if length $digest != 48;
    return b32($digest);
}

sub amos_of_bmw {
    my $bmw = shift // '';
    refuse('not a bmw384 base32 checksum') if $bmw !~ $BMW_RE;
    _amos_loaded();
    my $amos = AMOS7::CHKSUM::amos_chksum( \"$bmw" );
    refuse('amos checksum failed')
        if not defined $amos
        or $amos !~ $AMOS_RE;
    return $amos;
}

sub amos_of_bytes { return amos_of_bmw( bmw_b32( bmw384_bytes(shift) ) ) }

sub l13_standin {
    return $L13_TAG . substr( bmw_b32( bmw384_bytes(shift) ), 0, 13 );
}

##[ EPOCHS ]##################################################################

our $EPOCH_DIVISOR = 4200 * 86400 * 365 / 13;
our $EPOCHS_TOTAL  = 385280;

## high-resolution epoch value [ 'epoch-num', 13 fraction digits ]
sub epoch_num {
    my $ntime = shift // refuse('epoch : no ntime');
    my $epoch = $ntime / $EPOCH_DIVISOR;
    my $frac  = $epoch - int $epoch;
    return sprintf qw| %.13f |, ( int($epoch) % $EPOCHS_TOTAL ) + $frac;
}

sub epoch_int { return int epoch_num(shift) }

sub epoch_b32 {
    my $epoch = shift // '';
    refuse( 'epoch out of range [ %s ]', $epoch )
        if $epoch !~ m|\A\d{1,6}\z|
        or $epoch >= $EPOCHS_TOTAL;
    return b32( pack( qw| w |, 99999999 - $epoch ) );
}

sub epoch_from_b32 {
    my $str = shift // '';
    return undef if $str !~ m|\AV7[A-Z2-7]{5}\z|;
    my $raw   = AMOS7::N7FS::unb32($str)         // return undef;
    my $num   = eval { unpack( qw| w |, $raw ) } // return undef;
    my $epoch = 99999999 - $num;
    return undef if $epoch < 0 or $epoch >= $EPOCHS_TOTAL;
    return undef if epoch_b32($epoch) ne $str;    ## canonical form only ##
    return $epoch;
}

##[ THE EPOCH WINDOW ]########################################################

## the {previous, current, next} validity window
## [ data/tasks/epoch-validity-search-protocol.md + src/base.ntime.epoch_dec ]
## : single steps wrapping at 0 \ $EPOCHS_TOTAL -- never raw arithmetic,
## epoch_b32 rejects out-of-range
sub epoch_prev { return ( shift() + $EPOCHS_TOTAL - 1 ) % $EPOCHS_TOTAL }
sub epoch_next { return ( shift() + 1 ) % $EPOCHS_TOTAL }

sub epoch_window {
    my $cur = shift // 0;
    return ( epoch_prev($cur), $cur, epoch_next($cur) );
}

1;

#,,,.,,,,,,.,,.,,,.,.,,.,,,.,,,,.,.,,,.,.,,..,..,,...,...,,,,,,,,,..,,,,.,,.,,
#4X7ASX2H6NFYFZNQY6KLNVLBKNMWRRPOOTDRDVXLSL53XZWS2BVCCPJ7IEFJYOLHTVF56UT5JA7SC
#\\\|EMZJ2M5WYN66SEHHI75HV6QDZI47XLNYXJZRJUIQUBJHDZA2CR3 \ / AMOS7 \ YOURUM ::
#\[7]BJVJRYQYJEZPNOU4KO2YONJXYUOURYBLLYLODIETMVIYB2DUE2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
