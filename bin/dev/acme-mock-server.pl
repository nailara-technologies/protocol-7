#!/usr/bin/perl

## [:< ##
#
# name  = acme-mock-server
# descr = Minimal ACME server mock for local testing (simple TCP version)
#

use strict;
use warnings;
use IO::Socket::INET;
use JSON::XS;
use Digest::SHA qw(sha256);
use MIME::Base64
    qw(encode_base64 decode_base64 encode_base64url decode_base64url);
use Digest::MD5 qw(md5_hex);
use Time::HiRes qw(time);

our $PORT     = 8555;
our $BASE_URL = "http://localhost:$PORT";

## In-memory state
our %ACCOUNTS;
our %ORDERS;
our %AUTHORIZATIONS;
our %CHALLENGES;
our %CERTIFICATES;
our $NONCE_COUNTER = 0;
our %NONCES;

our $LOG_FILE = '/tmp/acme-mock-server.log';
our $JSON     = JSON::XS->new->canonical(1)->pretty(0);

## Create listening socket
my $socket = IO::Socket::INET->new(
    LocalHost => 'localhost',
    LocalPort => $PORT,
    Listen    => 5,
    Reuse     => 1,
) or die "Cannot create socket: $!";

print "ACME Mock Server listening on http://localhost:$PORT\n";
print "Log file: $LOG_FILE\n";
print "Press Ctrl+C to stop\n";

## Main server loop
while ( my $client = $socket->accept() ) {
    handle_connection($client);
    close($client);
}

sub handle_connection {
    my ($client) = @_;

    # Set timeout so we don't wait forever
    $client->timeout(5);

    # Read request line
    my $request_line;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(5);
        $request_line = <$client>;
        alarm(0);
    };
    return unless defined $request_line;

    chomp($request_line);
    my ( $method, $path, $protocol ) = split( m|\s+|, $request_line );
    $method //= 'GET';
    $path   //= '/';

    # Read headers
    my $content_length = 0;
    my $header_count   = 0;
    while ( my $header = <$client> ) {
        chomp($header);
        $header =~ s|\r$||;    # Remove carriage return if present
        last if $header eq '';
        if ( $header =~ m|^Content-Length:\s*(\d+)|i ) {
            $content_length = $1;
        }
        $header_count++;
        last if $header_count > 100;    # Safety limit
    }

    # Read body if present
    my $content = '';
    if ( $content_length > 0 && $content_length < 1000000 ) {
        read( $client, $content, $content_length );
    }

    log_request( $method, $path, $content );

    my $response = '';
    my $status   = '200 OK';
    my $type     = 'application/json';

    # Route requests
    my $location_header;
    if ( $path eq '/directory' ) {
        $response = handle_directory();
    } elsif ( $path eq '/nonce' ) {
        $response = handle_nonce();
    } elsif ( $path eq '/new-account' ) {
        my $result = handle_new_account( $method, $content );
        if ( ref($result) eq 'HASH' ) {
            $response        = $result->{json};
            $location_header = $result->{location};
        } else {
            $response = $result;
        }
        $status = '201 Created' if $response !~ m|error|;
    } elsif ( $path eq '/new-order' ) {
        my $result = handle_new_order( $method, $content );
        if ( ref($result) eq 'HASH' ) {
            $response        = $result->{json};
            $location_header = $result->{location};
        } else {
            $response = $result;
        }
        $status = '201 Created' if $response !~ m|error|;
    } elsif ( $path =~ m{^/authz/([^/]+)$} ) {
        $response = handle_authz($1);
    } elsif ( $path =~ m{^/challenge/([^/]+)$} ) {
        $response = handle_challenge( $method, $1, $content );
    } elsif ( $path =~ m{^/order/([^/]+)$} ) {
        $response = handle_order($1);
    } elsif ( $path =~ m{^/finalize/([^/]+)$} ) {
        $response = handle_finalize( $method, $1, $content );
    } elsif ( $path =~ m{^/cert/([^/]+)$} ) {
        $response = handle_cert($1);
        $type     = 'application/pem-certificate-chain';
    } else {
        $status   = '404 Not Found';
        $response = $JSON->encode(
            { type => 'urn:acme:error:malformed', detail => 'Not found' } );
    }

    log_response( $status, $response );

    # Send HTTP response
    print $client "HTTP/1.1 $status\r\n";
    print $client "Content-Type: $type\r\n";
    print $client "Content-Length: " . length($response) . "\r\n";
    print $client "Replay-Nonce: " . create_nonce() . "\r\n";
    if ($location_header) {
        print $client "Location: $location_header\r\n";
    }

    print $client "Connection: close\r\n";
    print $client "\r\n";
    print $client $response;
}

