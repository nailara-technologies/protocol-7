## [:< ##

# name  = clients.http.handler.io
# descr = io watcher : read the http response, then on_done

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
    {   'ok'            => $ok,
        'status'        => $status,
        'body'          => $parsed->{'body'},
        'headers'       => $parsed->{'headers'}       // {},
        'headers_multi' => $parsed->{'headers_multi'} // {},
        'params'        => $state->{'params'},
    }
);

#,,..,,,.,,..,...,,..,,.,,..,,,,,,,..,,,,,,,,,..,,...,...,,..,.,,,.,.,,,.,,..,
#PSBNHAAG4L3USFK7YWW75YLZN2DHNVPX5UEGTERMNM2TKL3KZHHIGOSMLHKLQ3QCDPMGNYYHQKMUK
#\\\|5AFG6Z4N4OZJGUYG2HMM4KZHOASUGDWJPLX3T5BSVRXEGCQLGOJ \ / AMOS7 \ YOURUM ::
#\[7]GHCGGVAYN4YLGBSDRFU7MMVR2ZSMQ7CZ7KNZNF7UJ47EUH62M4DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
