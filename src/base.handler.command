# >:]

# name    = base.handler.command
# descr   = handling of protocol-7 syntax, calling command handlers
# comment = protocol-7 specific --> move to 'protocol.protocol-7' namespace and
#                                              replace with a generic version..,
#                                                            [ needs rewrite. ]
# [LLL] : reduce memory usage during compilation [ ..3MB for this subroutine., ]

my $id = $_[0]->w->data;

##[ INIT \ VARIABLES ]##########################################################

my $user = $data{'session'}{$id}{'user'};

my $re = <regex.base>;    # <-- regex cache

my $protocol_messages = <protocol.protocol-7.messages>;

my $uninitialized      = $protocol_messages->{'uninitialized'};
my $protocol_error     = $protocol_messages->{'protocol_error_message'};
my $unkown_command     = $protocol_messages->{'command_unknown'};
my $permission_message = $protocol_messages->{'permission_message'};

my $input  = \$data{'session'}{$id}{'buffer'}{'input'};
my $output = \$data{'session'}{$id}{'buffer'}{'output'};

my $cmd    = '';
my $cmd_id = 0;

##[ DROP \ DATA REPLIES ]#######################################################

if ( exists $data{'session'}{'ignore_bytes'} ) {    # ..dropped DATA replies.,
    if ( my $ignore_bytes = $data{'session'}{'ignore_bytes'} ) {
        <[base.log]>->( 1, "[$id] dropping $ignore_bytes [ignore-]bytes.," );
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

##[ STOP WATCHER TO MODIFY INPUT BUFFER ]#######################################

# stop handler to modify buffer without calling the handler

$_[0]->w->stop;

##[ STOP TIMER \ ONDEMAND TIMEOUT ]#############################################

# cancel ondemand timeout [ reinstalled in idle watcher ]
if ( exists <base.timer.ondemand_timeout> ) {
    <base.timer.ondemand_timeout>->cancel;
    delete <base.timer.ondemand_timeout>;
}

##[ CLEAN-UP ]##################################################################

### cleaning up command line ###

$$input =~ s|^\s+||;
$$input =~ s|^([^\n]+?)[ \t]+\n|$1\n|;

##[ SET-UP \ VARIABLES ]########################################################

my @args;
my $command_mode = 0;
my $call_args    = {};

##[ SYNTAX CHECK \ CMD-ID ]#####################################################

# check cmd_id regex [ for numbers or valid length ]
if (    $$input =~ m|^\(([^\)]*)\)[^\n]+\n|
    and $$input !~ m|^\(($re->{cmd_id})\)| ) {
    my $cmd_id = $1 // '';
    $$input =~ s|^(\([^\)]*\)[^\n]+)\n||;
    <[base.log]>->( 1, "[$id] invalid command id ['$cmd_id']" );
    $$output .= "NAK invalid command id syntax or length\n";
    return 0;    ## comand complete ##
}

##[ MULTI-LINE ]################################################################

## checking for multi-line commands ###

