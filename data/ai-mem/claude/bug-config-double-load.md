---
name: config double-load on startup
description: config files parsed twice during zenka startup — duplicate key warnings
type: project
---

## symptom
`duplicate config key 'auth.setup.usr.taeki'` and `access.cmd.usr.unix-taeki` warnings
appear on BOTH regular startup and reload for the cube zenka.

## cause
same config file (e.g. `configuration/zenki/cube/access.users`) is being read twice
during the startup sequence — once from zenka description load, once from start file.
confirmed: the key exists only once on disk.

## fix
add "already loaded" guard to the config file parser — track which files have been
parsed and skip on second encounter.

## status
pre-existing, unrelated to staged loader work. address as a separate cleanup.

#,,,.,.,.,...,,..,,..,,..,,..,.,,,,,,,..,,,..,..,,...,...,,..,,,.,..,,.,,,,,,,
#TMKVDFFWUEBZ2FZVRCNOZIDHMJXB73CSKHNMGXOH667B6ZGQOOXW2G7HPKXGBJJ7GD6G3YB54BOHQ
#\\\|67MS4L6HBLCYZN3NK66ONPL3PKPYQRFJX6PMKYGU3UMBG46MSDU \ / AMOS7 \ YOURUM ::
#\[7]UV23GRZF4SZBRI2FXTIAUOYLXJI2T5F7IXHPZTTITYHBGFRLWODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
