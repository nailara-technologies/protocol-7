## [:< ##

# name  = clients.https.h2.handler.io
# descr = io watcher : feeds bytes to http/2 codec, drains queued outbound frames
# note  = on_done/on_error fire synchronously from feed() and complete the request

my $state = shift->w->data;
my $sock  = $state->{'sock'};
my $h2    = $state->{'h2'};

return if not defined $h2;    ## already completed ##

my $chunk = '';
my $bytes = <[base.s_read]>->( $sock, \$chunk, 65536 );

## error ##
if ( ( $bytes // -1 ) == -1 ) {
    <[base.logs]>->(
        0, 'clients.https.h2.handler.io: read error: %s', $OS_ERROR
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

## data : feed codec ##
if ( $bytes > 0 ) {
    eval { $h2->feed($chunk) };
    if ( length $EVAL_ERROR ) {
        my $err = "http/2 codec error: $EVAL_ERROR";
        <[base.logs]>->( 0, 'clients.https.h2.handler.io: %s', $err );
        <[clients.https.cleanup]>->($state);
        $code{ $state->{'on_done'} }->(
            {   'ok'     => FALSE,
                'error'  => $err,
                'params' => $state->{'params'},
            }
        );
        return;
    }

    ## on_done/on_error fired during feed() may have completed the ##
    ## request already [ watchers cancelled, socket closed ]       ##
    return if not defined $state->{'sock'};

    ## drain frames queued by feed [ settings ack, window update, ... ] : ##
    ## a single feed can produce multiple frames, loop until exhausted   ##
    while ( my $frame = $h2->next_frame ) {
        my $total   = length($frame);
        my $written = 0;
        while ( $written < $total ) {
            my $n = syswrite( $sock, $frame, $total - $written, $written );
            if ( defined $n ) {
                $written += $n;
            } elsif ( $OS_ERROR{EAGAIN}
                or $OS_ERROR{EWOULDBLOCK}
                or $IO::Socket::SSL::SSL_ERROR
                == IO::Socket::SSL::SSL_WANT_WRITE()
                or $IO::Socket::SSL::SSL_ERROR
                == IO::Socket::SSL::SSL_WANT_READ() )
            {
                select( undef, undef, undef, 0.001 );
            } else {
                my $err = "ssl write failed: $OS_ERROR";
                <[base.logs]>->(
                    0, 'clients.https.h2.handler.io: %s', $err
                );
                <[clients.https.cleanup]>->($state);
                $code{ $state->{'on_done'} }->(
                    {   'ok'     => FALSE,
                        'error'  => $err,
                        'params' => $state->{'params'},
                    }
                );
                return;
            }
        }
    }
    return;
}

## bytes == 0 : ssl internal frame [ renegotiation, alert ] or true eof ##
if (   $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_READ()
    or $IO::Socket::SSL::SSL_ERROR == IO::Socket::SSL::SSL_WANT_WRITE() ) {
    return;    ## ssl consumed internal frame : wait for next io event ##
}

## true eof before stream completion : abnormal ##
<[base.logs]>->(
    0,
    'clients.https.h2.handler.io: connection closed before response complete'
);
<[clients.https.cleanup]>->($state);
$code{ $state->{'on_done'} }->(
    {   'ok'     => FALSE,
        'error'  => 'connection closed before http/2 response complete',
        'params' => $state->{'params'},
    }
);

#,,,.,.,,,,,.,,..,,..,,..,,.,,,,.,.,,,..,,.,,,..,,...,...,,,.,..,,,.,,,,.,.,,,
#JRJHVMK35NQKCSG6LBQOAGZXPMNAVM3K67FZOW2GIHF3ZGY6ZC7TN6TN57U3GMDFE7YH4JU6IRP22
#\\\|TMVANGHVRZBUEGZLM7W6ZUML3KPM4D4XM5NFNYBDHMS5Z5TXTWG \ / AMOS7 \ YOURUM ::
#\[7]NLKKOH5QREFWV6E3HCCWRIV3HJXXS7A2VUWUM4DRZ4NLSVXTM6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
