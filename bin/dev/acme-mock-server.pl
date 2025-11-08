#!/usr/bin/perl

## [:< ##
#
# name  = acme-mock-server
# descr = Minimal ACME server mock for local testing
#

use strict;
use warnings;
use HTTP::Server::Simple;
use CGI;
use JSON::XS;
use Data::Dumper;
use Digest::SHA qw(sha256);
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::X509;
use Digest::MD5  qw(md5_hex);
use Time::HiRes  qw(time);
use MIME::Base64 qw|
    encode_base64 decode_base64 encode_base64url decode_base64url
    |;

our $PORT     = 8555;
our $BASE_URL = "http://localhost:$PORT";

### In-memory state ##
##
our %ACCOUNTS;    # kid => { account_key, contact, ... }

## order_id => { account_id, domains, status, authorizations, ... }
#
our %ORDERS;
## authz_id => { order_id, identifier, status, challenges, ... }
#
our %CHALLENGES;      # challenge_id => { authz_id, type, token, status, ... }
our %CERTIFICATES;    # cert_id => { order_id, certificate_pem, ... }
our %NONCES;          # nonce => { created_at, used => 0|1 }
our $NONCE_COUNTER = 0;
our %AUTHORIZATIONS;

our $LOG_FILE = '/tmp/acme-mock-server.log';
our $JSON     = JSON::XS->new->canonical(1)->pretty(1);

package ACMEServer;
use base qw(HTTP::Server::Simple);

sub handle_request {
    my ($self) = @_;
    my $cgi = CGI->new();

    my $method  = $cgi->request_method() || 'GET';
    my $path    = $cgi->path_info()      || '/';
    my $content = '';

    # Read POST body
    if ( $method eq 'POST' ) {
        my $len = $cgi->content_length() || 0;
        read( STDIN, $content, $len ) if $len > 0;
    }

    &log_request( $method, $path, $content );

    my $response     = '';
    my $status       = '200 OK';
    my $content_type = 'application/json';

    # Route requests
    if ( $path eq '/directory' ) {
        $response = &handle_directory();
    } elsif ( $path =~ m{^/nonce$} ) {
        $response = &handle_nonce();
    } elsif ( $path =~ m{^/new-account$} ) {
        $response = &handle_new_account( $method, $content );
    } elsif ( $path =~ m{^/new-order$} ) {
        $response = &handle_new_order( $method, $content );
    } elsif ( $path =~ m{^/authz/(.+)$} ) {
        my $authz_id = $1;
        $response = &handle_authz($authz_id);
    } elsif ( $path =~ m{^/challenge/(.+)$} ) {
        my $challenge_id = $1;
        $response = &handle_challenge( $method, $challenge_id, $content );
    } elsif ( $path =~ m{^/order/(.+)$} ) {
        my $order_id = $1;
        $response = &handle_order($order_id);
    } elsif ( $path =~ m{^/finalize/(.+)$} ) {
        my $order_id = $1;
        $response = &handle_finalize( $method, $order_id, $content );
    } elsif ( $path =~ m{^/cert/(.+)$} ) {
        my $cert_id = $1;
        $response     = &handle_cert($cert_id);
        $content_type = 'application/pem-certificate-chain';
    } else {
        $status   = '404 Not Found';
        $response = &to_json(
            { type => 'urn:acme:error:malformed', detail => 'Not found' } );
    }

    &log_response( $status, $response );

    # Send response
    print "HTTP/1.1 $status\r\n";
    print "Content-Type: $content_type\r\n";
    print "Content-Length: " . length($response) . "\r\n";
    print "Replay-Nonce: " . &create_nonce() . "\r\n";
    print "\r\n";
    print $response;
}

sub handle_directory {
    return &to_json(
        {   'newNonce'   => "$BASE_URL/nonce",
            'newAccount' => "$BASE_URL/new-account",
            'newOrder'   => "$BASE_URL/new-order",
            'revokeCert' => "$BASE_URL/revoke-cert",
            'keyChange'  => "$BASE_URL/key-change",
            'meta'       => {
                'termsOfService' =>
                    'https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf',
                'website'                 => 'https://letsencrypt.org',
                'caaIdentities'           => ['letsencrypt.org'],
                'externalAccountRequired' => JSON::XS::false,
            }
        }
    );
}