sub handle_directory {
    return $JSON->encode(
        {   'newNonce'   => "$BASE_URL/nonce",
            'newAccount' => "$BASE_URL/new-account",
            'newOrder'   => "$BASE_URL/new-order",
            'revokeCert' => "$BASE_URL/revoke-cert",
            'keyChange'  => "$BASE_URL/key-change",
            'meta'       => {
                'termsOfService' => 'https://letsencrypt.org/document'
                    . 's/LE-SA-v1.2-November-15-2017.pdf',
                'website'                 => 'https://letsencrypt.org',
                'caaIdentities'           => ['letsencrypt.org'],
                'externalAccountRequired' => JSON::XS::false,
            }
        }
    );
}

sub handle_nonce {
    my $nonce = create_nonce();
    return $JSON->encode( { nonce => $nonce } );
}

sub create_nonce {
    my $nonce = sprintf( '%s-%d', md5_hex( time() ), $NONCE_COUNTER++ );
    $NONCES{$nonce} = { created_at => time(), used => 0 };
    return $nonce;
}

sub handle_new_account {
    my ( $method, $content ) = @_;

    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'POST required' } )
        if $method ne 'POST';

    my $jws = parse_jws($content);
    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'Invalid JWS' } )
        unless $jws;

    my $payload = $jws->{payload};
    return $JSON->encode(
        {   type   => 'urn:acme:error:malformed',
            detail => 'TOS must be agreed'
        }
    ) unless $payload->{termsOfServiceAgreed};

    my $account_id = sprintf( 'acct-%d', int( rand(999999) ) );
    $ACCOUNTS{$account_id} = {
        id         => $account_id,
        contact    => $payload->{contact} || [],
        status     => 'valid',
        key        => $jws->{header}->{jwk},
        created_at => time(),
    };

    log_line("Created account: $account_id");

    my $account_url = "$BASE_URL/account/$account_id";
    my $json        = $JSON->encode(
        {   status               => 'valid',
            contact              => $payload->{contact} || [],
            termsOfServiceAgreed => JSON::XS::true,
            createdAt            => time(),
        }
    );

    return {
        json     => $json,
        location => $account_url,
    };
}

