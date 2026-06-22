## [:< ##

package AMOS7::SHM::Feedback; ################################################

use v5.24;
use strict;
use English;
use warnings;

use AMOS7::SHM;
use AMOS7::SHM::Page;

use Fcntl qw| O_NONBLOCK O_RDONLY O_WRONLY |;
use IO::Select;
use POSIX qw| mkfifo |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

## feedback region : two 64-bit unsigned integers packed back-to-back ##
## big-endian [ Q> ] for consistent network-byte-order semantics, matching
## the page index's use of big-endian 'N' ##
use constant FEEDBACK_SIZE => 16;
use constant FEEDBACK_PACK => 'Q> Q>';

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

@EXPORT_OK = qw|
    FEEDBACK_SIZE
    feedback_offset
    pack_feedback unpack_feedback
    read_feedback write_feedback
    process_feedback
    compute_ntime
    notify_path
    create_notify_fifo
    open_notify_fifo_reader
    ding
    watch_fifo
    |;

our $VERSION = qw| AMOS7::SHM::Feedback-VERSION.AAAAAAA |;    ##  -VCS  ##

##[ AMOS MODULE ]#############################################################

## the feedback layer is pure mechanics over an already-paged AMOS7::SHM
## segment. it does not care whether a zenka is running; context-specific
## concerns [ ntime source, event-loop flavour ] are injected by the caller,
## the same way AMOS7::SHM and AMOS7::SHM::Page stay branch-free. ##

##[ NTIME ]###################################################################

## standalone path : the bare arithmetic, no harmony validation. the formula
## is exact and must not be replaced with int() : sprintf("%.0f", ...) rounds
## to nearest, int() truncates toward zero, and the two sides must agree on
## the same instant or the freshness comparison is meaningless. ##
sub compute_ntime {
    return sprintf( "%.0f", ( time() - 1023228000 ) * 4200 );
}

## note on the zenka path : the wrapper modules/data.mount.shm.feedback.write
## inject <[base.ntime]> [ no parameter ] as the time_source. that value is
## produced by p7_ntime's real harmony-retry loop and is the project's notion
## of a validated network time. the standalone value above is only a
## comparator for ordering, not a security primitive. this asymmetry is
## intentional and is documented here and at the wrapper call site. ##

##[ FEEDBACK REGION OFFSET ]##################################################

## feedback sits immediately after the last page of data, never inside the
## mount header or page index regions ##
sub feedback_offset {

    my $mount = shift;

    my $index = AMOS7::SHM::Page::read_index($mount);
    return undef unless defined $index;

    return AMOS7::SHM::Page::data_offset()
        + $index->{'total_pages'} * $index->{'page_size'};
}

##[ PACK / UNPACK ]###########################################################

sub pack_feedback {

    my ( $last_page_read, $ntime ) = @ARG;

    return pack( FEEDBACK_PACK, $last_page_read, $ntime );
}

sub unpack_feedback {

    my $raw = shift;

    return undef unless length($raw) >= FEEDBACK_SIZE;

    my ( $last_page_read, $ntime )
        = unpack( FEEDBACK_PACK, substr( $raw, 0, FEEDBACK_SIZE ) );

    return {
        'last_page_read' => $last_page_read,
        'ntime'          => $ntime,
    };
}

##[ FEEDBACK READ / WRITE ]###################################################

## read the feedback region and clamp last_page_read against the announced
## [ 0, total_pages ] range. the writer is the sole reader of this region,
## so it is the right place to sanitize. ##
sub read_feedback {

    my $mount = shift;

    my $offset = feedback_offset($mount);
    return undef unless defined $offset;

    my $raw = substr( ${ $mount->{'mmap_ptr'} }, $offset, FEEDBACK_SIZE );

    my $fb = unpack_feedback($raw) // return undef;

    my $index = AMOS7::SHM::Page::read_index($mount) // return undef;
    my $total_pages = $index->{'total_pages'};

    $fb->{'last_page_read'} = 0
        if $fb->{'last_page_read'} < 0;
    $fb->{'last_page_read'} = $total_pages
        if $fb->{'last_page_read'} > $total_pages;

    return $fb;
}

## write the feedback region. the caller is the reader; it stamps ntime.
## options : time_source [ coderef returning ntime ], ntime [ explicit value ].
## if neither is supplied, compute_ntime() is used [ standalone path ]. ##
sub write_feedback {

    my ( $mount, $last_page_read, $options ) = @ARG;

    $options //= {};

    my $offset = feedback_offset($mount);
    return undef unless defined $offset;

    my $ntime;
    if ( exists $options->{'ntime'} ) {
        $ntime = $options->{'ntime'};
    } elsif ( defined $options->{'time_source'} ) {
        ## zenka path : real <[base.ntime]>, harmony-validated ##
        $ntime = $options->{'time_source'}->();
    } else {
        ## standalone path : bare arithmetic, no harmony validation ##
        $ntime = compute_ntime();
    }

    substr( ${ $mount->{'mmap_ptr'} }, $offset, FEEDBACK_SIZE )
        = pack_feedback( $last_page_read, $ntime );

    return {
        'written'         => FEEDBACK_SIZE,
        'last_page_read'  => $last_page_read,
        'ntime'           => $ntime,
    };
}

##[ DING PROCESSING ]#########################################################

