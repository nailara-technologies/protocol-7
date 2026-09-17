## [:< ##

# name  = clients.https.handler.io
# descr = io watcher handler : reads https response, fires on_done when complete

my $state = shift->w->data;
my $sock  = $state->{'sock'};

my $chunk = '';
my $bytes = <[base.s_read]>->( $sock, \$chunk, 65536 );

## error ##
if ( ( $bytes // -1 ) == -1 ) {
    <[base.logs]>->(
        0, 'clients.https.handler.io: read error: %s', $OS_ERROR
    );
    <[clients.https.cleanup]>->($state);
    $code{ $state->{'on_done'} }->(
        {   'ok'     => FALSE,
            'error'  => "read error: $OS_ERROR",
            'params' => $state->{'params'},
        }
    );
    return;
}

## data : accumulate [ or stream to disk when a destination fh is open ] ##
if ( $bytes > 0 ) {
    if ( defined $state->{'stream_fh'} ) {
        my $stream_result
            = <[clients.https.stream.chunk]>->( $state, \$chunk );

        if ( $stream_result eq qw| error | ) {
            <[clients.https.cleanup]>->($state);
            $code{ $state->{'on_done'} }->(
                {   'ok'     => FALSE,
                    'error'  => "stream write error: $OS_ERROR",
                    'params' => $state->{'params'},
                }
            );
            return;
        } elsif ( $stream_result eq qw| done | ) {
            ## chunked terminal block consumed : response complete before ##
            ## socket eof -- finalize without waiting for the connection  ##
            <[clients.https.stream.finish]>->($state);
            return;
        }

        ## per-chunk stall-reset : a transfer making progress must never   ##
        ## age out of its timeout window [ see clients.https.stall_reset ] ##
        <[clients.https.stall_reset]>->($state);
    } else {
        $state->{'buffer'} .= $chunk;
    }
    return;
}

## bytes == 0 : could be ssl internal frame (renegotiation, alert, etc.) or ##
## true eof. io::socket::ssl sets SSL_ERROR to SSL_WANT_READ when it        ##
## consumed a frame internally with no app data : not a real eof in that    ##
## case.                                                                    ##
if (   $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_READ()
    or $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_WRITE() ) {
    return;    ## ssl consumed internal frame : wait for next io event ##
}

## true eof : streaming mode finalizes from what reached the disk ##
if ( defined $state->{'stream_fh'} ) {
    <[clients.https.stream.finish]>->($state);
    return;
}

## true eof : parse and fire callback ##
<[clients.https.cleanup]>->($state);
my $parsed = <[clients.http.parse_response]>->( $state->{'buffer'} );
my $status = $parsed->{'status'} // 0;
my $ok     = ( $status >= 200 and $status < 300 ) ? TRUE : FALSE;

## decompress + character-decode : same treatment as the h2 path, see     ##
## clients.https.decode_body -- this http/1.1 fallback used to hand the   ##
## body downstream as still-raw wire bytes [ mojibake on write, and worse ##
## still-compressed garbage whenever a server actually honoured the       ##
## gzip/deflate/zstd accept-encoding this client always sends ]           ##
my $body = <[clients.https.decode_body]>->(
    $parsed->{'body'}, $parsed->{'headers'}, qw| clients.https |
);

## response headers travel with the result : keys are lower-cased here [    ##
## and on the h2 path ], so callers look them up in lower case -- needed by ##
## any api that carries its answer in headers rather than the body [ e.g.   ##
## the anthropic-ratelimit-* set ]                                          ##
$code{ $state->{'on_done'} }->(
    {   'ok'      => $ok,
        'status'  => $status,
        'body'    => $body,
        'headers' => $parsed->{'headers'} // {},
        'params'  => $state->{'params'},
    }
);

#,,..,,..,,..,,,.,,.,,,,.,.,.,...,,,.,,,.,,.,,..,,...,...,.,.,...,..,,,,.,.,,,
#A53CIGVODDAYY2ZEPNZJ3DMGWSB2A34CWKZPPIJN6FRJMCJ3U4EFU4B4GXFYRG2S6BTDYTSJ4N5GE
#\\\|IQYGPZPZSJY6LTTLGOBZCCHJAHEGZ22ZW53JACKHYGII43CMEC3 \ / AMOS7 \ YOURUM ::
#\[7]4QDFBC47A537XLDUHBPCYLL4E7NZWRIXD5TZYBZISNVIXY5PEGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
