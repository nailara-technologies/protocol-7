# user-edit console zenka — phase 1 skeleton (clone `keys`, strip content)

**Read first, both required:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` — P7 module
  conventions, common mistakes to avoid.
- `data/yaml/coding-tasks/user-edit-console-zenka.yaml` — the full design doc this
  task is scoped from. Read `phase_1_skeleton` and `phase_1b_path_discovery`
  specifically; the rest of the doc (rendering, users-zenka integration, offline
  outbox, amos-term overlap) is NOT in scope for this task — do not implement it,
  do not try to resolve its open questions.

## Goal

Get a new zenka, `user-edit`, existing and compiling cleanly — nothing more. This
is a skeleton-only task: no editor UI wiring, no rendering, no field schema, no
users.* calls. Just a zenka that boots and loads its modules without error.

## Precedent to clone (structure, not content)

`configuration/zenki/keys/` is the shape to copy:
- `configuration/zenki/keys/start` — thin start file, loads modules, drops into
  `[base.call.console_command]`
- `configuration/zenki/keys/source/` — one empty placeholder file per top-level
  module namespace loaded (`base`, `crypt.C25519`, `keys`, `terminal` — `base` is
  implicit, not listed in `modules.load` but still has a placeholder)
- `configuration/zenki/keys/pm-dep/` — DO NOT hand-author these. They are
  tool-generated (empty marker files, one per required CPAN module). Leave this
  directory out of your changes entirely; the user will regenerate it separately.
- `configuration/zenki/keys/subroutines.load-early` — also tool-generated
  (`bin/dev/gen-sub-whitelist <zenka>`, see the file's own header comment). Do
  NOT hand-author this either. Leave it out.

## What to build

1. `configuration/zenki/user-edit/start` — modeled on `keys/start`, but:
   - `modules.load = terminal editor ascii.frame user-edit`
   - do NOT load `crypt.C25519` — user-edit has no key-management role (see
     design doc's phase_1_skeleton for why)
   - keep the same overall shape: `[load_config_file:'shared-params']`,
     `[load_modules:<modules.load>]`, `[init_modules]`,
     `[root.drop_privs:<system.amos-zenka-user>]`,
     `[base.net.connect:'unix']`, `[base.get_session_id]`, `[zenka.loop]` — check
     `keys/start` for the exact working order and copy it, don't improvise the
     sequence.
2. `configuration/zenki/user-edit/source/` — one empty placeholder file per
   loaded namespace: `base`, `terminal`, `editor`, `ascii.frame`, `user-edit`.
3. `modules/user-edit.init_code` — minimal stub. Look at a small, similarly-thin
   zenka's own `<zenka-name>.init_code` for the minimal working shape (e.g.
   `ascii.frame.init_code` is a good minimal example — it just does one small
   thing and returns TRUE). user-edit.init_code at this stage should do the
   bare minimum to exist and log that it initialized — do not add settings
   logic, editor.control.* calls, or anything from later phases.

## Explicitly out of scope — do not implement

- `phase_1b_path_discovery` (path keyword registration) — separate follow-up
- any editor.control.*, ascii.frame.*, or users.* calls
- `access.cmd.usr.cube` grants, cube `auth.zenki` grants, or any change to
  shared access-control config — this stays a local skeleton only; wiring it
  into the live zenka network is a manual step the user will do themselves
- `configuration/zenki/v7/start-set-up.base` registration (always-on/on-demand
  wiring) — not this task

## Verification

- the new files exist, `start`'s module load order matches `keys/start`'s
  pattern
- confirm modules/user-edit.init_code has valid P7 module header format (see
  any existing `*.init_code` file for the exact `## [:< ##` / `# name = ` /
  `# descr = ` header shape)
- do NOT attempt to actually boot the zenka against the live network — no
  cube access has been granted, it will not be reachable. Just confirm the
  files are structurally correct and consistent with `keys/start`'s pattern.

## P7 pitfalls (from prior kimi sessions, avoid these)

- use `base.logs` (list form), not `base.log` (singular) unless you've
  confirmed the specific call site actually wants singular — check existing
  precedent files rather than guessing
- never redeclare `my $call` — check surrounding scope first
- `TRUE` = 5, `FALSE` = 0 in this codebase (not 1/0) — see CLAUDE.md
- no fake/placeholder AMOS7 signature blocks at the end of files — leave that
  to the human, who signs files with the real tool
- `sprintf( qw| foo bar %s |, $x )` is broken if the `qw()` has internal
  whitespace (multi-word) — collapses to just its last word in scalar context.
  Single-word `qw| %s |`-style formats are fine. Don't write multi-word
  `sprintf qw()` calls at all here.

When done, write a short note to `data/ai-mem/kimi/coding-style.md` or
`data/ai-mem/kimi/MEMORY.md` (whichever fits) if you hit anything non-obvious
along the way — same as any other task.

#,,.,,,..,.,,,.,.,,,.,.,.,,,.,,.,,,,,,,.,,...,..,,...,.,.,,,,,,,,,..,,...,..,,
#HZ62HCOPCFXMPJF3MECGISPM3T4QZLHLK6TLW5Q7F365ESHUR3362DUY3SOGQ4NYI7FEHY6ANFRA2
#\\\|5VQORR5MCCUELIJQ62SSYYTH3ZKEJWRFSF2WLE3FDYNG4RZT66P \ / AMOS7 \ YOURUM ::
#\[7]TWASJYI2XP2TBRFV22GKC6RLC2YVCZHNLBPMWVBS2I563WN5WMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
