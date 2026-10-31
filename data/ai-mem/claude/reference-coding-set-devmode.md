---
name: coding-set-devmode
description: change a coding runtime value live [ e.g. inference.model.* sampler ] with `p7c coding.set <key> <val>` [ devmode ] -- tree-write refuses the inference namespace
metadata:
  type: reference
---

`p7c coding.set <key> <val>` [ devmode command, owner 2026-10-31 ]
[ devmod is OFF by default. `:: v7-zenki.devmod-enable <zenka>` now loads
SAFE mode only : read-only diagnostics such as `get`, never `set`, `del`,
`exec-sub`, `eval-code`, blocking commands, or memory-exhaustion commands.
For `set` or `del`, use `:: v7-zenki.devmod-enable-rw <zenka>` [ FULL mode,
the old devmod-enable behavior ]. the off \ safe \ full choice is remembered
across restarts until `v7-zenki.devmod-clear <zenka>`. `devmod-disable`
unloads everything, `devmod-unload-unsafe` reduces full to safe, and
`devmod-clear` only forgets the restart state. a `reload` drops devmod unless
`<zenka>.keep-devmod-loaded` [ full-only state-changing command ]. list with
`:: <zenka>.commands devmod` \ `unsafe` ] sets a live value in coding's %data,
also `inference.model.*` [ sampler, DRY ]. read fresh per request, so an A\B
test needs no config edit. a later `coding.reload config` restores the
start-file value.

`coding.get <key>` works in safe mode. `coding.del <key>` requires full mode ;
both act directly on the live value [ unlike `dump` \ `tree-write` ].

`coding.tree-write` is NOT that : it only writes the coding, context,
observations and task namespaces.

#,,..,,,.,,.,,,..,..,,,..,,.,,,..,...,...,..,,..,,...,...,...,...,..,,...,,..,
#UODWE3PAUXBT756GVDU5ZUCH75TKWUWCMESXJVJC3U2SE5ZZTMPVD5XJHXTDOVQJFNYPXG3TFDPRM
#\\\|CXLEQDRHPAIQBPU7RUJZP7K4IHGY6AAPCCDIHQFWF6LFLHFPJXM \ / AMOS7 \ YOURUM ::
#\[7]HKVT54BPHT6OTA443MHP7G5P6SUHKCYAUEYROZ2JBRJA7SS2LIDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
