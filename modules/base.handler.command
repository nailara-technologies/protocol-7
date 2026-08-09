## [:< ##

# name    = base.handler.command
# descr   = handling of protocol-7 syntax, calling command handlers
#
# comment = protocol-7 specific --> move to protocol.protocol-7 namespace and
#                                            replace with a generic version..,
#                                                           [ needs rewrite. ]
my $event = shift;
my $id    = $event->w->data;

##[ INIT \ VARIABLES ]########################################################

my $re = <regex.base>;    # <-- regex cache

my $session = $data{'session'}->{$id};
my $user    = <[base.session.user]>->($id);

my $input  = \$session->{'buffer'}->{'input'};
my $output = \$session->{'buffer'}->{'output'};

## Use bytes::length() for accurate byte count on input buffer  Critical for
## SIZE mode protocol where buffer may contain UTF-8 characters
my $buffer_length = bytes::length( $input->$* );

my $cmd    = '';
my $cmd_id = 0;

<system.devmod_capture> //= FALSE;

## record traffic for searching protocol errors ##
##
if (<system.devmod_capture>) {

    <[base.log]>->( 0, 'devmod capture buffer enabled' )
        if not exists <buffer.devmod-capture>;
    <buffer.devmod-capture.max_size> //= 63 * 1024;    ## 63K buffer size ##

    <[base.buffer.add_line]>->( qw| devmod-capture |, $input->$* );
}

##[ DROP \ SIZE + CHRSIZE REPLIES ]###########################################

## Handle incomplete SIZE \ STRM \ STRM-SIZE replies [ tracked by byte count ]
if ( defined $session->{'ignore_bytes'} ) {    # ..dropped SIZE replies.,
    if ( my $ignore_bytes = $session->{'ignore_bytes'} ) {
        my $ignore_log_level = 1;
        $ignore_log_level = 2
            if exists <net.silent_ignore>->{$user}
            and <net.silent_ignore>->{$user}
            or exists $session->{'silent_ignore'}
            and $session->{'silent_ignore'};
        <[base.logs]>->(
            $ignore_log_level, '[%d] dropping %03d [ignore-]byte%s.,',
            $id, $ignore_bytes, <[base.cnt_s]>->($ignore_bytes)
        );
        if ( $buffer_length >= $ignore_bytes ) {
            my $byte_input = $input->$*;
            utf8::downgrade( $byte_input, 1 )
                if utf8::is_utf8($byte_input);
            bytes::substr( $byte_input, 0, $ignore_bytes, '' );
            $input->$* = $byte_input;
            $buffer_length = bytes::length( $input->$* );
            delete $session->{'ignore_bytes'};
        } else {
            $session->{'ignore_bytes'} -= bytes::length( $input->$* );
            $input->$* = '';        ##  truncating buffer to ''  ##
            $buffer_length = 0;
        }
    } else {
        delete $session->{'ignore_bytes'};
    }
}

## Handle incomplete CHRSIZE replies [ tracked by character count ]
if ( defined $session->{'ignore_chars'} ) {
    if ( my $ignore_chars = $session->{'ignore_chars'} ) {
        my $ignore_log_level = 1;
        $ignore_log_level = 2
            if exists <net.silent_ignore>->{$user}
            and <net.silent_ignore>->{$user}
            or exists $session->{'silent_ignore'}
            and $session->{'silent_ignore'};
        <[base.logs]>->(
            $ignore_log_level, '[%d] dropping %03d [ignore-]char%s.,',
            $id, $ignore_chars, <[base.cnt_s]>->($ignore_chars)
        );

        my $chars_available = CORE::length( $input->$* );

        if ( $chars_available >= $ignore_chars ) {
            ## Extract and remove the specified number of characters
            my $extracted       = substr $input->$*, 0, $ignore_chars;
            my $bytes_to_remove = bytes::length($extracted);
            substr $input->$*, 0, $bytes_to_remove, '';
            $buffer_length = bytes::length( $input->$* );
            delete $session->{'ignore_chars'};
        } else {
            ## Incomplete - update remaining character count and clear buffer
            $session->{'ignore_chars'} -= $chars_available;
            $input->$* = '';        ##  truncating buffer to ''  ##
            $buffer_length = 0;
        }
    } else {
        delete $session->{'ignore_chars'};
    }
}

##[ STOP WATCHER TO MODIFY INPUT BUFFER ##]###################################

##  stop the watcher to modify buffer without re-triggering  ##
$event->w->stop;

##[ STOP TIMER \ ONDEMAND TIMEOUT ]###########################################

# cancel ondemand timeout [ reinstalled in idle watcher ]
if ( defined <base.timer.ondemand_timeout> ) {
    <base.timer.ondemand_timeout>->cancel
        if <base.timer.ondemand_timeout>->is_active;
    delete <base.timer.ondemand_timeout>;
}

