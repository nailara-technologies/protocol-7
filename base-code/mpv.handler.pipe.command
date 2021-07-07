## >:] ##

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

#,,.,,,,.,...,,,,,.,,,...,,,.,,..,,,,,,..,..,,..,,...,...,.,.,...,.,.,,..,.,.,
#33APUF2KD3NHXFR2OHMTG5R7ASP6UAIFOHCN7XTZC4HC7U35GNZ572HJ5ACWIYAJFQ363CAOILRY4
#\\\|ZLOPJL2ZHXBDZ7FWNQK6Z3I74GEAEXCJKVOXLCBDCHU32MRFHKR \ / AMOS7 \ YOURUM ::
#\[7]JHYBA2QZWIANGRTUZT2PMYHJLDHM3NCXX5ESXV7A52VEX2U2H4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
