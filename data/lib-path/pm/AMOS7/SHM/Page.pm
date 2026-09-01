## [:< ##

package AMOS7::SHM::Page; ####################################################

use v5.24;
use strict;
use English;
use warnings;

use AMOS7::SHM;
use AMOS7::SHM::Feedback;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

## page index region : sits between the 512-byte P7SH mount header and the ##
## first page of actual data. fixed 32 bytes : 4-byte magic, two packed    ##
## 32-bit ints [ total_pages, page_size ], 13-byte bmw-L13 checksum [      ##
## always exactly 13 chars per the harmonize_L13 contract ], padded to 32  ##
use constant PAGE_INDEX_MAGIC  => 'P7PG';
use constant PAGE_INDEX_SIZE   => 32;
use constant CHECKSUM_LEN      => 13;
use constant DEFAULT_PAGE_SIZE => 64 * 1024;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

@EXPORT_OK = qw|
    create
    write_index read_index
    write_page read_page
    pack_page_index unpack_page_index
    data_offset
    |;

our $VERSION = qw| AMOS7::SHM::Page-VERSION.AAAAAAA |;    ##  -VCS  ##

##[ AMOS MODULE ]#############################################################

## this layer is pure computation over an already-created AMOS7::SHM        ##
## segment — it does not care whether a zenka is running, same as           ##
## AMOS7::SHM itself.  no behavior differs by $main::PROTOCOL_SEVEN here at ##
## all ; this is purely new functionality, not a promotion of existing      ##
## zenka-only code                                                          ##

## offset where actual page data begins : after both the mount header and ##
## the page index region. page boundaries never write into either         ##
sub data_offset {
    return AMOS7::SHM::SHM_HEADER_SIZE() + PAGE_INDEX_SIZE;
}

##[ PAGE INDEX PACK / UNPACK ]################################################

