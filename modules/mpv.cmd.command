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

#,,,,,,..,,.,,,..,,,.,,..,,,,,.,.,.,,,.,.,...,..,,...,..,,...,,,.,..,,,,.,,,,,
#BT2FVOO65WWX2747MUBFJT5SBYJJPANQDMJXDGRYONNMUCFKRFFVCZ2XNDL22RM6ZNCJY5BELAS5O
#\\\|TNSYP5SFZUIGABULHHFA4KKOSKAIEMHRIHV6SKX3G6Q3J4MLCP2 \ / AMOS7 \ YOURUM ::
#\[7]WDB3NCYPTFKCZJ2XRMQOFYBJIEBHQCNAYMRKSMSPLY3G3W356YAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
