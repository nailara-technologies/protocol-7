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

#,,,.,...,,.,,,.,,..,,...,,,.,,,.,,..,,.,,,,.,..,,...,...,.,.,,.,,,.,,.,,,.,.,
#SXBINWKIFNTTTQYLZVIGPTEFHMALVVDELZVRZBUZBG3EAHJWNLPHQWX34G6HMGKXKG4XTEG6TAOKE
#\\\|P6VH2YOIAZTNNEOQ42MQP6L2SU454D3OPLGVNPFN4DUAHTRK5Y4 \ / AMOS7 \ YOURUM ::
#\[7]OMWR4BQLCYF6XPQW4L3I3MUGXGCJUGYNXOOS6BF4HOBDZZGWOICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
