# >:]

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
        ;    # -> config
}

$data{'handle'}{ $_[0]->{'handle'} }{'cmd'}{ $_[0]->{'target_cid'} }{'handler'}
    = $_[0]->{'answer_handler'};
$data{'handle'}{ $_[0]->{'handle'} }{'cmd'}{ $_[0]->{'target_cid'} }{'params'}
    = $_[0]->{'handler_params'};

<[net.out]>->(
    $_[0]->{'handle'},
    '(' . $_[0]->{'target_cid'} . ')' . $_[0]->{'command'} . "\n"
);

# return $command_id;

#.............................................................................
#MBVYQODLAG7XMXSX6ZUZMTIQJMN4TL6WH26KD6JI5JRVR325OBPAD2V6GU4RPYFRIAT4KWYJUJR4S
#::: CRI32PNN6WO6K7MPQUYFHW7QY5PIPHIASSJGCWFDLLCGS6IZVMO :::: NAILARA AMOS :::
# :: HWGJNSNA32UIKMIQT3VPK27U7LJN2A4QZNG3VUPPIECCB3JXGIAI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