##[ SET-UP \ VARIABLES ]######################################################

my @args;
my $command_mode = 0;
my $call_args    = {};

##[ CHECK SYNTAX \ CMD-ID ]###################################################

# check cmd_id regex [ for numbers or valid length ]
if (    $input->$* =~ m|^\(([^\)]*)\)[^\n]+\n|
    and $input->$* !~ m|^\(($re->{cmd_id})\)| ) {
    my $cmd_id   = ${^CAPTURE}[0] // '';
    my $bad_line = $input->$*;
    $bad_line  =~ s|\n$||;
    $input->$* =~ s|^(\([^\)]*\)[^\n]+)\n||;
    <[base.logs]>->(
        "[%d] command id syntax not valid ['%s'] line=['%s']",
        $id, $cmd_id, $bad_line
    );
    $output->$* .= "FALSE invalid command id syntax or length\n";
    $event->w->start;    ##  restarting input buffer processing  ##
    return 0;            ## comand complete ##
}

##  calculate and store average command line length  ##

<[base.session.calc_cmd_stats]>->( $id, $input );   ## updates for protocol ##

##[ MULTI-LINE ]##############################################################

## checking for multi-line commands ###

if ( $input->$*
    =~ s,^(((\($re->{cmd_id}\)|)$re->{cmdp})\+[ \t]*\n([^\n]*\n)*\.\n),,o ) {

    ( my $multiline_cmd, $cmd ) = ( ${^CAPTURE}[0], ${^CAPTURE}[1] );

    if ( $multiline_cmd !~ s,^(\($re->{cmd_id}\)|)$re->{cmdp}\+\n,,o ) {
        warn 'multiline cmd regex error';    ##  never happening  ##
        return 2;    ##  undefined state \ terminates connection  ##
    }

    # cube zenka 'select' command [ base path prefix handling ]
    $cmd = sprintf qw| %s.%s |, $session->{'base_path'}, $cmd
        if defined $session->{'base_path'};

    ## read argument header ##

    my $cmd_id = '';
    $cmd_id = ${^CAPTURE}[0] if length ${^CAPTURE}[0];
    $cmd_id = ''             if $cmd_id =~ m|^\(0+\)$|;

    my $is_header = TRUE;    ## true ##

    while ( length $multiline_cmd ) {
        my $line_feed_pos = index( $multiline_cmd, "\n", 0 );
        if ( $line_feed_pos == -1 ) {
            warn 'unterminated multiline packet';
            $line_feed_pos = length $multiline_cmd;
        }

        my $mcmd_line = substr( $multiline_cmd, 0, $line_feed_pos, '' );
        substr( $multiline_cmd, 0, 1, '' ) if length $multiline_cmd;  ## lf ##

        ##  '.' in single line terminates a packet  ##
        last if $mcmd_line eq qw| . |;

        ##  empty line ending header  ##
        if ( $is_header and $mcmd_line =~ m|^[ \t]*$| ) {
            $is_header = 0;
            next;
        }

        if ( not $is_header ) {    ## body data ##
            $call_args->{'data'} .= sprintf "%s\n", $mcmd_line;
            next;
        }

        ## still header processing ##

        ## < key > : < value > ##
        my $param_seperator = qw| [=:] |;    ##  '=' | ':'  ##

        if ( $mcmd_line !~ m|$param_seperator| ) {    ### protocol error ###
            <[base.logs]>->(    ## <-- back to log level 1 << ! >>
                2,
                "[%d] command parameter format syntax not valid",
                $id
            );
            <[base.logs]>->(    ## <-- back to log level 1 << ! >>
                2,
                "[%d] :. parameter line : '%s' .:",
                $id, $mcmd_line
            );
            $output->$* = sprintf
                "%sFALSE error in [multi-line] command param syntax\n",
                $cmd_id;

            $event->w->start;    ##  restarting input buffer processing  ##
            return 0;            ## comand complete ##
        }

        ## clean linefeed pre|postix ##
        $mcmd_line =~ s{^[ \t]+|[ \t]+$}{}g;

        ( my $key, my $val )
            = split( m|[ \t]*$param_seperator[ \t]*|, $mcmd_line, 2 );

        ##  save header parameters for ondemand zenka  ##
        $call_args->{'param'}->{$key} = $val;
        $buffer_length = bytes::length( $input->$* );
    }

    $command_mode = 2;
}

##[ RETURN \ INCOMPLETE MULTI-LINE ]##########################################

## incomplete multiple line command ##

elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *$re->{cmdrp})\+\n,o ) {

    $event->w->start;    ##  restarting input buffer processing  ##
    return 1;            ## command not complete ###
}

