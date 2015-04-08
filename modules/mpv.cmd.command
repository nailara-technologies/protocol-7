# >:]

# name  = mpv.cmd.command
# param = <mpv_command>
# descr = sends test commands through mpv control pipe

my $mpv_socket = <mpv.socket>;
my $cmd_str    = $$call{'args'};

return { 'mode' => 'nack', 'data' => 'socket is not valid' } if !-S $mpv_socket;

return { 'mode' => 'nack', 'data' => 'expected test command string' }
    if not defined $cmd_str or !length($cmd_str);

syswrite( $mpv_socket, "$cmd_str\n" );

return { 'mode' => 'ack', 'data' => 'command sent.' };
