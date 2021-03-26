# >:]

# name = mpv.handler.pipe.command

my $cmd_reply_str = shift // '';
my $reply_id      = shift @{<mpv.reply_ids>};

if ( length($cmd_reply_str) and $cmd_reply_str !~ /\n/ ) {
    <[base.callback.cmd_reply]>->(
        $reply_id,
        {   'mode' => 'ack',
            'data' => $cmd_reply_str
        }
    );
} else {
    $cmd_reply_str .= "\n" if length($cmd_reply_str);
    <[base.callback.cmd_reply]>->(
        $reply_id,
        {   'mode' => 'data',
            'data' => $cmd_reply_str
        }
    );
}

#.............................................................................
#NS4XY6IHK7V6Y6TVAQH3U7KHDMNREG75F7VTJYOOLNPIT4BMQOYA7U36VPFMRYWYVQ7PMMLTQNILO
#::: PASOFLC72OVU55VYCNRJXYRBTORMISZGNW6644GVFYJIEKUPQL7 :::: NAILARA AMOS :::
# :: 55U4QHY465BX4BM6GAZEHRHQNX54NJHJOUEZUKT4IPZ7AMTOQSBQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