##[ RETURN \ INCOMPLETE 'SIZE' REPLY ]########################################

## incomplete SIZE reply ## [LLL] switch to stream type transfer ..,

elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *SIZE +(0*\d+)\n),o
    and $buffer_length - bytes::length( ${^CAPTURE}[0] )
    < 0 + ${^CAPTURE}[2] ) {

    $session->{'read-mode'} = qw| bytewise |;    ##  switch for efficiency  ##
    ## bytes-to-read is what's still MISSING, not the full declared size -- ##
    ## the header's already-buffered payload bytes must be subtracted or    ##
    ## read_bytewise over-reads by that amount and desyncs the next frame   ##
    $session->{'bytes-to-read'}
        = 0 + ${^CAPTURE}[2]
        - ( $buffer_length - bytes::length( ${^CAPTURE}[0] ) );
    ##
    ##  also : linewise had a bug with incomplete replies blocking cube  ##

    $event->w->start;    ##  restarting input buffer processing  ##
    return 1;            ## command not complete ###
}

##[ RETURN \ INCOMPLETE 'STRM-SIZE' CHUNK DATA ]##############################

## incomplete STRM-SIZE chunk data ##

elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *STRM-SIZE +(\d+)\n),o
    and $buffer_length - bytes::length( ${^CAPTURE}[0] )
    < 0 + ${^CAPTURE}[2] ) {

    ## chunk header present but data incomplete - switch to bytewise        ##
    ## bytes-to-read is what's still MISSING, not the full declared size -- ##
    ## the header's already-buffered payload bytes must be subtracted or    ##
    ## read_bytewise over-reads by that amount and desyncs the next frame   ##
    $session->{'read-mode'} = qw| bytewise |;
    $session->{'bytes-to-read'}
        = 0 + ${^CAPTURE}[2]
        - ( $buffer_length - bytes::length( ${^CAPTURE}[0] ) );

    $event->w->start;    ##  restarting input buffer processing  ##
    return 1;            ## command not complete ###
}

##[ RETURN \ INCOMPLETE 'STRM' CHUNK DATA ]###################################

## incomplete STRM chunk data ##

elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *STRM +(\d+)\n),o
    and $buffer_length - bytes::length( ${^CAPTURE}[0] )
    < 0 + ${^CAPTURE}[2] ) {

    ## chunk header present but data incomplete - switch to bytewise        ##
    ## bytes-to-read is what's still MISSING, not the full declared size -- ##
    ## the header's already-buffered payload bytes must be subtracted or    ##
    ## read_bytewise over-reads by that amount and desyncs the next frame   ##
    $session->{'read-mode'} = qw| bytewise |;
    $session->{'bytes-to-read'}
        = 0 + ${^CAPTURE}[2]
        - ( $buffer_length - bytes::length( ${^CAPTURE}[0] ) );

    $event->w->start;    ##  restarting input buffer processing  ##
    return 1;            ## command not complete ###
}

##[ RETURN \ INCOMPLETE 'CHRSIZE' REPLY ]#####################################

## incomplete CHRSIZE reply ##

elsif ( $input->$* =~ m,^((\($re->{cmd_id}\)|) *CHRSIZE +(0*\d+)\n),o ) {

    my $header_bytes = bytes::length( ${^CAPTURE}[0] );
    my $char_count   = 0 + ${^CAPTURE}[2];

    ## count UTF-8 characters available after header ##
    my $data_after_header = substr( $input->$*, $header_bytes );
    utf8::upgrade($data_after_header);
    my $chars_available = length($data_after_header);

    if ( $chars_available < $char_count ) {
        ## incomplete - wait for more data in linewise mode ##
        $event->w->start;
        return 1;    ## command not complete ###
    }
}

##[ PARSE \ !TRM! BACKCHANNEL ]###############################################

elsif ( $input->$*
    =~ s,^((\($re->{cmd_id}\)|) *!TRM!(?:[ \t]+([^\n]*))?)[ \t]*\n,,o ) {

    $event->w->start;

    my $cmd_id_str = ${^CAPTURE}[1] // '';
    my $reason_str = ${^CAPTURE}[2] // '';

    $cmd_id
        = $cmd_id_str =~ m|^\(($re->{cmd_id})\)$|o ? 0 + ${^CAPTURE}[0] : 0;
    $cmd                 = q|!TRM!|;
    $command_mode        = 1;
    $call_args->{'args'} = $reason_str;
}

##[ CLEAN-UP CMD LINE ]#######################################################

elsif ( $input->$* =~ s|^[ \t\n]+||sg ) {
    $event->w->start;    ##  restarting input buffer processing  ##
    return 1;            ## command not complete ###
}

##[ SESSION BLOCKED BY STRM-SIZE STREAM ]#####################################