## process a ding : read the feedback region, guard against the writer's own
## clock moving backward, and skip stale / duplicate dings [ incoming ntime is
## not strictly newer than the last value acted on ]. $state is a hashref the
## caller keeps across dings; key last_seen_ntime is updated here. options :
## time_source [ coderef for the writer's own now ]. ##
sub process_feedback {

    my ( $mount, $state, $options ) = @ARG;

    $state  //= {};
    $options //= {};

    ## writer's own freshly-computed now, same precision as the stamp ##
    my $now = defined $options->{'time_source'}
        ? $options->{'time_source'}->()    ## zenka path : harmony-validated ##
        : compute_ntime();                  ## standalone path : bare arithmetic ##

    my $last_seen = $state->{'last_seen_ntime'} // 0;

    ## clock-regression guard : if our recorded high-water mark is now in the
    ## future relative to the current clock, rebase to current now rather than
    ## resetting to 0. resetting to 0 would make the next ding — whatever its
    ## ntime, even one from well before the jump — look unconditionally fresher
    ## and be accepted, which destroys the ordering check entirely. rebasing to
    ## now keeps the comparison meaningful going forward, just at the lower
    ## clock reading. this is a deliberate judgment call worth recording. ##
    if ( $last_seen > $now ) {
        $last_seen = $now;
    }

    my $fb = read_feedback($mount);
    return { 'error' => 'no_feedback' } unless defined $fb;

    my $incoming = $fb->{'ntime'};

    if ( $incoming <= $last_seen ) {
        $state->{'last_seen_ntime'} = $last_seen;
        return {
            'fresh'           => FALSE,
            'skipped'         => TRUE,
            'last_seen_ntime' => $last_seen,
            'feedback'        => $fb,
        };
    }

    $state->{'last_seen_ntime'} = $incoming;
    return {
        'fresh'           => TRUE,
        'last_seen_ntime' => $incoming,
        'feedback'        => $fb,
    };
}

##[ NOTIFY FIFO ]#############################################################

## sibling notify fifo path for a segment [ e.g. /dev/shm/p7:M:...:sub.notify ] ##
sub notify_path {

    my $mount_or_path = shift;

    my $path
        = ref( $mount_or_path ) eq qw| HASH |
        ? $mount_or_path->{'path'}
        : $mount_or_path;

    return undef unless defined $path;

    return $path . '.notify';
}

## create the native fifo alongside a segment. lifecycle follows the segment;
## phase-4 cleanup will unlink it together with the segment file. ##
sub create_notify_fifo {

    my $mount = shift;
    my $path  = notify_path($mount);

    return undef unless defined $path;
    return { 'created' => 0, 'existed' => 1 } if -p $path;

    if ( mkfifo( $path, 0600 ) ) {
        return { 'created' => 1, 'path' => $path };
    }

    return {
        'error'    => 'mkfifo_failed',
        'path'     => $path,
        'os_error' => $OS_ERROR,
    };
}

## open the fifo read end non-blocking, so a writer-less open returns instead
## of blocking forever ##
sub open_notify_fifo_reader {

    my $mount = shift;
    my $path  = notify_path($mount);

    return undef unless defined $path;

    sysopen( my $fh, $path, O_RDONLY | O_NONBLOCK )
        or return undef;

    binmode( $fh, ':raw' );

    return $fh;
}

## reader side : after updating the feedback region, write one byte to the fifo
## as a pure ding [ the payload lives in the feedback region, not the fifo ]. ##
sub ding {

    my $mount = shift;
    my $path  = notify_path($mount);

    return { 'error' => 'no_notify_path' } unless defined $path;

    ## open write end non-blocking so a reader-less ding fails fast instead of
    ## blocking until a reader appears ##
    if ( sysopen( my $fh, $path, O_WRONLY | O_NONBLOCK ) ) {
        binmode( $fh, ':raw' );
        my $wrote = syswrite( $fh, "\x01" );
        close($fh);
        return { 'dinged' => 1 }
            if defined $wrote && $wrote == 1;
        return {
            'error'    => 'ding_write_failed',
            'os_error' => $OS_ERROR,
        };
    }

    return {
        'error'    => 'ding_open_failed',
        'os_error' => $OS_ERROR,
    };
}

## standalone writer-side wait : one blocking IO::Select call, no polling loop.
## the zenka path uses modules/data.mount.shm.feedback.watch -> base.event.add_io
## instead, but the underlying fifo semantics are identical. ##
sub watch_fifo {

    my ( $mount, $params ) = @ARG;

    $params //= {};

    my $fh = open_notify_fifo_reader($mount);
    return { 'error' => 'fifo_open_failed' } unless defined $fh;

    my $select  = IO::Select->new($fh);
    my $timeout = $params->{'timeout'} // 0;

    my @ready = $select->can_read($timeout);

    if (@ready) {
        my $buf;
        my $n = sysread( $fh, $buf, 64 );    ## drain whatever is available ##
        close($fh) unless $params->{'keep_open'};

        my $cb = $params->{'cb'};
        $cb->( { 'bytes' => $n, 'buf' => $buf } ) if defined $cb;

        return { 'fired' => TRUE, 'bytes' => $n };
    }

    close($fh) unless $params->{'keep_open'};

    my $tcb = $params->{'timeout_cb'};
    $tcb->() if defined $tcb;

    return { 'timeout' => TRUE };
}

return TRUE  #################################################################

#,,,,,,,,,,.,,..,,...,.,,,,,,,.,,,..,,.,,,...,..,,...,...,,,,,..,,,..,,,.,..,,
#E5JYZ6FHV3O47NE5HKSITNMR3YDRV7VUVJSYU3IWWXUJJ4KWJC6O73EJRZLVLYCOKXF7SENTHF7OY
#\\\|KJT6KOSW34T4KZVZK76FBYP4N37UV3F6SKG6B7EJ3MRQ6FNBSWK \ / AMOS7 \ YOURUM ::
#\[7]SRGKJHXPHFNV2HZAQX4DABOKNFTR7USKWFP6JG5NMNYBCXWBHSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
