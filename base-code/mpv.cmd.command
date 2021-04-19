# >:]

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

#.............................................................................
#4QFBCZTMDHS4HXUPRA2IKDY3UAFC2GYLB33TZPSWPK7TCFPNWJA6Z7PMC2CZNQ54AOOJ4E6V3744U
#::: RDUEHAADNI5EEBPGOTR5FWV2PPIWHAQYMA7U7BZUPBEOVH5WC26 :::: NAILARA AMOS :::
# :: WRQJ5TEAZ74MQ4IEJQVLSPZ6YSZ7IFQYYEADLFYNLJDTHFYMGICQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
