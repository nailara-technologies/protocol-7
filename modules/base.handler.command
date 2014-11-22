# >:]

# name    = base.handler.command
# descr   = handle commands and call their handlers
# comment = currently nailara protocol specific -> move to proto.nailara
#           and replace with a generic version ..
#           needs rewrite

my $id = $_[0]->w->data;

my $usr = $data{'session'}{$id}{'user'};

my $cmd    = '';
my $cmd_id = 0;

my $input  = \$data{'session'}{$id}{'buffer'}{'input'};
my $output = \$data{'session'}{$id}{'buffer'}{'output'};

# stop handler to modify buffer without calling the handler

$_[0]->w->stop;

# cleanup command line

$$input =~ s/^[\s|\t|\n]+//o;

my @args;
my $command_mode = 0;
my $call_args    = {};

# check for multiple line commands

if ( $$input =~ m/^((\(\d+\)|)[\(\d+\)]?[\w\.]+)\+\n(.*\n)*\.\n/o ) {
    $cmd = $1;
    if ( $$input =~ s/^(\(\d+\)|)[\w\.]+\+\n//o ) {

        # read argument header

        $cmd_id  = $1 if length($1);
        my $_cmd_id = '';
        if ( $cmd_id > 0 ) { $_cmd_id = '(' . $cmd_id . ')' }

        my $header = 1;

        while ( $$input =~ s/^(.*)\n// ) {

            my $arg = $1 || '';

            if ( $arg ne '.' ) {

                # ".\n" as 'end of parameters' terminator

                if ( $header and $arg ne '' ) {

                    if ( $arg =~ /^([\w|\.]+)[\s|\t]*[=:][\s|\t]*(.*)$/o ) {
                        my ( $key, $val ) = ( $1, $2 );

                        $$call_args{'param'}{$key} = $val;

                    }

                    # protocol error

                    else {
                        $code{'base.log'}->( 1,
                            "[$id] invalid command parameter format" );
                        $$output .=
                          $_cmd_id . "NACK invalid command parameter format\n";

                        $_[0]->w->start;

                        return 0;
                    }
                }
                elsif ( $header == 1 ) { $header = 0 }
                else { $$call_args{'data'} .= $arg . "\n" }

            }
            else { last }
        }
        $command_mode = 2;
    }
}

# incomplete multiple line command

elsif ( $$input =~ /^((\(\d+\)|)\s*[\w\.]+)\+\n/o ) {
    $_[0]->w->start;
    return 1;
}

# single command line

