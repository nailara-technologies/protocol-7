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

#,,,.,,,.,,,.,.,,,,,,,,..,.,,,,,,,,..,..,,,..,..,,...,...,,,,,,..,.,.,,..,,.,,
#X7FA4SCPQE2QDKIHJVOHLSE6AOICX3PVLJ4BI7IHNDQ6IS2OMQOI4MSYLSEKI2G4BGCK5QLK44EGC
#\\\|SNKTNSNLBSUIAPMDH22YSKDLVT6GOZ34CJBXSGOYIY4XYJFT2J7 \ / AMOS7 \ YOURUM ::
#\[7]TZ6Q7FNQT6SBKI2BPHW7BM6UCNG2FFYU6EET2XV5PCYRS32DQMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
