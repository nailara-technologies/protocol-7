## [:< ##

package AMOS7::SHM::Live; ####################################################

use v5.24;
use strict;
use English;
use warnings;

use AMOS7::SHM;
use AMOS7::SHM::Feedback;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

@EXPORT_OK = qw|
    live_create
    live_write
    live_read
    |;

our $VERSION = qw| AMOS7::SHM::Live-VERSION.AAAAAAA |;    ##  -VCS  ##

##[ AMOS MODULE ]#############################################################

## shape-3 "live-mounted current state" primitive. a writer keeps a single  ##
## bounded value current in place; any permitted reader opens the segment   ##
## and sees whatever is current right now. there is no transfer, no ack, no ##
## consumed cursor, no position tracking. the optional notify FIFO is       ##
## reused from AMOS7::SHM::Feedback purely as a change ding, not as a       ##
## stream atom.                                                             ##

##[ CREATE ]##################################################################

## create a live-mount segment with capacity bytes of data region and an    ##
## optional phase-3 notify FIFO. $content is the initial value and must fit ##
## within $capacity. returns the $mount hashref or an error hashref.        ##
sub live_create {

    my ( $pub_key_b32, $content, $capacity, $options ) = @ARG;

    $content  //= '';
    $capacity //= AMOS7::SHM::DEFAULT_SEGMENT_SIZE();
    $options  //= {};

    return { 'error' => 'content_exceeds_capacity' }
        if length($content) > $capacity;

    my $mount = AMOS7::SHM::shm_create( $pub_key_b32, $capacity, $options );
    return { 'error' => 'shm_create_failed' } unless defined $mount;

    substr(
        ${ $mount->{'mmap_ptr'} },
        AMOS7::SHM::SHM_HEADER_SIZE(),
        length($content)
    ) = $content;

    $mount->{'header'}{'data_size'} = length($content);
    AMOS7::SHM::header_write( $mount->{'mmap_ptr'}, $mount->{'header'} );

    if ( $options->{'notify'} ) {
        my $fifo = AMOS7::SHM::Feedback::create_notify_fifo($mount);
        return $fifo if defined $fifo && exists $fifo->{'error'};
    }

    return $mount;
}

##[ WRITE ]###################################################################

## replace the live-mount's current value in place. rejects content larger  ##
## than the mount's data-region capacity. if a notify FIFO exists, dings it ##
## after a successful write. returns an error hashref on failure.           ##
sub live_write {

    my ( $mount, $content ) = @ARG;

    return { 'error' => 'no_mount' }
        unless defined $mount && ref( $mount->{'mmap_ptr'} ) eq 'SCALAR';

    my $capacity = $mount->{'size'};
    return { 'error' => 'capacity_unknown' } unless defined $capacity;

    return { 'error' => 'content_exceeds_capacity' }
        if length($content) > $capacity;

    substr(
        ${ $mount->{'mmap_ptr'} },
        AMOS7::SHM::SHM_HEADER_SIZE(),
        length($content)
    ) = $content;

    $mount->{'header'}{'data_size'} = length($content);
    AMOS7::SHM::header_write( $mount->{'mmap_ptr'}, $mount->{'header'} );

    if ( -p AMOS7::SHM::Feedback::notify_path($mount) ) {
        AMOS7::SHM::Feedback::ding($mount);  ## reader-less ding fails fast ##
    }

    return { 'written' => length($content) };
}

##[ READ ]####################################################################

## read the current value of a live-mount. returns exactly the bytes    ##
## declared by the mount header's data_size field. no checksum verify — ##
## there is none.                                                       ##
sub live_read {

    my $mount = shift;

    return undef
        unless defined $mount && ref( $mount->{'mmap_ptr'} ) eq 'SCALAR';

    my $header = AMOS7::SHM::header_read( $mount->{'mmap_ptr'} );
    return undef unless defined $header;

    my $data_size = $header->{'data_size'} // 0;
    return '' if $data_size <= 0;

    return substr( ${ $mount->{'mmap_ptr'} },
        AMOS7::SHM::SHM_HEADER_SIZE(), $data_size );
}

return TRUE  #################################################################

#,,,.,...,..,,.,,,..,,.,.,.,.,...,.,,,,..,,.,,..,,...,.,.,..,,...,,,,,.,.,,,.,
#B6BYZO754SAPL4GDQYACA4HL2AOTSIDFL6CBWVYHGXPJ6TNEEOSBK4SXGNEVEVGY5NZRIZU2IK42Q
#\\\|2MCHRMYOQFYARUNGC4DOYP3VH4PKVEOXVDNOUSIGCE5QHBWJKO2 \ / AMOS7 \ YOURUM ::
#\[7]T7OLPPS2DP45X7FMQKVL2U4CWFTYHPMCDGLLDPD2YIHJ2FVLEOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
