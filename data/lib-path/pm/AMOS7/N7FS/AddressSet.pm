## [:< ##

package AMOS7::N7FS::AddressSet;    ##########################################
our $VERSION = qw| AMOS7::N7FS::AddressSet-VERSION.6Y47R2I |;

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
        qw| bytes |   => '',
        qw| pending | => {}
    };
}

## new addresses wait in a plain hash ; the first lookup or walk after them
## sorts the bucket once [ a bulk build never re-sorts per insert ]
sub _merge {
    my $bucket = shift;
    return $bucket if not %{ $bucket->{'pending'} };
    $bucket->{'bytes'} = join '',
        sort { $a cmp $b } ( $bucket->{'bytes'} =~ m|.{93}|gs ),
        keys %{ $bucket->{'pending'} };
    $bucket->{'pending'} = {};
    return $bucket;
}

sub _find {
    my ( $self, $address ) = @_;
    my $bucket = $self->{'buckets'}{ _shard($address) } // return -1;
    return _search( _merge($bucket)->{'bytes'}, $address );
}

## the binary search over the sorted bytes alone ##
sub _search {
    my ( $bytes, $address ) = @_;
    my ( $low,   $high )    = ( 0, length($bytes) / $ADDRESS_LENGTH - 1 );
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
    my $bucket = _bucket( $self, $address );
    return TRUE
        if $bucket->{'pending'}{$address}
        or _search( $bucket->{'bytes'}, $address ) >= 0;
    $bucket->{'pending'}{$address} = TRUE;
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
        my $shard = shift $self->{'iteration_shards'}->@* // return undef;
        $self->{'iteration_bytes'}
            = _merge( $self->{'buckets'}{$shard} )->{'bytes'};
        $self->{'iteration_at'} = 0;
    }
}

## the shards that hold addresses, in shard order [ batched map lookups ] ##
sub shards {
    my $self = shift;
    return sort grep { $self->{'counts'}{$ARG} } keys $self->{'buckets'}->%*;
}

## the sorted addresses of one shard ##
sub shard_addresses {
    my ( $self, $shard ) = @_;
    my $bucket = $self->{'buckets'}{$shard} // return ();
    return _merge($bucket)->{'bytes'} =~ m|.{93}|gs;
}

1;

#,,,.,.,,,...,,.,,,..,,,,,,.,,.,,,,,.,.,,,,,.,..,,...,...,...,,..,.,,,.,.,...,
#3KAAI5R66YPOWNM6QYZSHSJJLCDTBHXGP5U3L3NJ6ULD7DJF2OCJU7BOKNT734J6IXO6Q2QFR73WQ
#\\\|WNEIFCMYAUQZLRD2OVQ3JMXZXXUJ7SZ3CHHQJQSFJ6USKMC47GH \ / AMOS7 \ YOURUM ::
#\[7]AYVKC2VORFT6J5WSIN5IT7GHBQJRZP26FVMM3PDPQPOPANWULOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
