## [:< ##

# name  = mpv.cmd.command
# param = [!]<mpv_cmd>
# descr = send raw command through mpv control pipe

my $cmd_str
    = $$call{'args'};    # LLL: implement parameter quoting instead of '!'

return { 'mode' => qw| false |, 'data' => 'expected mpv command' }
    if not defined $cmd_str or !length($cmd_str);
return {
    'mode' => qw| false |,
    'data' => 'requested command matches blacklist!'
    }
    if $cmd_str =~ m,^\!?(run|hook|subprocess),;

push( @{<mpv.reply_ids>},     $$call{'reply_id'} );
push( @{<mpv.command.reply>}, { 'handler' => 'mpv.handler.pipe.command' } );

if ( $cmd_str !~ s/^\!// ) {
    <[mpv.send_command]>->( split / +/, $cmd_str );
} else {
    <[mpv.send_command]>->( split / +/, $cmd_str, 2 )
        ;    # i.e. !show-text foo bar
}

return { 'mode' => 'deferred' };

#,,,,,,..,,.,,,..,,,.,,..,,,,,.,.,.,,,.,.,...,..,,...,...,.,,,.,.,,,,,..,,...,
#2E6EEQSYJGUT2VAOQ6XUG2KJXMKXCU623R7CBPLESOQEWUNTLYFEL75YRTWXNHLAZKQU3C2W6LS7O
#\\\|OJJI6NIAIMM4UUNV4GLXBBXGHSWROI4WN2SM7KYMZN6P4UTOFXU \ / AMOS7 \ YOURUM ::
#\[7]2VGN5OUYY2DZS5NFWSAADBWPBHPK45KV7CJCJUJHNKENWMAHTACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
