## [:< ##

# name  = nameserv.enc.handler.io
# descr = io watcher of one encrypted connection : connect, tls, read

## event handler : the event carries the connection hash. phases : connect ##
## [ tcp writable ] -> handshake                                           ##
## [ connect_SSL polled on readable \ writable ] -> ready. certificate     ##
## verification is on : a failed one is a failed upstream, never a plain   ##
## fallback                                                                ##

my $conn = shift->w->data;
return if ref $conn ne qw| HASH | or $conn->{'dead'};

require IO::Socket::SSL;
require Socket;

my $sock = $conn->{'sock'} // return;
my $up   = $conn->{'up'};

if ( $conn->{'phase'} eq qw| connect | ) {
    my $err  = $sock->getsockopt( Socket::SOL_SOCKET(), Socket::SO_ERROR() );
    my $code = defined $err ? unpack( qw| i |, $err ) : 1;
    if ($code) {
        local $OS_ERROR = $code;
        return
            <[nameserv.enc.fail]>
            ->( $conn, "tcp connect failed : $OS_ERROR" );
    }
    ## writable with no pending error but no peer : the connect was refused ##
    ## at once [ loopback \ closed port ] and the error is already consumed ##
    return <[nameserv.enc.fail]>->(
        $conn,
        'tcp connect failed : not connected [ refused or unreachable ]'
    ) if not defined $sock->peername;
    my %ssl = (
        'SSL_startHandshake'  => 0,
        'SSL_verify_mode'     => IO::Socket::SSL::SSL_VERIFY_PEER(),
        'SSL_verifycn_scheme' => qw| http |,
        'SSL_verifycn_name'   => $up->{'tls_name'},
        'SSL_version'         => 'SSLv23:!SSLv2:!SSLv3:!TLSv1:!TLSv1_1',
    );
    ## sni is a host name : never an ip literal ##
    $ssl{'SSL_hostname'} = $up->{'tls_name'}
        if $up->{'tls_name'} !~ m{^[0-9a-f:.]+$};
    $ssl{'SSL_ca_file'} = <nameserv.cfg.encrypted.ca_file>
        if length( <nameserv.cfg.encrypted.ca_file> // '' );
    $ssl{'SSL_alpn_protocols'} = ['http/1.1']
        if $up->{'protocol'} eq qw| doh | and IO::Socket::SSL->can_alpn;
    my $upgraded = IO::Socket::SSL->start_SSL( $sock, %ssl );
    return <[nameserv.enc.fail]>->(
        $conn, 'tls setup failed : ' . IO::Socket::SSL::errstr()
    ) if not $upgraded;
    $conn->{'phase'} = qw| handshake |;
}

if ( $conn->{'phase'} eq qw| handshake | ) {
    if ( not $sock->connect_SSL ) {
        my $ssl_error = $IO::Socket::SSL::SSL_ERROR // 0;
        if ( $ssl_error == IO::Socket::SSL::SSL_WANT_READ() ) {
            $conn->{'watcher'}->poll(qw| r |);
            return;
        }
        if ( $ssl_error == IO::Socket::SSL::SSL_WANT_WRITE() ) {
            $conn->{'watcher'}->poll(qw| w |);
            return;
        }
        my $text = IO::Socket::SSL::errstr() // '';
        $text =~ s{\s+}{ }g;
        $text
            = "certificate verification failed "
            . "[ name $up->{'tls_name'} ] : $text"
            if $text =~ m{verif|certificate}i;
        return
            <[nameserv.enc.fail]>->( $conn, "tls handshake failed : $text" );
    }
    $conn->{'phase'}      = qw| ready |;
    $conn->{'ever_ready'} = TRUE;
    delete <nameserv.enc.health>->{ $up->{'name'} }
        if ref <nameserv.enc.health>;
    <[base.logs]>->(
        2,
        ': dns encrypted upstream %s connected [ %s %s:%d %s ]',
        $up->{'name'},
        $up->{'protocol'},
        $up->{'address'},
        $up->{'port'},
        eval { $sock->get_sslversion } // 'tls'
    );
    $conn->{'watcher'}->poll(qw| r |);
    <[nameserv.enc.pump]>->($conn);
    return if $conn->{'dead'};
}

## ready : flush what waits, then read every record that is there ##
<[nameserv.enc.flush]>->($conn) if length $conn->{'out'};
return                          if $conn->{'dead'};

for ( 1 .. 64 ) {
    my $chunk = '';
    my $read  = sysread $sock, $chunk, 65536;
    if ( not defined $read ) {
        last
            if $OS_ERROR{EAGAIN}
            or $OS_ERROR{EWOULDBLOCK}
            or ( $IO::Socket::SSL::SSL_ERROR // 0 )
            == IO::Socket::SSL::SSL_WANT_READ()
            or ( $IO::Socket::SSL::SSL_ERROR // 0 )
            == IO::Socket::SSL::SSL_WANT_WRITE();
        return <[nameserv.enc.fail]>->( $conn, "read failed : $OS_ERROR" );
    }
    return <[nameserv.enc.fail]>->( $conn, 'connection closed by the server' )
        if not $read;

    $conn->{'in'} .= $chunk;
    return <[nameserv.enc.fail]>->( $conn, 'reply buffer too large' )
        if length $conn->{'in'} > 131072;

    if ( $up->{'protocol'} eq qw| dot | ) {
        my @messages = <[nameserv.enc.dot_unframe]>->( \$conn->{'in'} );
        return
            <[nameserv.enc.fail]>->( $conn, 'invalid dns over tls framing' )
            if @messages and not defined $messages[0];
        for my $wire (@messages) {
            <[nameserv.enc.dispatch]>->( $conn, $wire );
            return if $conn->{'dead'};
        }
    } else {
        while ( length $conn->{'in'} ) {
            my ( $status, $body, $close )
                = <[nameserv.enc.doh_response]>->( \$conn->{'in'} );
            last if $status eq qw| need |;
            return <[nameserv.enc.fail]>->( $conn, "doh : $body" )
                if $status eq qw| error |;
            <[nameserv.enc.dispatch]>->( $conn, $body );
            return if $conn->{'dead'};
            if ($close) {
                ## the server ends this connection : waiting queries move ##
                ## to a fresh one, nothing failed                         ##
                my @waiting = @{ $conn->{'queue'} };
                $conn->{'queue'} = [];
                <[nameserv.enc.close]>->($conn);
                $ARG->{'enc_conn'} = undef for @waiting;
                <[nameserv.enc.start]>->( $ARG, $ARG->{'enc_target'} )
                    for @waiting;
                return;
            }
            <[nameserv.enc.pump]>->($conn);
            return if $conn->{'dead'};
        }
    }
    last if not eval { $sock->pending };
}
return;

#,,,.,...,.,,,,,.,,.,,.,.,.,,,...,.,.,,,.,...,..,,...,...,...,,.,,,.,,..,,.,.,
#2SRMX5PLJFGJCPQK5EQ2A2WLILUQL7MAYEX6YHO7KXNTVQLWY4X42CEGJZ4WJVU3IPUGIENG6ATJI
#\\\|CLVJQCDS5X2YHQ4YG37SVYPYSJGWJSDYT7Y2CT2AK3DG2RMLOAG \ / AMOS7 \ YOURUM ::
#\[7]5IC5URDVCZWFE5LIXNCL56XWDCP6Y525SQ4H37CPMBXPHXFKJ6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
