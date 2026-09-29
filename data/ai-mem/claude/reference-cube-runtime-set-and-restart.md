---
name: reference-cube-runtime-set-and-restart
description: how to change a %data value in a running zenka [ cube ] and restart cube -- devmod-enable first, cube takes bare commands, v7-zenki.restart
metadata:
  type: reference
---

- `p7c set <key> <value>` on cube answers `command does not exist` until devmod
  is loaded : `p7c v7-zenki.devmod-enable cube` first [ user tip 2026-09-29 ].
  avoids a temp `zenka.v7` edit + restart for a runtime toggle
- devmod-enable is PERSISTENT : v7 remembers it and re-enables devmod after
  every restart of that zenka. `p7c v7-zenki.devmod-clear <zenka>` only
  clears the remembered state [ the next restart comes up without devmod ;
  the running process keeps it until then ]. clearing on another zenka
  than the caller needs the admin user. a restart is NOT a cleanup.
  full cleanup in one step : `p7c <zenka>.unload-devmod` [ undefines the
  devmod subs in the running process AND sends devmod-clear for its own
  instance ]
- cube takes BARE commands : `p7c reload source`, not `cube.reload`
  [ -> `client not present` ]
- restart cube : `p7c v7-zenki.restart cube` [ `v7.restart` -> not present ]
- Event.pm hooks [ `Event->add_hooks` ] can't be removed from a running loop :
  instrumentation installed that way needs a zenka restart to go away

**Why:** cost several round trips in the 70ms-stall session [ 227d50b90 ].
**How to apply:** runtime experiments on cube -> devmod-enable + set, not
config edits. see [[reload-success-doesnt-guarantee-new-file-loaded]].

#,,,,,...,,..,,.,,,.,,...,.,.,,..,,.,,.,.,..,,..,,...,...,.,.,,,,,,..,...,,,,,
#EVCJ7DUHLQIG5DWBYCQCKRPSMVU2ZJU5I4VC2VLSIAQ6ZCYXGY4RLWXWELIOYLUWOL63DNG5WEQ5E
#\\\|UCSWDJYAGTDVNZIQLQCI766S2KIQSRLSPDSJQZJ5GJYBQVKXJLG \ / AMOS7 \ YOURUM ::
#\[7]B2567CWJ6LUKRQK33B2IKAGDGY27N62LDS5PRAXN2BHJK73H4SAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
