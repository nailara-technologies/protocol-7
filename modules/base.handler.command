# >:]

# name    = base.handler.command
# descr   = handle commands and call their handlers
# comment = currently nailara protocol specific -> move to proto.nailara
#           and replace with a generic version ..
#           needs rewrite
# TODO = reduce memory usage during compilation! ( ~ 3MB just for this sub !! )

my $id = $_[0]->w->data;

my $usr = $data{'session'}{$id}{'user'};

my $cmd    = '';
my $cmd_id = 0;

my $input  = \$data{'session'}{$id}{'buffer'}{'input'};
my $output = \$data{'session'}{$id}{'buffer'}{'output'};

# regex cache
my $re = $data{'regex'}{'base'};

# stop handler to modify buffer without calling the handler

$_[0]->w->stop;

# cleanup command line

$$input =~ s/^\s+//;
$$input =~ s/^([^\n]+?)[ \t]+\n/$1\n/;

my @args;
my $command_mode = 0;
my $call_args    = {};

# check cmd_id regex (for numbers or valid length)
if (    $$input =~ m|^\(([^\)]*)\)[^\n]+\n|
    and $$input !~ m|^\(($re->{cmd_id})\)| ) {
    my $cmd_id = $1 || '';
    $$input =~ s|^\([^\)]*\)[^\n]+\n||;
    <[base.log]>->( 1, "[$id] invalid command id ('$cmd_id')" );
    $$output .= "NACK invalid command id syntax or length\n";
    return 1;
}

# check for multiple line commands

if ( $$input
    =~ m/^((\($re->{cmd_id}\)|)[\(\d+\)]?[\w\d\-\_\.]+)\+\n(.*\n)*\.\n/o ) {
    $cmd = $1;
    if ( $$input =~ s/^(\($re->{cmd_id}\)|)[\w\d\-\_\.]+\+\n//o ) {

        # read argument header

        my $_cmd_id = '';
        $cmd_id = $1 if length($1);
        if ( $cmd_id > 0 ) { $_cmd_id = '(' . $cmd_id . ')' }

        my $header = 1;

        while ( $$input =~ s/^(.*)\n// ) {

            my $arg = $1 || '';

            if ( $arg ne '.' ) {

                # ".\n" as 'end of parameters' terminator

                if ( $header and $arg ne '' ) {

                    if ( $arg =~ /^([\w\.]+)[ \t]*[=:][ \t]*(.*)$/o ) {
                        my ( $key, $val ) = ( $1, $2 );

                        $$call_args{'param'}{$key} = $val;

                    }

                    # protocol error

                    else {
                        <[base.log]>->(
                            1, "[$id] invalid command parameter format"
                        );
                        $$output .= $_cmd_id
                            . "NACK invalid command parameter format\n";

                        $_[0]->w->start;

                        return 0;
                    }
                } elsif ( $header == 1 ) {
                    $header = 0;
                } else {
                    $$call_args{'data'} .= $arg . "\n";
                }

            } else {
                last;
            }
        }
        $command_mode = 2;
    }
}

# incomplete multiple line command

elsif ( $$input =~ /^((\($re->{cmd_id}\)|) *[\w\.]+)\+\n/o ) {
    $_[0]->w->start;
    return 1;
}

# incomplete RAW reply   XXX: switch to stream type transfer!!!

elsif ( $$input =~ /^((\($re->{cmd_id}\)|) *RAW +(\d+)\n)/o
    and length($$input) < ( $3 + length($1) ) ) {
    $_[0]->w->start;
    return 1;
}

# single command line

elsif ( $$input =~ s/^((\($re->{cmd_id}\)|) *[\w\d\-\_\.]+)( +(.+)|)\n//o ) {

    $_[0]->w->start;

    ( $cmd, $$call_args{'args'} ) = ( $1, $4 );

    $command_mode = 1;
}

# empty command line

