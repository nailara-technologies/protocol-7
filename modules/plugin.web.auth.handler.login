## [:< ##

# name  = plugin.web.auth.handler.login
# descr = POST /auth/login — verify pre-shared token, return session info

my $id       = shift;
my $zenka    = <system.zenka.name> // qw| web |;
my $is_httpd = ( $zenka eq qw| httpd | or $zenka eq qw| httpsd | );

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
if ( length $token ) {
    my $session_data = <[plugin.web.auth.verify_session]>->($token);
    if ( defined $session_data ) {
        $json_str = eval {
            JSON::XS::encode_json(
                {   'ok'         => JSON::XS::true(),
                    'token_hash' => $session_data->{'token_hash'} // '',
                    'user_id'    => $session_data->{'user_id'}    // '',
                    'node_id'    => $session_data->{'node_id'}    // '',
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
    $data{'session'}->{$http_sid}->{'buffer'}->{'output'}
        .= <[httpd.new_header]>->(
        $code,
        {   'Content-Type'   => qw| application/json |,
            'Content-Length' => length($json_str),
            'Connection'     => qw| close |,
        }
        );
    $data{'session'}->{$http_sid}->{'buffer'}->{'output'} .= $json_str;
    return 2;
}

return {
    'mode'         => qw| strm |,
    'data'         => $json_str,
    'content_type' => qw| application/json |,
};

#,,.,,...,,..,...,.,,,..,,,..,..,,,,,,...,,,.,..,,...,...,,.,,,..,,.,,,.,,..,,

#,,,,,..,,,,,,,..,,,,,,.,,..,,..,,.,.,.,,,,,.,..,,...,...,.,.,,,,,.,.,,..,,,,,
#O3H6IIPVUGSI7KR73XGOM7R4B6LEYVXPBC46XFFATFMXLJKVO3F7ZDKQQR7X4IMI6ZT5QYOVGZQ3S
#\\\|G3XPS7UZC2YT423VZPWPMRXA66K67XDJQUKILLHFDDU5EYCRFKB \ / AMOS7 \ YOURUM ::
#\[7]3SUHVXMAYESWB6X4C4YH3CG4ZYJNLNBNLFREHTKTCDCESIZ3TYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
