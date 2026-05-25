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

## bytes == 0 : could be ssl internal frame (renegotiation, alert, etc.)
## or true eof. io::socket::ssl sets SSL_ERROR to SSL_WANT_READ when it
## consumed a frame internally with no app data : not a real eof in that case. ##
if (   $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_READ()
    or $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_WRITE() ) {
    return;    ## ssl consumed internal frame : wait for next io event ##
}

## true eof : parse and fire callback ##
<[clients.https.cleanup]>->($state);
my $parsed = <[clients.http.parse_response]>->( $state->{'buffer'} );
my $status = $parsed->{'status'} // 0;
my $ok     = ( $status >= 200 and $status < 300 ) ? TRUE : FALSE;

$code{ $state->{'on_done'} }->(
    {   'ok'     => $ok,
        'status' => $status,
        'body'   => $parsed->{'body'},
        'params' => $state->{'params'},
    }
);

#,,,,,,,.,.,,,...,.,.,,,,,.,.,...,.,,,...,,.,,..,,...,...,,,,,...,,..,,..,,.,,
#IGFCN5T6FV3LRBPJZ46MXNIK7YEA6Y7PUGWYV52GMOJNTP46TD4ZGEB4HH7FUK45JWFBCTZVHPHMA
#\\\|C5AURDE7GH4PDLSUDNMI7KAVP46PKPV4QMNXR4XNBCEKIYBCJW5 \ / AMOS7 \ YOURUM ::
#\[7]GM7UHQMD2JSGXSQCDH62I5ZO4VWRFANMOP6HQJT6WRDHZFDVOKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
