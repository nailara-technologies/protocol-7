## >:] ##

# name = mpv.handler.pipe.command

my $cmd_reply_str = shift // '';
my $reply_id      = shift @{<mpv.reply_ids>};

if ( length($cmd_reply_str) and $cmd_reply_str !~ /\n/ ) {
    <[base.callback.cmd_reply]>->(
        $reply_id,
        {   'mode' => 'true',
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

#,,,.,,.,,,,.,,,,,,,,,,.,,.,,,,,.,,,,,,,.,,..,..,,...,...,.,.,..,,,..,...,,..,
#4N2CJI5CKILJYJE54OC4JB4M7ZMCKKEHQYBE5CHEAWVDOLCGZ7YR4ZNCVQELCNDKGOOKG43HHEUJE
#\\\|XO5LWVMHWHWCFWPR5ASYVK2M52NWF5BB7B2ZNV6YMVIIAC2OS5Q \ / AMOS7 \ YOURUM ::
#\[7]RMGYPD77NREIEQ7XQV6N5KPZ3EF5DONZNMXIQEIVMAXU3SIUDUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
