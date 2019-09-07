# >:]

# name  = log.cmd.msg
# descr = write a log message to corresponding log file
# todo  = implement buffered write (not line by line..)

my ($node_agent, $instance_id, $buffer_name,
    $log_time,   $log_level,   $log_message
) = split( / /, shift->{'args'}, 6 );

# note : log_time is accepted in unix or nailara network time, default: ntime!!!

my $default_mode = 'localtime';
<log.timestamp_mode> //= $default_mode;

my $log_file = "$node_agent.$buffer_name";

## input ##

if ( <log.timestamp_mode> !~ /^localtime|ntime|unix/ ) {
    <[base.log]>->(
        0, "invalid timestamp mode '" . <log.timestamp_mode> . "' configured!"
    );
    <[base.log]>->( 1, "setting timestamp mode '$default_mode' (fallback)" );
    <log.timestamp_mode> = $default_mode;
} elsif ( $log_time !~ /^(\d{1,17})(\.\d+)?/ ) { # invalid time value -> current
    $log_time = <[base.ntime]>;                  # TODO: deliver warning _once_!
} elsif ( length($1) < 13 ) {                    # unix time input value
    $log_time = <[base.ntime]>->($log_time);
}

## output ##

if ( <log.timestamp_mode> eq 'unix' ) {          # output in unix time

    $log_time = <[base.n2u_time]>->( $log_time, 5 );

} elsif ( <log.timestamp_mode> eq 'localtime' ) {   # human readable time string
    my ( $unix, $secs_fp ) = split( /\./, <[base.n2u_time]>->( $log_time, 5 ) );
    (   $log_time = join( '.',
            <[base.parser.timestamp]>->( 'timestamp', $unix ),
            $secs_fp // 0 )
    ) =~ s' '|';
}

my $write_line = sprintf( "%s %7s %d %s\n",
    $log_time, $instance_id, $log_level, $log_message );

my $msg_len = length($write_line);
my ( $ok, $err_msg ) = <[log.add_line]>->( $log_file, \$write_line );

# success
return {
    'mode' => 'ack',
    'data' => "wrote $msg_len bytes"
} if $ok;

# fail
<[base.log]>->( 0, $err_msg );
return {
    'mode' => 'nak',
    'data' => $err_msg
};
