## [:< ##

# name  = mpv.cmd.command
# param = [!]<mpv_cmd>
# descr = send raw command through mpv control pipe

my $cmd_str
    = $call->{'args'};    # LLL: implement parameter quoting instead of '!'

return { 'mode' => qw| false |, 'data' => 'expected mpv command' }
    if not defined $cmd_str or !length($cmd_str);
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

return { 'mode' => 'deferred' };

#,,.,,.,.,,..,.,,,,..,,.,,.,,,,,,,,,.,..,,...,..,,...,...,...,,..,,,.,..,,.,,,
#4VWHFQGUT34UMHLRE5AWHECVLCDY5N4XX6OOJRHK6MJKFXVBY3JC5DQNRYQMHKGUVEXUVZGDNJ4IU
#\\\|OITZRAR5VEMFXY2EG3KBOIJUCCK5WQBZF3SALQ7NH34Z4VTITGZ \ / AMOS7 \ YOURUM ::
#\[7]T6FXTRKLQMDGYSJAVLECFEF6VADAMGSWLWYAZ5FWSCMXGL4UKSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
