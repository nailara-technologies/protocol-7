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

## data : accumulate ##
if ( $bytes > 0 ) {
    $state->{'buffer'} .= $chunk;
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

#,,,,,,,,,,,,,,..,,.,,.,,,.,,,,,,,...,..,,...,..,,...,...,...,.,.,,.,,..,,,..,
#EPPNYNNW2MTZUAKJCOOWNMFIYFZOOAKVPFI4X3XUIOREIXKVVCKQEB2IXVG7X3MMKWZCPQXKAG3PU
#\\\|SR6MFKL6PZN5VV5NM23WL53K5P22SLEU455RPVDVEWK5KZRZQMH \ / AMOS7 \ YOURUM ::
#\[7]NM5M4QKRAANKGKKK43S4YGM5WGXGZYOTRSITXC77RWMB374OZOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
