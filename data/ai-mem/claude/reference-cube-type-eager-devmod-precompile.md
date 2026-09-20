---
name: reference-cube-type-eager-devmod-precompile
description: cube-type zenki (system.zenka.type = cube) eagerly pre-compile devmod via subroutines.load-early on purpose -- appliance filesystem-crash resilience, not a bug to clean up
metadata:
  type: reference
---

`system.zenka.type = cube` zenki [ `cube`, `cube-13` confirmed so far ] have
`devmod.*` entries in their `subroutines.load-early` whitelist that
`bin/dev/dep-graph`/`bin/dev/gen-sub-whitelist` regenerate deterministically
even after manual removal — traced 2026-09-20 to a real, reproducible
dep-graph edge (`base.init_code`'s `dump_var()` global debug helper, a
`$code{'devmod.dump'}` canary check) that only resolves to an included edge
for cube-type zenki, not regular client zenki [ confirmed: `credentials`,
`weather`, `nshell` all show zero devmod-reachable subs via the identical
dep-graph tool, despite loading the exact same `base.init_code` ].

**this is deliberate, not a bug or leftover cruft** — user's own words: "a
feature for the case of devmod enabled in config, compared to the ondemand
loader that ignores the whitelist and loads them all... ensuring no lazy
loading occurs, since over a decade ago with the appliances there were cases
of disappearing or crashing filesystems, and in such cases only what is
already compiled is available." Cube-type zenki are the routing hubs; eager
startup-time compilation (while the filesystem is presumably still healthy)
means debug/recovery tooling stays available even if the filesystem later
vanishes mid-run — lazy/on-demand compilation would need to read source
files from disk at the moment of first use, which could be exactly when
it's least available.

**don't hand-prune cube-type zenki's `subroutines.load-early`** the way the
rest of the [[devmod-zenki-sweep-classification]] sweep did for regular
client zenki (that cleanup was correct there — it only affects eager-vs-
deferred compile *timing*, never access/reachability, which is governed
entirely by `access.cmd.usr.*`/`access.devcmd.usr.*`). For cube-type zenki
specifically, the eager pre-compile is load-bearing for the filesystem-loss
resilience property. If it needs touching again, regenerate via
`bin/dev/gen-sub-whitelist <zenka>` and accept the output rather than
manually stripping devmod entries.

**future direction** [ not built yet ]: user's stated plan is to eventually
keep a packed copy of the source in RAM regardless of compile state, so
"lazy loading only becomes lazy compilation, not breaking with a
filesystem" — i.e. decouple the resilience property from eager compilation
specifically, letting cube-type zenki use normal deferred compilation too
once source availability no longer depends on the filesystem being present
at first-use time.

#,,,.,,.,,,,.,,,.,,,,,,,,,,.,,,.,,..,,,..,,..,..,,...,...,..,,,,,,.,.,,.,,.,.,
#FIUO37BO7RQSXABLS447TWR2X4ORSU4O3WR252SHKOAWRS4OPKRAYZ36U6TYASSC5UBXEGBWCLGF4
#\\\|EU7YWHQC3JLH3EL6E7N2NYODDLLJBPJEN6LPQ7573MGCBGLWDE7 \ / AMOS7 \ YOURUM ::
#\[7]FBTOZ7TMWYIJ2SWVUMCZQGA22HBK4CFLZSEQMTYTCQW6TZNN2YAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
