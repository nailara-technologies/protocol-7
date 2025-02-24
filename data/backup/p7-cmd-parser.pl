## [:< ##
# name    = protocol.protocol-7.parser.command
# descr   = parse protocol-7 command syntax
# comment = command validation and parsing

my $ctx = shift;   ## connection context ##

##[ INIT \ VARIABLES ]##########################################################

my $re = <regex.base>;    # <-- regex cache

my $session = $ctx->{'session'};
my $input   = $ctx->{'input'};
my $output  = $ctx->{'output'};
my $id      = $ctx->{'id'};

my $buffer_length = length $input->$*;

##[ RETURN : INVALID CMD-ID ]#################################################

# check cmd_id regex [ for numbers or valid length ]
if (    $input->$* =~ m|^\(([^\)]*)\)[^\n]+\n|
    and $input->$* !~ m|^\(($re->{cmd_id})\)| ) {
    my $cmd_id = ${^CAPTURE}[0] // '';
    $input->$* =~ s|^(\([^\)]*\)[^\n]+)\n||;
    <[base.logs]>->( "[%d] command id syntax not valid [%s]", $id, $cmd_id );
    $output->$* .= "FALSE invalid command id syntax or length\n";
    return {
        'success' => FALSE,
        'status'  => 0
    };
}

##[ MULTI-LINE ]##############################################################

if ($input->$* =~ s|^(((\($re->{cmd_id}\)|)$re->{cmdp})\+[ \t]*\n([^\n]*\n)*\.\n)||o) {
    
    my ($multiline_cmd, $cmd) = (${^CAPTURE}[0], ${^CAPTURE}[1]);

    if (not $multiline_cmd =~ s|^(\($re->{cmd_id}\)|)$re->{cmdp}\+\n||o) {
        warn 'multiline cmd regex error';    ##  never happening  ##
        return {
            'success' => FALSE,
            'status'  => 2
        };
    }

    my $cmd_id = '';
    $cmd_id = ${^CAPTURE}[0] if length ${^CAPTURE}[0];
    $cmd_id = ''             if $cmd_id =~ m|^\(0+\)$|;

    # Handle base path prefix
    $cmd = sprintf qw| %s.%s |, $session->{'base_path'}, $cmd
        if defined $session->{'base_path'};

    # Parse headers
    my $args = {};
    my $is_header = TRUE;

    while (length $multiline_cmd) {
        my $line_feed_pos = index($multiline_cmd, "\n", 0);
        if ($line_feed_pos == -1) {
            warn 'unterminated multiline packet';
            $line_feed_pos = length $multiline_cmd;
        }

        my $mcmd_line = substr($multiline_cmd, 0, $line_feed_pos, '');
        substr($multiline_cmd, 0, 1, '') if length $multiline_cmd;

        last if $mcmd_line eq qw| . |;

        ##  empty line ending header  ##
        if ($is_header and $mcmd_line =~ m|^[ \t]*$|) {
            $is_header = FALSE;
            next;
        }

        if (not $is_header) {    ## body data ##
            $args->{'data'} .= sprintf "%s\n", $mcmd_line;
            next;
        }

        ## still header processing ##
        my $param_seperator = qw| [=:] |;    ##  '=' | ':'  ##

        if ($mcmd_line !~ m|$param_seperator|) {    ### protocol error ###
            <[base.logs]>->(
                2, "[%d] command parameter format syntax not valid", $id
            );
            <[base.logs]>->(
                2, "[%d] :. parameter line : '%s' .:", $id, $mcmd_line
            );
            $output->$* = sprintf
                "%sFALSE error in [multi-line] command param syntax\n",
                $cmd_id;

            return {
                'success' => FALSE,
                'status'  => 0
            };
        }

        ## clean linefeed pre|postix ##
        $mcmd_line =~ s{^[ \t]+|[ \t]+$}{}g;

        my ($key, $val) = split(m|[ \t]*$param_seperator[ \t]*|, $mcmd_line, 2);

        ##  save header parameters for ondemand zenka  ##
        $args->{'param'}->{$key} = $val;
    }

    $buffer_length = length $input->$*;

    return {
        'success'  => TRUE,
        'status'   => 0,
        'type'     => 'multiline',
        'cmd'      => $cmd,
        'cmd_id'   => $cmd_id,
        'args'     => $args,
        'mode'     => 2
    };
}

