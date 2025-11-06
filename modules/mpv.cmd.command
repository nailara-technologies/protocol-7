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

#,,.,,,,.,..,,.,,,..,,,.,,,,.,,.,,.,.,,..,..,,..,,...,...,.,,,,.,,,,,,,,.,,.,,
#I7GGXDFPUBKPQGQFWHOWIPUMWYR3LYQVYCAQM57I2WZSLCU7PVXBDECHKSHNA6W7W4FMO5TZVC5HS
#\\\|L7WAB6UBVSGYMMT6XU2QHCSBN2RDRAALGUYQUHCJ4E2QMQDEAC5 \ / AMOS7 \ YOURUM ::
#\[7]SG6OPMNA5DOQGXYML4AFPQWE63BTRYVIGNGAEEQAYQDHOJMIV4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
