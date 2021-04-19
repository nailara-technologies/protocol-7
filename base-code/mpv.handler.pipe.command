# >:]

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
        {   'mode' => 'data',
            'data' => $cmd_reply_str
        }
    );
}

#.............................................................................
#M46EDREPI3HXOUOGQ7JJ5PGXA5GF2THXV4VFREJRUMLHTUOONS72GHUPNNLT744ZQKNV2QCMOFIDU
#::: 2FOWQJTPBUAXKN33FE3PF2663NQOEUG2YDPQKEFNWBIS5G4OP6J :::: NAILARA AMOS :::
# :: N327BG7K5TW6WQWWQGOYNPDYKGEPLU4ZXHY67CZP6VW4NTFI46DQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
