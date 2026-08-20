---
name: v7.restart cube restarts all zenki
description: use v7.restart cube to implicitly restart all zenki (except v7 itself); no need to restart each individually
type: feedback
originSessionId: 982c43a3-00c1-40ac-9d1c-a6fafdb428c8
---
`p7c v7.restart cube` restarts cube and causes all connected zenki to reconnect, effectively restarting the whole network except v7.

**Why:** Much faster than restarting each zenka individually when config changes (e.g. access.zenki) affect the whole network.

**How to apply:** After editing `cfg/zenki/cube/access.zenki` or other global cube config, use `v7.restart cube` instead of reloading cube + restarting each zenka.

#,,,.,,..,,.,,,.,,,..,,..,.,,,.,.,...,,.,,.,.,..,,...,...,...,.,.,,..,,,.,,,,,
#N4XAZWTZNFSLPLW3MYYSDBPM3C56ZEQCSYV3SCFFZO7ZJKMJIB56MAFUJHNO2S6P536G3ELFOD3FQ
#\\\|QMFX7UHUKA2AUR3PFGWVOQTEKRDHQZLNVMQ7MKKOT2N5A3M2FFD \ / AMOS7 \ YOURUM ::
#\[7]XKQ6Y23U6DZX5ZI5RIB7JU53VQG4F4TOTXXLSMTBA46UCPGKVWCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
