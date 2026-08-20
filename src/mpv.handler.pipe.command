## [:< ##

# name = mpv.handler.pipe.command

my $cmd_reply_str = shift // '';
my $reply_id      = shift // '';

if ( length($cmd_reply_str) and $cmd_reply_str !~ /\n/ ) {
    <[base.callback.cmd_reply]>->(
        $reply_id,
        {   'mode' => qw| true |,
            'data' => $cmd_reply_str
        }
    );
} else {
    $cmd_reply_str .= "\n" if length($cmd_reply_str);
    <[base.callback.cmd_reply]>->(
        $reply_id,
        {   'mode' => qw| size |,
            'data' => $cmd_reply_str
        }
    );
}

#,,.,,,,,,,..,...,,.,,.,.,.,.,...,...,,.,,.,.,..,,...,...,,..,,.,,,.,,,,.,,.,,
#MPK2IPNNZP546DYYY4OL44EKJGLXL4EVZK5DNLXUEXXY63I4FZMLIJJOAERBUO7PV4PEPJFVKJ5VG
#\\\|ERTIOR2VQZLI7WXEX3EQPUS5ZFTPIP7OYYNJTWLK657WD36PCB6 \ / AMOS7 \ YOURUM ::
#\[7]GJL3AJJ5QNXFBXJVSJ3O7OXWR6FLSDCA5K7TIYSB7HP4G4YFPCDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
