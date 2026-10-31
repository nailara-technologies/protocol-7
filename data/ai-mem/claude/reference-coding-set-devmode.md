---
name: coding-set-devmode
description: change a coding runtime value live [ e.g. inference.model.* sampler ] with `p7c coding.set <key> <val>` [ devmode ] -- tree-write refuses the inference namespace
metadata:
  type: reference
---

`p7c coding.set <key> <val>` [ devmode command, owner 2026-10-31 ]
[ devmod is OFF by default : `:: v7-zenki.devmod-enable <zenka>` loads it,
remembered across restarts until `v7-zenki.devmod-clear <zenka>` ; a `reload`
drops it unless `<zenka>.keep-devmod-loaded` ; `unload-devmod` removes it,
`unload-unsafe` only the unsafe ones [ WRITE to %data : set \ del, or
BLOCK : sleep and similar, or EXHAUST the host : eat-mem [ can take all
the host's memory in one command ], or RUN ANYTHING : exec-sub \ eval-code ;
get stays. BUT a zenka restart loads ALL of devmod again, unsafe ones
included, while the v7-zenki flag is set [ it does not tell unsafe apart
yet ] -- after testing : `v7-zenki.devmod-clear <zenka>` too, not only
unload-unsafe ] -- list with `:: <zenka>.commands devmod` \ `unsafe` ] sets a
live value in coding's %data, also `inference.model.*` [ sampler, DRY ].
read fresh per request, so an A\B test needs no config edit. a later
`coding.reload config` restores the start-file value.

`coding.get <key>` and `coding.del <key>` work the same way, directly on the
live value [ unlike `dump` \ `tree-write` ].

`coding.tree-write` is NOT that : it only writes the coding, context,
observations and task namespaces.

#,,,,,,..,,.,,...,,..,,..,.,,,,,,,,,.,,,.,,,,,..,,...,...,,.,,...,,.,,,.,,,,,,
#VI63VEOZRXUWUYFYFVKDBPIUZFKGBM7UO7HRG53KUNW4F5YZXHVWZB2NBGU45BVC67LFT7EBOBLGI
#\\\|Q5XGIWOUMB2UZLR5M43PUGFGCU4KYUATAT3JHJ6IZJOYX5MIIF2 \ / AMOS7 \ YOURUM ::
#\[7]O6CLSUAZMVX2HQSS7SHZCT4JB7EKNZBCUJRUIGE27UCKP5XP3UDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
