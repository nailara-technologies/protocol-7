## [:< ##

# name  = mpv.cmd.command
# param = [!]<mpv_cmd>
# descr = send raw command through mpv control pipe

my $cmd_str = $call->{'args'}
    // '';    # LLL: implement parameter quoting instead of '!'

return { 'mode' => qw| false |, 'data' => 'expected mpv command' }
    if !length($cmd_str);
return {
    'mode' => qw| false |,
    'data' => 'requested command matches blacklist!'
    }
    if $cmd_str =~ m,^\!?(run|hook|subprocess),;

push( <mpv.reply_ids>->@*,     $call->{'reply_id'} );
push( <mpv.command.reply>->@*, { 'handler' => 'mpv.handler.pipe.command' } );

if ( $cmd_str !~ s|^\!|| ) {
    <[mpv.send_command]>->( split / +/, $cmd_str );
} else {
    <[mpv.send_command]>->( split / +/, $cmd_str, 2 )
        ;    # i.e. !show-text foo bar
}

return { 'mode' => qw| deferred | };

#,,,,,,..,,,,,..,,...,,.,,.,.,,,,,..,,.,.,.,,,..,,...,...,..,,...,,.,,,,.,..,,
#ERSU5GTHTEF456C7ZI2IAINBILUNIWJ63W27RZBVCDBSPI7O5N2T6FKORSKUWPQICATZKVDKWEL5Q
#\\\|2J7SY3VO5BYP37NZKHLD5VJ6MBHEACBV5PAPBMW7QLPYGMDMB2D \ / AMOS7 \ YOURUM ::
#\[7]ZJIVYQJOVM5OLZFNYPNA6ODPPFD7VR5FNIYSGD64PFAYP56NVSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