sub handle_nonce {
    my $nonce = &create_nonce();
    return &to_json( { nonce => $nonce } );
}

sub create_nonce {
    my $nonce = sprintf( '%s-%d', md5_hex( time() ), $NONCE_COUNTER++ );
    $NONCES{$nonce} = { created_at => time(), used => 0 };
    return $nonce;
}

sub handle_new_account {
    my ( $method, $content ) = @_;

    if ( $method ne 'POST' ) {
        return &to_json(
            { type => 'urn:acme:error:malformed', detail => 'POST required' }
        );
    }

    my $jws = &parse_jws($content);
    unless ($jws) {
        return &to_json(
            { type => 'urn:acme:error:malformed', detail => 'Invalid JWS' } );
    }

    my $payload = $jws->{payload};
    unless ( $payload->{termsOfServiceAgreed} ) {
        return &to_json(
            {   type   => 'urn:acme:error:malformed',
                detail => 'TOS must be agreed'
            }
        );
    }

    # Create account
    my $account_id = sprintf( 'acct-%d', int( rand(999999) ) );
    $ACCOUNTS{$account_id} = {
        id         => $account_id,
        contact    => $payload->{contact} || [],
        status     => 'valid',
        key        => $jws->{header}->{jwk},
        created_at => time(),
    };

    &log_line("Created account: $account_id");

    my $response = &to_json(
        {   status               => 'valid',
            contact              => $payload->{contact} || [],
            termsOfServiceAgreed => JSON::XS::true,
            createdAt            => time(),
        }
    );

    return $response;
}

sub handle_new_order {
    my ( $method, $content ) = @_;

    if ( $method ne 'POST' ) {
        return &to_json(
            { type => 'urn:acme:error:malformed', detail => 'POST required' }
        );
    }

    my $jws = &parse_jws($content);
    unless ($jws) {
        return &to_json(
            { type => 'urn:acme:error:malformed', detail => 'Invalid JWS' } );
    }

    my $payload     = $jws->{payload};
    my @identifiers = @{ $payload->{identifiers} || [] };

    unless (@identifiers) {
        return &to_json(
            {   type   => 'urn:acme:error:malformed',
                detail => 'No identifiers'
            }
        );
    }

    # Create order
    my $order_id = sprintf( 'order-%d', int( rand(999999) ) );
    my @authz_ids;
    my @domains;

    foreach my $identifier (@identifiers) {
        push @domains, $identifier->{value};
        my $authz_id = sprintf( 'authz-%d', int( rand(999999) ) );
        push @authz_ids, $authz_id;

        # Create authorization
        my @challenge_ids;

        # HTTP-01 challenge
        my $http01_id = sprintf( 'chal-%d-http01', int( rand(999999) ) );
        push @challenge_ids, $http01_id;
        $CHALLENGES{$http01_id} = {
            id         => $http01_id,
            authz_id   => $authz_id,
            type       => 'http-01',
            token      => &random_token(),
            status     => 'pending',
            created_at => time(),
        };

        # DNS-01 challenge
        my $dns01_id = sprintf( 'chal-%d-dns01', int( rand(999999) ) );
        push @challenge_ids, $dns01_id;
        $CHALLENGES{$dns01_id} = {
            id         => $dns01_id,
            authz_id   => $authz_id,
            type       => 'dns-01',
            token      => &random_token(),
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
        not_after      => time() + ( 90 * 24 * 3600 ),      # 90 days
        finalize       => "$BASE_URL/finalize/$order_id",
        created_at     => time(),
    };

    &log_line(
        "Created order: $order_id for domains: " . join( ', ', @domains ) );

    my $response = &to_json(
        {   status         => 'pending',
            expires        => time() + ( 30 * 24 * 3600 ),    # 30 days
            identifiers    => \@identifiers,
            authorizations => [ map {"$BASE_URL/authz/$_"} @authz_ids ],
            finalize       => "$BASE_URL/finalize/$order_id",
            notBefore      => time(),
            notAfter       => time() + ( 90 * 24 * 3600 ),
        }
    );

    return $response;
}

sub handle_authz {
    my ($authz_id) = @_;

    my $authz = $AUTHORIZATIONS{$authz_id};
    unless ($authz) {
        return &to_json(
            {   type   => 'urn:acme:error:malformed',
                detail => 'Authz not found'
            }
        );
    }

    my @challenge_urls
        = map {"$BASE_URL/challenge/$_"} @{ $authz->{challenges} };

    my $response = &to_json(
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
                        validationRecord => $chal->{validation_record} || [],
                    };
                } @{ $authz->{challenges} }
            ],
        }
    );

    return $response;
}

