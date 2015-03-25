# >:]

# name  = log.cmd.msg
# descr = write a log message to corresponding log file
# todo  = implement buffered write (not line by line..)

my ( $node_agent, $instance_id, $buffer_name, $log_line )
    = split( / /, shift->{'args'}, 4 );

<log.timestamp_mode> //= 'localtime';
my $tstamp_mode = <log.timestamp_mode>;
if ( not exists <log.warned_tstamp_mode>
    and $tstamp_mode !~ /^(unix|localtime)$/ ) {
    <[base.log]>->( 0, "invalid timestamp mode '$tstamp_mode' configured!" );
    <[base.log]>->( 1, "setting timestamp mode 'localtime' (fallback)" );
    <log.timestamp_mode> = 'localtime';
    $tstamp_mode = 'localtime';
    <log.warned_tstamp_mode> = 1;
}

my $log_file = "$node_agent.$buffer_name";
my $log_msg  = "$instance_id $log_line\n";

$log_msg =~ s/\ ?(\d{10})(\.\d+)?\ /my$fp=$2||'';
            (my$ts=<[base.parser.timestamp]>->('timestamp',$1))=~s' '|';
            " $ts$fp "/xe
    if $tstamp_mode eq 'localtime';

my $msg_len = length($log_msg);
my ( $ok, $err_msg ) = <[log.add_line]>->( $log_file, $log_msg );

# success
return { 'mode' => 'ack', 'data' => "wrote $msg_len bytes" } if $ok;

# fail
<[base.log]>->( 0, $err_msg );
return { 'mode' => 'nack', 'data' => $err_msg };
