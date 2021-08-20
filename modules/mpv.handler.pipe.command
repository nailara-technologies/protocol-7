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

#,,,.,,,,,,,.,,..,.,.,,..,,..,,..,...,,.,,..,,..,,...,.,.,.,.,.,.,.,,,,..,,..,
#CFXOWWDWTIBF4SOUZP2BLNHRM7F3NKQHCEC4HGHJBC26GZTUPDA5CCMJHYRGV7GG725EJCR7Q5TKC
#\\\|5A5RICBPAHK2KXMYFKJPPJA5Y4LLFDUPGYVJRPBIHQ24HZKV7CY \ / AMOS7 \ YOURUM ::
#\[7]7BCCGUDFGZIA7DVQFEDJJJ4BYQZNSWKRZH5EXR4FFPEW52Q5AMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
