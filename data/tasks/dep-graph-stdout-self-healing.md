# task: dep-graph stdout mode + zenka self-healing whitelist

## context

zenka whitelists are statically generated at build time by `bin/dev/dep-graph`.
when a module is missing from the whitelist (stale list, namespace move, new
dep added), the zenka logs NOT FOUND and the module is unavailable until the
whitelist is manually regenerated and the zenka restarted.

self-healing solves this post-init, with no startup latency constraints.
the zenka runs an on-demand dep-graph scan of its own namespace, validates
signatures, applies its configured policy to the result.

## design: subprocess, not module loading

dep-graph runs as a **forked subprocess** — not loaded as modules into the
zenka. reasons:

- dep-graph is already a signed, trusted binary in `bin/dev/`
- scan logic stays in one place, no duplication into module form
- no `base.load_modules` / `base.load_code` surface added to every zenka
- self-healing has no latency target — subprocess cost is acceptable
- stdout stream is the natural interface; policy layer reads it line by line

the subprocess receives the zenka's own name and outputs only its scoped
slice of the graph — no noise from unrelated zenki.

## dep-graph changes — minimal

dep-graph needs **no new flags** for signature validation. existing
`--zenka=NAME --list-subs` output is the module list — the zenka's
self-healing handler validates signatures itself using `source.*` modules.

dep-graph stays a pure dependency scanner. one concern stays in one place.

## signature validation via source.*

`modules/source.*` already owns signature concerns:
- `source.signature_valid` — validates AMOS7 signature of a module file
- `source.extract_sig_body` — extracts payload for verification

the handler calls `<[source.signature_valid]>` per module from the dep-graph
list. no signature logic needed in dep-graph, no duplication.

output classification in the handler:

```
OK   — dep-graph listed it, signature valid
MISS — dep-graph listed it, no signature block found
BAD  — dep-graph listed it, signature present but invalid
MOV  — not in dep-graph output, but moved_to entry exists in runtime registry
```

## moved_to forensics

before triggering a dep-graph scan, handler checks `<base.modules.moved_to>`
— the runtime registry written by `base.swap_subs` and `base.init_modules`.

if a `moved_to` entry exists: log MOV and attempt load of new name directly,
without needing a full dep-graph scan. fast path for namespace moves.
only escalate to full scan if moved_to lookup also fails.

## self-healing handler in zenka

new module: `base.handler.whitelist_miss` (or hooked into existing NOT FOUND
path in `base.init_modules` / whitelist check code).

on NOT FOUND:
1. check `<base.modules.moved_to>` first — if found, log MOV and recover
2. if not found: fork dep-graph subprocess with `--zenka=self --list-subs
   --validate-sigs`
3. read stdout line by line, apply configured policy:
   - `OK` lines: candidate for runtime load via `base.load_code`
   - `MISS` / `BAD` lines: log to forensics channel (code quality + security)
   - `MOV` lines: log move, attempt load of new name
4. report outcome to forensics zenka (both channels as appropriate)
5. zenka stays live throughout — no restart required for clean recoveries

## policy configuration

per-zenka policy in zenka start or config:

```
whitelist.miss.policy = heal       # attempt recovery (default)
whitelist.miss.policy = warn       # log only, no load attempt
whitelist.miss.policy = strict     # treat as fatal, alert forensics
whitelist.miss.sig_fail = reject   # never load BAD-signature modules
```

## forensics channels

- **security channel**: BAD signature, unexpected MOV, policy violations
- **code quality channel**: MISS signature, stale whitelist pattern (same
  miss repeated across restarts), dep not declared in module headers

the forensics zenka correlates: repeated self-heals of the same entry over
time reveal whether drift is accidental or systematic.

## runtime load path

once policy approves a recovered module, it is loaded via `base.load_code`
(single module) or `base.load_modules` (namespace prefix). this is the
existing on-demand compile path — self-healing reuses it, not a new surface.

## core subs in bin/Protocol-7

some relevant subroutines are defined as core subs directly in `bin/Protocol-7`
rather than as module files. before implementing new helpers, check what already
exists:

```
bin/Protocol-7 -core-subs [subname-pattern]
```

e.g. `bin/Protocol-7 -core-subs load_code` to inspect `base.load_code` before
implementing the runtime recovery path. avoids duplicating functionality that
is already available at the core level.

## signatures note

do not modify or regenerate any AMOS7 signature lines. the signing system
handles all footer blocks — leave them untouched.

## files to create / modify

- `bin/dev/dep-graph` — no changes needed for this task
- `modules/base.modules.check_migrated` — new helper: checks
  `<base.modules.moved_to>` for a given name, returns new target or undef.
  handler delegates to this without knowing registry internals.
- `modules/source.target_namespace` — new helper: resolves a module name to
  its on-disk path and namespace root. used before `source.signature_valid`
  so the handler never needs to know path conventions.
- `modules/base.handler.whitelist_miss` — new on-demand self-healing handler;
  delegates to check_migrated + target_namespace + source.signature_valid
- hook into NOT FOUND path (locate in `base.init_modules` or whitelist check)
- policy config keys in relevant zenka start files (opt-in per zenka)
- `source.*` modules are already available — load on-demand if not present

## open design question

`base.load_code` vs `base.load_modules` for the recovery load:
- `base.load_code` — single module, minimal surface, preferred for targeted
  recovery of one missing entry
- `base.load_modules` — full namespace prefix, appropriate when a whole
  namespace moved (MOV case with prefix swap)
choose per case in the handler, not a global setting.

## hard dependency

this task does NOT depend on the loading policy / control method checks being
in place first — the stdout + subprocess approach sidesteps the file-write
signing requirement entirely. policy is applied at read time in the handler,
not at write time to a file.

#,,,.,,,.,..,,,.,,.,.,,..,,.,,...,,,,,...,..,,..,,...,...,.,.,,,,,.,,,,,,,,,.,
#WYTVOYVFJ2DY5EME3XUZ2BLSJCMCFZQQ4MUBJK55RWEC4KX4OGDUPMP4Q6ICYMMDDV5C2FGUP23OO
#\\\|UKSZZB5YVRLKSOU6YORGLB7PHQI3TLP5Z77NUBKUO5VLQUFGYMS \ / AMOS7 \ YOURUM ::
#\[7]46AD5OEGZC2WAEJDQQTVR36RRA7UG4KLNKYGZF2X4HAIHUED2IAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
