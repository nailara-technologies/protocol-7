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

#,,..,,..,,,.,,,.,...,.,.,..,,.,.,..,,,..,,..,..,,...,...,.,.,.,,,,..,,,.,,,.,
#OCHBUHMNZQZ2M7DKUWB5L2E3JUCEWF5IDLSO4Z5TNLDJYY74QOCP53ZAZNKFOYOQDBSXGWUGXJTHU
#\\\|TUXEYMPUKS6I3RWEFD7AUGFSXLOUQRLWM5FKV26BUBPCCQTHGJ6 \ / AMOS7 \ YOURUM ::
#\[7]2UMEI3VP6TXFFL4TT4CFLKJZJCH4CQ3XYHOGTITAKNWVAXCCOUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
