## [:< ##

package AMOS7::NTIME;    ###################################################

## protocol-7 network time for STANDALONE scripts [ bin/ntime, p7-vault,
## anything that runs without a backend ]. zenki keep their native routines [
## base.ntime, base.ntime.b32, base.encode_ntime_to_B32, base.ntime.
## BASE32_to_numerical in bin/Protocol-7 ] -- this module mirrors them and is
## not loaded there. keep both in step.
##
## ntime  = ( unix seconds - 1023228000 ) * 4200   [ 2002-06-05 ] base32 = rfc
## 4648 of perl pack( 'w*', int [ , '7' . fraction ] )
##
## conversions need Crypt::Misc only. harmony [ stepping 'now' back to a
## harmonic value, as base.ntime does ] loads AMOS7::Assert::Truth on demand
## -- callers that do not ask for it never pull that chain in.

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use constant NTIME_START => 1023228000;    ## 2002-06-05 [ ntime zero ] ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::NTIME-VERSION.0000001 |;

@EXPORT_OK = qw|
    NTIME_START
    ntime_now
    ntime_b32_now
    unix_to_ntime
    ntime_to_unix
    ntime_to_b32
    b32_to_ntime
    b32_to_unix
    ntime_step_back
    duration_str
    relative_str
    localtime_str
    |;

use Time::HiRes qw| time |;
use Crypt::Misc qw| encode_b32r decode_b32r |;

our $HARMONY_RETRIES = 24;    ## base.ntime's limit ##

##[ NUMERIC ]#################################################################

## unix seconds [ fractional ok ] -> decimal ntime string with $precision
## fraction digits. truncated, never rounded up : a time value is never in the
## future [ base.ntime ]
sub unix_to_ntime {
    my $unix      = shift // return undef;
    my $precision = shift // 0;

    return undef   if $unix !~ m|^\d+(\.\d+)?$|;
    $precision = 8 if $precision > 8;

    my $factor = 10**$precision;
    my $ntime  = int( ( $unix - NTIME_START ) * 4200 * $factor ) / $factor;
    return sprintf q{%.*f}, $precision, $ntime;
}

sub ntime_to_unix {
    my $ntime = shift // return undef;
    return undef if $ntime !~ m|^\d+(\.\d+)?$|;
    return $ntime / 4200 + NTIME_START;
}

## one unit of the last digit back, on the digit string [ exact at every
## precision ]
sub ntime_step_back {
    my @digits = split m||, shift // '';
    for ( my $i = $#digits; $i >= 0; $i-- ) {
        next if $digits[$i] eq '.';
        if ( $digits[$i] > 0 ) { $digits[$i]--; last }
        $digits[$i] = 9;    ##  borrow  ##
    }
    return join '', @digits;
}

## the current ntime. $harmony : step back to the latest harmonic value
sub ntime_now {
    my $precision = shift // 0;
    my $harmony   = shift // FALSE;

    my $ntime = unix_to_ntime( time, $precision );
    return $ntime if not $harmony or not _harmony_loaded();

    my $retries = $HARMONY_RETRIES;
    my $value   = $ntime;
    while ( not AMOS7::Assert::Truth::is_true( \$value, 1, 0 )
        and $retries-- > 0 ) {
        $value = ntime_step_back($value);
    }
    return $retries < 0 ? $ntime : $value;
}

##[ BASE32 ]##################################################################

## decimal ntime -> base32 [ base.encode_ntime_to_B32 ]. the fraction is
## stored with a '7' prefix, which keeps its leading zeros
sub ntime_to_b32 {
    my $ntime = shift // return undef;
    return undef if $ntime !~ m|^\d{1,17}(\.\d{1,17})?$|;

    my @part = split m|\.|, $ntime;
    $part[1] = '7' . $part[1] if @part == 2;
    return encode_b32r( pack( qw| w* |, @part ) );
}

## base32 -> decimal ntime [ base.ntime.BASE32_to_numerical ]
sub b32_to_ntime {
    my $stamp = shift // return undef;
    return undef if $stamp !~ m|^[A-Z2-7]+$|;

    my $raw  = eval { decode_b32r($stamp) } // return undef;
    my @part = eval { unpack( qw| w* |, $raw ) };
    return undef if not @part or @part > 2;

    $part[1] =~ s|^7|| if @part == 2;
    my $ntime = join '.', @part;
    $ntime =~ s|(\.0)+$||;    ## as core : only all-zero groups ##

    return undef if $ntime !~ m|^\d{1,17}(\.\d{1,20})?$|;
    return $ntime;
}

sub b32_to_unix { return ntime_to_unix( b32_to_ntime(shift) ) }

