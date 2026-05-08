---
name: v7.restart cube restarts all zenki
description: use v7.restart cube to implicitly restart all zenki (except v7 itself); no need to restart each individually
type: feedback
originSessionId: 982c43a3-00c1-40ac-9d1c-a6fafdb428c8
---
`p7c v7.restart cube` restarts cube and causes all connected zenki to reconnect, effectively restarting the whole network except v7.

**Why:** Much faster than restarting each zenka individually when config changes (e.g. access.zenki) affect the whole network.

**How to apply:** After editing `configuration/zenki/cube/access.zenki` or other global cube config, use `v7.restart cube` instead of reloading cube + restarting each zenka.

#,,,,,,.,,,.,,...,..,,.,.,.,,,,,,,.,.,.,.,.,,,..,,...,...,,.,,,,,,..,,,.,,.,.,
#V34FC5KKB7SCQ6T3KQ5J5RVASEAVU7TFB2AYDTELKNMZNSL5NB6YDYD2PBVNZUULMS64CIAIFHMLC
#\\\|2YNGKWCAB4EX5XDM5SRKH3ZI2U3XOY7RHISUMJUFM7FPFP4RMF6 \ / AMOS7 \ YOURUM ::
#\[7]DRYZSPHH3YPJLDMS5X66MWIAWNWFFL2CYFFCGENTTQKTMV7TJSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