## stream data arrives via routing regex [ line 439 : STRM-SIZE included ] ##
## no early return here : STRM-SIZE chunks must reach route handler        ##

##[ SINGLE LINE CMD ]#########################################################

### single command line ###

elsif ( $input->$*
    =~ s,^((\($re->{cmd_id}\)|) *$re->{cmdrp}\/?)( +(.+?)|)[ \t]*\n,,o ) {

    $event->w->start;    ##  restarting input buffer processing  ##

    ( $cmd, $call_args->{'args'} ) = ( ${^CAPTURE}[0], ${^CAPTURE}[3] );

    # cube zenka 'select' command [ base path prefix handling ]
    $cmd = qw| unselect | if $cmd eq qw| .. |;    ## 'unselect'-alias '..'
    $cmd = join( qw| . |, $session->{'base_path'}, $cmd )
        if defined $session->{'base_path'}
        and $cmd !~ m,^(\($re->{cmd_id}\)|) *(unselect|basepath)$,
        and $cmd !~ s,^(\($re->{cmd_id}\) *| *)\.\.($re->{cmdrp}|),$1$2,;

    ## ^ commands prefixed with '..' mean 'parent' to 'select'ed base_path
    ## 'unselect' and '..' are synonymous, they reset the base_path to ''

    $buffer_length = bytes::length( $input->$* );
    $command_mode  = 1;
}

##[ REPLY TO PROTOCOL ERRORS ]################################################

## protocol error ##

elsif ( $input->$* =~ s,^((\($re->{cmd_id}\)|) *[^\n]+)\n,,o ) {
    my ( $cmd_id_str, $cmd_string ) = ( ${^CAPTURE}[1], ${^CAPTURE}[0] );

    <[base.logt]>->( qw| AXLDCOY |, $id, $cmd_string );  # protocol mismatch #

    $output->$* .= <[base.sprint_t]>->( qw| YYOPDKA |, $cmd_id_str );

    $event->w->start;    ##  restarting input buffer processing  ##
    return 0;            ## comand complete ##
}

##[ RETURN \ EMPTY COMMAND LINE ]#############################################

# empty command line

elsif ( $buffer_length == 0 ) {
    $event->w->start;    ##  restarting input buffer processing  ##
    return 0;            ## command complete ##
}

##[ RETURN \ COMMAND NOT COMPLETE ]###########################################

# incomplete command line

else {
    $event->w->start;    ##  restarting input buffer processing  ##
    return 1;            ## command not complete ###
}

# not going to modify buffer again

$event->w->start;        ##  restarting input buffer processing  ##

##[ PROCESS COMMAND \ EXTRACT ID ]############################################

# extract command id

if ( $cmd =~ s|^\(($re->{cmd_id})\) *||o ) { $cmd_id = ${^CAPTURE}[0] }

$call_args->{'command_id'} = $cmd_id;
$call_args->{'session_id'} = $id;

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
my $args_orig = $call_args->{'args'};

##[ PROCESS \ ALIASES ]#######################################################

if ( defined $alias_to and length $alias_to ) {
    $call_args->{'cmd'}{'unalias'} = $cmd;
    $cmd = $alias_to;

    my $args_map = {
        qw|  SOURCE_SID  | => $id,
        qw| SOURCE_ZENKA | =>
            $user,    ## hostname prefix is log-only, never on wire ##
    };
    map { $cmd =~ s|$ARG|$args_map->{$ARG}|g } keys $args_map->%*;

    if ( $cmd =~ s|^([^ ]+) +([^\n]+)$|$1| ) {
        if ( defined $call_args->{'args'} ) {
            $call_args->{'args'} = join ' ', ${^CAPTURE}[1],
                $call_args->{'args'};
        } else {
            $call_args->{'args'} = ${^CAPTURE}[1];
        }
    }
}

##[ PREPARE REPLY \ HAS REPLY ID ]############################################

my $cmd_id_str = '';
if ( $cmd_id > 0 ) { $cmd_id_str = sprintf '(%d)', $cmd_id }

##[ COMMAND REPLIES ]#########################################################

my ( $_m1, $_m2 );

# used for access checking [ relevant with <sid>.<cmd> ]
##
my $cmd_usr_str = $cmd;

$cmd_usr_str = sprintf qw| %s%s |, $data{'session'}{$_m1}{'user'}, $_m2
    if $cmd =~ m|^($re->{sid_str})(\..+)$|
    and $_m1 = ${^CAPTURE}[0]
    and $_m2 = ${^CAPTURE}[1]
    and exists $data{'session'}{$_m1}
    and $data{'session'}{$_m1}{'user'} =~ $re->{'usr'};

##[ COMMAND REPLY \ !TRM! BACKCHANNEL ]#######################################

