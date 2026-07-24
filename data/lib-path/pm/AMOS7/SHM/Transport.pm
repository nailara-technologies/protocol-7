## [:< ##

package AMOS7::SHM::Transport
    ;    ################################################

use v5.24;
use strict;
use English;
use warnings;

use AMOS7::SHM;
use AMOS7::SHM::Page;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

@EXPORT_OK = qw|
    shm_announce
    shm_receive
    |;

our $VERSION = qw| AMOS7::SHM::Transport-VERSION.AAAAAAA |;    ##  -VCS  ##

##[ AMOS MODULE ]#############################################################

## shape-1 "one-shot bounded-scalar transport" primitive. a writer pages a
## finite, fully-known payload into a segment, announces a compact descriptor,
## and a permitted reader pulls every page and verifies the announced
## checksum.  there is no ordering guarantee across calls, no exactly-once
## guarantee, and no phase-3 Feedback atom — this is the simplest asymmetric
## transfer shape.
##
## checksum algorithm is caller's choice; this package never assumes bmw-L13
## specifically. `shm_announce` takes the checksum as a required
## caller-supplied parameter (mirroring AMOS7::SHM::Page::create), and
## `shm_receive` only verifies a checksum when the caller supplies a matching
## `checksum_fn`.

##[ ANNOUNCE ]################################################################

## page a payload into a segment, sign a read grant for the reader, and return
## a compact descriptor. $options keys:  owner_pubkey, owner_privkey,
## reader_pubkey, content_ref, checksum [required] page_size [default
## AMOS7::SHM::Page::DEFAULT_PAGE_SIZE]  sub_path, rights [default ['read']],
## expiry [default time()+3600] time_source, mlock [passed through to
## AMOS7::SHM::Page::create] returns descriptor hashref on success, { error =>
## ... } on failure.
sub shm_announce {

    my $options = shift;

    my $owner_pubkey  = $options->{'owner_pubkey'};
    my $owner_privkey = $options->{'owner_privkey'};
    my $reader_pubkey = $options->{'reader_pubkey'};
    my $content_ref   = $options->{'content_ref'};
    my $checksum      = $options->{'checksum'};

    return { 'error' => 'missing_owner_pubkey' }
        unless defined $owner_pubkey;
    return { 'error' => 'missing_owner_privkey' }
        unless defined $owner_privkey;
    return { 'error' => 'missing_reader_pubkey' }
        unless defined $reader_pubkey;
    return { 'error' => 'missing_content_ref' }
        unless defined $content_ref && ref($content_ref) eq 'SCALAR';
    return { 'error' => 'missing_checksum' }
        unless defined $checksum;

    my $content_size = length($$content_ref);
    my $page_size    = $options->{'page_size'}
        // AMOS7::SHM::Page::DEFAULT_PAGE_SIZE();
    my $sub_path = $options->{'sub_path'};
    my $rights   = $options->{'rights'} // ['read'];
    my $expiry   = $options->{'expiry'} // time() + 3600;

    my $create_options = {};
    $create_options->{'time_source'} = $options->{'time_source'}
        if defined $options->{'time_source'};
    $create_options->{'mlock'} = $options->{'mlock'}
        if defined $options->{'mlock'};
    $create_options->{'sub_path'} = $sub_path
        if defined $sub_path;

    my $mount = AMOS7::SHM::Page::create(
        $owner_pubkey, $content_size, $page_size,
        $checksum,     $create_options
    );
    return { 'error' => 'create_failed' } unless defined $mount;

    my $total_pages = int( ( $content_size + $page_size - 1 ) / $page_size );
    $total_pages = 1 if $total_pages < 1;

    for my $page_num ( 0 .. $total_pages - 1 ) {
        my $offset = $page_num * $page_size;
        my $slice  = substr( $$content_ref, $offset, $page_size );
        my $wr = AMOS7::SHM::Page::write_page( $mount, $page_num, $slice );
        return { 'error' => 'write_page_failed', 'page' => $page_num }
            if !defined $wr || exists $wr->{'error'};
    }

    my $perm = {
        'to'      => $reader_pubkey,
        'branch'  => $sub_path // '',
        'rights'  => $rights,
        'expiry'  => $expiry,
        'granted' => time(),
    };

    my $sig = AMOS7::SHM::sign_permission( $perm, $owner_privkey );
    $perm->{'sig'} = $sig;

    return { 'error' => 'permissions_full' }
        if scalar( @{ $mount->{'header'}{'permissions'} } )
        >= AMOS7::SHM::MAX_PERMISSIONS();

    push @{ $mount->{'header'}{'permissions'} }, $perm;
    AMOS7::SHM::header_write( $mount->{'mmap_ptr'}, $mount->{'header'} );

    return {
        'shm_path'     => $mount->{'path'},
        'total_pages'  => $total_pages,
        'page_size'    => $page_size,
        'content_size' => $content_size,
        'checksum'     => $checksum,
        'owner_pubkey' => $owner_pubkey,
        'sub_path'     => $sub_path,
    };
}

