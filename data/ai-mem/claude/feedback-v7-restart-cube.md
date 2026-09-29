---
name: v7-zenki.restart cube restarts all zenki
description: use v7-zenki.restart cube to implicitly restart all zenki (except v7 itself); no need to restart each individually
type: feedback
originSessionId: 982c43a3-00c1-40ac-9d1c-a6fafdb428c8
---
`p7c v7-zenki.restart cube` restarts cube and causes all connected zenki to reconnect, effectively restarting the whole network except v7.

**Why:** Much faster than restarting each zenka individually when config changes (e.g. access.zenki) affect the whole network.

**How to apply:** After editing `cfg/zenki/cube/access.zenki` or other global cube config, use `v7-zenki.restart cube` instead of reloading cube + restarting each zenka.

#,,,.,,,.,,.,,...,,,.,...,,..,.,,,..,,,,.,..,,..,,...,...,...,,,,,...,...,,,,,
#SYJQ52AMZP7ZOJBJVCSQZEO6FHGFRMY4MN6SNI27X6BA4H6QUWJLDU6IWIB6UTV2DOZSZGI2SVC64
#\\\|NDSBOYT66BCHO47DXCG67QNWHGSAAQUXNUH4A7RU6HNU74AWVOJ \ / AMOS7 \ YOURUM ::
#\[7]6SOMY2VQYKP44OQAPS5WYUZPEXKICL7ZSBGFAYYWIEV5P4MUVUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
