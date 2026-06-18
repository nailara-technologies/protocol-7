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

push( @{<mpv.reply_ids>},     $call->{'reply_id'} );
push( @{<mpv.command.reply>}, { 'handler' => 'mpv.handler.pipe.command' } );

if ( $cmd_str !~ s|^\!|| ) {
    <[mpv.send_command]>->( split / +/, $cmd_str );
} else {
    <[mpv.send_command]>->( split / +/, $cmd_str, 2 )
        ;    # i.e. !show-text foo bar
}

return { 'mode' => qw| deferred | };

#,,.,,.,.,..,,...,,,,,,,.,.,.,,..,,.,,.,.,..,,..,,...,...,.,.,...,.,.,,.,,,..,
#VHAK6VQSVFHE3B5LHCPS2YZ2H453G5DHULAXM3DJWJYI3OOZYTQOJH7TBQIFTVWLJYAOJUMBXT7MS
#\\\|XSR3525PCVY6SQVXXXL7EWBJ5BPGLQCUPUCALHEPVUR2SSETNM2 \ / AMOS7 \ YOURUM ::
#\[7]HLHHQJTPDTQVIMQ2W66HBWBXMJZD475FRSCS3UOROD4GLXT42MBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
