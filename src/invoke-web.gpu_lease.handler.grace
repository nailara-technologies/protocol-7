## [:< ##

# name  = invoke-web.gpu_lease.handler.grace
# descr = empty or hand-paused queue grace expired : release the gpu lease

my $event      = shift;
my $user_pause = ( $event->w->data // {} )->{'user_pause'} // FALSE;
delete <invoke-web.gpu_lease.grace_timer>;
delete <invoke-web.gpu_lease.grace_user_pause>;
return <[invoke-web.gpu_lease.unload]>->( '', qw| release |, $user_pause )
    if not $user_pause;

return TRUE if ( <invoke-web.gpu_lease.holder> // '' ) ne qw| invoke-web |;
return TRUE if <invoke-web.gpu_lease.auto_paused>;
return TRUE
    if defined <invoke-web.gpu_lease.processor_paused>
    and not <invoke-web.gpu_lease.processor_paused>;

my $recheck = not defined <invoke-web.gpu_lease.processor_paused>;
if ( not $recheck ) {
    my $dbh = <[invoke-web.queue.db]>;
    if ( not defined $dbh ) {
        $recheck = TRUE;
    } else {
        my ( $in_progress, $pending ) = $dbh->selectrow_array(
            "SELECT SUM( status = 'in_progress' ), SUM( status "
                . "= 'pending' AND priority > ? ) FROM session_queue",
            undef,
            -( <invoke-web.session.park_offset> // 1000000 ) / 2
        );
        $recheck = TRUE
            if not defined $in_progress
            or not defined $pending
            or $in_progress;
    }
}

if ($recheck) {
    <invoke-web.gpu_lease.grace_user_pause> = TRUE;
    <invoke-web.gpu_lease.grace_timer>      = <[event.add_timer]>->(
        {   'after'   => 2,
            'handler' => qw| invoke-web.gpu_lease.handler.grace |,
            'data'    => { 'user_pause' => TRUE },
        }
    );
    return TRUE;
}

return <[invoke-web.gpu_lease.unload]>->( '', qw| release |, $user_pause );

#,,.,,,.,,.,.,.,.,,,,,...,,..,,,,,.,,,..,,,.,,..,,...,..,,,..,,.,,,..,.,.,,,,,
#ARAMXSOAYQPQJHNOF2GXX6I47XLIEN675Q4NCBD5FV6A3YSYNCC4P2X7NLZ6SOGLNL32G5WF6DYRC
#\\\|3WS4L4PPWX556PTBB7ZYAKL4OZ3JCC7PRGSE4LBG73YGZKQMSKD \ / AMOS7 \ YOURUM ::
#\[7]ZTU2V6DJGTFBZWUVIGRXRMGS3RLQEZU4NUX4TDJDLINRQUNLLKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
