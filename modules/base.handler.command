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

if ( exists $data{'session'}{'ignore_bytes'} ) {    # ..dropped RAW replies..
    if ( my $ignore_bytes = $data{'session'}{'ignore_bytes'} ) {
        <[base.log]>->( 1, "[$id] dropping $ignore_bytes [ignore]bytes.." );
        if ( length($$input) >= $ignore_bytes ) {
            substr( $$input, 0, $ignore_bytes, '' );
            delete $data{'session'}{'ignore_bytes'};
        } else {
            $data{'session'}{'ignore_bytes'} -= length($$input);
            truncate( $$input, 0 );
        }
    } else {
        delete $data{'session'}{'ignore_bytes'};
    }
}

# stop handler to modify buffer without calling the handler

$_[0]->w->stop;

# cancel ondemand timeout (reinstalled in idle watcher)
if ( exists <base.timer.ondemand_timeout> ) {
    <base.timer.ondemand_timeout>->cancel;
    delete <base.timer.ondemand_timeout>;
}

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
        $cmd_id = '' if $cmd_id =~ /^\(0+\)$/;

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
                            . "NACK invalid command parameter format\n";  # FIX!
                        $_[0]->w->start;
                        return 1;
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

# protocol error

elsif ( $$input =~ s/^((\($re->{cmd_id}\)|) *[^\n]+)\n//o ) {
    my ( $_cmd_id, $cmd_string ) = ( $2, $1 );
    <[base.log]>->( 1, "[$id] protocol error ['$cmd_string\']" );
    $$output .= $_cmd_id . "NACK protocol error\n";
    $_[0]->w->start;
    return 0;
}

# empty command line

