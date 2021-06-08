## >:] ##

# name  = mpv.cmd.command
# param = [!]<mpv_cmd>
# descr = send raw command through mpv control pipe

my $cmd_str
    = $$call{'args'};    # LLL: implement parameter quoting instead of '!'

return { 'mode' => 'false', 'data' => 'expected mpv command' }
    if not defined $cmd_str or !length($cmd_str);
return {
    'mode' => 'false',
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

#,,,,,,,,,..,,...,...,,,,,...,...,,.,,,.,,..,,..,,...,..,,.,,,,..,,..,,,,,...,
#CNORE2P7B3XJB3X3NXKYTIB22USM2RVR47GJO2EHCKZFNYUWBFQS2TLD4EBY3T4VPQQWP2R7UMDQW
#\\\|5MYBM3IMT2RVQMGS6DF2L67OS66TROOWKOKYHGD6JVJQRDERAUC \ / AMOS7 \ YOURUM ::
#\[7]NRASTRPIQGI2KOEU3JYS6UREXNP4USPIMSVYG5XZYG2MEXDDBKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
