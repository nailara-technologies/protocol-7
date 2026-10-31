---
name: reference-cube-runtime-set-and-restart
description: how to change a %data value in a running zenka [ cube ] and restart cube -- devmod-enable-rw first, cube takes bare commands, v7-zenki.restart
metadata:
  type: reference
---

- `p7c set <key> <value>` on cube answers `command does not exist` until devmod
  is loaded : `p7c v7-zenki.devmod-enable-rw cube` first [ user tip 2026-09-29 ].
  avoids a temp `zenka.v7` edit + restart for a runtime toggle
- devmod-enable-rw is PERSISTENT : v7 remembers it and re-enables devmod after
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

**Why:** cost several round trips in the 70ms-stall session [ 9bedf3c4c ].
**How to apply:** runtime experiments on cube -> devmod-enable-rw + set, not
config edits. see [[reload-success-doesnt-guarantee-new-file-loaded]].

#,,,,,...,,,.,,.,,...,,..,.,,,,,,,...,.,.,,.,,..,,...,...,.,.,..,,,.,,,..,...,
#3O6SIQWFE5DVTSRESAR63CCBYIXSEVSNQHI3GG3NIJTCJY22DTURDERRCIJ6FPKTNBRO36ZOSEH4G
#\\\|NCI33VQVIWG3JVGPFKVTGDDCERRL24HREHRD6JB3NIT4OZMPPD2 \ / AMOS7 \ YOURUM ::
#\[7]TD7LC4W5YSEYM5K4QDGG4UJVK332G4JXAE42LFX2TI2IKSFWVUAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
