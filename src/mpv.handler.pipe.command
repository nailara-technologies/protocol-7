## [:< ##

# name = mpv.handler.pipe.command

my $cmd_reply_str = shift // '';
my $reply_id      = shift // '';

if ( length($cmd_reply_str) and $cmd_reply_str !~ m|\n| ) {
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

#,,.,,...,.,.,.,,,,..,,,,,,..,,,,,...,,.,,.,.,..,,...,...,...,,,.,,,.,,,.,,..,
#45FW76QHWW4AL3JNU57MZU7GU5SOAZCJYAOONTDGLV3AHGGDGJRFZNNI5TM3PWPOQQO3MOWQV2L4S
#\\\|CHTWFPI6A44KFNYYQW7NNSMXVQSOBTIMDN3U7QAWEZEJNIVGFIJ \ / AMOS7 \ YOURUM ::
#\[7]C52XD6JNRD4FWK7RAORYQJEUKN56JYPCNFYJHJGQFDM6A6QRTEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
