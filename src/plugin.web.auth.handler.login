## [:< ##

# name  = plugin.web.auth.handler.login
# descr = POST /auth/login — verify pre-shared token, return session info

my $id       = shift;
my $zenka    = <system.zenka.name> // qw| web |;
my $is_httpd = ( $zenka eq qw| httpd | or $zenka eq qw| httpsd | );

## no token over plain http [ plugin.web.auth.refuse_plaintext ] ##
return 2 if $is_httpd and <[plugin.web.auth.refuse_plaintext]>->($id);

my ( $http_sid, $body, $headers );

if ($is_httpd) {
    $http_sid = $id;
    $body     = $data{'session'}->{$http_sid}->{'buffer'}->{'input'} // '';
    $data{'session'}->{$http_sid}->{'buffer'}->{'input'} = '';
    $headers
        = $data{'session'}->{$http_sid}->{'http'}->{'request'}->{'headers'}
        // {};
} else {
    my $call = $id // {};
    $body     = $call->{'args'}     // '';
    $http_sid = $call->{'http_sid'} // 0;
    $headers  = {};
}

## parse JSON body if present ##
my $payload = {};
if ( length $body ) {
    $payload = eval { JSON::XS::decode_json($body) } // {};
}

## extract token from body, header, or cookie ##
my $token = '';
if ( ref $payload eq qw| HASH | and length( $payload->{'token'} // '' ) ) {
    $token = $payload->{'token'};
} else {
    my $auth = $headers->{'authorization'} // '';
    if ( $auth =~ m|^Bearer\s+(\S+)$|i ) {
        $token = $LAST_PAREN_MATCH;
    } else {
        my $cookie = $headers->{'cookie'} // '';
        if ( $cookie =~ m|\bp7_session=([^;\s]+)| ) {
            $token = $LAST_PAREN_MATCH;
        }
    }
}

my $json_str;
my $login_session;
if ( length $token ) {
    $login_session = <[plugin.web.auth.verify_session]>->($token);
    $login_session = <[plugin.web.auth.ui_session.begin]>->($login_session)
        if defined $login_session;
    if ( defined $login_session ) {
        $json_str = eval {
            JSON::XS::encode_json(
                {   'ok'         => JSON::XS::true(),
                    'token_hash' => $login_session->{'token_hash'} // '',
                    'user_id'    => $login_session->{'user_id'}    // '',
                    'node_id'    => $login_session->{'node_id'}    // '',
                }
            );
        } // '{"ok":true}';
    } else {
        $json_str = '{"ok":false,"error":"invalid token"}';
    }
} else {
    $json_str = '{"ok":false,"error":"token required"}';
}

if ($is_httpd) {
    my $code = ( $json_str =~ m|"ok":true| ) ? 200 : 401;
    $data{'session'}->{$http_sid}->{'http'}->{'close'} = 1;
    my $header = {
        'Content-Type'   => qw| application/json |,
        'Content-Length' => length($json_str),
        'Connection'     => qw| close |,
    };
    if ( $code == 200 and length $token ) {
        ## session cookie : HttpOnly + SameSite=Strict always, Secure when ##
        ## the request arrived over TLS                                    ##
        ## [ real socket check, never a header ] -- the browser keeps      ##
        ## sending it; the ui needs no local storage copy of the token     ##
        my $secure_flag = '';
        my $peer_fh     = $data{'session'}->{$http_sid}->{'handle'};
        $secure_flag = '; Secure'
            if ref $peer_fh and $peer_fh->isa('IO::Socket::SSL');
        my $cookie_expiry = $login_session->{'expires_at_epoch'} // 0;
        my $max_expiry
            = $login_session->{'data'}{'ui'}{'max_expires_at_epoch'} // 0;
        $cookie_expiry = $max_expiry
            if $max_expiry > 0 and $max_expiry < $cookie_expiry;
        my $max_age = $cookie_expiry - time;
        $max_age = 0 if $max_age < 0;
        $header->{'Set-Cookie'}
            = sprintf(
            'p7_session=%s; Path=/; Max-Age=%d; HttpOnly; SameSite=Strict%s',
            $token, $max_age, $secure_flag );
    }
    $data{'session'}->{$http_sid}->{'buffer'}->{'output'}
        .= <[httpd.new_header]>->( $code, $header );
    $data{'session'}->{$http_sid}->{'buffer'}->{'output'} .= $json_str;
    return 2;
}

return {
    'mode'         => qw| strm |,
    'data'         => $json_str,
    'content_type' => qw| application/json |,
};

#,,,.,,,.,..,,,.,,,.,,...,...,...,.,,,,.,,.,,,..,,...,...,...,.,,,..,,.,,,..,,
#3ZVDOZFFA7AS6UZLOSWJOWO7ETSIW4G3OIRVHQAF2UA66L4HEX27HEXGUBHK55WHLVFJ7PDXWHR7S
#\\\|R4CWW2YTPRP77RGP7C3CPRFIJLBF3H2NI2GEEKOYTRFBHUVPY6R \ / AMOS7 \ YOURUM ::
#\[7]IH73AYA37CPY2S33RLPJA7MLYMJVNW7S7ZQKBRHBKMBLOF5DMQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
