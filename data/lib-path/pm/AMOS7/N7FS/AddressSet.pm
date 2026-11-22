## [:< ##

package AMOS7::N7FS::AddressSet;    ##########################################
our $VERSION = qw| AMOS7::N7FS::AddressSet-VERSION.AKJZV2Y |;

## a tied set for canonical node addresses : fixed-width packed buckets, with
## binary-search lookup and per-bucket iteration instead of one hash per node

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

use constant TRUE  => 5;
use constant FALSE => 0;

my $ADDRESS_LENGTH = 93;

sub TIEHASH {
    my $class = shift;
    return bless { qw| buckets | => {}, qw| counts | => {} }, $class;
}

sub _shard { return substr( $ARG[0], 16, 2 ) }

sub _bucket {
    my ( $self, $address ) = @_;
    die "invalid n7fs node address\n" if length($address) != $ADDRESS_LENGTH;
    return $self->{'buckets'}{ _shard($address) } //= {
        qw| bytes |  => '',
        qw| sorted | => 1
    };
}

sub _find {
    my ( $self, $address ) = @_;
    my $bucket = $self->{'buckets'}{ _shard($address) } // return -1;
    if ( not $bucket->{'sorted'} ) {
        $bucket->{'bytes'} = join '',
            sort { $a cmp $b } $bucket->{'bytes'} =~ m|.{93}|gs;
        $bucket->{'sorted'} = 1;
    }
    my $bytes = $bucket->{'bytes'};
    my ( $low, $high ) = ( 0, length($bytes) / $ADDRESS_LENGTH - 1 );
    while ( $low <= $high ) {
        my $middle = int( ( $low + $high ) / 2 );
        my $cmp    = $address cmp
            substr( $bytes, $middle * $ADDRESS_LENGTH, $ADDRESS_LENGTH );
        return $middle if $cmp == 0;
        if ( $cmp < 0 ) {
            $high = $middle - 1;
        } else {
            $low = $middle + 1;
        }
    }
    return -1;
}

sub STORE {
    my ( $self, $address, undef ) = @_;
    return TRUE if _find( $self, $address ) >= 0;
    my $bucket = _bucket( $self, $address );
    $bucket->{'bytes'} .= $address;
    $bucket->{'sorted'} = FALSE;
    $self->{'counts'}{ _shard($address) }++;
    return TRUE;
}

sub FETCH {
    my ( $self, $address ) = @_;
    return _find( $self, $address ) >= 0 ? TRUE : undef;
}

sub EXISTS {
    my ( $self, $address ) = @_;
    return _find( $self, $address ) >= 0 ? TRUE : FALSE;
}

sub DELETE {
    my ( $self, $address ) = @_;
    my $position = _find( $self, $address );
    return undef if $position < 0;
    my $shard = _shard($address);
    substr(
        $self->{'buckets'}{$shard}{'bytes'},
        $position * $ADDRESS_LENGTH,
        $ADDRESS_LENGTH, ''
    );
    $self->{'counts'}{$shard}--;
    return TRUE;
}

sub CLEAR {
    my $self = shift;
    $self->{'buckets'} = {};
    $self->{'counts'}  = {};
    return;
}

sub SCALAR {
    my $self  = shift;
    my $count = 0;
    $count += $self->{'counts'}{$ARG} // 0 for keys $self->{'counts'}->%*;
    return $count;
}

sub FIRSTKEY {
    my $self = shift;
    $self->{'iteration_shards'} = [ sort keys $self->{'buckets'}->%* ];
    $self->{'iteration_bytes'}  = '';
    $self->{'iteration_at'}     = 0;
    return NEXTKEY($self);
}

sub NEXTKEY {
    my $self = shift;
    while (1) {
        if ( $self->{'iteration_at'} < length $self->{'iteration_bytes'} ) {
            my $address = substr(
                $self->{'iteration_bytes'},
                $self->{'iteration_at'},
                $ADDRESS_LENGTH
            );
            $self->{'iteration_at'} += $ADDRESS_LENGTH;
            return $address;
        }
        my $shard  = shift $self->{'iteration_shards'}->@* // return undef;
        my $bucket = $self->{'buckets'}{$shard};
        if ( not $bucket->{'sorted'} ) {
            $bucket->{'bytes'} = join '',
                sort { $a cmp $b } $bucket->{'bytes'} =~ m|.{93}|gs;
            $bucket->{'sorted'} = 1;
        }
        $self->{'iteration_bytes'} = $bucket->{'bytes'};
        $self->{'iteration_at'}    = 0;
    }
}

1;

#,,..,,,,,,..,..,,,..,,,,,,,,,,,,,,,,,...,,..,..,,...,...,.,.,.,.,,,.,,,,,.,.,
#XYIKVF546Y57NDVUGRXAF7ADOOL6UBEXMZEYGO4CDSVPV2BLDV6DEWTMVKMPQJZOOWYWMWBIVQNLO
#\\\|U5RFZ2CX7BRW5ZUTICDDAIVEBDWEXTR3WBLQESV7CF6P3G7VTII \ / AMOS7 \ YOURUM ::
#\[7]2SZACTYE4HPBWPTLDIICG77JIFM4CUWJNC3FV3JQE6NHL7Y6JQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