if ( $cmd eq q|!TRM!| ) {

    my $reason = $call_args->{'args'} // '';

    ##  no cmd_id : implicit lookup unless disabled  ##
    if ( $cmd_id == 0 ) {
        my $implicit = $session->{'stream_term_implicit'} // TRUE;
        my $streams  = $session->{'streams'}              // {};
        my @active = grep { $ARG > 0 and ref $streams->{$ARG} eq qw| HASH | }
            keys %{$streams};
        if ( $implicit and @active ) {
            ## sort by opened_at : highest timestamp = most recently opened ##
            ## -- STRM/STRM-SIZE streams opened via process_reply's own     ##
            ## open-handling [ as opposed to base.stream.open ] stamp       ##
            ## 'started_at' instead of 'opened_at', so a comparison reading ##
            ## only 'opened_at' hits undef <=> undef for any session whose  ##
            ## active streams are all that kind -- fall back to             ##
            ## 'started_at' before defaulting to 0                          ##
            my $newest = (
                sort {
                    ( $streams->{$b}{'opened_at'}
                            // $streams->{$b}{'started_at'} // 0 )
                        <=> ( $streams->{$a}{'opened_at'}
                            // $streams->{$a}{'started_at'} // 0 )
                } @active
            )[0];
            $cmd_id = $newest;
            <[base.logs]>->(
                1,
                '[%d] !TRM! no cmd_id : implicitly '
                    . 'targeting cmd_id=%d [ most recent ]',
                $id,
                $cmd_id
            );
        } else {
            <[base.logs]>->( 1, '[%d] !TRM! ignored : no cmd_id', $id );
            $event->w->start;
            return 0;
        }
    }

    ##  routed case : active route exists → translate and cancel at source  ##
    if (   defined $session->{'route'}->{$cmd_id}
        && defined $data{'route'}->{ $session->{'route'}->{$cmd_id} } ) {

        my $route      = $data{'route'}->{ $session->{'route'}->{$cmd_id} };
        my $src_sid    = $route->{'source'}->{'sid'};
        my $src_cmd_id = $route->{'source'}->{'cmd_id'};

        if (   defined $src_sid
            && exists $data{'session'}{$src_sid}
            && $src_cmd_id > 0 ) {

            $data{'session'}{$src_sid}{'stream_cancelled'}{$src_cmd_id}
                = TRUE;

            <[base.logs]>->(
                1, '[%d] !TRM! cmd_id=%d -> src_sid=%d src_cmd_id=%d [ %s ]',
                $id, $cmd_id, $src_sid, $src_cmd_id, $reason
            );
        }

        ##  forward !TRM! to the producing side [ target of the route ]  ##
        my $tgt_sid    = $route->{'target'}->{'sid'};
        my $tgt_cmd_id = $route->{'target'}->{'cmd_id'} // 0;
        if (    $tgt_cmd_id > 0
            and defined $tgt_sid
            and exists $data{'session'}{$tgt_sid} ) {
            $data{'session'}{$tgt_sid}{'buffer'}{'output'}
                .= sprintf "(%d)!TRM!\n", $tgt_cmd_id;
            <[base.logs]>->(
                2,   '[%d] !TRM! forwarded to target sid=%d cmd_id=%d',
                $id, $tgt_sid, $tgt_cmd_id
            );
        }
        ##  local producer : active stream registered for this cmd_id  ##
    } elsif ( ref $session->{'streams'} eq qw| HASH |
        && ref $session->{'streams'}->{$cmd_id} eq qw| HASH |
        && $session->{'streams'}->{$cmd_id}->{'producer'} ) {

        $session->{'stream_cancelled'}->{$cmd_id} = TRUE;

        <[base.logs]>->(
            1,   '[%d] !TRM! cmd_id=%d local [ %s ]',
            $id, $cmd_id, $reason
        );

    } else {

        ##  no active stream for this cmd_id : log and drop  ##
        <[base.logs]>->(
            1,   '[%d] !TRM! ignored : no active stream [ cmd_id %d ]',
            $id, $cmd_id
        );
    }

    $event->w->start;
    return 0;    ##  command complete  ##
}

##[ COMMAND REPLY \ MATCH TYPE ]##############################################

my $refusal_type;    ##  tracking types of access denial for logging  ##

if (   $cmd =~ m,^(TRUE|FALSE|WAIT|SIZE|CHRSIZE|STRM|STRM-SIZE|GET|TERM)$,
    or $cmd eq uc $cmd ) {

    return <[base.handler.command.process_reply]>->(
        {   'event'         => $event,
            'session'       => $session,
            'id'            => $id,
            'user'          => $user,
            'cmd'           => $cmd,
            'cmd_id'        => $cmd_id,
            'cmd_id_str'    => $cmd_id_str,
            'call_args'     => $call_args,
            'input'         => $input,
            'output'        => $output,
            'buffer_length' => $buffer_length,
        }
    );

} elsif ( <[base.has_access]>->( $user, $cmd_usr_str ) ) {

    ### local command ###

    if ( $cmd =~ $re->{'cmd'}
        or defined $data{'base'}{'cmd'}{$cmd} ) {

        if ( defined $data{'base'}{'cmd'}{$cmd} ) {
            if ( defined $code{ $data{'base'}{'cmd'}{$cmd} } ) {

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
                    my $caller = <[base.caller]>->(-1)
                        and $reply
                        = eval { $code{ <base.cmd>->{$cmd} }->($call_args) };

                    $EVAL_ERROR
                        = sprintf "command '%s' did not return hash ref [%s]",
                        $cmd, $reply // qw| undef |
                        if not length $EVAL_ERROR
                        and ( not defined $reply
                        or ref($reply) ne qw| HASH | );

                    $EVAL_ERROR = "expected 'mode' and 'data' reply keys"
                        if not length $EVAL_ERROR
                        and ( not defined $reply->{'mode'}
                        or $reply->{'mode'} ne qw| deferred |
                        and not exists $reply->{'data'} );

                    if ($EVAL_ERROR) {

                        ( my $err_str, my $extracted_callerstr )
                            = <[base.format_error]>->( $EVAL_ERROR, -1 );

                        $caller = $extracted_callerstr
                            if defined $extracted_callerstr
                            and ( not defined $caller
                            or $extracted_callerstr ne $caller );

                        $caller = defined $caller ? " $caller" : '';
                        my $log_error = TRUE;
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
                                0,   '[%d] <<< %s >>>%s',
                                $id, $err_str, $caller
                            );
                            my $params = $call_args->{'args'} // '';
                            my $msg = sprintf '[%d]  \\\\\\ <%s>', $id, $cmd;
                            $msg .= sprintf " [ '%s' ]", $params
                                if length $params;
                            <[base.log]>->( 0, $msg );
                        }

                        $reply->{'mode'} = qw| false |;
                        $reply->{'data'} = 'error during command invocation '
                            . '[ details are logged ]';
                    }
                }

##[ LOCAL CMD \ DEFERRED ]####################################################

                if ( $reply->{'mode'} eq qw| deferred | ) {
                    <[base.logs]>->(    ### deferred reply., ###
                        2, 'setting up reply for id %d', $reply_id
                    );

                    # [LLL] set up reply timeout .,

                    ##  restarting input buffer processing  ##
                    $event->w->start;
                    return 0;    ## comand complete ##
                }
                delete <base.cmd_reply>->{$reply_id};

##[ LOCAL CMD \ REPLY ERROR CHECK ]###########################################

                ##  REPLACING RENAMED REPLY TYPE  ##
                $reply->{'mode'} = qw| size |
                    if ref $reply eq qw| HASH |
                    and $reply->{'mode'} eq qw| data |;
                ###

                ## reply error check ##

                if ( ref $reply ne qw| HASH | ) {    # <-- catches undef
                    $reply           = {};
                    $reply->{'mode'} = qw| false |;
                    $reply->{'data'} = 'error during command invocation '
                        . '[ details are logged ]';
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
                    $$reply{'data'} = 'error during command invocation '
                        . '[ details are logged ]';
                }

##[ LOCAL CMD \ CHECKING ANSWER MODE ]########################################

                ## check answer mode ##
                if ( $reply->{'mode'} =~ m,^(TRUE|FALSE|WAIT)$,io ) {

                    <[base.stream.emit]>->(
                        {   'sid'        => $id,
                            'cmd_id'     => $cmd_id,
                            'mode'       => uc( $reply->{'mode'} ),
                            'data'       => \$reply->{'data'},
                            'cmd_id_str' => $cmd_id_str,
                        }
                    );

                } elsif ( uc( $reply->{'mode'} ) eq qw| STRM | ) {

                    ## STRM mode : explicit streaming, chunked delivery ##

                    my $data_to_send = $reply->{'data'};
                    my $chunk_data   = $data_to_send;
                    utf8::encode($chunk_data) if utf8::is_utf8($chunk_data);
                    my $total_bytes = bytes::length($chunk_data);
                    my $chunk_size  = <protocol.strm.packet_size> // 8192;
                    my $chunk_count = 0;

                    <[base.logs]>->(
                        2,
                        '[%d] STRM open : total=%d bytes [ chunk_size=%d ]',
                        $id, $total_bytes, $chunk_size
                    );

                    my $h = <[base.stream.open]>->(
                        {   'sid'        => $id,
                            'cmd_id'     => $cmd_id,
                            'type'       => qw| STRM |,
                            'total'      => $total_bytes,
                            'cmd_id_str' => $cmd_id_str,
                        }
                    );

                    if ( defined $h ) {

                        my $offset = 0;
                        while ( $offset < $total_bytes ) {
                            my $chunk_len = $chunk_size;
                            $chunk_len = $total_bytes - $offset
                                if $offset + $chunk_len > $total_bytes;

                            my $chunk = substr $chunk_data, $offset,
                                $chunk_len;
                            my $n = <[base.stream.push]>->( $h, \$chunk );
                            last if not $n;    ## cancelled / gone ##
                            $offset += $chunk_len;
                            $chunk_count++;
                        }

                        <[base.stream.close]>->($h);

                        <[base.logs]>->(
                            2,
                            "[%d] STRM streaming complete: "
                                . "%d bytes in %d chunks",
                            $id,
                            $total_bytes,
                            $chunk_count
                        );
                    }

                } elsif ( uc( $reply->{'mode'} ) eq qw| SIZE | ) {

                    ## SIZE mode : reports BYTE count ##

                    my $data_to_send = $reply->{'data'};
                    my $session_mode = $session->{'size_mode'} // qw| SIZE |;
                    my $count        = bytes::length($data_to_send);

                    ## ensure byte-oriented chunking for UTF-8 content ##
                    my $chunk_data = $data_to_send;
                    utf8::encode($chunk_data);

                    ## use STRM-SIZE fragmentation for large replies sent  ##
                    ## through cube relay [ not for cube's own responses ] ##

                    my $buf_limit = $data{'size'}->{'buffer'}->{'input'};
                    if ( $count > $buf_limit
                        and <system.zenka.type> ne qw| cube | ) {

                        my $chunk_size = <protocol.strm_size.packet_size>
                            // 8192;

                        my $h = <[base.stream.open]>->(
                            {   'sid'        => $id,
                                'cmd_id'     => $cmd_id,
                                'type'       => qw| STRM-SIZE |,
                                'total'      => $count,
                                'cmd_id_str' => $cmd_id_str,
                            }
                        );

                        if ( defined $h ) {

                            my $offset = 0;
                            while ( $offset < $count ) {
                                my $chunk_len = $chunk_size;
                                $chunk_len = $count - $offset
                                    if $offset + $chunk_len > $count;

                                my $chunk = substr $chunk_data, $offset,
                                    $chunk_len;
                                my $n = <[base.stream.push]>->( $h, \$chunk );
                                last if not $n;
                                $offset += $chunk_len;
                            }

                            <[base.stream.close]>->($h);

                            <[base.logs]>->(
                                2, '[%d] STRM-SIZE sent : %d bytes in chunks',
                                $id, $count
                            );
                        }

                    } elsif ( $session_mode eq qw| CHRSIZE | ) {

                        <[base.stream.emit]>->(
                            {   'sid'        => $id,
                                'cmd_id'     => $cmd_id,
                                'mode'       => qw| CHRSIZE |,
                                'data'       => \$data_to_send,
                                'cmd_id_str' => $cmd_id_str,
                            }
                        );

                    } else {

                        <[base.stream.emit]>->(
                            {   'sid'        => $id,
                                'cmd_id'     => $cmd_id,
                                'mode'       => qw| SIZE |,
                                'data'       => \$data_to_send,
                                'cmd_id_str' => $cmd_id_str,
                            }
                        );
                    }

                } elsif ( uc( $reply->{'mode'} ) eq qw| CHRSIZE | ) {

                    ## CHRSIZE mode : reports CHARACTER count [ UTF-8 ] ##

                    my $data_to_send = $reply->{'data'};
                    my $session_mode = $session->{'size_mode'} // qw| SIZE |;

                    <[base.stream.emit]>->(
                        {   'sid'    => $id,
                            'cmd_id' => $cmd_id,
                            'mode'   => $session_mode eq qw| SIZE |
                            ? qw| SIZE |
                            : qw| CHRSIZE |,
                            'data'       => \$data_to_send,
                            'cmd_id_str' => $cmd_id_str,
                        }
                    );

                } elsif ( uc( $reply->{'mode'} ) eq qw| TERM | ) {
                    <[base.session.shutdown]>->( $id, $reply->{'data'} );
                }
                return 0;    ## comand complete ##

##[ LOCAL COMMAND \ HANDLER NOT DEFINED ######################################

            } else {
                <[base.logs]>->(
                    "[%d] command '%s' configured but not defined",
                    $id, $cmd
                );
            }

##[ LOCAL COMMAND \ UNKNOWN COMMAND ]#########################################

        } else {    ## command does not exist ##
            ## [ HOOK POINT: unknown-command ]
            ## hook can intercept unknown commands user tried to execute
            if (
                <[base.handler.hooks.has_hooks]>->( $id, 'unknown-command' ) )
            {
                my $hook_result = <[base.handler.hooks]>->(
                    qw| unknown-command |,
                    {   'sid'       => $id,
                        'cmd'       => $cmd,
                        'call_args' => $call_args,
                        'context'   => 'local'
                    }
                );
                ## if hook returns TRUE, it handled the message,
                goto UNKNOWN_CMD_HANDLED    ## skip normal processing
                    if defined $hook_result and $hook_result == TRUE;
            }

            ## only send error response if hook didn't handle it
            $output->$* .= <[base.sprint_t]>->( qw| VPB3EKI |, $cmd_id_str );
            <[base.logt]>->( qw| 4W6K5SY |, $id, $cmd );
        }

    UNKNOWN_CMD_HANDLED:

        return 0;    ## comand complete ##
    } else {    ##  not a local command  ##

        my $route_ret = <[base.handler.command.route_to_target]>->(
            {   'event'        => $event,
                'session'      => $session,
                'id'           => $id,
                'user'         => $user,
                'cmd'          => $cmd,
                'cmd_id'       => $cmd_id,
                'cmd_id_str'   => $cmd_id_str,
                'cmd_usr_str'  => $cmd_usr_str,
                'call_args'    => $call_args,
                'args_orig'    => $args_orig,
                'command_mode' => $command_mode,
                'output'       => $output,
            }
        );
        return $route_ret if defined $route_ret;
    }

