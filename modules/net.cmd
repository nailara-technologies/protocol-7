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

#,,,.,,.,,..,,...,.,.,,..,.,,,..,,.,.,.,,,...,..,,...,...,,..,,,,,..,,...,,,.,
#PXWLZXNJ6KCVHPNJK72FU57VMPP3WDZHL7TOOKLH6FHXUK6RDEOGFTEX3WQQDPGK6A4PMA7437XP4
#\\\|NJDBADG4C2CY74W5APHSCZAIVTA73UGBXAPZMFTTXHIMRFLPE6B \ / AMOS7 \ YOURUM ::
#\[7]GHIOISIZWVSLHCJPHKHBHL5KURVBQLLEFGOHQFEUZZONYURUVIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
