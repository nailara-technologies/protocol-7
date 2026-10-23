## [:< ##

# name  = httpd.handler.web-relay.login
# descr = reply handler for the login admission relay
# note  = reply handler for the login admission relay : the web zenka's
#         envelope [ status, body, retry_after, set_cookie ] becomes the
#         HTTP answer -- 200 with the session cookie, 401, or an
#         immediate 429 with Retry-After [ never a held connection for
#         a refused source ]

my $reply    = shift                          // {};
my $http_sid = $reply->{'params'}{'http_sid'} // return;

my $session = $data{'session'}->{$http_sid};
if ( ref $session ne qw| HASH | ) {
    return <[base.logs]>->(
        1, '[%d] client already gone.. [web-relay.login]', $http_sid
    );
}

my ( $mode, $text ) = <[base.reply.mode_text]>->($reply);

my $envelope;
$envelope = eval { JSON::XS::decode_json($text) }
    if length $text and $mode =~ m{^(size|data|true)$};

if ( ref $envelope ne qw| HASH | or not length( $envelope->{'body'} // '' ) )
{
    <[base.logs]>->(
        1,         '[%d] bad login admission reply [ mode %s ] : 502',
        $http_sid, $mode
    );
    $session->{'buffer'}->{'output'}
        .= <[httpd.send_error_page]>->( $http_sid, 502 );
    $session->{'flush_shutdown'} = TRUE;
    return;
}

my $status = $envelope->{'status'} // 502;
my $body   = $envelope->{'body'};

my $header = {
    'Content-Type'   => qw| application/json |,
    'Content-Length' => length($body),
    'Connection'     => qw| close |,
};
$header->{'Retry-After'} = $envelope->{'retry_after'}
    if defined $envelope->{'retry_after'};
$header->{'Set-Cookie'} = $envelope->{'set_cookie'}
    if defined $envelope->{'set_cookie'};

$session->{'buffer'}->{'output'}
    .= <[httpd.new_header]>->( $status, $header );
$session->{'buffer'}->{'output'} .= $body;
$session->{'flush_shutdown'} = TRUE;

return;

#,,,.,,..,.,.,.,,,...,,..,..,,.,,,,,.,.,,,,.,,..,,...,...,,,,,,.,,...,..,,.,.,
#COLG4A52RFWI4RATSNQEHMBLLSLYSAXN4GPSDQXORSOLFGQ36MXTWGGD7TSRLOLBSHZNXZR76MCQW
#\\\|7UM5EYCYWQONX7S6YQKINT7LX4GS4CVDN5WAWJRWFUYTAKQ6QSN \ / AMOS7 \ YOURUM ::
#\[7]ETIS6WNLBOSXELKPRVLYMFZERY5FDMFGUFWMYCCE4G3UWCPFRIAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
