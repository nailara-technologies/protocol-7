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

#,,,.,,,.,,,.,.,,,,,,,,..,.,,,,,,,,..,..,,,..,..,,...,...,..,,,..,,.,,,..,,,.,
#TQCYMN3TCBBJAUBBZILS3TU3QND5R53X6SSJGMKSFGVFMOJHEEGHRUCWNDMTIBSV6HNPKODOQIQKK
#\\\|R4JUXONQOCJ5GP6FBDI7LRGFFOZB5D2WZZLNGWKZIFBQ2HSRG7C \ / AMOS7 \ YOURUM ::
#\[7]D3TFCJ4OMA65UMGHGW45SSK5BMPAROI55T2ODSNE222L7J7A32CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
