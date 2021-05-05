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
        {   'mode' => qw| size |,
            'data' => $cmd_reply_str
        }
    );
}

#.............................................................................
#QXHDCKXYGHJMQYDIGURXSQTABUFZ3EZEGMUVDCBDZUA4FE4RT4RLG52ZAWFCKMUNOGJYM5FAM2KMO
#::: DV6AYCJKK7VJZZZKCGAI7TKRADZQ2OSN35TUHYTM5Q3DN3ZLFX2 :::: NAILARA AMOS :::
# :: 736AJNZ7W2OIPU5YOMT65GHRCJR6X4Q2TV7QOUM74HQJUOU5X2AI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