sub handle_new_order {
    my ( $method, $content ) = @_;

    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'POST required' } )
        if $method ne 'POST';

    my $jws = parse_jws($content);
    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'Invalid JWS' } )
        unless $jws;

    my $payload     = $jws->{payload};
    my @identifiers = @{ $payload->{identifiers} || [] };

    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'No identifiers' } )
        unless @identifiers;

    my $order_id = sprintf( 'order-%d', int( rand(999999) ) );
    my @authz_ids;
    my @domains;

    foreach my $identifier (@identifiers) {
        push @domains, $identifier->{value};
        my $authz_id = sprintf( 'authz-%d', int( rand(999999) ) );
        push @authz_ids, $authz_id;

        my @challenge_ids;

        my $http01_id = sprintf( 'chal-%d-http01', int( rand(999999) ) );
        push @challenge_ids, $http01_id;
        $CHALLENGES{$http01_id} = {
            id         => $http01_id,
            authz_id   => $authz_id,
            type       => 'http-01',
            token      => random_token(),
            status     => 'pending',
            created_at => time(),
        };

        my $dns01_id = sprintf( 'chal-%d-dns01', int( rand(999999) ) );
        push @challenge_ids, $dns01_id;
        $CHALLENGES{$dns01_id} = {
            id         => $dns01_id,
            authz_id   => $authz_id,
            type       => 'dns-01',
            token      => random_token(),
            status     => 'pending',
            created_at => time(),
        };

        $AUTHORIZATIONS{$authz_id} = {
            id         => $authz_id,
            order_id   => $order_id,
            identifier => $identifier,
            status     => 'pending',
            challenges => \@challenge_ids,
            created_at => time(),
        };
    }

    $ORDERS{$order_id} = {
        id             => $order_id,
        status         => 'pending',
        identifiers    => \@identifiers,
        authorizations => \@authz_ids,
        domains        => \@domains,
        not_before     => time(),
        not_after      => time() + ( 90 * 24 * 3600 ),
        finalize       => "$BASE_URL/finalize/$order_id",
        created_at     => time(),
    };

    log_line(
        "Created order: $order_id for domains: " . join( ', ', @domains ) );

    my $order_url = "$BASE_URL/order/$order_id";
    my $json      = $JSON->encode(
        {   status         => 'pending',
            expires        => time() + ( 30 * 24 * 3600 ),
            identifiers    => \@identifiers,
            authorizations => [ map {"$BASE_URL/authz/$_"} @authz_ids ],
            finalize       => "$BASE_URL/finalize/$order_id",
            notBefore      => time(),
            notAfter       => time() + ( 90 * 24 * 3600 ),
        }
    );

    return {
        json     => $json,
        location => $order_url,
    };
}

sub handle_authz {
    my ($authz_id) = @_;

    my $authz = $AUTHORIZATIONS{$authz_id};
    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'Authz not found' } )
        unless $authz;

    return $JSON->encode(
        {   identifier => $authz->{identifier},
            status     => $authz->{status},
            expires    => $authz->{created_at} + ( 30 * 24 * 3600 ),
            challenges => [
                map {
                    my $chal_id = $_;
                    my $chal    = $CHALLENGES{$chal_id};
                    {   type      => $chal->{type},
                        url       => "$BASE_URL/challenge/$chal_id",
                        status    => $chal->{status},
                        token     => $chal->{token},
                        validated => $chal->{validated_at}
                        ? JSON::XS::true
                        : JSON::XS::false,
                    };
                } @{ $authz->{challenges} }
            ],
        }
    );
}

sub handle_challenge {
    my ( $method, $challenge_id, $content ) = @_;

    my $challenge = $CHALLENGES{$challenge_id};
    return $JSON->encode(
        {   type   => 'urn:acme:error:malformed',
            detail => 'Challenge not found'
        }
    ) unless $challenge;

    if ( $method eq 'POST' ) {
        my $jws = parse_jws($content);
        return $JSON->encode(
            { type => 'urn:acme:error:malformed', detail => 'Invalid JWS' } )
            unless $jws;

        log_line( "Challenge $challenge_id validation "
                . "initiated (type: $challenge->{type})" );

        sleep(1);

        $challenge->{status}       = 'valid';
        $challenge->{validated_at} = time();

        my $authz = $AUTHORIZATIONS{ $challenge->{authz_id} };

        ## For testing: mark ALL challenges in this authorization as valid
        ## (Real ACME servers require responding to each challenge separately)
        foreach my $chal_id ( @{ $authz->{challenges} } ) {
            $CHALLENGES{$chal_id}->{status}       = 'valid';
            $CHALLENGES{$chal_id}->{validated_at} = time();
        }

        $authz->{status} = 'valid';
        log_line( "Authorization $challenge->{authz_id} is "
                . "now valid (all challenges marked valid)" );
        log_line("Challenge $challenge_id is now valid");
    }

    return $JSON->encode(
        {   type      => $challenge->{type},
            url       => "$BASE_URL/challenge/$challenge_id",
            status    => $challenge->{status},
            token     => $challenge->{token},
            validated => $challenge->{validated_at}
            ? JSON::XS::true
            : JSON::XS::false,
        }
    );
}