elsif ( $$input =~ s/^((\(\d+\)|)\s*[\w\.]+)(\s+(.+)|)\n//o ) {

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

if ( $cmd =~ s/^\((\d+)\)\s*//o ) { $cmd_id = $1 }

$$call_args{'command_id'} = $cmd_id;
$$call_args{'session_id'} = $id;

# alias check and replacement

if ( defined $data{'alias'}{$cmd} and $data{'alias'}{$cmd} ne '' ) {
    $$call_args{'cmd'}{'unalias'} = $cmd;
    $cmd = $data{'alias'}{$cmd};
    my $args_map = {
	'SOURCE_AGENT' => <system.node.name>.'.'.$data{'session'}{$id}{'user'}
    };
    foreach my $map_key (keys %{$args_map}){
        $cmd =~ s/$map_key/$args_map->{$map_key}/;
    }
    if($cmd =~ s/^(\S+)\s+(.+)$/$1/) {
        $$call_args{'args'} = $2 . ' ' . $$call_args{'args'};
    }
}

my $_cmd_id = '';
if ( $cmd_id > 0 ) { $_cmd_id = '(' . $cmd_id . ')' }

# check reply types

my $valid_answer = 0;

if ( $cmd =~ /^N?ACK$|^WAIT$|^RAW$|^GET$|^STRM$/ ) {

    if ( defined $data{'session'}{$id}{'route'}{$cmd_id} ) {

        my $route = $data{'route'}{ $data{'session'}{$id}{'route'}{$cmd_id} };

        if ( $$route{'target'}{'sid'} == $id ) {

            my $s_cmd_id = '';
            if ( $$route{'source'}{'cmd_id'} > 0 ) {
                $s_cmd_id = '(' . $$route{'source'}{'cmd_id'} . ')';
            }

            if ( $cmd =~ /^(N?ACK)$|^WAIT$/ ) {

                # check if reply handler is set

                if ( defined $$route{'reply'}{'handler'}
                    and $$route{'reply'}{'handler'} ne '' )
                {
                    if (    defined $code{ $$route{'reply'}{'handler'} }
                        and defined &{ $code{ $$route{'reply'}{'handler'} } } )
                    {

                        # call reply handler

                        &{ $code{ $$route{'reply'}{'handler'} } }(
                            {
                                'sid'       => $id,
                                'cmd'       => $cmd,
                                'call_args' => $call_args,
                                'params'    => $$route{'reply'}{'params'}
                            }
                        );

                    }
                    else {
                        $code{'base.log'}->(
                            1,
                            "[$id] called undefined reply handler ("
                              . $$route{'reply'}{'handler'} . ")"
                        );
                    }
                }
                else {

                    # route reply

                    $data{'session'}{ $$route{'source'}{'sid'} }{'buffer'}
                      {'output'} .=
                      $s_cmd_id . $cmd . ' ' . $$call_args{'args'} . "\n";

                }

                # delete route

                if ( $cmd ne 'WAIT' ) {
                    delete $data{'session'}{ $$route{'source'}{'sid'} }{'route'}
                      { $$route{'source'}{'cmd_id'} };
                    delete $data{'route'}
                      { $data{'session'}{$id}{'route'}{$cmd_id} };
                    delete $data{'session'}{$id}{'route'}{$cmd_id};
                }
                else {

                    # insert WAIT limit here

                    $$route{'counter'}{'wait'}++;
                }

                $valid_answer = 1;
            }
            elsif ( $cmd =~ /^RAW$/ ) {
                if ( $$call_args{'args'} =~ /^\d+$/ ) {
                    my $msg_len = $$call_args{'args'};

                    if ( length($$input) >= $msg_len ) {

                        # cut out body data

                        my $data = substr( $$input, 0, $msg_len );
                        my $rest = length($$input) - $msg_len;
                        $$input = substr( $$input, $msg_len, $rest );

                        # send raw command to target

                        $data{'session'}{ $$route{'source'}{'sid'} }{'buffer'}
                          {'output'} .=
                            $s_cmd_id . $cmd . ' '
                          . $$call_args{'args'} . "\n"
                          . $data;

                        # delete route

                        delete $data{'session'}{ $$route{'source'}{'sid'} }
                          {'route'}{ $$route{'source'}{'cmd_id'} };
                        delete $data{'route'}
                          { $data{'session'}{$id}{'route'}{$cmd_id} };
                        delete $data{'session'}{$id}{'route'}{$cmd_id};

                        $valid_answer = 1;
                    }
                    else {
                        $code{'base.log'}->(
                            1,
                            "[$id] (RAW) invalid body length ("
                              . $$call_args{'args'} . " : "
                              . length($$input) . ")"
                        );
                    }
                }
            }
            else {
                $code{'base.log'}->( 1,
                    "[$id] called unimplemented answer type ($cmd)" );
                $$output .= "[$cmd] answer type not implemented yet.\n";
                return 1;
            }
        }
    }
    else {
        $code{'base.log'}->( 1,
            "[$id] reply to unknown route id, ignored." );
        return 1;
    }

}
elsif ( defined $data{'access'}{'cmd'}{'regex'}{'usr'}{$usr}
    and $cmd =~ $data{'access'}{'cmd'}{'regex'}{'usr'}{$usr}
    or defined $data{'access'}{'cmd'}{'regex'}{'usr'}{'*'}
    and $cmd =~ $data{'access'}{'cmd'}{'regex'}{'usr'}{'*'} )
{

    # local command

    if ( $cmd =~ /^[^\.]+$/o ) {
        if ( defined $data{'base'}{'cmd'}{$cmd} ) {
            if (    defined $code{ $data{'base'}{'cmd'}{$cmd} }
                and defined &{ $code{ $data{'base'}{'cmd'}{$cmd} } } )
            {

                # call command handler

                my $reply =
                  &{ $code{ $data{'base'}{'cmd'}{$cmd} } }($call_args);

                # check answer mode

                if ( ref($reply) ne 'HASH' ) {
                    $reply          = {};
                    $$reply{'mode'} = 'nack';
                    $$reply{'data'} = 'system error';
                }
                elsif ( $$reply{'mode'} =~ /^N?ACK$|^WAIT$/io ) {
                    $$reply{'data'} =~ s/\n/\\n/go;
                    $$output .= $_cmd_id
                      . uc( $$reply{'mode'} ) . ' '
                      . $$reply{'data'} . "\n";
                }
                elsif ( $$reply{'mode'} =~ /RAW/i ) {
                    my $len = length( $$reply{'data'} );
                    $$output .=
                      $_cmd_id . 'RAW ' . $len . "\n" . $$reply{'data'};

                }

                return 0;
            }
            else {
                $code{'base.log'}->( 1,
                    "[$id] command '$cmd' is configured but not defined!" );
            }
        }
        else {
            $code{'base.log'}->( 1, "[$id] unknown command '$cmd'" );
        }

        $$output .= $_cmd_id . "NACK unknown command\n";

        return 1;
    }

    # tree upwards

    elsif ( $cmd =~ /^\.\.([^\.]+)\.(.+)$/o ) {

        #        not working yet..

        $code{'base.log'}->( 1, "outgoing: nexthop: '$1' command: '$2'" );
        if ( defined $data{'user'}{$1} and $data{'user'}{$1}{'mode'} eq 'link' )
        {

#            $code{'net.send_command'}->( $id, $command_id, $cmd, @params );
        }
        return -1;
    }

    # absolute address notation

    elsif ( $cmd =~ /^\^(\w+)\.([^\.]+)$/o ) {
        my $network_name = $1;
        my $node_name    = $1;

        # ^ uhm, this will take a while (route discovery feature..)

    }
    elsif ( $cmd =~ s/^(\w+)\.([^\.]+)$/$2/go ) {
        my $target_name = $1;
        my @sids;

        if ( $target_name =~ /^(\d+)$/ ) {

            if (    defined $data{'session'}{$1}
                and $data{'session'}{$1}{'mode'} eq 'client'
                and $target_name = $data{'session'}{$1}{'user'} )
            {
                push( @sids, $1 );
            }
        }
        elsif ( defined $data{'user'}{$target_name} ) {
            foreach my $target_sid (
                keys( %{ $data{'user'}{$target_name}{'session'} } ) )
            {
                push( @sids, $target_sid );
            }
        }

        # send to all clients with that username (group mode)

        if ( scalar @sids ) {
            foreach my $target_sid (@sids) {

                # setup route

                my $route = $code{'base.route.add'}->(
                    {
                        'source' => { 'sid' => $id, 'cmd_id' => $cmd_id },
                        'target' => { 'sid' => $target_sid }
                    }
                );

                my $target_cmd_id = $$route{'target'}{'cmd_id'};

                $code{'base.log'}->(
                    2,
                    "[$id] "
                      . $data{'session'}{$id}{'user'}
                      . " -> $target_name > $cmd [ mode $command_mode ]"
                );

                $target_cmd_id =~ s/^(\d+)$/($1)/;

                if ( $command_mode == 1 )    # single line command mode
                {
                    my $args = '';
                    local $$call_args{'args'} = ''
                        if not defined $$call_args{'args'};

                    if ( $$call_args{'args'} ne '' ) { $cmd .= ' ' }

                    $data{'session'}{$target_sid}{'buffer'}{'output'} .=
                      $target_cmd_id . $cmd . $$call_args{'args'} . "\n";

                    # TODO: setup timeout handler

                }
                elsif ( $command_mode == 2 )    # multi line command mode
                {
                    my $header = '';

                    if ( defined $$call_args{'param'}
                        and ref( $$call_args{'param'} ) eq
                        'HASH' )                # prepare parameter header
                    {
                        my ( $key, $val );

                        while ( ( $key, $val ) =
                            each( %{ $$call_args{'param'} } ) )
                        {
                            $header .= $key . '=' . $val . "\n";
                        }
                    }

                    $data{'session'}{$target_sid}{'buffer'}{'output'} .=
                        $target_cmd_id . $cmd . "+\n" . $header . "\n"
                      . $$call_args{'data'} . ".\n";

                }
                else    # should never get here..
                {
                    $code{'base.log'}->( 1, 'unknown command mode' );
                    return 1;
                }
            }

            return 0;
        }
        else {

            $$output .= $_cmd_id . "NACK unknown command\n";

            $code{'base.log'}->( 1,
                "[$id] command '$2' rejected. no '$1' client present!" );

            return 1;
        }

    }

    # unknown command

    $$output .= $_cmd_id . "NACK unknown command\n";

    $code{'base.log'}->( 1,
        "[$id] unknown command. ( usr '$usr', cmd '$cmd' )" );
}
else    # access denied
{
    $$output .= $_cmd_id . "NACK unknown command\n";
    $code{'base.log'}->( 1,
        "[$id] access denied. ( usr '$usr', cmd '$cmd' )" );
}

return 0;

