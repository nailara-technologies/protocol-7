## >:] ##

# name    = base.handler.command
# descr   = handling of protocol-7 syntax, calling command handlers
#
# comment = protocol-7 specific --> move to protocol.protocol-7 namespace and
#                                            replace with a generic version..,
#                                                           [ needs rewrite. ]
# [LLL] : reduce memory usage during compilation [ ..3MB for this subroutine ]

my $id = $_[0]->w->data;

##[ INIT \ VARIABLES ]##########################################################

my $user = $data{'session'}{$id}{'user'};

my $re = <regex.base>;    # <-- regex cache

my $input  = \$data{'session'}{$id}{'buffer'}{'input'};
my $output = \$data{'session'}{$id}{'buffer'}{'output'};

my $cmd    = '';
my $cmd_id = 0;

##[ DROP \ SIZE REPLIES ]#####################################################

if ( exists $data{'session'}{'ignore_bytes'} ) {    # ..dropped SIZE replies.,
    if ( my $ignore_bytes = $data{'session'}{'ignore_bytes'} ) {
        <[base.log]>->( 1, "[$id] dropping $ignore_bytes [ignore-]bytes.," );
        if ( length( $input->$* ) >= $ignore_bytes ) {
            substr( $input->$*, 0, $ignore_bytes, '' );
            delete $data{'session'}{'ignore_bytes'};
        } else {
            $data{'session'}{'ignore_bytes'} -= length( $input->$* );
            truncate( $input->$*, 0 );
        }
    } else {
        delete $data{'session'}{'ignore_bytes'};
    }
}

##[ STOP WATCHER TO MODIFY INPUT BUFFER ]#####################################

# stop handler to modify buffer without calling the handler

$_[0]->w->stop;

##[ STOP TIMER \ ONDEMAND TIMEOUT ]###########################################

# cancel ondemand timeout [ reinstalled in idle watcher ]
if ( exists <base.timer.ondemand_timeout> ) {
    <base.timer.ondemand_timeout>->cancel;
    delete <base.timer.ondemand_timeout>;
}

##[ CLEAN-UP CMD LINE ]#######################################################

### cleaning up command line ###

$input->$* =~ s|^\s+||;
$input->$* =~ s|^([^\n]+?)[ \t]+\n|$1\n|;

##[ SET-UP \ VARIABLES ]######################################################

my @args;
my $command_mode = 0;
my $call_args    = {};

##[ CHECK SYNTAX \ CMD-ID ]###################################################

# check cmd_id regex [ for numbers or valid length ]
if (    $input->$* =~ m|^\(([^\)]*)\)[^\n]+\n|
    and $input->$* !~ m|^\(($re->{cmd_id})\)| ) {
    my $cmd_id = $1 // '';
    $input->$* =~ s|^(\([^\)]*\)[^\n]+)\n||;
    <[base.log]>->( 1, "[$id] invalid command id ['$cmd_id']" );
    $output->$* .= "FALSE invalid command id syntax or length\n";
    return 0;    ## comand complete ##
}

##  calculate and store average command line length  ##

<[base.session.calc_cmd_stats]>->( $id, $input );   ## updates for protocol ##

##[ MULTI-LINE ]##############################################################

## checking for multi-line commands ###

if ( $input->$*
    =~ s,^(((\($re->{cmd_id}\)|)$re->{cmdp})\+\n([^\n]*\n)*\.\n),,o ) {
    ( my $multiline_cmd, $cmd ) = ( $1, $2 );
    if ( $multiline_cmd =~ s,^(\($re->{cmd_id}\)|)$re->{cmdp}\+\n,,o ) {

        # cube zenka 'select' command [ base path prefix handling ]
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
                        $output->$*
                            .= $_cmd_id
                            . "FALSE [multi-line] command parameter"
                            . " syntax not valid\n";  ## <-- [re]define. [LLL]

                        $_[0]->w->start;
                        return 0;    ##  command processing was complete  ##
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

##[ RETURN \ INCOMPLETE MULTI-LINE ]##########################################

## incomplete multiple line command ##

elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *$re->{cmdrp})\+\n,o ) {

    $_[0]->w->start;
    return 1;    ## command not complete ###
}

##[ RETURN \ INCOMPLETE 'SIZE' REPLY ]########################################

## incomplete SIZE reply ## [LLL] switch to stream type transfer ..,

elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *SIZE +(\d+)\n),o
    and length( $input->$* ) < ( $3 + length($1) ) ) {

    $_[0]->w->start;
    return 1;    ## command not complete ###
}

##[ SINGLE LINE CMD ]#########################################################

### single command line ###

elsif (
    $input->$* =~ s,^((\($re->{cmd_id}\)|) *$re->{cmdrp}\/?)( +(.+)|)\n,,o ) {

    $_[0]->w->start;

    ( $cmd, $$call_args{'args'} ) = ( $1, $4 );

    # cube zenka 'select' command [ base path prefix handling ]
    $cmd = qw| unselect | if $cmd eq qw| ../ |;    ## 'unselect'-alias '../'
    $cmd = join( qw| . |, $data{'session'}{$id}{'base_path'}, $cmd )
        if defined $data{'session'}{$id}{'base_path'}
        and $cmd !~ m,^(\($re->{cmd_id}\)|) *(unselect|basepath)$,
        and $cmd !~ s,^(\($re->{cmd_id}\) *| *)\.\.($re->{cmdrp}|),$1$2,;

  #       ^ commands prefixed with '..' mean "parent" to 'select'ed base_path!
  #         'unselect' and '../' are synonyms, they reset the base_path to ''!

    $command_mode = 1;
}

##[ REPLY TO PROTOCOL ERRORS ]################################################

## protocol error ##

elsif ( $input->$* =~ s,^((\($re->{cmd_id}\)|) *[^\n]+)\n,,o ) {
    my ( $_cmd_id, $cmd_string ) = ( $2, $1 );

    <[base.logt]>->( qw| HTKSXIY |, $id, $cmd_string );  # protocol mismatch #

    $output->$* .= <[base.sprint_t]>->( qw| PQKWOXQ |, $_cmd_id );

    $_[0]->w->start;
    return 0;    ##  command processing was complete  ##
}

##[ RETURN \ EMPTY COMMAND LINE ]#############################################

# empty command line

elsif ( $input->$* =~ s|^$|| ) { $_[0]->w->start; return 0 }

##[ RETURN \ COMMAND NOT COMPLETE ]###########################################

# incomplete command line

else { $_[0]->w->start; return 1 }    ## command not complete ###

# not going to modify buffer again

$_[0]->w->start;

##[ PROCESS COMMAND \ EXTRACT ID ]############################################

# extract command id

if ( $cmd =~ s|^\(($re->{cmd_id})\) *||o ) { $cmd_id = $1 }

$$call_args{'command_id'} = $cmd_id;
$$call_args{'session_id'} = $id;

##[ REROUTE ]#################################################################

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

##[ COMMAND ALIASES ]#########################################################

# alias check and replacement

my $alias_to;

##[ ALIASES \ GLOBAL ]########################################################

# global alias
$alias_to = $data{'alias'}{$cmd}
    if exists $data{'alias'} and exists $data{'alias'}{$cmd};

##[ ALIASES \ USERNAME ]######################################################

# per user alias
$alias_to = $data{'user'}{$user}{'alias'}{$cmd}
    if exists $data{'user'}{$user}{'alias'}
    and exists $data{'user'}{$user}{'alias'}{$cmd};
my $cmd_orig  = $cmd;
my $args_orig = $$call_args{'args'};

##[ PROCESS \ ALIASES ]#######################################################

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
            $$call_args{'args'} = ${^CAPTURE}[1];
        }
    }
}

##[ PREPARE REPLY \ HAS REPLY ID ]############################################

my $_cmd_id = '';
if ( $cmd_id > 0 ) { $_cmd_id = '(' . $cmd_id . ')' }

##[ COMMAND REPLIES ]#########################################################

# check reply types
my $valid_answer = 0;

my ( $_m1, $_m2 );
my $cmd_usr_str
    = $cmd;    # used for access checking [ relevant with <sid>.<cmd> ]
$cmd_usr_str = $data{'session'}{$_m1}{'user'} . $_m2
    if $cmd =~ m|^($re->{sid_str})(\..+)$|
    and $_m1 = ${^CAPTURE}[0]
    and $_m2 = ${^CAPTURE}[1]
    and exists $data{'session'}{$_m1}
    and $data{'session'}{$_m1}{'user'} =~ $re->{usr};

##[ COMMAND REPLY \ MATCH TYPE ]##############################################