## pack [ total_pages, page_size, checksum ] into the fixed 32-byte index ##
sub pack_page_index {

    my ( $total_pages, $page_size, $checksum ) = @ARG;

    $checksum = substr( $checksum // '', 0, CHECKSUM_LEN );
    $checksum .= ' ' x ( CHECKSUM_LEN - length($checksum) );

    my $packed = pack( 'A4 N N', PAGE_INDEX_MAGIC, $total_pages, $page_size )
        . $checksum;
    $packed .= "\0" x ( PAGE_INDEX_SIZE - length($packed) );

    return substr( $packed, 0, PAGE_INDEX_SIZE );
}

## unpack the fixed 32-byte index back into a hashref, or undef if the ##
## magic doesn't match [ no index written yet, or wrong offset ]       ##
sub unpack_page_index {

    my $raw = shift;

    return undef unless length($raw) >= PAGE_INDEX_SIZE;

    my ( $magic, $total_pages, $page_size ) = unpack( 'A4 N N', $raw );
    return undef unless $magic eq PAGE_INDEX_MAGIC;

    my $checksum = substr( $raw, 12, CHECKSUM_LEN );
    $checksum =~ s{\s+$}{};

    return {
        'total_pages' => $total_pages,
        'page_size'   => $page_size,
        'checksum'    => $checksum,
    };
}

##[ PAGE INDEX READ / WRITE ]#################################################

## write the page index into a segment [ between the mount header and the ##
## first page of data ]                                                   ##
sub write_index {

    my ( $mount, $total_pages, $page_size, $checksum ) = @ARG;

    return undef
        unless defined $mount and ref( $mount->{'mmap_ptr'} ) eq 'SCALAR';

    my $packed = pack_page_index( $total_pages, $page_size, $checksum );
    substr(
        ${ $mount->{'mmap_ptr'} },
        AMOS7::SHM::SHM_HEADER_SIZE(),
        PAGE_INDEX_SIZE
    ) = $packed;

    return { 'written' => PAGE_INDEX_SIZE };
}

## read the page index back out of a segment ##
sub read_index {

    my $mount = shift;

    return undef
        unless defined $mount and ref( $mount->{'mmap_ptr'} ) eq 'SCALAR';

    my $raw = substr(
        ${ $mount->{'mmap_ptr'} },
        AMOS7::SHM::SHM_HEADER_SIZE(),
        PAGE_INDEX_SIZE
    );

    return unpack_page_index($raw);
}

##[ PAGE READ / WRITE ]#######################################################

## write page number $page_num. rejects an out-of-range page number or a ##
## page larger than the announced page_size — never writes past the      ##
## segment, never writes into the header / index regions                 ##
sub write_page {

    my ( $mount, $page_num, $data ) = @ARG;

    my $index = read_index($mount);
    return { 'error' => 'no_index' } unless defined $index;

    return { 'error' => 'page_out_of_range' }
        if $page_num < 0
        or $page_num >= $index->{'total_pages'};

    return { 'error' => 'page_too_large' }
        if length($data) > $index->{'page_size'};

    my $offset = data_offset() + $page_num * $index->{'page_size'};
    substr( ${ $mount->{'mmap_ptr'} }, $offset, length($data) ) = $data;

    return { 'written' => length($data), 'page' => $page_num };
}

## read page number $page_num. the last page is clipped to the real content ##
## length [ the mount header's data_size field, which                       ##
## AMOS7::SHM::Page::create sets to the actual payload size, not the padded ##
## index+pages region ] so a reader reassembling pages byte-identically     ##
## does not pick up trailing zero-padding from the final, possibly-partial  ##
## page                                                                     ##
sub read_page {

    my ( $mount, $page_num ) = @ARG;

    my $index = read_index($mount);
    return undef unless defined $index;

    return undef
        if $page_num < 0
        or $page_num >= $index->{'total_pages'};

    my $offset = data_offset() + $page_num * $index->{'page_size'};

    my $header = $mount->{'header'}
        // AMOS7::SHM::header_read( $mount->{'mmap_ptr'} );
    my $content_size = $header->{'data_size'}
        // ( $index->{'total_pages'} * $index->{'page_size'} );

    my $page_start = $page_num * $index->{'page_size'};
    my $remaining  = $content_size - $page_start;
    return '' if $remaining <= 0;

    my $len
        = $remaining < $index->{'page_size'}
        ? $remaining
        : $index->{'page_size'};

    return substr( ${ $mount->{'mmap_ptr'} }, $offset, $len );
}

##[ SEGMENT CREATE [ convenience ] ]##########################################

## create a segment sized to hold $content_size bytes across pages of      ##
## $page_size, with the page index already written. returns the $mount     ##
## hashref [ from AMOS7::SHM::shm_create ], or undef on failure.  the      ##
## underlying mount header's data_size is overwritten to the real content  ##
## length [ not the padded index+pages region size ] so read_page can clip ##
## the last page correctly — shm_create itself does not know about paging, ##
## this is the one place that bridges the two layers                       ##
sub create {

    my ( $pub_key_b32, $content_size, $page_size, $checksum, $options )
        = @ARG;

    $options   //= {};
    $page_size //= DEFAULT_PAGE_SIZE;
    return undef unless $page_size > 0;

    my $total_pages = int( ( $content_size + $page_size - 1 ) / $page_size );
    $total_pages = 1 if $total_pages < 1;    ## always at least one page ##

    ## segment sized for header + page index + all pages + feedback region ##
    my $payload_size
        = PAGE_INDEX_SIZE
        + $total_pages * $page_size
        + AMOS7::SHM::Feedback::FEEDBACK_SIZE();

    my $mount
        = AMOS7::SHM::shm_create( $pub_key_b32, $payload_size, $options );
    return undef unless defined $mount;

    $mount->{'header'}{'data_size'} = $content_size;
    AMOS7::SHM::header_write( $mount->{'mmap_ptr'}, $mount->{'header'} );

    write_index( $mount, $total_pages, $page_size, $checksum );

    return $mount;
}

return TRUE;

#,,..,,,,,,,,,,,.,...,,..,..,,,.,,.,.,...,,..,..,,...,...,,,,,..,,..,,,,,,,,.,
#HOYRMIGU5OWZU4WHJHCDX6YK4CKRX42ZQGYYGO7O3OS7KIZCRKW6JYKFKSKN32ATVAJQ7UUOJC7ES
#\\\|YKEQQPM6OXPZZXNPSTFT44FFKOQHCLXURROSBMLRIV663ZQSDYQ \ / AMOS7 \ YOURUM ::
#\[7]KQT22KO72FFG243KX5DMC6YBH3ZQ3PD5SFOBUO34RH4LVLH5ZECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
