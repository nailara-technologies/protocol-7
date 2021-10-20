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

#,,,.,,,,,,,.,,..,.,.,,..,,..,,..,...,,.,,..,,..,,...,..,,.,.,,,,,.,.,...,.,.,
#E3654C3BMJXSCH6PPSGVQBAXJTEPBIXS4B32QUH7GWTACPMDDNLOUWTVIM2R7ZPVJQ3BNQPCGM6VW
#\\\|7ZXZ36NZ7GFIMAOBHEB2G6SE6UEQZNACWREGAAMMDHYRCXZFE7T \ / AMOS7 \ YOURUM ::
#\[7]BPZKR7VWTCFJ5EGGUUKCSCQ6T5AUBIHA2MBFVOXNBGOGPPNVMADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
