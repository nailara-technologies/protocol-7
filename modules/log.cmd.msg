# >:]

# name  = log.cmd.msg
# descr = write a log message to corresponding log file
# todo  = implement buffered write (not line by line..)

my ( $node_agent, $instance_id, $buffer_name, $log_line )
    = split( / /, shift->{'args'}, 4 );

my $log_file = "$node_agent.$buffer_name";
my $log_msg  = "$instance_id $log_line\n";
my $msg_len  = length($log_msg);

my ( $ok, $err_msg ) = <[log.add_line]>->( $log_file, $log_msg );

# success
return { 'mode' => 'ack', 'data' => "wrote $msg_len bytes" } if $ok;

# fail
<[base.log]>->( 0, $err_msg );
return { 'mode' => 'nack', 'data' => $err_msg };
