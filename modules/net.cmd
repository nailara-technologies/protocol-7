## [:< ##

# name       = net.cmd

my ( $filehandle, $command, $handler, $param_hash ) = (
    $_[0]->{'handle'},         $_[0]->{'command'},
    $_[0]->{'answer_handler'}, $_[0]->{'handler_params'}
);

if ( not defined $_[0]->{'answer_handler'} ) {
    <[base.log]>->( 0, "net.cmd: no answer-handler specified" );
}

if ( not defined $_[0]->{'target_cid'} ) {
    $_[0]->{'target_cid'}
        = <[base.gen_id]>->( $data{'handle'}{$filehandle}{'cmd'}, 23000 )
        ;    # --> config
}

$data{'handle'}{ $_[0]->{'handle'} }{'cmd'}{ $_[0]->{'target_cid'} }
    {'handler'} = $_[0]->{'answer_handler'};
$data{'handle'}{ $_[0]->{'handle'} }{'cmd'}{ $_[0]->{'target_cid'} }{'params'}
    = $_[0]->{'handler_params'};

<[base.net.send_to_socket]>->(
    $_[0]->{'handle'},
    '(' . $_[0]->{'target_cid'} . ')' . $_[0]->{'command'} . "\n"
);

# return $command_id;

#,,,.,,,.,,,.,.,,,,,,,,..,.,,,,,,,,..,..,,,..,..,,...,...,,.,,.,.,,,,,,,,,,,.,
#IZVLFQW6JC3BZ7NWNRGFQ2PXLF6NMOEXEYYCBAAJ5SSEDU2JDOMT7U3RSARRDPKLYSXZLZ3FLD5W2
#\\\|WXJZIKANB6PH5XRFOQODPXXQ2ITPWOIB7VRR7Y4CB4L6C5UGNMG \ / AMOS7 \ YOURUM ::
#\[7]BK3SSPJBQH5XPZ357SK4VWH3MDY2BO6XPAXTUC25YD5W7ZKXXEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
