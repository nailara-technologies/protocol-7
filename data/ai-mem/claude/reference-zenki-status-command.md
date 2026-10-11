---
name: zenki-status-command
description: to check whether protocol-7 \ a zenka is up use `p7c v7-zenki.list zenki` -- there is no v7-zenki.status [ a wait loop on it spammed 'command does not exist' ]
metadata:
  type: reference
---

`p7c v7-zenki.list zenki` lists the managed zenki and their state -- the status check after a restart \ teardown. `v7-zenki.status` does NOT exist : 2026-10-11 a wait loop polling it after a teardown filled the user's console with `command does not exist ['status']`. a single zenka : `p7c <zenka>.status` only where that zenka defines it [ nameserv does ] ; otherwise its line in `v7-zenki.list zenki`.

wait for a restart with ONE check after a pause, not a tight loop of failing commands. related : [[changed-established-behavior-silently]].

#,,,.,.,,,.,,,,.,,.,,,..,,...,..,,,,,,.,,,.,.,..,,...,...,,,.,,,.,.,,,...,,,.,
#PJAS2PV5MX7TQRK7MWFKJLLEBPVMTHUILTWKAMUZKJCZCKTU3225KKUDUQRGOOPRTIARNKE3UUWZM
#\\\|PSYYCREBTYLDTVKY4LGOOQPEWXPJKXFBMZB6MTZNSQDM64P37D6 \ / AMOS7 \ YOURUM ::
#\[7]NOU4XLRA43T5D7KJWWAOXLXP7TONBTIWCICYLK2QBUHCNW7G4CDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
