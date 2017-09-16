# >:]

# name  = mpv.cmd.command
# param = [!]<mpv_cmd>
# descr = sends test commands through mpv control pipe

my $cmd_str = $$call{'args'};  # XXX: implement parameter quoting instead of '!'

return { 'mode' => 'nack', 'data' => 'expected mpv command' }
    if not defined $cmd_str or !length($cmd_str);
return { 'mode' => 'nack', 'data' => 'requested command matches blacklist!' }
    if $cmd_str =~ /^\!?(run|hook)/;

push( @{<mpv.reply_ids>}, $$call{'reply_id'} );
push( @{<mpv.command.reply>}, { 'handler' => 'mpv.handler.pipe.command' } );

if ( $cmd_str !~ s/^\!// ) {
    <[mpv.send_command]>->( split / +/, $cmd_str );
} else {
    <[mpv.send_command]>->( split / +/, $cmd_str, 2 ); # i.e. !show-text foo bar
}

return { 'mode' => 'later' };