sub handle_order {
    my ($order_id) = @_;

    my $order = $ORDERS{$order_id};
    unless ($order) {
        log_line("ERROR: Order $order_id not found in ORDERS hash");
        log_line( "Available orders: " . join( ", ", keys %ORDERS ) );
        return $JSON->encode(
            {   type   => 'urn:acme:error:malformed',
                detail => 'Order not found'
            }
        );
    }

    log_line("Handling order $order_id, current status: $order->{status}");

    my $all_valid = 1;
    foreach my $authz_id ( @{ $order->{authorizations} } ) {
        if ( $AUTHORIZATIONS{$authz_id}->{status} ne 'valid' ) {
            $all_valid = 0;
            log_line( "  Authorization $authz_id not valid yet (status: "
                    . "$AUTHORIZATIONS{$authz_id}->{status})" );
            last;
        }
    }

    if ( $all_valid && $order->{status} eq 'pending' ) {
        $order->{status} = 'ready';
        log_line("Order $order_id is now ready for finalization");
    } elsif ($all_valid) {
        log_line( "Order $order_id: all authorizations valid, "
                . "but status is already '$order->{status}'" );
    }

    my $response_data = {
        status         => $order->{status},
        expires        => $order->{created_at} + ( 30 * 24 * 3600 ),
        identifiers    => $order->{identifiers},
        authorizations =>
            [ map {"$BASE_URL/authz/$_"} @{ $order->{authorizations} } ],
        finalize  => "$BASE_URL/finalize/$order_id",
        notBefore => $order->{not_before},
        notAfter  => $order->{not_after},
    };

    # Only include certificate if it's been issued
    $response_data->{certificate} = $order->{certificate_url}
        if $order->{certificate_url};

    log_line("Returning order status: $response_data->{status}");
    return $JSON->encode($response_data);
}

sub handle_finalize {
    my ( $method, $order_id, $content ) = @_;

    log_line("Finalize request for order: $order_id");

    my $order = $ORDERS{$order_id};
    unless ($order) {
        log_line( "ERROR: Finalize order $order_id "
                . "not found. Available orders: "
                . join( ", ", keys %ORDERS ) );
        return $JSON->encode(
            {   type   => 'urn:acme:error:malformed',
                detail => 'Order not found'
            }
        );
    }

    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'POST required' } )
        if $method ne 'POST';

    my $jws = parse_jws($content);
    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'Invalid JWS' } )
        unless $jws;

    my $payload = $jws->{payload};
    my $csr     = $payload->{csr};

    return $JSON->encode(
        { type => 'urn:acme:error:malformed', detail => 'CSR required' } )
        unless $csr;

    return $JSON->encode(
        {   type   => 'urn:acme:error:orderNotReady',
            detail => 'Order not ready'
        }
    ) if $order->{status} ne 'ready';

    my $cert_id  = sprintf( 'cert-%d', int( rand(999999) ) );
    my $cert_pem = generate_certificate( $order, $csr );

    $CERTIFICATES{$cert_id} = {
        id          => $cert_id,
        order_id    => $order_id,
        certificate => $cert_pem,
        created_at  => time(),
    };

    $order->{status}          = 'valid';
    $order->{certificate_url} = "$BASE_URL/cert/$cert_id";

    log_line("Order $order_id finalized, certificate $cert_id generated");

    return $JSON->encode(
        {   status         => 'valid',
            expires        => $order->{created_at} + ( 30 * 24 * 3600 ),
            identifiers    => $order->{identifiers},
            authorizations =>
                [ map {"$BASE_URL/authz/$_"} @{ $order->{authorizations} } ],
            finalize    => "$BASE_URL/finalize/$order_id",
            notBefore   => $order->{not_before},
            notAfter    => $order->{not_after},
            certificate => "$BASE_URL/cert/$cert_id",
        }
    );
}

