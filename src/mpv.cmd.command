# >:]

# name  = mpv.cmd.command
# param = <mpv_cmd>
# descr = sends test commands through mpv control pipe

my $mpv_socket = <mpv.socket>;
my $cmd_str    = $$call{'args'};

return { 'mode' => 'nack', 'data' => 'expected mpv command' }
    if not defined $cmd_str or !length($cmd_str);

return { 'mode' => 'nack', 'data' => 'requested command matches blacklist!' }
    if $cmd_str =~ /run|hook/;

push( @{<mpv.reply_ids>}, $$call{'reply_id'} );
<mpv.success_reply_str> = "mpv reported success :)";

<[mpv.send_command]>->( split / +/, $cmd_str );

return { 'mode' => 'later' };