##[ RETURN \ INCOMPLETE MULTI-LINE ]##########################################

elsif ($input->$* =~ m|^((\($re->{cmd_id}\)|) *$re->{cmdrp})\+\n|o) {
    return {
        'success' => FALSE,
        'status'  => 1    ## command not complete ###
    };
}

##[ RETURN \ INCOMPLETE 'SIZE' REPLY ]########################################

elsif ($input->$* =~ m|^((\($re->{cmd_id}\)|) *SIZE +(0*\d+)\n)|o
    and $buffer_length - length(${^CAPTURE}[0]) < 0 + ${^CAPTURE}[2]) {

    $session->{'read-mode'} = qw| bytewise |;    ##  switch for efficiency  ##
    $session->{'bytes-to-read'} = 0 + ${^CAPTURE}[2];

    return {
        'success' => FALSE,
        'status'  => 1    ## command not complete ###
    };
}

##[ CLEAN-UP CMD LINE ]#######################################################

elsif ($input->$* =~ s|^[ \t\n]+||sg) {
    return {
        'success' => FALSE,
        'status'  => 1    ## command not complete ###
    };
}

##[ SINGLE LINE CMD ]#########################################################

elsif ($input->$* =~ s|^((\($re->{cmd_id}\)|) *$re->{cmdrp}\/?)( +(.+?)|)[ \t]*\n||o) {

    my $cmd = ${^CAPTURE}[0];
    my $args = ${^CAPTURE}[3];

    # cube zenka 'select' command [ base path prefix handling ]
    $cmd = qw| unselect | if $cmd eq qw| .. |;    ## 'unselect'-alias '..'
    $cmd = join(qw| . |, $session->{'base_path'}, $cmd)
        if defined $session->{'base_path'}
        and $cmd !~ m|^(\($re->{cmd_id}\)|) *(unselect|basepath)$|
        and $cmd !~ s|^(\($re->{cmd_id}\) *| *)\.\.($re->{cmdrp}|)|$1$2|;

    my $cmd_id = '';
    if ($cmd =~ s|^\(($re->{cmd_id})\) *||o) { $cmd_id = ${^CAPTURE}[0] }

    $buffer_length = length $input->$*;

    return {
        'success'  => TRUE,
        'status'   => 0,
        'type'     => 'command',
        'cmd'      => $cmd,
        'cmd_id'   => $cmd_id,
        'args'     => $args,
        'mode'     => 1
    };
}

##[ REPLY TO PROTOCOL ERRORS ]################################################

elsif ($input->$* =~ s|^((\($re->{cmd_id}\)|) *[^\n]+)\n||o) {
    my ($cmd_id_str, $cmd_string) = (${^CAPTURE}[1], ${^CAPTURE}[0]);

    <[base.logt]>->( qw| AXLDCOY |, $id, $cmd_string );  # protocol mismatch #

    $output->$* .= <[base.sprint_t]>->( qw| YYOPDKA |, $cmd_id_str );

    return {
        'success' => FALSE,
        'status'  => 0
    };
}

##[ RETURN \ EMPTY COMMAND LINE ]#############################################

elsif ($buffer_length == 0) {
    return {
        'success' => FALSE,
        'status'  => 0    ## command complete ##
    };
}

##[ RETURN \ COMMAND NOT COMPLETE ]###########################################

else {
    return {
        'success' => FALSE,
        'status'  => 1    ## command not complete ###
    };
}

#,,.,,...,,,,,,,.,.,,,,.,,...,,,.,,.,,..,,,,.,..,,...,...,..,,...,.,.,...,.,.,
#YRQXCIXSKHWT2UHVBDXGP3LPSFJ6MPTLQRFCUXP3HGQLKJ3DRZW3XZHFRP46SVLYPYHQ5YUN46NIE
#\\\|KNCGDCYY2QI4XKAFJ5NFPZXAFNUCWSJ6IIBDYXFLGZLZRKHP5A6 \ / AMOS7 \ YOURUM ::
#\[7]RP72XPWAXQLQHLBKLCDAYOZLZIQRYVSCJMCFDTHWJVQRDFQZC4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
