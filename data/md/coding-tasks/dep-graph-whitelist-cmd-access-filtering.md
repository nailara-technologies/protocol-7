# Task: dep-graph whitelist — loaded-set boundary enforcement

## Core Bug

`walk_reachable` in `bin/dev/dep-graph` follows all static call edges in the
global dep-graph regardless of whether the target module's namespace is actually
loaded by the zenka. this causes modules from unrelated zenki to leak into
every whitelist.

### Example: X-11 zenka

X-11 loads: `auth net protocol io.unix io.ip X-11`

yet its `--list-subs` output includes subs from `channels.*`, `httpd.*`,
`httpsd.*`, `v7.*`, `p7-log.*`, `set-up.*`, `crypt.*` — none of which
are in the loaded set.

### Leak path

```
plugin.auth.auth-keypair.tofu-notification
  → channels.cmd.update          [ static call edge ]
    → channels.util.yaml_decode  [ walked transitively ]
    → channels.handler.data_change
```

`plugin.auth.*` is correctly included [ auth is loaded ]. but
`channels.cmd.update` is a call that would fail at runtime if channels
is not loaded — the whitelist should not include it.

same pattern causes httpd/httpsd/v7/p7-log subs to appear in zenki
that never load those namespaces.

## Root Cause

`walk_reachable` (line ~1190) is a plain BFS over the dep-graph with no
boundary check. it follows every edge in `$graph->{$module}` into any
target, even if that target belongs to a namespace the zenka never loads.

the loaded set (`$loaded_set`) is available and already used for scoping
cmd/console/lifecycle subs — but the core `walk_reachable` walk itself
is unconstrained.

## Fix: loaded-namespace boundary filter

after the full reachable set is built [ after lifecycle subs, line ~882 ],
filter out subs whose top-level namespace is not in the loaded set.

### determining shared vs zenka-owned namespaces

shared namespaces are loaded by most/all zenki via `base.*` and are always
valid targets: `base`, `io`, `net`, `auth`, `protocol`, `plugin`, `event`,
`file`, `chk-sum`, `log`, `crypt`.

zenka-owned namespaces correspond to directories in `configuration/zenki/`
— these should only appear in the whitelist if they are in the loaded set.

the filter logic:
1. build `%loaded_ns` from `$loaded_set` top-level prefixes [ already done at line 856 ]
2. build `%zenka_ns` by scanning `configuration/zenki/` directory names
3. for each sub in `%reachable`: extract top-level namespace prefix
4. if prefix is in `%zenka_ns` AND NOT in `%loaded_ns`: remove from reachable
5. subs with non-zenka prefixes [ shared namespaces ] are always kept

### placement in code

insert the filter between the lifecycle-subs loop (line ~882) and the
existing access.cmd filter (line ~884). this way:
- the reachable set is fully expanded first [ including runtime loads ]
- the namespace boundary is enforced
- the access.cmd filter then further narrows cmd subs [ Phase A, already implemented ]

### devmod special case

`devmod.*` enters via `base.sig_NUM53` → `load_runtime_modules('devmod')`.
the runtime-load scanner (line ~770) correctly adds devmod to `$loaded_set`,
so devmod subs pass the namespace filter. the existing access.cmd filter
(line ~884) then narrows devmod cmd subs to those permitted by access config.
no special handling needed — the two filters compose correctly.

## Acceptance criteria

- [ ] X-11 whitelist contains zero channels.*/httpd.*/httpsd.*/v7.* subs
- [ ] httpd whitelist still contains all httpd.* subs [ httpd is in loaded set ]
- [ ] cube whitelist still contains all its subs [ cube loads everything it needs ]
- [ ] zenki with `modules.load = auth net protocol io.unix io.ip ZENKA`
      contain only base/shared + ZENKA namespace subs
- [ ] regression: whitelists for zenki that explicitly load a namespace are
      unchanged from current output

## Related files

- `bin/dev/dep-graph` — `walk_reachable` (line ~1190), `analyze_zenka_reachability`
  (line ~628), `$loaded_set` construction, lifecycle-subs loop (line ~846),
  access.cmd filter (line ~884)
- `bin/dev/gen-sub-whitelist` — whitelist file writer
- `configuration/zenki/*/subroutine.white-list` — generated output
- `configuration/zenki/*/start` — `modules.load` defines loaded set
- `modules/plugin.auth.auth-keypair.tofu-notification` — example leak path
  [ calls channels.cmd.update ]

## Notes

- do NOT hardcode namespace lists to filter [ httpd, httpsd, etc. ].
  the filter must be generic: derive zenka-owned namespaces from
  `configuration/zenki/` directory listing, check against loaded set.
- `walk_reachable` itself should remain unconstrained — the filter is
  a post-pass, not a walk boundary. this keeps the walk simple and
  avoids breaking the reachability analysis for other output modes.
- the existing access.cmd filter (Phase A) is already correct and
  composes with this fix — no changes needed there.

#,,,,,,..,.,.,,,.,,.,,,.,,.,,,,,,,,.,,...,,..,..,,...,..,,...,..,,,..,.,,,...,
#AEDASVB6ZCKGUCCO5RF4GC5ALDSAC2L5OZ5CEQBDOLSMAPAEAI7AJIWJ2ZV7KKACREUX5S7RBVIWY
#\\\|BQ74P2EB3UPG7NZSFZI3LNZZDUEJMPOEYRC4O3I2ZYRDBECBIPW \ / AMOS7 \ YOURUM ::
#\[7]OHTWBPXCPH5RMXWLE5N5HC3FFAXKYVQOWRT2IBGPYBEY6HPVLIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
