# >:]

# name  = mpv.cmd.command
# param = [!]<mpv_cmd>
# descr = send raw command through mpv control pipe

my $cmd_str
    = $$call{'args'};    # LLL: implement parameter quoting instead of '!'

return { 'mode' => 'nak', 'data' => 'expected mpv command' }
    if not defined $cmd_str or !length($cmd_str);
return { 'mode' => 'nak', 'data' => 'requested command matches blacklist!' }
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
#VP7BSMD2S33KOH3BIKIPLQKB7ATKKGG45POOJOZB7XNYXV6U5IZYMNGMJ2LYS7V3QQZNHJMN2N7DO
#::: LV2PB4C2B2PV5Q33T4U3BW6WUR2NH7KLAK643XMGWPCUG3A6UBP :::: NAILARA AMOS :::
# :: NKO3VS44P7Y5644RLIYGISUSA42EI657FLW5SSJKUWCGXBNJHKBA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