sub handle_cert {
    my ($cert_id) = @_;

    my $cert = $CERTIFICATES{$cert_id};
    return '' unless $cert;

    return $cert->{certificate};
}

sub generate_certificate {
    my ( $order, $csr_b64url ) = @_;

    my $cert_pem = <<"EOF";
-----BEGIN CERTIFICATE-----
MIIBkTCB+wIJAIHHIgKwNpjxMA0GCSqGSIb3DQEBBQUAMBMxETAPBgNVBAMMCENv
bW1vbk5hbWUwHhcNMjQwMTAxMDAwMDAwWhcNMjQwMTMxMjM1OTU5WjATMREwDwYD
VQQDDAhDb21tb25OYW1lMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBANvKqCABo7bB
llzTM5cRQ0S5RR5Tj0F7HfcJL8MzQyxzGR7A5QCmNvOQlUZvRSqFl4eJ9N9lpFDq
MvSKEZFYSWECAwEAATANBgkqhkiG9w0BAQUFAANBAHVh7kC5GK3hxTW3XD0DRwkP
5VBGqRm6T3EWPXxV7kKXkKPWZvLfSQsK0e0XFJz9Uw5C5eL3JQz4F4Tz8JQ1LCQ=
-----END CERTIFICATE-----
EOF

    return $cert_pem;
}

sub parse_jws {
    my ($content) = @_;

    return undef unless $content;

    my $jws_obj = eval { $JSON->decode($content) };
    return undef unless $jws_obj;

    my $header = eval {
        $JSON->decode( decode_base64url( $jws_obj->{protected} || '' ) );
    };
    my $payload = eval {
        $JSON->decode( decode_base64url( $jws_obj->{payload} || '' ) );
    };

    return undef unless $header && $payload;

    return {
        header    => $header,
        payload   => $payload,
        signature => $jws_obj->{signature},
    };
}

sub random_token {
    my @chars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9' );
    my $token = '';
    for ( 1 .. 32 ) {
        $token .= $chars[ rand @chars ];
    }
    return $token;
}

sub log_request {
    my ( $method, $path, $content ) = @_;
    my $msg = "$method $path";
    $msg .= " (body: " . length($content) . " bytes)"
        if $content && length($content) > 0;
    log_line($msg);
}

sub log_response {
    my ( $status, $response ) = @_;
    my $msg = "Response: $status";
    $msg .= " (body: " . length($response) . " bytes)"
        if $response && length($response) > 0;
    log_line($msg);
}

sub log_line {
    my ($msg) = @_;
    my $timestamp = scalar(localtime);
    print "[$timestamp] $msg\n";

    if ( open( my $fh, '>>', $LOG_FILE ) ) {
        print $fh "[$timestamp] $msg\n";
        close($fh);
    }
}

#,,.,,..,,,.,,.,,,..,,..,,.,,,,..,,..,...,.,.,.,.,...,...,...,.,,,,..,,,.,.,,,
#7TYQPCW2ZXCV2573IJWZLYADFZH3PI3Z3FZ5S5J7GMX3ARPW4HRYZGKO53LBFNF3LQFRD5ZNSCMB2
#\\\|TF3KDF2R5YMM3NDB57XUGXCEVJZBQIRQNBHT3NY5VHRPGZ3G6VL \ / AMOS7 \ YOURUM ::
#\[7]XNBB6T57AYHJJENH52MZ4K7K4Q6IUAWDYP5L6QM4IQOAY3752ODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
