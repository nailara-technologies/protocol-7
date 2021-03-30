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

$data{'handle'}{ $_[0]->{'handle'} }{'cmd'}{ $_[0]->{'target_cid'} }
    {'handler'} = $_[0]->{'answer_handler'};
$data{'handle'}{ $_[0]->{'handle'} }{'cmd'}{ $_[0]->{'target_cid'} }{'params'}
    = $_[0]->{'handler_params'};

<[net.out]>->(
    $_[0]->{'handle'},
    '(' . $_[0]->{'target_cid'} . ')' . $_[0]->{'command'} . "\n"
);

# return $command_id;

#.............................................................................
#6A54AI7AZZS73RINZCWKRJHOUIE2ZJNQOSGNHM6P7BG2I7TGKXLW4CM7MLWTNPBGZ3KW6FQALKESC
#::: MWMRYU3AL47ULCZKSTCSJYHJCE3BDXWOWSIT3YRG5YI3EDDDV6D :::: NAILARA AMOS :::
# :: F2RYRQB235C64M4BO7F6CEWAYGW26CAOLN6KBCWHGQWRUSE2Y2CI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
