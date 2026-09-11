## [:< ##

# name  = task: reunite models.scan_paths and models.storage.search_paths
# descr = the models zenka's model-discovery scanner and its user-facing
#         scan-path-add/del/list commands read and write two entirely
#         separate, disconnected data structures -- paths added via the
#         user-facing command are silently never actually scanned

## context

found 2026-09-10 while investigating an unrelated LoRA-training task,
via `ncode s src:models. scan-paths` -> `src/models.init_code:63`.

## the bug, confirmed by reading every reference [ not just the init file ]

two separate structures exist and are NOT kept in sync:

1. **`<models.scan_paths>`** (a HASH, keyed by path-id) --
   `models.init_code:40` initializes it empty. `models.cmd.scan-path-add`
   / `models.cmd.scan-path-del` read and write ONLY this one.
   `models.storage.yaml_load` / `yaml_save` persist ONLY this one to
   disk. `<list.scan-paths>` (`models.init_code:63-72`, the definition
   `models.list scan-paths` renders) reads ONLY this one
   (`'key' => 'models.scan_paths'`). **This is the structure the user-
   facing commands and the `list` output actually operate on.**

2. **`<models.storage.search_paths>`** (an ARRAY of `{path, enabled,
   recursive, tier}` hashes) -- `models.init_code:149-167` hardcodes
   three defaults on first init: `/mnt/ext-xfs-data/models-lmstudio`
   (tier 2), `/mnt/ext-xfs-data/models-invoke` (tier 4), and
   **`/data/models`** (tier 5, `recursive => FALSE`) -- note this last
   default path does not even exist on disk on this host (confirmed
   2026-09-10, permission denied creating it as a non-root user; also
   unrelated to but coincides with a real host-disk-space hazard, see
   `[[feedback-...]]` if one gets written about the WSL2 C:\ constraint
   -- not this task's concern, just noted). **This is the structure the
   actual model-discovery SCANNER reads.**

**the disconnect**: `models.storage.discover.discover_models:7` reads
`<models.storage.search_paths>` directly, no fallback, no awareness of
`scan_paths` at all. `models.discover.scan_all_paths:13-20` is aware of
both -- its own comment says "`models.storage.search_paths` is the
canonical shape; fall back to `models.scan_paths` ... and convert" --
but the fallback only fires `if ( !@$search_paths && ... )`
(`scan_all_paths:18`). Since `search_paths` is hardcoded to 3 entries at
init and nothing ever empties it, **that fallback condition is never
true in practice, so anything added via `scan-path-add` is silently
never included in an actual discovery scan** -- it shows up correctly in
`models.list scan-paths` (cosmetically working) and persists to YAML
correctly, but has no effect on what `models.discover` actually finds.

## the real fix [ per the user, 2026-09-10 ]

**reunite the two into one structure**, then adjust `<list.scan-paths>`
if it still needs changes afterward. concretely:

1. decide which shape is canonical going forward -- the hash-by-id
   (`scan_paths`, user-facing/persisted) or the list-with-metadata
   (`search_paths`, tier/enabled/recursive) -- or a merged shape that
   keeps `scan_paths`' persisted-hash identity (so `scan-path-add`/`del`/
   the YAML persistence keep working unchanged) while carrying
   `search_paths`' per-entry `enabled`/`recursive`/`tier` fields as
   values in that same hash, rather than two containers.
2. **migrate the 3 hardcoded defaults into the reunited structure on
   first init** (as pre-registered `scan_paths` entries, e.g. via the
   same code path `scan-path-add` itself uses) so existing behavior for
   the two real, already-scanned paths (`models-lmstudio`,
   `models-invoke`) doesn't regress -- decide whether the dead
   `/data/models` default should be dropped entirely or kept but
   flagged, given it doesn't exist on this host.
3. update `models.storage.discover.discover_models` to read the reunited
   structure directly (no separate `search_paths` variable at all), and
   simplify/remove `models.discover.scan_all_paths`'s now-dead fallback-
   and-convert logic once there's only one shape to read.
4. re-check `<list.scan-paths>`'s `mask`/`align` (`models.init_code:63-
   72`) against whatever the final per-entry shape looks like -- it
   currently only renders `id`/`dir_path`; if `enabled`/`recursive`/
   `tier` become part of the merged entries, decide whether the list
   view should surface them too (probably yes, tier/enabled at least,
   since those are exactly the fields users would want to see when
   deciding what `scan-path-add`/`del` to run).
5. verify live: `scan-path-add` a new directory, confirm it actually
   shows up in a real `models.discover :re-scan:` (or whatever the live
   rescan command is) afterward -- that end-to-end path is exactly what
   is broken today and exactly what needs to be proven fixed, not just
   "the code reads one variable now instead of two."

## explicitly out of scope

- no relation to the LoRA/coding-zenka work this was found during --
  purely a `models` zenka bug, independent thread
- don't assume the specific merged shape proposed in step 1 without
  checking whether anything else (a UI, another zenka) reads
  `models.storage.search_paths` or `models.scan_paths` directly by name
  beyond the 6 files already found via `grep -rl "models.storage.
  search_paths\|models.scan_paths" src/` (re-run that grep before
  assuming this task file's file list is still exhaustive, in case
  something new landed since 2026-09-10)

do not add any trailing signature/checksum footer to this file or any
new file for this task -- the real signing pipeline (`bin/Protocol-7
sourcecode update-signatures`) adds that later.

#,,,.,,,,,..,,,..,,.,,..,,,..,..,,..,,...,,,,,..,,...,...,...,,..,,..,,,,,.,,,
#P73BW6CCI7BI7AQNK2XOSOACKW3QFSFDDEBJI3ZGLQCHWCTJJFX7UHU7AEMKIIY223TWZUGCFKTXE
#\\\|AUZN34VO257WCYNSME5DUL4HB3HC3S6Q24RCG2FMIUYRX3O47VU \ / AMOS7 \ YOURUM ::
#\[7]WNT6LXNOZF5TKGMVSVZSC3SE42IZONYFMSWF77NKXL55HQ6DCAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
