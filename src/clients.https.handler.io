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

$code{ $state->{'on_done'} }->(
    {   'ok'     => $ok,
        'status' => $status,
        'body'   => $body,
        'params' => $state->{'params'},
    }
);

#,,.,,,.,,...,...,,..,.,,,.,,,.,.,,,.,..,,,..,..,,...,...,...,,.,,..,,,,.,,.,,
#FUEDLYVUSMBW7QNO4ZZXHKAIA77VUR4QSG5V3K67GKUTITCPQVZ4BXFQMHQKSYI7ZEPNIQFQ6CP3C
#\\\|QKFXBIHEBQLQNTZAOHHIBTLKKL6MQDKAN7ARBPKTYXSKARG3LF4 \ / AMOS7 \ YOURUM ::
#\[7]D4WMRVPQLDOQWEGUMPODY4OHY6KZ6W5Y25H6XGA4Y5O3J3WJO6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
