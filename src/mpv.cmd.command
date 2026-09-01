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
    <[mpv.send_command]>->( split m| +|, $cmd_str );
} else {
    <[mpv.send_command]>->( split m| +|, $cmd_str, 2 )
        ;    # i.e. !show-text foo bar
}

return { 'mode' => qw| deferred | };

#,,,,,,.,,.,,,,.,,,..,,,.,,..,...,,..,...,.,,,..,,...,...,,..,,.,,...,.,.,...,
#NU2YF6HQ7WXOPYYNLLXW7V332BQNAJXHYHOJTXH4KOZFGFPSMJVXNYFRNY536FMLNQQWD7FL67BFS
#\\\|RUFNPQDCF2RIHK6PTE7OPPYBSZBMPXADJFRDHHUXHSCA43VMU5P \ / AMOS7 \ YOURUM ::
#\[7]6W26BYC3Y2WTEYMHYWXLL2RO2C33EDCUIF4NBRFWZHIAYUUQL4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
