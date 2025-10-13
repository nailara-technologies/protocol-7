## [:< ##

# name = mpv.handler.pipe.command

my $cmd_reply_str = shift // '';
my $reply_id      = shift @{<mpv.reply_ids>};

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

#,,,.,,,,,,,.,,..,.,.,,..,,..,,..,...,,.,,..,,..,,...,...,,,,,,,,,.,,,,.,,,,.,
#FYUNXOSQOZOGB7FXWA3CORRQ5CMH6UYRE44ZHOUZWF32F3UNLMUW4RB2IWPDNMJHNC6YZTCW7ZB76
#\\\|FPUSP2ED4MXJ6CSJGD6ZA6QF4CK5P6YSRT2M7NOZWXSYPAOSRPN \ / AMOS7 \ YOURUM ::
#\[7]IWP4B4JHJWQCXR7YYZEV7BXDVTAKBJLPFTTIU77C55IY4DQO22CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
