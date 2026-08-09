# user-edit console zenka — phase 1b: path registry

**Read first, both required:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` — P7 module
  conventions, common mistakes to avoid.
- `data/yaml/coding-tasks/user-edit-console-zenka.yaml` — read `phase_1b_path_discovery`
  specifically (search for that key). The rest of the doc (rendering, users-zenka
  integration, offline outbox, amos-term overlap) is NOT in scope here.

The phase 1 skeleton (`configuration/zenki/user-edit/`, `modules/user-edit.init_code`)
already exists and is committed — this task extends `user-edit.init_code`, it does
not create the zenka from scratch.

## Goal

Register three named path-root keywords for the user-edit zenka via the existing
`base.path.register_keywords` mechanism, so later code can write
`[VAR_P7]/user-edit/outbox/...` instead of hand-building paths. This task is
registration only — no outbox, no draft-save, no actual reads/writes of any real
file under these roots. Just get the keywords registered correctly and provably
resolvable.

## Precedent to follow (do not invent a new mechanism)

- `modules/base.path.register_keywords` — takes one hashref `{ NAME => path, ... }`.
  Read this file's source to see the exact call signature and what it validates.
- `modules/base.path.resolve_keywords` — resolves `[NAME]/rest` strings back to
  the real path. Read this file too.
- `modules/workspace-transfer.pre_init` — the one existing call site in this repo
  that calls `register_keywords`. Look at how it's invoked (single call, one
  hashref) — mirror that shape, don't build something more elaborate.
- `modules/base.path-set-up.zenka-directories` — defines `<system.path.zenka-dirs>`
  (the hash with `var_P7`/`etc_P7` keys) that this task reads from. Read it to
  confirm the exact keys available (`var_P7`, `etc_P7`, others) — don't guess.
- `data/lib-path/pm/AMOS7/FILE.pm`'s `get_homepath()` sub — the existing helper
  for resolving the current user's home directory. Every other `~/.n/` consumer
  in this repo (`crypt.C25519.get_usr_keys_dir`, `create-session-seed-file`, etc.)
  builds its path from a home-dir resolution like this one — check one of those
  call sites for the exact usage pattern (how it's called, is it a P7 module call
  or a standalone Perl `use AMOS7::FILE` — user-edit is a P7 zenka module, so use
  whatever the P7-module-side precedent does, not the standalone-script pattern).

## What to build

In `modules/user-edit.init_code` (append to the existing minimal stub, don't
replace the existing `base.logs` init line), register three keywords:

- `VAR_P7` → the zenka's own var directory: `<system.path.zenka-dirs.var_P7>` +
  `/user-edit` (check `base.file.zenka_dir.data_path` for the exact existing
  pattern other zenki use to build this same path — reuse it rather than
  hand-rolling `catdir`/string concatenation differently)
- `ETC_P7` → same pattern, `<system.path.zenka-dirs.etc_P7>` + `/user-edit`
- `HOME_N` → the current user's `~/.n` directory, via `get_homepath()`

Register all three in a single `register_keywords({ ... })` call, matching
`workspace-transfer.pre_init`'s call shape.

## Explicitly out of scope — do not implement

- creating any actual file/directory under these paths — registration only
- `format.yaml.*` usage, outbox, draft-save — later phases, not this task
- anything from `phase_2_rendering`, `phase_3_form`, or the `users.*` command
  surface — not this task
- do not touch `configuration/zenki/user-edit/start` or any other already-committed
  file except `modules/user-edit.init_code`

## Verification

- run `bin/dev/ptd -c modules/user-edit.init_code` and confirm it reports
  syntax ok
- after registering, confirm (by reading the code, not by executing — this
  zenka is not network-reachable yet) that `base.path.resolve_keywords`
  applied to a string like `'[VAR_P7]/outbox/test.yaml'` would correctly
  substitute to the real absolute path, based on how `resolve_keywords`'s
  regex substitution works (read the sub, trace it by hand, state in your own
  summary what the resolved path would be for all three keywords)

## P7 pitfalls (from prior kimi sessions, avoid these)

- use `base.logs` (list form), not `base.log` (singular) unless confirmed
  otherwise by precedent
- never redeclare `my $call`
- `TRUE` = 5, `FALSE` = 0 in this codebase
- no fake/placeholder AMOS7 signature blocks — the human signs files
- `sprintf( qw| foo bar %s |, $x )` breaks on multi-word `qw()` in scalar
  context — don't write multi-word `sprintf qw()` calls
- module calls use the `<[module.name]>->(...)` syntax (or `<[module.name]>`
  bare when no args) — see the existing `user-edit.init_code` for the pattern
  already in use in this exact file

When done, write a short note to `data/ai-mem/kimi/coding-style.md` or
`data/ai-mem/kimi/MEMORY.md` if you hit anything non-obvious.

#,,,.,,..,.,,,,..,.,,,,..,,.,,,,.,,.,,,,,,.,,,..,,...,..,,..,,...,.,.,..,,,.,,
#O4ZWIBKGSPODP7B6KIHKPYGVJE2FQWDQAUQRYJYPLJU4BGHEAUT2Z3BYGDZGRQM7NUFBITKP2WXWO
#\\\|BK77SFSILKGSJJZ2LQMGJNK2VV7ASW46XI6B2H4FGLBDNY6OQPX \ / AMOS7 \ YOURUM ::
#\[7]WNBTJWA4X62E23R7QDZVBPRKN7YZ7G4SX7P7SNUJ7FMGIGOY7YBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