##[ PROCESS \ COMMAND UNKNOWN ]###############################################

    ## [ HOOK POINT: unknown-command-global ]
    ## Hook can intercept commands that don't exist or user lacks access
    if ( <[base.handler.hooks.has_hooks]>->( $id, 'unknown-command-global' ) )
    {
        my $hook_result = <[base.handler.hooks]>->(
            qw| unknown-command-global |,
            {   'sid'       => $id,
                'cmd'       => $cmd,
                'call_args' => $call_args,
                'user'      => $user
            }
        );
        ## If hook returns TRUE, it handled the message,  skip normal
        ## processing
        goto UNKNOWN_CMD_GLOBAL_HANDLED
            if defined $hook_result and $hook_result == TRUE;
    }

    ## Only send error response if hook didn't handle it
    $output->$* .= <[base.sprint_t]>->( qw| VPB3EKI |, $cmd_id_str );
    <[base.logt]>->( qw| V4DWTWA |, $id, $user, $cmd );

UNKNOWN_CMD_GLOBAL_HANDLED:

} else {    ## insufficient access permissions ##

    ##  contextual reply for '.cmd.' in routed command names  ##
    if ( index( $cmd, qw| .cmd. | ) >= 0
        and not defined $data{'base'}{'cmd'}{$cmd} ) {

        if ( exists $data{'diag'}{'cmd_anomalies'}{$cmd} ) {
            my $reason = $data{'diag'}{'cmd_anomalies'}{$cmd};
            $output->$* .= <[base.sprint_t]>->(
                qw| MALFORMED_CMD |,
                $cmd_id_str, $cmd, $reason
            );
        } else {
            ( my $corrected_cmd = $cmd ) =~ s|\.cmd\.|.|g;
            $output->$* .= <[base.sprint_t]>->(
                qw| CMD_HAS_DOT |,
                $cmd_id_str, $corrected_cmd
            );
        }

    } else {

        $output->$*
            .= <[base.sprint_t]>->( qw| AUJWOPY |, $cmd_id_str, $cmd );
    }

    <[base.logt]>->( 0, qw| VSY5TBA |, $id, $user, $cmd ); ##  no perm. .., ##
    <[base.logs]>->(
        2,   '[%d] :. refusal type : %s .:',
        $id, $refusal_type // qw| has_access |
    );
    undef $refusal_type;

    return 0;    ## comand complete ##
}

##[ RETURN : PROCESSING COMPLETE ]############################################

return 0;        ## comand complete ##

#,,..,...,,,,,,..,...,..,,,.,,,.,,,,.,,,.,,,,,..,,...,...,,,.,,,.,...,,,,,..,,
#OVEYGIMNJRTE37IKU5MI3SQMJ2CK4QBPD7O5YNRLSZENHPYDUOGFG6IQXC7IAWPDJNWDMULWZOCX2
#\\\|MIYHBYQX3XHAQRGGMOLBHLGVLIVWDIKZXFGDUIXIOJKCW5G5ZGA \ / AMOS7 \ YOURUM ::
#\[7]YKGNLXV4MD5KUKMJGXYFA73OEWCVN5COOK3RKXNRWKG3TZGOMSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
