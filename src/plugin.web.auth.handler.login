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
        my $max_age = ( $login_session->{'expires_at_epoch'} // 0 ) - time;
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

#,,,.,,,,,,.,,..,,..,,...,.,,,.,,,.,.,,.,,,..,..,,...,...,,,.,,.,,.,.,..,,,,.,
#2RYSEEQTUKBQGFTEHLNRQDISRGT3E62XUXXGI6D234C4K4NOBIPDYJDOPIDTB77JIIO32MUYFCAV4
#\\\|KKGGLSPTNRJNO6BHRXGOUVH2P5CBJRYEVNNMQ7J6NW5EW5BCTM4 \ / AMOS7 \ YOURUM ::
#\[7]2DEA6362WXHLZMZ5I7YOX5HVEBM3VFVAWLCWP3PKAPMS27GE6CCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
