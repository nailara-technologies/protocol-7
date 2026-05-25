## [:< ##

# name  = clients.http.handler.io
# descr = io watcher handler : reads http response, fires on_done when complete

my $state = shift->w->data;
my $sock  = $state->{'sock'};

my $chunk = '';
my $bytes = <[base.s_read]>->( $sock, \$chunk, 65536 );

## error ##
if ( ( $bytes // -1 ) == -1 ) {
    <[base.logs]>
        ->( 0, 'clients.http.handler.io: read error: %s', $OS_ERROR );
    <[clients.http.cleanup]>->($state);
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

## eof (bytes == 0) : parse and fire callback ##
<[clients.http.cleanup]>->($state);
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

#,,.,,,,.,,,.,,..,...,..,,,,.,,..,,,.,.,,,...,..,,...,...,,,.,,.,,.,.,.,.,,..,
#L6ULON2GWF5ORXUDWPOXP36XVY2CASSBBCXV3ID2PBKIJLIEECGOESMZ2UZHLBNGVPP6FFXEWD6QO
#\\\|XMPIXRTMR7TP7ZEKSQKQCBY6SOXBHTMHT5QRFUEALGCVZI2GKJU \ / AMOS7 \ YOURUM ::
#\[7]VUIJJVSOQAXCEWIN5JIZJB6GB4UMOUX7BJBADNN2OYHOBNQ3A4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