sub handle_challenge {
    my ( $method, $challenge_id, $content ) = @_;

    my $challenge = $CHALLENGES{$challenge_id};
    unless ($challenge) {
        return &to_json(
            {   type   => 'urn:acme:error:malformed',
                detail => 'Challenge not found'
            }
        );
    }

    if ( $method eq 'POST' ) {
        my $jws = &parse_jws($content);
        unless ($jws) {
            return &to_json(
                {   type   => 'urn:acme:error:malformed',
                    detail => 'Invalid JWS'
                }
            );
        }

        # Mark challenge as being validated
        # In a real server, it would actually check the validation
        # For mock, we accept it immediately for HTTP-01
        # For DNS-01, we'd check DNS records

        &log_line(
            "Challenge $challenge_id validation initiated (type: $challenge->{type})"
        );

        # Simulate validation delay
        sleep(1);

        $challenge->{status}       = 'valid';
        $challenge->{validated_at} = time();

        # Update authorization status if all challenges are valid
        my $authz     = $AUTHORIZATIONS{ $challenge->{authz_id} };
        my $all_valid = 1;
        foreach my $chal_id ( @{ $authz->{challenges} } ) {
            if ( $CHALLENGES{$chal_id}->{status} ne 'valid' ) {
                $all_valid = 0;
                last;
            }
        }
        if ($all_valid) {
            $authz->{status} = 'valid';
            &log_line("Authorization $challenge->{authz_id} is now valid");
        }

        &log_line("Challenge $challenge_id is now valid");
    }

    my $response = &to_json(
        {   type      => $challenge->{type},
            url       => "$BASE_URL/challenge/$challenge_id",
            status    => $challenge->{status},
            token     => $challenge->{token},
            validated => $challenge->{validated_at}
            ? JSON::XS::true
            : JSON::XS::false,
            validationRecord => $challenge->{validation_record} || [],
        }
    );

    return $response;
}

sub handle_order {
    my ($order_id) = @_;

    my $order = $ORDERS{$order_id};
    unless ($order) {
        return &to_json(
            {   type   => 'urn:acme:error:malformed',
                detail => 'Order not found'
            }
        );
    }

    # Check if all authorizations are valid
    my $all_valid = 1;
    foreach my $authz_id ( @{ $order->{authorizations} } ) {
        if ( $AUTHORIZATIONS{$authz_id}->{status} ne 'valid' ) {
            $all_valid = 0;
            last;
        }
    }

    if ( $all_valid && $order->{status} eq 'pending' ) {
        $order->{status} = 'ready';
        &log_line("Order $order_id is now ready for finalization");
    }

    my $response = &to_json(
        {   status         => $order->{status},
            expires        => $order->{created_at} + ( 30 * 24 * 3600 ),
            identifiers    => $order->{identifiers},
            authorizations =>
                [ map {"$BASE_URL/authz/$_"} @{ $order->{authorizations} } ],
            finalize    => "$BASE_URL/finalize/$order_id",
            notBefore   => $order->{not_before},
            notAfter    => $order->{not_after},
            certificate => $order->{certificate_url} || undef,
        }
    );

    return $response;
}