## the current ntime as base32. $harmony is asserted on the ENCODED value, as
## base.ntime.b32 does [ default precision 4 there too ]
sub ntime_b32_now {
    my $precision = shift // 4;
    my $harmony   = shift // FALSE;

    my $ntime   = ntime_now( $precision, FALSE );
    my $encoded = ntime_to_b32($ntime);
    return $encoded if not $harmony or not _harmony_loaded();

    my $retries = 9;          ## base.ntime.b32's limit ##
    my $value   = $ntime;
    my $try     = $encoded;
    while ( AMOS7::Assert::Truth::is_true( \$try, 1, TRUE ) == 0
        and $retries-- > 0 ) {
        $value = ntime_step_back($value);
        $try   = ntime_to_b32($value);
    }
    return $retries < 0 ? $encoded : $try;
}

##[ HUMAN FORMS ]#############################################################

## duration in seconds -> '3 days 04h 12'09"' [ base.parser.duration's format,
## leap years ignored, a year = 365.25 days like Time::Seconds ]
sub duration_str {
    my $secs      = abs( shift // 0 );
    my $precision = shift // 2;

    my %r = ( years => 0, days => 0, hours => 0, minutes => 0, seconds => 0 );
    my @unit = (
        [ years   => 31557600 ],
        [ days    => 86400 ],
        [ hours   => 3600 ],
        [ minutes => 60 ],
    );
    foreach my $unit (@unit) {
        my ( $name, $size ) = @{$unit};
        next if $secs < $size;
        $r{$name} = int( $secs / $size );
        $secs -= $r{$name} * $size;
    }
    $r{'seconds'} = sprintf q{%.*f}, $precision, $secs if $secs;

    my $s = sub { $ARG[0] == 1 ? '' : 's' };
    my @result;

    if ( $r{'years'} and not $r{'days'} ) {
        push @result, sprintf '%d year%s', $r{'years'}, $s->( $r{'years'} );
    } elsif ( $r{'years'} ) {
        push @result, sprintf '%dy', $r{'years'};
    }

    push @result, sprintf '%d day%s', $r{'days'}, $s->( $r{'days'} )
        if $r{'days'};

    if ( $r{'hours'} and $r{'minutes'} == 0 and $r{'seconds'} == 0 ) {
        push @result, sprintf '%d hour%s', $r{'hours'}, $s->( $r{'hours'} );
    } elsif ( $r{'hours'} ) {
        push @result, sprintf '%02dh', $r{'hours'};
    }

    if ( $r{'minutes'} and $r{'seconds'} == 0 ) {
        push @result, sprintf '%d min', $r{'minutes'};
    } elsif ( $r{'minutes'} ) {
        push @result,
            sprintf( $r{'hours'} ? q{%02d'%02d"} : q{%d'%02d"},
            $r{'minutes'}, $r{'seconds'} );
    }

    push @result, sprintf '%ss', $r{'seconds'}
        if $r{'seconds'} and not $r{'minutes'} or not @result;

    my $str = join ' ', @result;
    $str =~ s| days? (\d+)h |d $1 | if length $str >= 10;
    $str =~ s|(\d+d)(\d+ hours)|$1 $2 |;
    return $str;
}

## unix time -> '04h 12'09" ago' \ 'in 3 days 2 hours' [ against $now ]
sub relative_str {
    my $unix      = shift // return undef;
    my $now       = shift // time;
    my $precision = shift // 2;

    my $delta = $now - $unix;
    my $str   = duration_str( $delta, $precision );
    return $delta < 0 ? "in $str" : "$str ago";
}

## unix time -> 'Fri Oct  9 2026 16:56:52 [ +0.2368 ]' [ cube's localtime
## command : year before the time, sub seconds appended ]
sub localtime_str {
    my $unix      = shift // return undef;
    my $precision = shift // 4;

    my $whole = int $unix;
    my $str   = scalar localtime $whole;
    $str =~ s| (\d\d:\d\d:\d\d) (\d{4})$| $2 $1|;

    my $frac = sprintf q{%.*f}, $precision, $unix - $whole;
    $str .= " [ +$frac ]" if $precision and $frac != 0;
    return $str;
}

sub _harmony_loaded {
    state $loaded = eval { require AMOS7::Assert::Truth; 1 } ? TRUE : FALSE;
    return $loaded;
}

1;

#,,.,,.,,,,,,,,.,,,,.,,,.,,,.,..,,,..,,,.,..,,..,,...,...,,,.,,,,,.,,,.,,,,..,
#YXMWA2MQNXSW426WAAILSWQVX7QNE3LJG3O7COV2TZQY52FUSNJS3XIVR7S3BJTFCXOKA5OUMVP2E
#\\\|GTUIJIFHAJ74ZLQRKUXT7OVOVZI45GYPADOF2TMBKIILBHIJLLF \ / AMOS7 \ YOURUM ::
#\[7]5MGTXR5XUHVJ3W26WKYBD4H5YUVCGSCXZCHWN4BDXCTXXOOWICCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
