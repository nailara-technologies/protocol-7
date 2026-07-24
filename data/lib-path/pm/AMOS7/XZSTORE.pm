## [:< ##

package AMOS7::XZSTORE;    ###################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Crypt::Misc;
use Compress::Raw::Lzma;
use IO::Uncompress::AnyUncompress qw| anyuncompress $AnyUncompressError |;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

@EXPORT = qw| xz_write xz_read |;

our $VERSION = qw| AMOS7::XZSTORE-0.01 |;

##[ AMOS MODULE ]#############################################################

use AMOS7;

##[ SUBROUTINES ]#############################################################

sub xz_write {
    ## lzma-compress content and base32-encode for line-oriented storage ##
    ## returns encoded scalar string, or undef on error                  ##
    ##
    my $content = shift;

    return undef if not defined $content or not length $content;

    my ( $lz, $status ) = Compress::Raw::Lzma::EasyEncoder->new();
    if ( not defined $lz ) {
        warn sprintf "AMOS7::XZSTORE : lzma init failed [ %s ]\n",
            $status // 'unknown';
        return undef;
    }

    my $compressed = '';
    $lz->code( $content => $compressed );
    my $tail = '';
    $lz->flush($tail);
    $compressed .= $tail;

    if ( not length $compressed ) {
        warn "AMOS7::XZSTORE : compression produced no output\n";
        return undef;
    }

    return Crypt::Misc::encode_b32r($compressed);
}

sub xz_read {
    ## base32-decode and decompress content back to original returns ##
    ## content scalar, or undef on error                             ##
    ##
    my $encoded = shift;

    return undef if not defined $encoded or not length $encoded;

    my $compressed = Crypt::Misc::decode_b32r($encoded);

    if ( not defined $compressed or not length $compressed ) {
        warn "AMOS7::XZSTORE : base32 decode failed\n";
        return undef;
    }

    my $content;
    my $ok = anyuncompress( \$compressed => \$content );

    if ( not $ok or not defined $content or not length $content ) {
        warn sprintf "AMOS7::XZSTORE : decompression failed [ %s ]\n",
            $AnyUncompressError // 'unknown';
        return undef;
    }

    return $content;
}

5;    ##  truth  ##

#,,.,,,,.,,..,.,.,,.,,,.,,,.,,.,,,,,.,,,.,,,.,.,.,...,..,,...,...,.,,,.,.,.,,,
#OWKPSOPRY5KGKDLNYRRVRBCPNAGLPAQOTWN3UBLJ3XBM2ITVN4ZZBSTPVSUQMVB3N6AFV6Y2CCVHK
#\\\|OPPIB54YITT5RG4HWY3L6FU5HZETLY3TRY5QGSQOJBA2GX6KZ3U \ / AMOS7 \ YOURUM ::
#\[7]YP3VN4634YYDLQ4SLGQMJNRMHCYJE7TIGQFFFJ5JMPGRSLAIDQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