sub handle_finalize {
    my ( $method, $order_id, $content ) = @_;

    my $order = $ORDERS{$order_id};
    unless ($order) {
        return &to_json(
            {   type   => 'urn:acme:error:malformed',
                detail => 'Order not found'
            }
        );
    }

    if ( $method ne 'POST' ) {
        return &to_json(
            { type => 'urn:acme:error:malformed', detail => 'POST required' }
        );
    }

    my $jws = &parse_jws($content);
    unless ($jws) {
        return &to_json(
            { type => 'urn:acme:error:malformed', detail => 'Invalid JWS' } );
    }

    my $payload = $jws->{payload};
    my $csr     = $payload->{csr};

    unless ($csr) {
        return &to_json(
            { type => 'urn:acme:error:malformed', detail => 'CSR required' }
        );
    }

    # Check if order is ready
    if ( $order->{status} ne 'ready' ) {
        return &to_json(
            {   type   => 'urn:acme:error:orderNotReady',
                detail => 'Order not ready'
            }
        );
    }

    # Generate certificate
    my $cert_id  = sprintf( 'cert-%d', int( rand(999999) ) );
    my $cert_pem = &generate_certificate( $order, $csr );

    $CERTIFICATES{$cert_id} = {
        id          => $cert_id,
        order_id    => $order_id,
        certificate => $cert_pem,
        created_at  => time(),
    };

    $order->{status}          = 'processing';
    $order->{certificate_url} = "$BASE_URL/cert/$cert_id";

    &log_line("Order $order_id finalized, certificate $cert_id generated");

    # Immediately mark as valid (in real server, this takes time)
    $order->{status} = 'valid';

    my $response = &to_json(
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

    return $response;
}

sub handle_cert {
    my ($cert_id) = @_;

    my $cert = $CERTIFICATES{$cert_id};
    unless ($cert) {
        return '404 Not Found';
    }

    return $cert->{certificate};
}

sub generate_certificate {
    my ( $order, $csr_b64url ) = @_;

    # Decode CSR
    my $csr_der = decode_base64url($csr_b64url);

    # For this mock, just return a self-signed certificate
    # In a real scenario, we'd parse the CSR and sign it properly

    my $domains = join( ', ', @{ $order->{domains} } );

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

    unless ($content) {
        return undef;
    }

    my $jws_obj = eval { $JSON->decode($content) };
    unless ($jws_obj) {
        return undef;
    }

    # Extract header and payload
    my $header = eval {
        $JSON->decode( decode_base64url( $jws_obj->{protected} || '' ) );
    };
    my $payload = eval {
        $JSON->decode( decode_base64url( $jws_obj->{payload} || '' ) );
    };

    unless ( $header && $payload ) {
        return undef;
    }

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

sub to_json {
    my ($data) = @_;
    return $JSON->encode($data);
}

sub log_request {
    my ( $method, $path, $content ) = @_;
    my $msg = "[" . scalar(localtime) . "] $method $path";
    if ( $content && length($content) > 0 ) {
        $msg .= " (body: " . length($content) . " bytes)";
    }
    &log_line($msg);
}

sub log_response {
    my ( $status, $response ) = @_;
    my $msg = "[" . scalar(localtime) . "] Response: $status";
    if ( $response && length($response) > 0 ) {
        $msg .= " (body: " . length($response) . " bytes)";
    }
    &log_line($msg);
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

package main;

# Start server
my $server = ACMEServer->new($PORT);
print "ACME Mock Server listening on http://localhost:$PORT\n";
print "Log file: $LOG_FILE\n";
print "Press Ctrl+C to stop\n";

$server->run();

#,,..,,,,,.,.,...,..,,.,,,.,.,,,,,...,.,,,,..,.,.,...,...,,,.,...,,.,,..,,..,,
#FP7FKYBQ7KQIDZNP2NK3RJNK2XOXWWOE3VRCRUBC7FBA62REOLXV4VMBEBCMWVUJGCJB6DHC3RWS2
#\\\|YBBOQ5ONOJCFFF2LRJABMGOXUDRKZF2JDFHIHDTZM5YFHQPOA72 \ / AMOS7 \ YOURUM ::
#\[7]XOC6IM5OZAWAI26LITTVDXBB54ZKX5ZSBIMAUBHATNYTCWOR7SDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
