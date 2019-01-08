# >:]

# name  = log.cmd.msg
# descr = write a log message to corresponding log file
# todo  = implement buffered write (not line by line..)

my ($node_agent, $instance_id, $buffer_name,
    $log_time,   $log_level,   $log_message
) = split( / /, shift->{'args'}, 6 );
<log.timestamp_mode> //= 'localtime';

my $log_file = "$node_agent.$buffer_name";

if ( <log.timestamp_mode> ne 'localtime' and <log.timestamp_mode> ne 'unix' ) {
    <[base.log]>->(
        0, "invalid timestamp mode '" . <log.timestamp_mode> . "' configured!"
    );
    <[base.log]>->( 1, "setting timestamp mode 'localtime' (fallback)" );
    <log.timestamp_mode> = 'localtime';
}

my $time_string;
if ( <log.timestamp_mode> eq 'localtime' ) {
    my ( $u_time, $time_fp ) = split( /\./, $log_time );
    (   $time_string = join( '.',
            <[base.parser.timestamp]>->( 'timestamp', $u_time ), $time_fp )
    ) =~ s' '|';
} else {
    $time_string = $log_time;
}

my $write_line = sprintf( "%s %7s %d %s\n",
    $time_string, $instance_id, $log_level, $log_message );

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
