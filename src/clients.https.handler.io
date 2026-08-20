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

$code{ $state->{'on_done'} }->(
    {   'ok'     => $ok,
        'status' => $status,
        'body'   => $parsed->{'body'},
        'params' => $state->{'params'},
    }
);

#,,.,,,,.,,,.,...,...,,,.,..,,..,,.,.,,.,,,..,..,,...,...,.,,,.,,,,,,,,..,.,.,
#JURC6BRIIVTAVPW2IQA2IXEERIILDZHPWOPJAM4PNACM6UFSNFOIPVTWD2DUNAE5G5TZ7B26H2YIY
#\\\|EF6EIJS3B4AYL2SDHIDF7F2WT4TS4SWM3PA3DOZEENSAL5UUULG \ / AMOS7 \ YOURUM ::
#\[7]B2ZTM7WFXCDHQQL77S4SOWZOBF4SNMMBIFQESCWSXKHKNYS2VSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