if ( $$input =~ s,^(((\($re->{cmd_id}\)|)$re->{cmdp})\+\n([^\n]*\n)*\.\n),,o ) {
    ( my $multiline_cmd, $cmd ) = ( $1, $2 );
    if ( $multiline_cmd =~ s,^(\($re->{cmd_id}\)|)$re->{cmdp}\+\n,,o ) {

        # cube agent 'select' command [ base path prefix handling ]
        $cmd = join( '.', $data{'session'}{$id}{'base_path'}, $cmd )
            if defined $data{'session'}{$id}{'base_path'};

        ## read argument header ##

        my $_cmd_id = '';
        $cmd_id = $1 if length($1);
        $cmd_id = '' if $cmd_id =~ m|^\(0+\)$|;

        my $header = 1;

        while ( $multiline_cmd =~ s|^([^\n]*)\n|| ) {

            my $arg = $1 // '';

            if ( $arg ne '.' ) {

                ## '.\n' as 'end of parameters' terminator ##

                if ( $header and $arg ne '' ) {

                    if ( $arg =~ m|^([\w\.]+)[ \t]*[=:][ \t]*(.*)$| ) {
                        my ( $key, $val ) = ( $1, $2 );

                        $$call_args{'param'}{$key} = $val;

                    }

                    ### protocol error ###

                    else {
                        <[base.log]>->(
                            1, "[$id] invalid command parameter format"
                        );
                        $$output
                            .= $_cmd_id
                            . "NAK [multi-line] command parameter"
                            . " syntax not valid\n";    ## <-- [re]define. [LLL]

                        $_[0]->w->start;
                        return 0;                       ## command complete ##
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

##[ RETURN \ INCOMPLETE MULTI-LINE ]############################################

## incomplete multiple line command ##

elsif ( $$input =~ m,^((\($re->{cmd_id}\)|) *$re->{cmdrp})\+\n,o ) {

    $_[0]->w->start;
    return 1;    ## command not complete ###
}

##[ RETURN \ INCOMPLETE DATA ]##################################################

## incomplete DATA reply ## [LLL] switch to stream type transfer ..,

elsif ( $$input =~ m,^((\($re->{cmd_id}\)|) *DATA +(\d+)\n),o
    and length($$input) < ( $3 + length($1) ) ) {

    $_[0]->w->start;
    return 1;    ## command not complete ###
}

##[ SINGLE LINE ]###############################################################

### single command line ###

elsif ( $$input =~ s,^((\($re->{cmd_id}\)|) *$re->{cmdrp}\/?)( +(.+)|)\n,,o ) {

    $_[0]->w->start;

    ( $cmd, $$call_args{'args'} ) = ( $1, $4 );

    # cube agent 'select' command [ base path prefix handling ]
    $cmd = 'unselect' if $cmd eq '../';    # 'unselect' alias "../" <!>
    $cmd = join( '.', $data{'session'}{$id}{'base_path'}, $cmd )
        if defined $data{'session'}{$id}{'base_path'}
        and $cmd !~ m,^(\($re->{cmd_id}\)|) *(unselect|basepath)$,
        and $cmd !~ s,^(\($re->{cmd_id}\) *| *)\.\.($re->{cmdrp}|),$1$2,;

    #       ^ commands prefixed with '..' mean "parent" to 'select'ed base_path!
    #         'unselect' and '../' are synonyms, they reset the base_path to ''!

    $command_mode = 1;
}

##[ REPLY TO PROTOCOL ERRORS ]##################################################

## protocol error ##

elsif ( $$input =~ s,^((\($re->{cmd_id}\)|) *[^\n]+)\n,,o ) {
    my ( $_cmd_id, $cmd_string ) = ( $2, $1 );
    <[base.log]>->( 0, "[$id] protocol mismatch ['$cmd_string\']" );
    $$output .= $_cmd_id . "NAK $protocol_error\n";
    $_[0]->w->start;
    return 0;    ## command complete ##
}

##[ RETURN \ EMPTY COMMAND LINE ]###############################################

# empty command line

elsif ( $$input =~ s|^$|| ) { $_[0]->w->start; return 0 }

##[ RETURN \ COMMAND NOT COMPLETE ]#############################################

# incomplete command line

else { $_[0]->w->start; return 1 }    ## command not complete ###

# won't modify buffer again

$_[0]->w->start;

##[ PROCESS \ COMMAND \ EXTRACT ID ]############################################

# extract command id

if ( $cmd =~ s|^\(($re->{cmd_id})\) *||o ) { $cmd_id = $1 }

$$call_args{'command_id'} = $cmd_id;
$$call_args{'session_id'} = $id;

##[ REROUTE ]###################################################################

# 'reroute' replacement regex

if ( defined <cube.reroute> ) {
    if (    defined <cube.reroute.pattern.match>
        and defined <cube.reroute.pattern.replace>
        and uc($cmd) ne $cmd ) {
        my $rre_pattern_match   = <cube.reroute.pattern.match>;
        my $rre_pattern_replace = <cube.reroute.pattern.replace>;
        my $rre_pattern_usr
            = defined <cube.reroute.pattern.usr>
            ? <cube.reroute.pattern.usr>
            : '';

        my $rre_m = qr|$rre_pattern_match|;
        my $rre_u = qr|$rre_pattern_usr|;
        $cmd =~ s|$rre_m|$rre_pattern_replace| if $user =~ $rre_pattern_usr;
    }
    $cmd = <cube.reroute.command>->{$cmd}
        if defined <cube.reroute.command>
        and exists <cube.reroute.command>->{$cmd};
}

##[ ALIASES ]###################################################################

# alias check and replacement

my $alias_to;

##[ ALIASES \ GLOBAL ]##########################################################

# global alias
$alias_to = $data{'alias'}{$cmd}
    if exists $data{'alias'} and exists $data{'alias'}{$cmd};

##[ ALIASES \ USERNAME ]########################################################

# per user alias
$alias_to = $data{'user'}{$user}{'alias'}{$cmd}
    if exists $data{'user'}{$user}{'alias'}
    and exists $data{'user'}{$user}{'alias'}{$cmd};
my $cmd_orig  = $cmd;
my $args_orig = $$call_args{'args'};

##[ PROCESS \ ALIASES ]#########################################################

if ( defined $alias_to and length($alias_to) ) {
    $$call_args{'cmd'}{'unalias'} = $cmd;
    $cmd = $alias_to;
    my $args_map = {
        'SOURCE_AGENT' => <system.node.name> . '.' . $user,
        'SOURCE_SID'   => $id
    };
    map { $cmd =~ s|$ARG|$args_map->{$ARG}|g } keys %{$args_map};

    if ( $cmd =~ s|^([^ ]+) +([^\n]+)$|$1| ) {
        if ( defined $$call_args{'args'} ) {
            $$call_args{'args'} = join( ' ', $2, $$call_args{'args'} );
        } else {
            $$call_args{'args'} = $2;
        }
    }
}

##[ PREPARE REPLY \ HAS REPLY ID ]##############################################

my $_cmd_id = '';
if ( $cmd_id > 0 ) { $_cmd_id = '(' . $cmd_id . ')' }

##[ COMMAND REPLIES ]###########################################################

# check reply types
my $valid_answer = 0;

my ( $_m1, $_m2 );
my $cmd_usr_str = $cmd; # used for access checking [ relevant with <sid>.<cmd> ]
$cmd_usr_str = $data{'session'}{$_m1}{'user'} . $_m2
    if $cmd =~ m|^($re->{sid_str})(\..+)$|
    and $_m1 = $1
    and $_m2 = $2
    and exists $data{'session'}{$_m1}
    and $data{'session'}{$_m1}{'user'} =~ $re->{usr};

##[ COMMAND REPLY \ MATCH TYPE ]################################################

if ( $cmd =~ m,^(ACK|NAK|WAIT|DATA|STRM|GET|TERM)$, ) {

    if ( exists $data{'session'}{$id}
        and defined $data{'session'}{$id}{'route'}{$cmd_id} ) {

        my $route = $data{'route'}{ $data{'session'}{$id}{'route'}{$cmd_id} };
        if ( exists $$route{'target'}{'sid'}
            and $$route{'target'}{'sid'} == $id ) {

            my $s_cmd_id = '';
            if ( $$route{'source'}{'cmd_id'} > 0 ) {
                $s_cmd_id = '(' . $$route{'source'}{'cmd_id'} . ')';
            }

            if ( $cmd =~ m,^(ACK|NAK|WAIT|GET|TERM)$, ) {

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
                            "[$id] called undefined reply handler ["
                                . $$route{'reply'}{'handler'} . "]"
                        );
                    }
                } elsif ( defined $data{'session'}{ $$route{'source'}{'sid'} } )
                {
                    my $source_sid = $$route{'source'}{'sid'};
                    ##  calling reply handler if a filter hook was applied., ###
                    $route->{'hook_data'}->{'handler'}->(
                        {   'mode' => $cmd,
                            'args' => \$$call_args{'args'},
                            'data' => $route->{'hook_data'}->{'data'}
                        }
                        )
                        if defined $route->{'hook_data'}
                        and $cmd =~ $route->{'hook_data'}->{'mode'};

                    # route reply
                    $$call_args{'args'} //= 'UNDEFINED';
                    $data{'session'}{$source_sid}{'buffer'}{'output'}
                        .= $s_cmd_id . $cmd . ' ' . $$call_args{'args'} . "\n";

                } else {    # should never come here [ SID gone. ]
                    <[base.log]>->(
                        0,
                        sprintf(
                            '{%s} unknown session, dropped reply.. [%d bytes]',
                            $$route{'source'}{'sid'},
                            length("$s_cmd_id$cmd $$call_args{args}\n")
                        )
                    );
                }

                ### deleting route ###
                if ( $cmd ne 'WAIT' ) {
                    my $src_sid    = $$route{'source'}{'sid'};
                    my $src_cmd_id = $$route{'source'}{'cmd_id'};
                    delete $data{'session'}{$src_sid}{'route'}{$src_cmd_id};
                    delete $data{'route'}
                        { $data{'session'}{$id}{'route'}{$cmd_id} }
                        if defined $data{'session'}{$id}{'route'}{$cmd_id};
                    delete $data{'session'}{$src_sid}{'route'}
                        if !keys %{ $data{'session'}{$src_sid}{'route'} };
                    delete $data{'session'}{$id}{'route'}{$cmd_id};
                    delete $data{'session'}{$id}{'route'}
                        if !keys %{ $data{'session'}{$id}{'route'} };
                } else {

                    # insert WAIT limit here

                    $$route{'counter'}{'wait'}++;
                }

                $valid_answer = 1;

##[ PROCESS REPLY \ DATA ]######################################################

            } elsif ( $cmd eq 'DATA' ) {
                if ( $$call_args{'args'} =~ m|^\d+$| ) {
                    my $msg_len = $$call_args{'args'};

                    if ( length($$input) >= $msg_len ) {

                        ## cut out body data ##

                        my $data_reply = substr( $$input, 0, $msg_len, '' );

                        ## check if reply handler is set ##

                        if ( defined $$route{'reply'}{'handler'}
                            and $$route{'reply'}{'handler'} ne '' ) {
                            if (    defined $code{ $$route{'reply'}{'handler'} }
                                and
                                defined &{ $code{ $$route{'reply'}{'handler'} }
                                } ) {

                                ## calling reply handler ##

                                &{ $code{ $$route{'reply'}{'handler'} } }(
                                    {   'sid'       => $id,
                                        'cmd'       => $cmd,
                                        'call_args' => $call_args,
                                        'params' => $$route{'reply'}{'params'},
                                        'data'   => $data_reply
                                    }
                                );

                            } else {
                                <[base.log]>->(
                                    0,
                                    "[$id] called undefined reply handler ['"
                                        . $$route{'reply'}{'handler'} . "']"
                                );
                            }
                        } else {

                            ## sending DATA reply to target ##

                            $data{'session'}{ $$route{'source'}{'sid'} }
                                {'buffer'}{'output'}
                                .= $s_cmd_id
                                . $cmd . ' '
                                . $$call_args{'args'} . "\n"
                                . $data_reply;
                        }

                        # delete route
                        my $src_sid    = $$route{'source'}{'sid'};
                        my $src_cmd_id = $$route{'source'}{'cmd_id'};
                        delete $data{'session'}{$src_sid}{'route'}{$src_cmd_id};
                        delete $data{'route'}
                            { $data{'session'}{$id}{'route'}{$cmd_id} }
                            if defined $data{'session'}{$id}{'route'}{$cmd_id};
                        delete $data{'session'}{$src_sid}{'route'}
                            if !keys %{ $data{'session'}{$src_sid}{'route'} };
                        delete $data{'session'}{$id}{'route'}{$cmd_id};
                        delete $data{'session'}{$id}{'route'}
                            if !keys %{ $data{'session'}{$id}{'route'} };

                        $valid_answer = 1;
                    } else {    # should never reach this point
                        <[base.log]>->(
                            1,
                            "[$id] [DATA] buffer is missing data [ $msg_len <= "
                                . $$call_args{'args'} . "]"
                        );
                    }
                }

##[ PROCESS REPLY \ STRM ]######################################################

            } elsif ( $cmd eq 'STRM' ) {
                ####
                if ( $$call_args{'args'} =~ m|^open( (\d+))?$| ) {
                    my $open_size = $2 || 0;

                    warn "[ STRM REPLY ] open size : $open_size";

                } elsif ( $$call_args{'args'} =~ m|^\d+$| ) {
                    my $msg_len = $$call_args{'args'};
                    if ( length($$input) >= $msg_len ) {

                        ## cut out body data ##
                        my $data_reply = substr( $$input, 0, $msg_len, '' );
                    }
                }
                ####
            } else {
                <[base.log]>->(
                    1, "[$id] called unimplemented answer type ['$cmd']"
                );
                $$output .= "[$cmd] answer type not implemented yet.\n";
                return 0;    ## command complete ##
            }
        }

##[ PROCESS REPLY \ UNKNOWN ROUTE ID ]##########################################

    } else {
        my $ignore_log_level = 1;
        $ignore_log_level = 2
            if exists <net.silent_ignore>->{$user}
            and <net.silent_ignore>->{$user} == 1
            or exists $data{'session'}{$id}{'silent_ignore'}
            and $data{'session'}{$id}{'silent_ignore'} == 1;
        <[base.log]>->(
            $ignore_log_level, "[$id] $cmd-reply to unknown route id, ignored."
        );

        if (    $cmd eq 'DATA'
            and $call_args->{'args'} =~ m|^\d+$|
            and my $ignore_bytes = $call_args->{'args'} ) {
            if ( length($$input) >= $ignore_bytes ) {
                substr( $$input, 0, $ignore_bytes, '' );
                <[base.log]>->(
                    $ignore_log_level,
                    "[$id] : dropped next $ignore_bytes bytes too.. [DATA body]"
                );
                return 0;    ## command complete ###

            } else {
                <[base.log]>->(
                    $ignore_log_level,
                    "[$id] : ignoring next $ignore_bytes bytes as well., [DATA]"
                );
                $data{'session'}{'ignore_bytes'} -= length($$input);
                truncate( $$input, 0 );
            }
        }
        return 1;    ## command not complete ###
    }

##[ PROCESS REPLY \ UNKNOWN TYPE ]##############################################

} elsif ( $cmd eq uc($cmd) ) {
    <[base.log]>->( 1, "[$id] invalid reply type '$cmd'" );
    $$output .= $_cmd_id . "NAK protocol mismatch [ invalid reply type ]\n";

##[ PROCESSING \ LOCAL COMMAND ]################################################

} elsif ( <[base.has_access]>->( $user, $cmd_usr_str ) ) {

    ### local command ###

    if ( $cmd =~ $re->{'cmd'} ) {

        if ( defined $data{'base'}{'cmd'}{$cmd} ) {
            if (    defined $code{ $data{'base'}{'cmd'}{$cmd} }
                and defined &{ $code{ $data{'base'}{'cmd'}{$cmd} } } ) {

##[ LOCAL COMMAND \ PREPARING DEFERRED ]########################################

                ## prepare reply id [ used in 'deferred' mode ] ##

                <base.cmd_reply> //= {};
                my $reply_id
                    = <[base.gen_id]>->( <base.cmd_reply>, undef, undef, 0 );
                <base.cmd_reply>->{$reply_id} = {
                    'cmd'        => $cmd,
                    'cmd_id'     => $cmd_id,
                    'output_fh'  => $output,
                    'session_id' => $id
                };
                $call_args->{'reply_id'} = $reply_id;

##[ LOCAL COMMAND \ CALLING HANDLER ]###########################################

                ## calling command handler ##
                my $reply;
                {
                    local $EVAL_ERROR = undef;
                    $reply = eval { $code{ <base.cmd>->{$cmd} }->($call_args) };
                    if ( my $err_str = $EVAL_ERROR ) {
                        $err_str =~ s| at (\S+) line (\d+).*\n$||;
                        my $file = $1;
                        my $line = $2;
                        $file =~ s|^/usr/share/perl5/||; ## shorten path for .pm
                        my $log_error = 1;
                        ## alternative handler registered for filename:line ? ##
                        my $match_param = "$file:$line";  #  <-- expand. [ LLL ]
                        my $warn_handlers = <base.warn-match-handler> // {};
                        if ( defined $warn_handlers->{$match_param} ) {
                            my $cb_name = $warn_handlers->{$match_param};
                            $log_error
                                = $code{$cb_name}
                                ->( $err_str, $match_param, $call_args )
                                if defined $code{$cb_name};
                        }
                        ##
                        if ($log_error) {
                            <[base.log]>->(
                                0, "[$id] <<< $err_str >>> [ $file, $line ]"
                            );
                            my $params = $call_args->{'args'} // '';
                            my $msg    = "[$id]  \\\\\\ <$cmd>";
                            $msg .= " [ '$params' ]" if length($params);
                            <[base.log]>->( 0, $msg );
                        }
                    }
                }

##[ LOCAL COMMAND \ DEFERRED ]##################################################

                ### deferred reply., ###

                if ( ref($reply) eq 'HASH' and $$reply{'mode'} eq 'deferred' ) {

                    <[base.log]>->( 2, "setting up reply for id $reply_id" );

                    # [LLL] set up reply timeout .,
                    return 0;    ## command complete ##
                }
                delete <base.cmd_reply>->{$reply_id};

##[ LOCAL COMMAND \ REPLY ERROR CHECK ]#########################################

                ## reply error check ##

                if ( ref($reply) ne 'HASH' ) {    # <-- catches undef
                    $reply          = {};
                    $$reply{'mode'} = 'nak';
                    $$reply{'data'} = 'error during command invocation'
                        . ' [ details are logged ]';
                    <[base.log]>->(
                        0, "[$id] cmd ['$cmd'] <-- [ hashref expected ]"
                    );
                } elsif (
                    $$reply{'mode'} ne 'data'
                    and ( not defined $$reply{'data'}
                        or !length( $$reply{'data'} ) )
                ) {
                    ( undef, my $file, my $line ) = ( caller(0) );
                    my $source_str
                        = $file eq 'base.handler.input'
                        ? "'$cmd'"
                        : "$file:$line";
                    <[base.log]>->(
                        0,
                        "[$id] empty "
                            . uc( $$reply{'mode'} )
                            . "-reply attempted [$source_str]"
                    );
                    $$reply{'mode'} = 'nak';
                    $$reply{'data'} = 'error during command invocation'
                        . ' [ details are logged ]';
                }

##[ LOCAL COMMAND \ CHECK ANSWER MODE ]#########################################

                ## check answer mode ##

                if ( $$reply{'mode'} =~ m,^(ACK|NAK|WAIT)$,io ) {
                    $$reply{'data'} =~ s|\n|\\n|go;
                    $$output
                        .= $_cmd_id
                        . uc( $$reply{'mode'} ) . ' '
                        . $$reply{'data'} . "\n";
                } elsif ( uc( $$reply{'mode'} ) eq 'DATA' ) {
                    my $len = length( $$reply{'data'} );
                    $$output
                        .= $_cmd_id . 'DATA ' . $len . "\n" . $$reply{'data'};
                } elsif ( uc( $$reply{'mode'} ) eq 'TERM' ) {
                    <[base.session.shutdown]>->( $id, $$reply{'data'} );
                }
                return 0;    ## command complete ##

##[ LOCAL COMMAND \ HANDLER NOT DEFINED ########################################

            } else {
                <[base.log]>->(
                    1, "[$id] command '$cmd' configured but not defined"
                );
            }

##[ LOCAL COMMAND \ UNKNOWN COMMAND ]###########################################

        } else {
            <[base.log]>->( 1, "[$id] command unknown '$cmd'" );
        }

        $$output .= $_cmd_id . "NAK $unkown_command\n";

        return 0;    ## command complete ##
    }

##[ PARENT BRANCH \ EXTERNAL CORE ]#############################################

    ## tree upwards., ##

    elsif ( $cmd =~ m|^\.\.([^\.]+)\.(.+)$| ) {

        #        not working yet..,

        <[base.log]>->( 1, "outgoing: nexthop: '$1' command: '$2'" );

        $$output .= "NAK not implemented yet.,\n";
        return 0;    ## command complete ##

        if ( exists $data{'user'}{$1}{'session'}
            and $data{'user'}{$1}{'mode'} eq 'link' ) {

         #            <[net.send_command]>->( $id, $command_id, $cmd, @params );
        }
        return 0;    ## command complete ##
    }

##[ ABSOLUTE PATH ROUTING ]#####################################################

    ## absolute address notation ##

    elsif ( $cmd =~ m|^\^(\w+)\.([^\.]+)$| ) { # LLL: regex invalid: <only host>
        my $network_name = $1;
        my $node_name    = $1;

        # ^ not yet implemented [ route discovery feature.., ]

##[ PROCESS \ PREPARE TARGET SIDS ]#############################################

    } elsif (
        $cmd =~ s,^($re->{sid_str}|$re->{usr_str}|$re->{usr_subn_str})\.
                    ((($re->{sid_str}|$re->{usr_str}|$re->{usr_subn_str})\.)*
                    $re->{cmd_str})$,$2,gxo
    ) {
        my $target_name = $1;    # usr|sid
        my $command_str = $2;    # [ deeper targets + ] command
        my $target_subname
            = $target_name =~ s|\[($re->{subname})\]$|| ? $1 : undef;

        my @send_sids;

        if ( $target_name =~ $re->{sid} ) {    ## <session_id>.<command> mode
            my $target_sid = $target_name;
            if ( exists $data{'session'}{$target_sid}
                and $data{'session'}{$target_sid}{'mode'} eq 'client' ) {
                @send_sids = ($target_sid);
            }
        } elsif (
            exists $data{'user'}{$target_name}{'session'}
            and ( not defined $target_subname
                or
                defined $data{'user'}{$target_name}{'subname'}{$target_subname}
            )
            ) {                                ## [ online \ present ]
            foreach my $target_sid (
                keys( %{ $data{'user'}{$target_name}{'session'} } ) ) {
                next if $data{'session'}{$target_sid}{'mode'} ne 'client';

                #### 'target[subname]' syntax:
                next
                    if defined $target_subname
                    and ( not defined $data{'session'}{$target_sid}{'subname'}
                    or $data{'session'}{$target_sid}{'subname'} ne
                    $target_subname );

                push( @send_sids, $target_sid );
            }

##[ ONDEMAND AGENTS ]###########################################################

        } elsif ( my $v_id
            = <[base.agents.ondemand_registered]>->($target_name) ) { # ondemand
            my $target_user    = 'nroot';
            my $target_command = <agents.virtual>->{$v_id}->{'target_command'};
            if ( defined $target_command
                and $target_command =~ m|^([^\.]+)\.[^\.]+$| ) {
                $target_user = $1;
            } elsif ( defined $target_command ) {
                undef $target_user;
            }

            # [LLL] ..deal with multi-line commands.., [ command_mode 2 ]

            if ( not defined $target_user
                or exists $data{'user'}{$target_user}{'session'} ) {
                $target_command //= 'nroot.start_once';

                # ..,

                push(
                    @{ <agents.virtual>->{$v_id}->{'queue'} },
                    {   'source_id'   => $id,
                        'cmd_id'      => $_cmd_id,
                        'cmd_subname' => $target_subname,
                        'cmd_str'     => $command_str,
                        'cmd_args'    => $args_orig
                    }
                );

                if ( not exists <agents.virtual>->{$v_id}->{'starting'} ) {
                    <agents.virtual>->{$v_id}->{'starting'} = 1;

                    my $start_name = <agents.virtual>->{$v_id}->{'name'};

                    # [LLL] subname behaviour needs refinement \ configuration.,
                    $start_name .= "[$target_subname]"
                        if defined $target_subname;

                    <[base.log]>->(
                        1, "ondemand agent '$start_name' requested ..,"
                    );
                    <[base.protocol-7.command.send.local]>->(
                        {   'command'   => $target_command,
                            'call_args' => { 'args' => $start_name },
                            'reply'     => {
                                'handler' => 'base.handler.ondemand_startup',
                                'params'  => { 'v_id' => $v_id }
                            }
                        }
                    );
                }
                return 0;    ## command complete ##
            } else {
                <[base.log]>->( 1, ": target user '$target_user' not found" );
            }
        }

##[ NAK REPLY \ CLIENT NOT PRESENT ]############################################

        if ( !@send_sids ) {
            $$output .= $_cmd_id . "NAK $unkown_command\n";
            my $l_lvl = $target_name eq 'p7-log' ? 2 : 1;
            <[base.log]>->(
                $l_lvl, "[$id] offline : '$target_name' : '$command_str'"
            );
            return 0;    ## command complete ###
        }

##[ CHECK INITIALIZED ]#########################################################

        my @send_sids_left;
        foreach my $target_sid (@send_sids) { # check if session initialized yet
            if (
                (   not defined <system.agent.mode>
                    or <system.agent.mode> ne 'cube'
                )
                or $user eq 'nroot'  # [LLL] improve check if really nroot agent
                or ( $data{'session'}{$target_sid}{'initialized'} // 0 )
            ) {
                push( @send_sids_left, $target_sid );
                next;
            }

            # if 'agent'-mode session and not initialized allowing replies only.
            $$output .= $_cmd_id . "NAK $uninitialized\n";
            <[base.log]>->(
                0,
                "[$id] unroutable command \"$command_str\" "
                    . "[ $target_name session $target_sid not initialized yet ]"
            );
        }

##[ RETURN \ CHECK NONE LEFT ]##################################################

        return 0 if @send_sids_left == 0;    ##  <--  all done.,  ###
        @send_sids = @send_sids_left if @send_sids_left != @send_sids;

##[ PROCESS \ FILTER HOOKS ]####################################################

        # command [argument] filter hooks  ..,
        my $cmd_hook_data = <[base.handler.cmd_filter_hooks]>->(
            {   'sid'      => $id,
                'target'   => $target_name,
                'command'  => $cmd,
                'args_ref' => \$$call_args{'args'}
            }
        );

##[ PROCESS \ GROUP MODE ]######################################################

        # send to all clients with that username [ group mode ]
        my $targets_denied = 0;
        foreach my $target_sid (@send_sids) {

            my $target_session = $data{'session'}{$target_sid};
            if (   $target_session->{'user'} eq <base.session.uname.server>
                or $target_session->{'user'} eq <base.session.uname.client>
                or defined $target_session->{'authenticated'}
                and $target_session->{'authenticated'} ne 'yes' ) {
                $targets_denied++;
                next;    # skip unauthorized connections
            }

##[ SET UP ROUTE ]##############################################################

            ## setting up route ##

            my $route = <[base.route.add]>->(
                {   'source' => { 'sid' => $id, 'cmd_id' => $cmd_id },
                    'target' => { 'sid' => $target_sid }
                }
            );

            $route->{'hook_data'} = $cmd_hook_data if defined $cmd_hook_data;

            my $target_cmd_id = $$route{'target'}{'cmd_id'};

##[ LOGGING ]###################################################################

            if (   <system.verbosity.console> >= 2
                or <system.verbosity.agent_buffer> >= 2 ) {
                <[base.log]>->(
                    2,
                    "[$id] $data{'session'}{$id}{'user'}"
                        . " ..:. $target_name ..:. $cmd [M=$command_mode]"
                    )
                    if ( $target_name ne 'p7-log'
                    or $cmd ne 'append'
                    or !<debug.skip_log_msg> )
                    and ( $cmd ne 'p7-log.append'
                    or !<debug.skip_log_msg> )
                    and ( $user ne 'nroot'
                    or $cmd ne 'heart'
                    or !<debug.skip_nroot_heartbeat> );
            }

##[ LOGGING \ DEBUG MODE ]######################################################

            if ( <system.verbosity.console> >= 3 and defined $$call_args{'args'}
                or <system.verbosity.agent_buffer> >= 3
                and defined $$call_args{'args'} ) {
                ( my $args_str = $$call_args{'args'} ) =~ s|"|\"|g;
                <[base.log]>->( 3, "[$id] : args [' $args_str ']" );
            }

            $target_cmd_id =~ s|^($re->{cmd_id})$|($1)|;

##[ PROCESS \ SINGLE LINE ]#####################################################

            if ( $command_mode == 1 )    ## single line command mode ##
            {
                my $args = '';
                local $$call_args{'args'} = ''
                    if not defined $$call_args{'args'};

                $data{'session'}{$target_sid}{'buffer'}{'output'}
                    .= $target_cmd_id . $cmd . ' ' . $$call_args{'args'} . "\n";

                # [LLL] set up timeout handler

##[ PROCESS \ MULTI-LINE ]######################################################

            } elsif ( $command_mode == 2 )    ## multi line command mode ##
            {
                my $header = '';

                if ( defined $$call_args{'param'}
                    and ref( $$call_args{'param'} ) eq
                    'HASH' )    ## preparing parameter header ##
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
            }
        }

##[ PROCESS \ NOTHING SENT ]####################################################

        ## nothing was sent ##
        if ( $targets_denied == @send_sids ) {
            $$output .= $_cmd_id . "NAK $permission_message\n";
            <[base.log]>->(
                0,
                "[$id] blocked access [ usr:'$user' cmd:'$target_name.$cmd' ]"
            );
            return 0;    ## command complete ##
        }

        ## at least one target was valid ##

        return 0;        ## command complete ##

##[ PROCESS \ SYNTAX NOT VALID ]################################################

    } else {    ## command syntax not valid ##
        $$output .= $_cmd_id . "NAK $protocol_error\n";
        <[base.log]>->( 1, "[$id] protocol mismatch ['$cmd']" );
        return 0;    ## command complete ##
    }

##[ PROCESS \ COMMAND UNKNOWN ]#################################################

    ## command unknown ##
    $$output .= $_cmd_id . "NAK $unkown_command\n";
    <[base.log]>->( 1, "[$id] command unknown [ usr:'$user' cmd:'$cmd' ]" );
} else {    ## insufficient access permissions ##
    $$output .= $_cmd_id . "NAK $permission_message\n";
    <[base.log]>->( 0, "[$id] blocked access [ usr:'$user' cmd:'$cmd' ]" );
    return 0;    ## command complete ##
}

##[ RETURN \ PROCESSING COMPLETE ]##############################################

return 0;        ## command complete ##

# ______________________________________________________________________________
#\\YKBNOKBVKQJEHHPLJD6FCEFE65OBAIJIBN5DEA2PGCG7F2QVTUKG7LG3R4XMAUMM7TEUYUNVAER46
# \\ AIGFXMZ2JQTG2W5VIXKYQ7CV7WSWUIMOSZWRFOIGPZOWWPRGK5BF \\// C25519-BASE-32 //
#  \\// 5S63ES7OHJ3EM5O4P6UN7VCJHDMECWC6254HIHE23MGPSOYLGDY \\ CODE SIGNATURE \\
#   ````````````````````````````````````````````````````````````````````````````
