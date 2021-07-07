## >:] ##

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

#,,.,,,..,,,,,.,,,.,.,,.,,,..,..,,.,,,,..,.,,,..,,...,...,...,,,.,.,,,,.,,,,.,
#4CZPMJIY57L4CFC7XHAZWX2FOMJRFQ4E442SVXMEPS34ZRAH7IDYYWKRXAXMYGWSM3677JSYJU4EI
#\\\|FEJJ2DPQ3SCTLCYNJBGT7MRWDVZJEZCMUAURFWOX5CN3HWTINQM \ / AMOS7 \ YOURUM ::
#\[7]YIAACVRPDQAES2FZKNQ76JLHIHVVNDU4LN7KE4BMID3E727UOWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