elsif ( $$input =~ s/^$//o ) { $_[0]->w->start; return 0 }

# incomplete command line

else { $_[0]->w->start; return 1 }

# won't modify buffer again

$_[0]->w->start;

# extract command id

if ( $cmd =~ s/^\(($re->{cmd_id})\) *//o ) { $cmd_id = $1 }

$$call_args{'command_id'} = $cmd_id;
$$call_args{'session_id'} = $id;

# 'reroute' replacement regex

if ( defined <core.reroute> ) {
    if (    defined <core.reroute.pattern.match>
        and defined <core.reroute.pattern.replace>
        and uc($cmd) ne $cmd ) {
        my $rre_pattern_match   = <core.reroute.pattern.match>;
        my $rre_pattern_replace = <core.reroute.pattern.replace>;
        my $rre_pattern_usr
            = defined <core.reroute.pattern.usr>
            ? <core.reroute.pattern.usr>
            : '';

        my $rre_m = qr/$rre_pattern_match/;
        my $rre_u = qr/$rre_pattern_usr/;
        $cmd =~ s|$rre_m|$rre_pattern_replace| if $usr =~ $rre_pattern_usr;
    }
    $cmd = <core.reroute.command>->{$cmd}
        if defined <core.reroute.command>
        and exists <core.reroute.command>->{$cmd};
}

# alias check and replacement

my $alias_to;

# global alias
$alias_to = $data{'alias'}{$cmd}
    if exists $data{'alias'} and exists $data{'alias'}{$cmd};

# per user alias
$alias_to = $data{'user'}{$usr}{'alias'}{$cmd}
    if exists $data{'user'}{$usr}{'alias'}
    and exists $data{'user'}{$usr}{'alias'}{$cmd};
my $cmd_orig  = $cmd;
my $args_orig = $$call_args{'args'};
if ( defined $alias_to and length($alias_to) ) {
    $$call_args{'cmd'}{'unalias'} = $cmd;
    $cmd = $alias_to;
    my $args_map = {
        'SOURCE_AGENT' => <system.node.name> . '.' . $usr,
        'SOURCE_SID'   => $id
    };
    map { $cmd =~ s/$_/$args_map->{$_}/g } keys %{$args_map};

    if ( $cmd =~ s/^([^ ]+) +([^\n]+)$/$1/ ) {
        if ( defined $$call_args{'args'} ) {
            $$call_args{'args'} = join( ' ', $2, $$call_args{'args'} );
        } else {
            $$call_args{'args'} = $2;
        }
    }
}

my $_cmd_id = '';
if ( $cmd_id > 0 ) { $_cmd_id = '(' . $cmd_id . ')' }

# check reply types
my $valid_answer = 0;

my ( $_m1, $_m2 );
my $cmd_usr_str = $cmd; # used for access checking (relevant with <sid>.<cmd>'s)
$cmd_usr_str = $data{'session'}{$_m1}{'user'} . $_m2
    if $cmd =~ /^($re->{sid})(\..+)$/
    and $_m1 = $1
    and $_m2 = $2
    and exists $data{'session'}{$_m1}
    and $data{'session'}{$_m1}{'user'} =~ /^$re->{usr}$/;

if ( $cmd =~ /^(N?ACK|WAIT|RAW|GET|STRM|SHUTDOWN)$/ ) {

    if ( defined $data{'session'}{$id}{'route'}{$cmd_id} ) {

        my $route = $data{'route'}{ $data{'session'}{$id}{'route'}{$cmd_id} };
        if ( exists $$route{'target'}{'sid'}
            and $$route{'target'}{'sid'} == $id ) {

            my $s_cmd_id = '';
            if ( $$route{'source'}{'cmd_id'} > 0 ) {
                $s_cmd_id = '(' . $$route{'source'}{'cmd_id'} . ')';
            }

            if ( $cmd =~ /^(N?ACK)$|^WAIT$|^SHUTDOWN$/ ) {

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
                            0,
                            "[$id] called undefined reply handler ("
                                . $$route{'reply'}{'handler'} . ")"
                        );
                    }
                } else {

                    # route reply
                    $$call_args{'args'} //= '[no reply data]';
                    $data{'session'}{ $$route{'source'}{'sid'} }{'buffer'}
                        {'output'}
                        .= $s_cmd_id . $cmd . ' ' . $$call_args{'args'} . "\n";

                }

                # delete route

                if ( $cmd ne 'WAIT' ) {
                    delete $data{'session'}{ $$route{'source'}{'sid'} }
                        {'route'}{ $$route{'source'}{'cmd_id'} };
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

                        my $raw_data = substr( $$input, 0, $msg_len, '' );

                        # check if reply handler is set

                        if ( defined $$route{'reply'}{'handler'}
                            and $$route{'reply'}{'handler'} ne '' ) {
                            if (    defined $code{ $$route{'reply'}{'handler'} }
                                and
                                defined &{ $code{ $$route{'reply'}{'handler'} }
                                } ) {

                                # call reply handler

                                &{ $code{ $$route{'reply'}{'handler'} } }(
                                    {   'sid'       => $id,
                                        'cmd'       => $cmd,
                                        'call_args' => $call_args,
                                        'params' => $$route{'reply'}{'params'},
                                        'data'   => $raw_data
                                    }
                                );

                            } else {
                                <[base.log]>->(
                                    0,
                                    "[$id] called undefined reply handler ("
                                        . $$route{'reply'}{'handler'} . ")"
                                );
                            }
                        } else {

                            # send raw command to target

                            $data{'session'}{ $$route{'source'}{'sid'} }
                                {'buffer'}{'output'}
                                .= $s_cmd_id
                                . $cmd . ' '
                                . $$call_args{'args'} . "\n"
                                . $raw_data;
                        }

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
        <[base.log]>->( 1, "[$id] $cmd-reply to unknown route id, ignored." );
        if (    $cmd eq 'RAW'
            and $call_args->{'args'} =~ /^\d+$/
            and my $ignore_bytes = $call_args->{'args'} ) {
            if ( length($$input) >= $ignore_bytes ) {
                substr( $$input, 0, $ignore_bytes, '' );
                <[base.log]>->(
                    1,
                    "[$id] : dropped next $ignore_bytes bytes too.. (RAW body)"
                );
            } else {
                <[base.log]>->(
                    1,
                    "[$id] : ignoring next $ignore_bytes bytes as well.. (RAW)"
                );
                $data{'session'}{'ignore_bytes'} -= length($$input);
                truncate( $$input, 0 );
            }
        }
        return 1;
    }

} elsif ( $cmd eq uc($cmd) ) {
    <[base.log]>->( 1, "[$id] invalid reply type '$cmd'!" );
    $$output .= $_cmd_id . "NACK invalid reply type! (protocol error)\n";
} elsif ( exists <access.cmd.regex.usr>->{$usr}
    and $cmd_usr_str =~ <access.cmd.regex.usr>->{$usr}
    or exists <access.cmd.regex.usr>->{'*'}
    and $cmd_usr_str =~ <access.cmd.regex.usr>->{'*'} ) {

    # local command

    if ( $cmd =~ /^$re->{cmd}$/ ) {

        if ( defined $data{'base'}{'cmd'}{$cmd} ) {
            if ( exists $code{ $data{'base'}{'cmd'}{$cmd} }
                and defined &{ $code{ $data{'base'}{'cmd'}{$cmd} } } ) {

                # prepare reply id (used in mode 'later')

                <base.cmd_reply> //= {};
                my $reply_id = <[base.gen_id]>->(<base.cmd_reply>);
                <base.cmd_reply>->{$reply_id} = {
                    'cmd'        => $cmd,
                    'cmd_id'     => $cmd_id,
                    'output_fh'  => $output,
                    'session_id' => $id
                };
                $call_args->{'reply_id'} = $reply_id;

                # call command handler

                my $reply
                    = &{ $code{ $data{'base'}{'cmd'}{$cmd} } }($call_args);

                # replying later...

                if ( ref($reply) eq 'HASH' and $$reply{'mode'} eq 'later' ) {

                    <[base.log]>->(
                        2, "setting up async reply for reply-id $reply_id"
                    );

                    # XXX: set up reply timeout?
                    return 0;
                }
                delete <base.cmd_reply>->{$reply_id};

                # reply error check

                if ( ref($reply) ne 'HASH' ) {
                    $reply          = {};
                    $$reply{'mode'} = 'nack';
                    $$reply{'data'} = 'internal error (details in log!)';
                    <[base.log]>->(
                        0,
                        'base.handler.command: $reply is not a hash reference!'
                    );
                } elsif (
                    $$reply{'mode'} ne 'raw'
                    and ( not defined $$reply{'data'}
                        or !length( $$reply{'data'} ) )
                    ) {
                    <[base.log]>->(
                        0,
                        "[$id] empty "
                            . uc( $$reply{'mode'} )
                            . '-reply attempted! (base.handler.command)'
                    );
                    $$reply{'mode'} = 'nack';
                    $$reply{'data'} = 'internal error (details in log!)';
                }

                # check answer mode

                if ( $$reply{'mode'} =~ /^N?ACK$|^WAIT$/io ) {
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

        $$output .= "NACK not implemented yet..\n";
        return 1;

        if ( exists $data{'user'}{$1}{'session'}
            and $data{'user'}{$1}{'mode'} eq 'link' ) {

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
        } elsif ( exists $data{'user'}{$target_name}{'session'} ) {
            foreach my $target_sid (
                keys( %{ $data{'user'}{$target_name}{'session'} } ) ) {
                next if $data{'session'}{$target_sid}{'mode'} ne 'client';
                push( @send_sids, $target_sid );
            }
        } elsif ( my $v_id
            = <[base.agents.ondemand_registered]>->($target_name) ) {
            my $target_user    = 'root';
            my $target_command = <agents.virtual>->{$v_id}->{'target_command'};
            if ( defined $target_command
                and $target_command =~ /^([^\.]+)\.[^\.]+$/ ) {
                $target_user = $1;
            } elsif ( defined $target_command ) {
                undef $target_user;
            }

            # XXX: deal with multi line commands... (command_mode 2)

            if ( not defined $target_user
                or exists $data{'user'}{$target_user}{'session'} ) {
                $target_command //= 'root.start';

                # ...

                push(
                    @{ <agents.virtual>->{$v_id}->{'queue'} },
                    {   'source_id' => $id,
                        'cmd_id'    => $_cmd_id,
                        'cmd_str'   => $command_str,
                        'cmd_args'  => $args_orig
                    }
                );

                if ( not exists <agents.virtual>->{$v_id}->{'starting'} ) {
                    <agents.virtual>->{$v_id}->{'starting'} = 1;
                    <[base.log]>->(
                        1, "ondemand agent '$target_name' requested ..."
                    );
                    <[base.proto.nailara.command.send.local]>->(
                        {   'command'   => $target_command,
                            'call_args' => {
                                'args' => <agents.virtual>->{$v_id}->{'name'}
                            },
                            'reply' => {
                                'handler' => 'base.handler.ondemand_startup',
                                'params'  => { 'v_id' => $v_id }
                            }
                        }
                    );
                }
                return 0;
            } else {
                <[base.log]>->( 1, ": target user '$target_user' not found!" );
            }
        }

        if ( !@send_sids ) {
            $$output .= $_cmd_id . "NACK unknown command\n";
            <[base.log]>->(
                2,
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

            if (   <system.verbosity> >= 2
                or <system.internal_verbosity> >= 2 ) {
                <[base.log]>->(
                    2,
                    "[$id] $data{'session'}{$id}{'user'}"
                        . " -> $target_name > $cmd [ mode $command_mode ]"
                );
            }
            if (   <system.verbosity> >= 3 and defined $$call_args{'args'}
                or <system.internal_verbosity> >= 3
                and defined $$call_args{'args'} ) {
                ( my $args_str = $$call_args{'args'} ) =~ s|"|\"|g;
                <[base.log]>->( 3, "[$id] : args ( \"$args_str\" )" );
            }

            $target_cmd_id =~ s/^($re->{cmd_id})$/($1)/;

            if ( $command_mode == 1 )    # single line command mode
            {
                my $args = '';
                local $$call_args{'args'} = ''
                    if not defined $$call_args{'args'};

                $data{'session'}{$target_sid}{'buffer'}{'output'}
                    .= $target_cmd_id . $cmd . ' ' . $$call_args{'args'} . "\n";

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
    } else {    # invalid command syntax
        $$output .= $_cmd_id . "NACK protocol error\n";
        <[base.log]>->( 1, "[$id] protocol error ['$cmd']" );
        return 1;
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

