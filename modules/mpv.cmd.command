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

#,,,,,,..,,.,,,..,,,.,,..,,,,,.,.,.,,,.,.,...,..,,...,...,...,,,.,,..,,,,,,.,,
#RVKR72KYQ2TD5GRPFVCFO66GIYCONT52OPW7X65FKP6FBFGNHNMZ62O26JNECOAXBPLEWH2NYRJR2
#\\\|Z34PLUOSWFYPS73BBCNXJES43FZ4JTAXFJMRTH4NYOBKSHMFNSF \ / AMOS7 \ YOURUM ::
#\[7]23ECVAI4ZIF3ULEKSVBKOSJR4JJAW47BGWROVHU67QYY3E3L5MAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