##[ RECEIVE ]#################################################################

## pull every page from a segment and verify the announced checksum.  $options
## keys:  shm_path [or owner_pubkey + sub_path], reader_privkey [required]
## verify_checksum [default true]  checksum_fn [required when verify_checksum
## is true]  returns { ok => TRUE, content_ref => \$content, pages => N } on
## success, or { ok => FALSE, error => ... } on failure.
sub shm_receive {

    my $options = shift;

    my $shm_path       = $options->{'shm_path'};
    my $owner_pubkey   = $options->{'owner_pubkey'};
    my $sub_path       = $options->{'sub_path'} // '';
    my $reader_privkey = $options->{'reader_privkey'};

    return { 'ok' => FALSE, 'error' => 'missing_reader_privkey' }
        unless defined $reader_privkey;

    if ( !defined $shm_path ) {
        return { 'ok' => FALSE, 'error' => 'missing_shm_path' }
            unless defined $owner_pubkey;
        $shm_path = $owner_pubkey;
        $shm_path .= ':' . $sub_path if length($sub_path);
    }

    my $verify_checksum = $options->{'verify_checksum'} // 1;
    my $checksum_fn     = $options->{'checksum_fn'};

    my $mount
        = AMOS7::SHM::shm_open( $shm_path,
        { 'mode' => 'read', 'rights' => ['read'] },
        $reader_privkey );

    return {
        'ok'    => FALSE,
        'error' => $mount->{'error'},
        'path'  => $mount->{'path'}
        }
        if defined $mount
        && ref($mount) eq 'HASH'
        && exists $mount->{'error'};
    return { 'ok' => FALSE, 'error' => 'open_failed' } unless defined $mount;

    my $index = AMOS7::SHM::Page::read_index($mount);
    return { 'ok' => FALSE, 'error' => 'no_index' } unless defined $index;

    my $reassembled = '';
    for my $page_num ( 0 .. $index->{'total_pages'} - 1 ) {
        my $page_data = AMOS7::SHM::Page::read_page( $mount, $page_num );
        return {
            'ok'    => FALSE,
            'error' => 'read_page_failed',
            'page'  => $page_num
            }
            unless defined $page_data;
        $reassembled .= $page_data;
    }

    if ($verify_checksum) {
        return { 'ok' => FALSE, 'error' => 'checksum_alg_required' }
            unless defined $checksum_fn && ref($checksum_fn) eq 'CODE';

        my $computed = $checksum_fn->( \$reassembled );
        return { 'ok' => FALSE, 'error' => 'checksum_mismatch' }
            unless defined $computed
            && $computed eq $index->{'checksum'};
    }

    return {
        'ok'          => TRUE,
        'content_ref' => \$reassembled,
        'pages'       => $index->{'total_pages'},
    };
}

return TRUE  #################################################################

#,,,.,,,,,,,,,,.,,,,,,...,,,,,..,,.,.,.,,,,,.,.,.,...,...,...,,..,,,,,,,.,,.,,
#EF5JYHP4PSTCHLKLMQQRBPL22VXXEKDAS2JTWMH5OFORG2SG6R3YZEXKDGVHCJMNTD27HJZHWU22K
#\\\|7L77UE4IQ6VFCQAZP2GMI52TQ6ASL43N3G7JG24RANZAXO5QO5G \ / AMOS7 \ YOURUM ::
#\[7]4FY2ECLMHMWS5BG3AOHVTE54WEOE6JHUUB6JOETBYFWGUP6H4WBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
