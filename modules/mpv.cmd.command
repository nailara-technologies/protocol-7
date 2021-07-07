## >:] ##

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

#,,.,,.,.,.,,,...,...,,.,,,,,,,,,,,,,,.,,,...,..,,...,...,,..,,..,...,...,.,.,
#YUXHVMW2Z3TTMXK6VPWBHMUS52UGHL5SCCWVQJCCAWCINR6H7YNE5ATOLNKBULEJG5MABTTLY7RWI
#\\\|UYE6QVBAWGUREQQJZ64UO64U5F2AYTUTIGHGWPEKNKJ6YYUS7CR \ / AMOS7 \ YOURUM ::
#\[7]6Z4C6OUJEXPPBJADXSKFEJBV35GGYBKDBE5JPLXGZXYD3GZ5YOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