if ( $cmd =~ m,^(TRUE|FALSE|WAIT|SIZE|STRM|GET|TERM)$, ) {

    if ( exists $data{'session'}{$id}
        and defined $data{'session'}{$id}{'route'}{$cmd_id} ) {

        my $route = $data{'route'}{ $data{'session'}{$id}{'route'}{$cmd_id} };
        if ( exists $$route{'target'}{'sid'}
            and $$route{'target'}{'sid'} == $id ) {

            my $s_cmd_id = '';
            if ( $$route{'source'}{'cmd_id'} > 0 ) {
                $s_cmd_id = '(' . $$route{'source'}{'cmd_id'} . ')';
            }

            if ( $cmd =~ m,^(TRUE|FALSE|WAIT|GET|TERM)$, ) {

                # check if reply handler is set

                if ( defined $$route{'reply'}{'handler'}
                    and $$route{'reply'}{'handler'} ne '' ) {
                    if (    defined $code{ $$route{'reply'}{'handler'} }
                        and defined &{ $code{ $$route{'reply'}{'handler'} } }
                    ) {

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
                } elsif (
                    defined $data{'session'}{ $$route{'source'}{'sid'} } ) {
                    my $source_sid = $$route{'source'}{'sid'};
                    ## calling reply handler if a filter hook was applied., ##
                    $route->{'hook_data'}->{'handler'}->(
                        {   'mode' => $cmd,
                            'args' => \$$call_args{'args'},
                            'data' => $route->{'hook_data'}->{'data'}
                        }
                        )
                        if defined $route->{'hook_data'}
                        and $cmd =~ $route->{'hook_data'}->{'mode'};

                    # route reply
                    $$call_args{'args'} //= qw| UNDEFINED |;
                    $data{'session'}{$source_sid}{'buffer'}{'output'}
                        .= $s_cmd_id
                        . $cmd . ' '
                        . $$call_args{'args'} . "\n";

                } else {    # should never come here [ SID gone. ]
                    <[base.log]>->(
                        0,
                        sprintf(
                            '[%s] unknown session, reply dropped., [ %d B ]',
                            $$route{'source'}{'sid'},
                            length("$s_cmd_id$cmd $$call_args{args}\n")
                        )
                    );
                }

                ### deleting route ###
                if ( $cmd ne qw| WAIT | ) {
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

##[ PROCESS REPLY : 'SIZE' ]##################################################

            } elsif ( $cmd eq qw| SIZE | ) {
                if ( $$call_args{'args'} =~ m|^\d+$| ) {
                    my $msg_len = $$call_args{'args'};

                    if ( length( $input->$* ) >= $msg_len ) {

                        ## cut out body data ##

                        my $data_reply
                            = substr( $input->$*, 0, $msg_len, '' );

                        ## check if reply handler is set ##

                        if ( defined $$route{'reply'}{'handler'}
                            and $$route{'reply'}{'handler'} ne '' ) {
                            if ( defined $code{ $$route{'reply'}{'handler'} }
                                and defined
                                &{ $code{ $$route{'reply'}{'handler'} } } ) {

                                ## calling reply handler ##

                                &{ $code{ $$route{'reply'}{'handler'} } }(
                                    {   'sid'       => $id,
                                        'cmd'       => $cmd,
                                        'call_args' => $call_args,
                                        'params'    =>
                                            $$route{'reply'}{'params'},
                                        'data' => $data_reply
                                    }
                                );

                            } else {
                                <[base.log]>->(
                                    0,
                                    "[$id] called undefined reply handler ['"
                                        . $$route{'reply'}{'handler'} . "']"
                                );
                            }
                        } else {    ## sending SIZE reply to target ##
                            $data{'session'}{ $$route{'source'}{'sid'} }
                                {'buffer'}{'output'} .= <[base.sprint_t]>->(
                                qw| DFSFKQA |,       $s_cmd_id,
                                $$call_args{'args'}, $data_reply
                                );
                        }

                        # delete route
                        my $src_sid    = $$route{'source'}{'sid'};
                        my $src_cmd_id = $$route{'source'}{'cmd_id'};
                        delete $data{'session'}{$src_sid}{'route'}
                            {$src_cmd_id};
                        delete $data{'route'}
                            { $data{'session'}{$id}{'route'}{$cmd_id} }
                            if
                            defined $data{'session'}{$id}{'route'}{$cmd_id};
                        delete $data{'session'}{$src_sid}{'route'}
                            if !keys %{ $data{'session'}{$src_sid}{'route'} };
                        delete $data{'session'}{$id}{'route'}{$cmd_id};
                        delete $data{'session'}{$id}{'route'}
                            if !keys %{ $data{'session'}{$id}{'route'} };

                        $valid_answer = 1;
                    } else {    # should never reach this point
                        <[base.logt]>->(
                            qw| QQ4HHXI |, $id, $msg_len, $$call_args{'args'}
                        );
                    }
                }

##[ PROCESS REPLY \ STRM ]####################################################

            } elsif ( $cmd eq qw| STRM | ) {
                ####
                if ( $$call_args{'args'} =~ m|^open( (\d+))?$| ) {
                    my $open_size = $2 || 0;

                    warn "[ STRM REPLY ] open size : $open_size";

                } elsif ( $$call_args{'args'} =~ m|^\d+$| ) {
                    my $msg_len = $$call_args{'args'};
                    if ( length( $input->$* ) >= $msg_len ) {

                        ## cut out body data ##
                        my $data_reply
                            = substr( $input->$*, 0, $msg_len, '' );
                    }
                }
                ####
            } else {
                <[base.log]>->(
                    1, "[$id] called unimplemented answer type ['$cmd']"
                );
                $output->$* .= "[$cmd] answer type not implemented yet.\n";
                return 0;    ##  command processing was complete  ##
            }
        }

##[ PROCESS REPLY \ UNKNOWN ROUTE ID ]########################################

    } else {
        my $ignore_log_level = 1;
        $ignore_log_level = 2
            if exists <net.silent_ignore>->{$user}
            and <net.silent_ignore>->{$user} == 1
            or exists $data{'session'}{$id}{'silent_ignore'}
            and $data{'session'}{$id}{'silent_ignore'} == 1;
        <[base.log]>->(
            $ignore_log_level,
            "[$id] $cmd-reply to unknown route id, ignored."
        );

        if (    $cmd eq qw| SIZE |
            and $call_args->{'args'} =~ m|^\d+$|
            and my $ignore_bytes = $call_args->{'args'} ) {
            if ( length( $input->$* ) >= $ignore_bytes ) {
                substr( $input->$*, 0, $ignore_bytes, '' );
                <[base.log]>->(
                    $ignore_log_level,
                    "[$id] : dropped next $ignore_bytes bytes., [ SIZE body ]"
                );
                return 0;    ##  command processing was complete  ###

            } else {
                <[base.log]>->(
                    $ignore_log_level,
                    "[$id] : to ignore next $ignore_bytes bytes., [ SIZE ]"
                );
                $data{'session'}{'ignore_bytes'} -= length( $input->$* );
                truncate( $input->$*, 0 );
            }
        }
        return 1;    ## command not complete ###
    }

##[ PROCESS REPLY \ UNKNOWN TYPE ]############################################

} elsif ( $cmd eq uc($cmd) ) {
    <[base.log]>->( 1, "[$id] reply type '$cmd' not valid" );
    $output->$*
        .= $_cmd_id . "FALSE protocol error [ reply type not valid ]\n";

##[ PROCESSING \ LOCAL COMMAND ]##############################################

} elsif ( <[base.has_access]>->( $user, $cmd_usr_str ) ) {

    ### local command ###

    if ( $cmd =~ $re->{'cmd'} ) {

        if ( defined $data{'base'}{'cmd'}{$cmd} ) {
            if (    defined $code{ $data{'base'}{'cmd'}{$cmd} }
                and defined &{ $code{ $data{'base'}{'cmd'}{$cmd} } } ) {

##[ LOCAL COMMAND \ PREPARING DEFERRED ]######################################

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

##[ LOCAL COMMAND \ CALLING HANDLER ]#########################################

                ## calling command handler ##
                my $reply;
                {
                    local $EVAL_ERROR = undef;

                    my $caller = <[base.caller]>->(-1)
                        and $reply
                        = eval { $code{ <base.cmd>->{$cmd} }->($call_args) };

                    $EVAL_ERROR
                        = sprintf(
                        "command '%s' did not return hash ref [%s]",
                        $cmd, $reply // qw| undef | )
                        if not length $EVAL_ERROR
                        and ( not defined $reply
                        or ref($reply) ne qw| HASH | );

                    if ($EVAL_ERROR) {

                        ( my $err_str, my $extracted_callerstr )
                            = <[base.format_error]>->( $EVAL_ERROR, -1 );

                        $caller = $extracted_callerstr
                            if defined $extracted_callerstr
                            and ( not defined $caller
                            or $extracted_callerstr ne $caller );

                        $caller = defined $caller ? " $caller" : '';
                        my $log_error = 1;
                        ##  alternative handler for filename:line ?  ##
                        my $warn_handlers = <base.warn-match-handler> // {};
                        if ( defined $warn_handlers->{$caller} ) {
                            my $cb_name = $warn_handlers->{$caller};
                            $log_error
                                = $code{$cb_name}
                                ->( $err_str, $caller, $call_args )
                                if defined $code{$cb_name};
                        }
                        ##
                        if ($log_error) {
                            <[base.logs]>->(
                                0,   "[%d] <<< %s >>>%s",
                                $id, $err_str, $caller
                            );
                            my $params = $call_args->{'args'} // '';
                            my $msg    = "[$id]  \\\\\\ <$cmd>";
                            $msg .= " [ '$params' ]" if length($params);
                            <[base.log]>->( 0, $msg );
                        }
                    }
                }

##[ LOCAL CMD \ DEFERRED ]####################################################

                if ( ref($reply) eq 'HASH' and $$reply{'mode'} eq 'deferred' )
                {    ### deferred reply., ###
                    <[base.logs]>->(
                        2, 'setting up reply for id %d', $reply_id
                    );

                    # [LLL] set up reply timeout .,
                    return 0;    ##  command processing was complete  ##
                }
                delete <base.cmd_reply>->{$reply_id};

##[ LOCAL CMD \ REPLY ERROR CHECK ]###############@@@@########################

                ##  REPLACING RENAMED REPLY TYPE  ##
                $reply->{'mode'} = qw| size |
                    if ref($reply) eq qw| HASH |
                    and $reply->{'mode'} eq qw| data |;
                ###

                ## reply error check ##

                if ( ref($reply) ne qw| HASH | ) {    # <-- catches undef
                    $reply          = {};
                    $$reply{'mode'} = qw| false |;
                    $$reply{'data'} = 'error during command invocation'
                        . ' [ details are logged ]';
                    <[base.logs]>->(
                        0,   "[%d] cmd ['%s'] <-- [ hashref expected ]",
                        $id, $cmd
                    );
                } elsif (
                    (   $reply->{'mode'} ne qw| size | ## <-- new type name ##
                        and $reply->{'mode'} ne qw| data |  ## <-- old type ##
                    )
                    and (  not defined $reply->{'data'}
                        or not length $reply->{'data'} )
                ) {
                    ( undef, my $file, my $line ) = ( caller(0) );
                    my $source_str
                        = $file eq qw| base.handler.input |
                        ? "'$cmd'"
                        : "$file:$line";
                    <[base.logs]>->(
                        0,   "[%d] empty %s-reply attempted [%s]",
                        $id, uc( $$reply{'mode'} ), $source_str
                    );
                    $$reply{'mode'} = qw| false |;
                    $$reply{'data'} = 'error during command invocation'
                        . ' [ details are logged ]';
                }

##[ LOCAL CMD \ CHECKING ANSWER MODE ]########################################

                ## check answer mode ##
                if ( $$reply{'mode'} =~ m,^(TRUE|FALSE|WAIT)$,io ) {
                    $$reply{'data'} =~ s|\n|\\n|go;

                    $output->$* .= <[base.sprint_t]>->(    #  single line  #
                        qw| ZTLA6BI |, $_cmd_id, uc( $reply->{'mode'} ),
                        $reply->{'data'}                   ##  <-- message  ##
                    );

                } elsif ( uc( $reply->{'mode'} ) eq qw| SIZE | ) {
                    $output->$* .= <[base.sprint_t]>->(  ##  SIZE template  ##
                        qw| DFSFKQA |, $_cmd_id, length( $reply->{'data'} ),
                        $reply->{'data'}
                    );
                } elsif ( uc( $reply->{'mode'} ) eq qw| TERM | ) {
                    <[base.session.shutdown]>->( $id, $reply->{'data'} );
                }
                return 0;    ##  command processing was complete  ##

##[ LOCAL COMMAND \ HANDLER NOT DEFINED ######################################

            } else {
                <[base.logs]>->(
                    "[%d] command '%s' configured but not defined",
                    $id, $cmd
                );
            }

##[ LOCAL COMMAND \ UNKNOWN COMMAND ]#########################################

        } else {    ## command does not exist ##
            <[base.logt]>->( qw| IPWI3HI |, $id, $cmd );
        }

        $output->$* .= <[base.sprint_t]>->( qw| GLPLXJQ |, $_cmd_id );

        return 0;    ##  command processing was complete  ##
    }

##[ PARENT BRANCH \ EXTERNAL CORE ]###########################################

    ## tree upwards., ##

    elsif ( $cmd =~ m|^\.\.([^\.]+)\.(.+)$| ) {

        #        not working yet..,

        <[base.logs]>->( "outgoing: nexthop: '%s' command: '%s'", $1, $2 );

        $output->$* .= "FALSE not implemented yet.,\n";
        return 0;    ##  command processing was complete  ##

        if ( exists $data{'user'}{$1}{'session'}
            and $data{'user'}{$1}{'mode'} eq qw| link | ) {

       #            <[net.send_command]>->( $id, $command_id, $cmd, @params );
        }
        return 0;    ##  command processing was complete  ##
    }

##[ ABSOLUTE PATH ROUTING ]#####################################################

    ## absolute address notation ##

    elsif ( $cmd =~ m|^\^(\w+)\.([^\.]+)$| )
    {    # LLL: regex invalid: <only host>
        my $network_name = ${^CAPTURE}[0];
        my $node_name    = ${^CAPTURE}[0];

        # ^ not yet implemented [ route discovery feature.., ]

##[ PROCESS \ PREPARE TARGET SIDS ]###########################################

    } elsif (
        $cmd =~ s,^($re->{sid_str}|$re->{usr_str}|$re->{usr_subn_str})\.
                    ((($re->{sid_str}|$re->{usr_str}|$re->{usr_subn_str})\.)*
                    $re->{cmd_str})$,$2,gxo
    ) {
        my $target_name = ${^CAPTURE}[0];    # usr|sid
        my $command_str = ${^CAPTURE}[1];    # [ deeper targets + ] command
        my $target_subname
            = $target_name =~ s|\[($re->{subname})\]$||
            ? $LAST_PAREN_MATCH
            : undef;

        my @send_sids;

        if ( $target_name =~ $re->{sid} ) {    ## <session_id>.<command> mode
            my $target_sid = $target_name;
            if ( exists $data{'session'}{$target_sid}
                and $data{'session'}{$target_sid}{'mode'} eq qw| client | ) {
                @send_sids = ($target_sid);
            }
        } elsif (
            exists $data{'user'}{$target_name}{'session'}
            and ( not defined $target_subname
                or defined $data{'user'}{$target_name}{'subname'}
                {$target_subname} )
            ) {                                ## [ online \ present ]
            foreach my $target_sid (
                keys( %{ $data{'user'}{$target_name}{'session'} } ) ) {
                next if $data{'session'}{$target_sid}{'mode'} ne qw| client |;

                #### 'target[subname]' syntax:
                next
                    if defined $target_subname
                    and ( not defined $data{'session'}{$target_sid}{'subname'}
                    or $data{'session'}{$target_sid}{'subname'} ne
                    $target_subname );

                push( @send_sids, $target_sid );
            }

##[ ONDEMAND ZENKI ]##########################################################

        } elsif ( my $v_id
            = <[base.zenki.ondemand_registered]>->($target_name) )
        {    # ondemand
            my $target_user    = qw| v7 |;
            my $target_command = <zenki.virtual>->{$v_id}->{'target_command'};
            if ( defined $target_command
                and $target_command =~ m|^([^\.]+)\.[^\.]+$| ) {
                $target_user = $1;
            } elsif ( defined $target_command ) {
                undef $target_user;
            }

            # [LLL] ..deal with multi-line commands.., [ command_mode 2 ]

            if ( not defined $target_user
                or exists $data{'user'}{$target_user}{'session'} ) {
                $target_command //= qw| v7.start_once |;

                # ..,

                push(
                    @{ <zenki.virtual>->{$v_id}->{'queue'} },
                    {   'source_id'   => $id,
                        'cmd_id'      => $_cmd_id,
                        'cmd_subname' => $target_subname,
                        'cmd_str'     => $command_str,
                        'cmd_args'    => $args_orig
                    }
                );

                if ( not exists <zenki.virtual>->{$v_id}->{'starting'} ) {
                    <zenki.virtual>->{$v_id}->{'starting'} = 1;

                    my $start_name = <zenki.virtual>->{$v_id}->{'name'};

                  # [LLL] subname behaviour needs refinement \ configuration.,
                    $start_name .= "[$target_subname]"
                        if defined $target_subname;

                    <[base.log]>->(
                        1, "ondemand zenka '$start_name' requested ..,"
                    );
                    <[base.protocol-7.command.send.local]>->(
                        {   'command'   => $target_command,
                            'call_args' => { 'args' => $start_name },
                            'reply'     => {
                                'handler' =>
                                    qw| base.handler.ondemand_startup |,
                                'params' => { 'v_id' => $v_id }
                            }
                        }
                    );
                }
                return 0;    ##  command processing was complete  ##
            } else {
                <[base.logs]>->(
                    ": target user '%s' not found", $target_user
                );
            }
        }

##[ 'FALSE' REPLY : CLIENT NOT PRESENT ]######################################

        if ( !@send_sids ) {    ## FALSE client not present ##
            $output->$* .= <[base.sprint_t]>->( qw| FZJASRY |, $_cmd_id );

            my $llvl = $target_name eq qw| p7-log | ? 2 : 1;
            <[base.logt]>->(    ##  offline  ##
                $llvl, qw| ADMN6PY |, $id, $target_name, $command_str
            );

            return 0;           ##  command processing was complete  ###
        }

##[ CHECK INITIALIZED ]#######################################################

        my @send_sids_left;
        foreach my $target_sid (@send_sids)
        {    # check if session initialized yet
            if (
                (   not defined <system.zenka.mode>
                    or <system.zenka.mode> ne qw| cube |
                )
                or $user eq qw| v7 |  # [LLL] improve check if really v7 zenka
                or ( $data{'session'}{$target_sid}{'initialized'} // 0 )
            ) {
                push( @send_sids_left, $target_sid );
                next;
            }

          # if 'zenka'-mode session and not initialized allowing replies only.
            $output->$* .= <[base.sprint_t]>->( qw| GBAMFKI |, $_cmd_id );
            <[base.logt]>->(    #  session not initialized  #
                0, qw| J3OAOPQ |, $id, $command_str, $target_name, $target_sid
            );
        }

##[ RETURN \ CHECK NONE LEFT ]################################################

        return 0 if @send_sids_left == 0;    ##  <--  all done.,  ###
        @send_sids = @send_sids_left if @send_sids_left != @send_sids;

##[ PROCESS \ FILTER HOOKS ]##################################################

        # command [argument] filter hooks  ..,
        my $cmd_hook_data = <[base.handler.cmd_filter_hooks]>->(
            {   'sid'      => $id,
                'target'   => $target_name,
                'command'  => $cmd,
                'args_ref' => \$$call_args{'args'}
            }
        );

##[ PROCESS \ GROUP MODE ]####################################################

        # send to all clients with that username [ group mode ]
        my $targets_denied = 0;
        foreach my $target_sid (@send_sids) {

            my $target_session = $data{'session'}{$target_sid};
            if (   $target_session->{'user'} eq <base.session.uname.server>
                or $target_session->{'user'} eq <base.session.uname.client>
                or not
                <[base.cfg_bool]>->( $target_session->{'authenticated'} ) ) {
                $targets_denied++;
                next;    # skip unauthorized connections
            }

##[ SET UP ROUTE ]############################################################

            ## setting up route ##

            my $route = <[base.route.add]>->(
                {   'source' => { 'sid' => $id, 'cmd_id' => $cmd_id },
                    'target' => { 'sid' => $target_sid }
                }
            );

            $route->{'hook_data'} = $cmd_hook_data if defined $cmd_hook_data;

            my $target_cmd_id = $$route{'target'}{'cmd_id'};

##[ CMD LOGGING ]#############################################################

            if (   <system.verbosity.console> >= 2
                or <system.verbosity.zenka_buffer> >= 2 ) {
                <[base.logs]>->(
                    2,            '[%d] %s ..:. %s ..:. %s [M=%s]',
                    $id,          $data{'session'}{$id}{'user'},
                    $target_name, $cmd, $command_mode
                    )
                    if ( $target_name ne qw| p7-log |
                    or $cmd ne qw| append |
                    or not <debug.skip_log_msg> )
                    and ( $cmd ne qw| p7-log.append |
                    or not <debug.skip_log_msg> )
                    and ( $user ne qw| v7 |
                    or $cmd ne qw| heart |
                    or not <debug.skip_v7_heartbeat> );
            }

##[ LOGGING \ DEBUG MODE ]####################################################

            if ( <system.verbosity.console> >= 3
                and defined $$call_args{'args'}
                or <system.verbosity.zenka_buffer> >= 3
                and defined $$call_args{'args'} ) {
                ( my $args_str = $$call_args{'args'} ) =~ s|"|\"|g;
                <[base.logs]>->( 3, "[%d] : args ['%s']", $id, $args_str );
            }

            $target_cmd_id =~ s|^($re->{cmd_id})$|($1)|;

##[ PROCESS \ SINGLE LINE CMD ]###############################################

            if ( $command_mode == 1 ) {    ## single line command mode ##

                my $args = '';

                local $$call_args{'args'} = ''
                    if not defined $$call_args{'args'};

                $data{'session'}{$target_sid}{'buffer'}{'output'}
                    .= $target_cmd_id
                    . $cmd . ' '
                    . $call_args->{'args'} . "\n";

                # [LLL] set up timeout handler

##[ PROCESS \ MULTI-LINE ]####################################################

            } elsif ( $command_mode == 2 ) {    ## multi line command mode ##

                my $header = '';

                ## preparing parameter header ##
                if ( defined $$call_args{'param'}
                    and ref( $$call_args{'param'} ) eq qw| HASH | ) {
                    my ( $key, $val );

                    while ( ( $key, $val )
                        = each( %{ $$call_args{'param'} } ) ) {
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

##[ PROCESS \ NOTHING SENT ]##################################################

        ## nothing was sent ##
        if ( $targets_denied == @send_sids ) {

            ##  no perm. .., ##
            $output->$* .= <[base.sprint_t]>->( qw| 3KWYQCI |, $_cmd_id );
            <[base.logt]>->( qw| XY6BQLA |, $id, $user, $target_name, $cmd );

            return 0;    ##  command processing was complete  ##
        }

        ## at least one target was valid ##

        return 0;        ##  command processing was complete  ##

##[ PROCESS \ NOT VALID SYNTAX ]##############################################

    } else {    ## command syntax not valid ##

        $output->$* .= <[base.sprint_t]>->( qw| PQKWOXQ |, $_cmd_id );

        <[base.logt]>->( qw| HTKSXIY |, $id, $cmd );    # protocol mismatch #

        return 0;    ##  command processing was complete  ##
    }

##[ PROCESS \ COMMAND UNKNOWN ]###############################################

    ## command does not exist ##
    $output->$* .= <[base.sprint_t]>->( qw| GLPLXJQ |, $_cmd_id );
    <[base.logt]>->( qw| OZZAS3I |, $id, $user, $cmd );

} else {    ## insufficient access permissions ##

    $output->$* .= <[base.sprint_t]>->( qw| 2QWSHTY |, $_cmd_id, $cmd );

    <[base.logt]>->( 0, qw| CQL5VPA |, $id, $user, $cmd ); ##  no perm. .., ##

    return 0;    ##  command processing was complete  ##
}

##[ RETURN : PROCESSING COMPLETE ]############################################

return 0;        ##  command processing was complete  ##

#,,,.,..,,,..,.,,,,..,,.,,,,.,,,,,,.,,,..,,..,..,,...,...,,.,,..,,,,,,..,,.,.,
#SYIZFCOUVVFCMSZB7ZXJJ34JD4PFNAXJX6RARYTVAY6L5EOUB5YZXROHU3KFUWMFD66R4IQRRKSJC
#\\\|G4F75RNIRPUHM5I5ZPIURE2ZFNXE5U5QAWHBP2OXDJFXSO4NQS6 \ / AMOS7 \ YOURUM ::
#\[7]6FK3DEXBXLLL2OGE6THG7HU3AFLO4VGXY2F6ZVH2OPIVBCRGW2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