elsif ( $$input =~ s/^[^\n]+\n//o ) { $_[0]->w->start; return 0 }

# incomplete command line

else { $_[0]->w->start; return 1 }

# won't modify buffer again

$_[0]->w->start;

# extract command id

if ( $cmd =~ s/^\(($re->{cmd_id})\) *//o ) { $cmd_id = $1 }

$$call_args{'command_id'} = $cmd_id;
$$call_args{'session_id'} = $id;

# alias check and replacement

my $alias_to;

# global alias
$alias_to = $data{'alias'}{$cmd}
    if exists $data{'alias'} and exists $data{'alias'}{$cmd};

# per user alias
$alias_to = $data{'user'}{$usr}{'alias'}{$cmd}
    if exists $data{'user'}{$usr}{'alias'}
    and exists $data{'user'}{$usr}{'alias'}{$cmd};
if ( defined $alias_to and length($alias_to) ) {
    $$call_args{'cmd'}{'unalias'} = $cmd;
    $cmd = $alias_to;
    my $args_map = { 'SOURCE_AGENT' => <system.node.name> . '.' . $usr };
    map { $cmd =~ s/$_/$args_map->{$_}/g } keys %{$args_map};

    if ( $cmd =~ s/^([^ ]+) +([^\n]+)$/$1/ ) {
        $$call_args{'args'} = join( ' ', $2, $$call_args{'args'} )
            if defined $$call_args{'args'};
    }
}

my $_cmd_id = '';
if ( $cmd_id > 0 ) { $_cmd_id = '(' . $cmd_id . ')' }

# check reply types

my $valid_answer = 0;

if ( $cmd =~ /^N?ACK$|^WAIT$|^RAW$|^GET$|^STRM$/ ) {

    if ( defined $data{'session'}{$id}{'route'}{$cmd_id} ) {

        my $route = $data{'route'}{ $data{'session'}{$id}{'route'}{$cmd_id} };
        if ( exists $$route{'target'}{'sid'}
            and $$route{'target'}{'sid'} == $id ) {

            my $s_cmd_id = '';
            if ( $$route{'source'}{'cmd_id'} > 0 ) {
                $s_cmd_id = '(' . $$route{'source'}{'cmd_id'} . ')';
            }

            if ( $cmd =~ /^(N?ACK)$|^WAIT$/ ) {

                # check if reply handler is set

                if ( defined $$route{'reply'}{'handler'}
                    and $$route{'reply'}{'handler'} ne '' ) {
                    if (    defined $code{ $$route{'reply'}{'handler'} }
                        and defined &{ $code{ $$route{'reply'}{'handler'} } } )
                    {

                        # call reply handler

                        &{ $code{ $$route{'reply'}{'handler'} } }(
                            {   'sid'       => $id,
                                'cmd'       => $cmd,
                                'call_args' => $call_args,
                                'params'    => $$route{'reply'}{'params'}
                            }
                        );

                    } else {
                        <[base.log]>->(
                            1,
                            "[$id] called undefined reply handler ("
                                . $$route{'reply'}{'handler'} . ")"
                        );
                    }
                } else {

                    # route reply

                    $data{'session'}{ $$route{'source'}{'sid'} }{'buffer'}
                        {'output'}
                        .= $s_cmd_id . $cmd . ' ' . $$call_args{'args'} . "\n";

                }

                # delete route

                if ( $cmd ne 'WAIT' ) {
                    delete $data{'session'}{ $$route{'source'}{'sid'} }{'route'}
                        { $$route{'source'}{'cmd_id'} };
                    delete $data{'route'}
                        { $data{'session'}{$id}{'route'}{$cmd_id} };
                    delete $data{'session'}{$id}{'route'}{$cmd_id};
                } else {

                    # insert WAIT limit here

                    $$route{'counter'}{'wait'}++;
                }

                $valid_answer = 1;
            } elsif ( $cmd =~ /^RAW$/ ) {
                if ( $$call_args{'args'} =~ /^\d+$/ ) {
                    my $msg_len = $$call_args{'args'};

                    if ( length($$input) >= $msg_len ) {

                        # cut out body data

                        my $data = substr( $$input, 0, $msg_len );
                        my $rest = length($$input) - $msg_len;
                        $$input = substr( $$input, $msg_len, $rest );

                        # send raw command to target

                        $data{'session'}{ $$route{'source'}{'sid'} }{'buffer'}
                            {'output'}
                            .= $s_cmd_id
                            . $cmd . ' '
                            . $$call_args{'args'} . "\n"
                            . $data;

                        # delete route

                        delete $data{'session'}{ $$route{'source'}{'sid'} }
                            {'route'}{ $$route{'source'}{'cmd_id'} };
                        delete $data{'route'}
                            { $data{'session'}{$id}{'route'}{$cmd_id} };
                        delete $data{'session'}{$id}{'route'}{$cmd_id};

                        $valid_answer = 1;
                    } else {    # should never reach this point
                        <[base.log]>->(
                            1,
                            "[$id] (RAW) buffer is missing data ( $msg_len <= "
                                . $$call_args{'args'} . ")"
                        );
                    }
                }
            } else {
                <[base.log]>->(
                    1, "[$id] called unimplemented answer type ($cmd)"
                );
                $$output .= "[$cmd] answer type not implemented yet.\n";
                return 1;
            }
        }
    } else {
        <[base.log]>->( 1, "[$id] reply to unknown route id, ignored." );
        return 1;
    }

} elsif ( $cmd eq uc($cmd) ) {
    <[base.log]>->( 1, "[$id] invalid reply type '$cmd'!" );
    $$output .= $_cmd_id . "NACK invalid reply type! (protocol error)\n";
} elsif ( exists <access.cmd.regex.usr>->{$usr}
    and $cmd =~ <access.cmd.regex.usr>->{$usr}
    or exists <access.cmd.regex.usr>->{'*'}
    and $cmd =~ <access.cmd.regex.usr>->{'*'} ) {

    # local command

    if ( $cmd =~ /^$re->{cmd}$/ ) {
        if ( defined $data{'base'}{'cmd'}{$cmd} ) {
            if ( exists $code{ $data{'base'}{'cmd'}{$cmd} }
                and defined &{ $code{ $data{'base'}{'cmd'}{$cmd} } } ) {

                # call command handler

                my $reply
                    = &{ $code{ $data{'base'}{'cmd'}{$cmd} } }($call_args);

                # check answer mode

                if ( ref($reply) ne 'HASH' ) {
                    $reply          = {};
                    $$reply{'mode'} = 'nack';
                    $$reply{'data'} = 'system error';
                } elsif ( $$reply{'mode'} =~ /^N?ACK$|^WAIT$/io ) {
                    $$reply{'data'} =~ s/\n/\\n/go;
                    $$output
                        .= $_cmd_id
                        . uc( $$reply{'mode'} ) . ' '
                        . $$reply{'data'} . "\n";
                } elsif ( uc( $$reply{'mode'} ) eq 'RAW' ) {
                    my $len = length( $$reply{'data'} );
                    $$output
                        .= $_cmd_id . 'RAW ' . $len . "\n" . $$reply{'data'};
                } elsif ( uc( $$reply{'mode'} ) eq 'SHUTDOWN' ) {
                    <[base.session.shutdown]>->( $id, $$reply{'data'} );
                }
                return 0;
            } else {
                <[base.log]>->(
                    1, "[$id] command '$cmd' is configured but not defined!"
                );
            }
        } else {
            <[base.log]>->( 1, "[$id] unknown command '$cmd'" );
        }

        $$output .= $_cmd_id . "NACK unknown command\n";

        return 1;
    }

    # tree upwards

    elsif ( $cmd =~ /^\.\.([^\.]+)\.(.+)$/o ) {

        #        not working yet..

        <[base.log]>->( 1, "outgoing: nexthop: '$1' command: '$2'" );
        if ( exists $data{'user'}{$1} and $data{'user'}{$1}{'mode'} eq 'link' )
        {

         #            <[net.send_command]>->( $id, $command_id, $cmd, @params );
        }
        return -1;
    }

    # absolute address notation

    elsif ( $cmd =~ /^\^(\w+)\.([^\.]+)$/o ) { # XXX: regex invalid! (only host)
        my $network_name = $1;
        my $node_name    = $1;

        # ^ uhm, this will take a while (route discovery feature..)

    } elsif (
        $cmd =~ s/^($re->{sid}|$re->{usr})\.
                    ((($re->{sid}|$re->{usr})\.)*
                    $re->{cmd})$/$2/gxo
        ) {
        my $target_name = $1;                  # usr|sid
        my $command_str = $2;                  # [ deeper targets + ] command
        my @send_sids;

        if ( $target_name =~ /^$re->{sid}$/ ) {
            my $target_sid = $target_name;
            if ( exists $data{'session'}{$target_sid}
                and $data{'session'}{$target_sid}{'mode'} eq 'client' ) {
                @send_sids = ($target_sid);
            }
        } elsif ( exists $data{'user'}{$target_name} ) {
            foreach my $target_sid (
                keys( %{ $data{'user'}{$target_name}{'session'} } ) ) {
                next if $data{'session'}{$target_sid}{'mode'} ne 'client';
                push( @send_sids, $target_sid );
            }
        }

        if ( !@send_sids ) {
            $$output .= $_cmd_id . "NACK unknown command\n";
            <[base.log]>->(
                1,
                "[$id] command '$command_str' rejected!"
                    . " (client '$target_name' not found)"
            );
            return 1;
        }

        # send to all clients with that username (group mode)
        my $targets_denied = 0;
        foreach my $target_sid (@send_sids) {

            my $target_session = $data{'session'}{$target_sid};
            if ( $target_session->{'user'} eq '-'
                or exists $target_session->{'authenticated'}
                and $target_session->{'authenticated'} ne 'yes' ) {
                $targets_denied++;
                next;    # skip unauthorized connections
            }

            # setup route

            my $route = <[base.route.add]>->(
                {   'source' => { 'sid' => $id, 'cmd_id' => $cmd_id },
                    'target' => { 'sid' => $target_sid }
                }
            );

            my $target_cmd_id = $$route{'target'}{'cmd_id'};

            <[base.log]>->(
                2,
                "[$id] "
                    . $data{'session'}{$id}{'user'}
                    . " -> $target_name > $cmd [ mode $command_mode ]"
            );

            $target_cmd_id =~ s/^($re->{cmd_id})$/($1)/;

            if ( $command_mode == 1 )    # single line command mode
            {
                my $args = '';
                local $$call_args{'args'} = ''
                    if not defined $$call_args{'args'};

                if ( $$call_args{'args'} ne '' ) { $cmd .= ' ' }

                $data{'session'}{$target_sid}{'buffer'}{'output'}
                    .= $target_cmd_id . $cmd . $$call_args{'args'} . "\n";

                # TODO: setup timeout handler

            } elsif ( $command_mode == 2 )    # multi line command mode
            {
                my $header = '';

                if ( defined $$call_args{'param'}
                    and ref( $$call_args{'param'} ) eq
                    'HASH' )                  # prepare parameter header
                {
                    my ( $key, $val );

                    while ( ( $key, $val ) = each( %{ $$call_args{'param'} } ) )
                    {
                        $header .= $key . '=' . $val . "\n";
                    }
                }

                if ( exists $$call_args{'data'}
                    and defined $$call_args{'data'} ) {
                    $data{'session'}{$target_sid}{'buffer'}{'output'}
                        .= $target_cmd_id
                        . $cmd . "+\n"
                        . $header . "\n"
                        . $$call_args{'data'} . ".\n";
                } else {    # no request body present
                    $data{'session'}{$target_sid}{'buffer'}{'output'}
                        .= $target_cmd_id . $cmd . "+\n" . $header . ".\n";
                }

            } else    # should never get here..
            {
                <[base.log]>->( 1, 'unknown command mode' );
                return 1;
            }
        }

        if ( $targets_denied == @send_sids ) {    # nothing send
            $$output .= $_cmd_id . "NACK unknown command\n";
            <[base.log]>->(
                1,
                "[$id] access denied! ( usr:'$usr' cmd:'$target_name.$cmd' )"
            );
            return 1;
        }

        # at least one target was valid
        return 0;
    }

    # unknown command
    $$output .= $_cmd_id . "NACK unknown command\n";
    <[base.log]>->( 1, "[$id] unknown command. ( usr:'$usr' cmd:'$cmd' )" );
} else    # access denied
{
    $$output .= $_cmd_id . "NACK unknown command\n";
    <[base.log]>->( 1, "[$id] access denied! ( usr:'$usr' cmd:'$cmd' )" );
    return 1;
}

return 0;

