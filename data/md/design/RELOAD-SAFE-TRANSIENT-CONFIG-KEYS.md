# reload-safe transient config keys

[ origin: 2026-08-02 — surfaced while auditing `base.cmd.reload`'s
  `modules.load`/`modules.preload` handling (post `2528fb353`,
  `0425b210f`). `modules.load`/`modules.preload` are not a reserved,
  framework-guaranteed namespace — they're arbitrary `%data` keys ~127
  start files happen to use by convention, readable by anything
  (`devmod.cmd.unload-devmod` already does, mostly vestigially — see
  below). this doc captures the mechanism designed to make "set a value,
  consume it once, then guarantee it's gone" an actual property a start
  file can declare, safely across both initial boot AND every future
  reload cycle, not just the first boot. paused deliberately before
  implementation to allow more thinking time; `cfg/zenki/
  mod-test/start` carries a `[base.prune_key:'modules.load']` line as an
  intentional, known-incomplete placeholder/reminder — it only helps the
  boot case, not reload, until this design lands. ]

related: `src/base.prune_key`, `src/base.del_key`
(commit `0425b210f`), `src/base.reload_config`,
`src/base.execute_zenka_code`, `src/base.pre_init`,
`src/devmod.cmd.unload-devmod`

## the problem

Every zenka's `start` file typically does:

```
modules.load = auth.client net protocol io.unix ui <zenka-name>
[load_modules:<modules.load>]
[init_modules]
```

`modules.load` (and `modules.preload`, used by 7 zenki for a two-stage
load) is only ever *meant* to be read on the very next line. But because
it's a plain `%data` key with no enforced scope, nothing stops other code
from reading or depending on it existing — `devmod.cmd.unload-devmod`
already does (see "vestigial dependency" below), and `base.cmd.reload`'s
`source` reload path has a narrow fallback that specifically greps for
`<modules.load>` (missing `modules.preload` or any differently-named
convention entirely — a related, smaller, still-open gap, see "related
open item" below).

The user's position: relying on nobody ever reading an "arbitrary"
convention variable is not safe, and it's already happened once
(`devmod.cmd.unload-devmod`). But a full removal of the named variable
(inlining the module list as a literal argument directly into
`[load_modules:...]`, no `%data` footprint at all) was rejected — the
named variable is valuable exactly because module lists can get long,
and `modules.load` is the unambiguous, greppable, conventional place
anyone looks to see or add a zenka's module list. So the goal became:
keep the named variable for authoring, but make its *non-existence*
outside its point of use an actual guaranteed property, not a hoped-for
convention.

## why "just delete it after use" doesn't fully work

First attempt: `[load_modules:<modules.load>]` followed immediately by
`[base.prune_key:'modules.load']` (a new primitive built alongside this
work — see `src/base.prune_key`, deletes a key and prunes any
ancestor hash left empty by the delete; landed standalone in `0425b210f`
as a general utility regardless of this design's outcome).

This works correctly for the **initial boot** case — verified live
against the `mod-test` zenka (`modules` key confirmed absent from
`%data` after boot via a temporary `eval-code` grant, reverted after).

It does **not** survive a subsequent `reload config`/`reload all`.
Traced through `base.cmd.reload` → `base.reload_config`:

1. `base.reload_config` calls `base.load_config_file` for every entry in
   `<system.config.reload_order>` — but a zenka's own start file is
   explicitly *excluded* from that list (`base.load_config_file` only
   pushes a config name if it's not `<system.path.rel.cur_zenka_cfg>`).
2. Instead, the zenka's own start file is reloaded via a **separate,
   simpler path**: `base.reload_values` → `base.extract_values`, which
   only recognizes literal `key = value` lines (`split(qw| = |, ...)`).
   Bracket-command lines (`[load_modules:...]`, `[base.prune_key:...]`,
   `[init_modules]`, etc.) contain no bare `=` and are silently skipped.
3. So `modules.load = ...` **is** re-applied (recreated) by every
   reload, but `[base.prune_key:'modules.load']` **never runs again**
   after the initial boot — bracket-commands in a zenka's own start file
   only ever execute once, during the very first
   `base.execute_zenka_code` pass at boot.

Net effect: `modules.load` reappears after the first reload and then
sits in `%data` for the rest of the zenka's life (or until the next
reload, which recreates it again) — not meaningfully different from
never pruning it at all. This is not a defect in `reload_config` — it's
correct and intentional for `reload_config`'s actual purpose (you would
never want side-effecting bracket-commands like `[root.drop_privs:...]`
or `[base.net.connect:'unix']` silently re-executing on every config
reload). It's a genuine mismatch between how the reload mechanism is
built and what this specific cleanup pattern needs, not a bug to fix in
`reload_config` itself.

## `<config.reload.cleanup_keys>` is not reusable for this

`base.reload_config` already has a generic-looking mechanism:
`<config.reload.cleanup_keys>` (space-separated key list) gets deleted
key-by-key at the very *start* of `reload_config`, before
`base.reload_values` runs. Naively, moving this check to run *after*
`base.reload_values` looked like it might solve the ordering problem for
free.

Two reasons this is wrong, not just risky:

1. **Different intended purpose.** `cleanup_keys` exists because a
   reload can't wipe all of `%data` (too much live runtime state lives
   there beyond config-derived values), yet a config file can scatter
   values at arbitrary paths — so `cleanup_keys` is the surgical way to
   guarantee a *fresh* re-application (clearing stale sub-keys from a
   previous config state before the new values land), not to make a
   value *disappear after* being freshly reapplied. Moving its execution
   point would invert its documented contract, not just risk a
   regression.
2. Checked anyway: `config.reload.cleanup_keys` is currently referenced
   nowhere else in the codebase, so no *current* caller would break —
   but the design intent still matters independent of that.

Conclusion: leave `cleanup_keys` completely untouched. Build a
genuinely separate, distinctly-named mechanism for the post-reload case.

## the design

Two new pieces, kept deliberately separate from `cleanup_keys`:

### `base.register_prune` (name validated via `harmony`, both bare and
`base.`-prefixed forms return `TRUE` — no bare/prefixed conflict, unlike
`prune_key`)

A **pure registration** primitive. Takes a `%data` key name (same syntax
as `base.del_key`/`base.prune_key`) and pushes it onto
`<config.reload.prune>` (dedup-checked — see "why dedup" below). Does
**not** delete anything itself. Called from a start file right after
`[load_modules:<modules.load>]`, same placement `[base.prune_key:...]`
occupies today.

### `<config.reload.prune>` (name validated via `harmony`, `TRUE` —
along with two longer alternatives, `config.reload.after_values_prune`
and `config.reload.reapplied_prune_keys`, also `TRUE`; picked for
brevity and because it sits as a clean sibling to
`config.reload.cleanup_keys` in the same `config.reload.*` namespace)

Space-separated key list (same shape as `cleanup_keys`, for stylistic
consistency), built once at boot by `register_prune` calls in the start
file, and **never itself deleted** — it must persist unchanged for the
rest of the zenka's life, since nothing will ever rebuild it (see next
section for why that's actually fine).

### a small shared routine (not yet named) that reads
`<config.reload.prune>` and deletes each listed key (via the existing
`base.prune_key` ancestor-aware delete, not a flat `base.del_key`) —
**without** deleting the registry list itself.

Called from **two** places:

1. **`base.pre_init`** — for the initial-boot case. This is not a new
   hook: `base.pre_init` already exists (does passwd/user checks and
   path setup today) and is already invoked automatically, exactly
   once, as part of every zenka's `[init_modules]` — confirmed via
   `base.init_modules` (`foreach my $init_mode (qw| pre_init init_code
   post_init |)`). Since `[init_modules]` always comes *after*
   `[load_modules:...]` in every start file, any `register_prune` call
   earlier in the same file has already run and populated the registry
   by the time `base.pre_init` fires. No new hook needed at all.
2. **`base.reload_config`**, appended *after* its existing
   `base.reload_values` call (not before, unlike `cleanup_keys`) — this
   is what actually fixes the reload-recurrence problem: `reload_values`
   recreates `modules.load` from the start file's `key = value` line,
   and the new step runs immediately after to remove it again, every
   single reload cycle.

### why the registry never needs rebuilding, and why that's fine

The user initially worried this implies the prune list "can never be
changed during runtime." True only for the specific channel of *declared
via a start file* — bracket-commands there execute exactly once, so you
cannot add a new start-file-authored registration without a restart.
But `base.register_prune` is an ordinary subroutine, callable from
*any* running code (a command handler, an event callback, anything) —
not exclusively tied to start-file execution. Since `config.reload.prune`
is a live, mutable `%data` list rather than something snapshotted at
boot, a call from elsewhere in running code would take effect on the
very next reload with no restart needed. The one real gap: there is no
"unregister" — only additive registration. Not needed for the
`modules.load`/`modules.preload` use case (nothing would ever want to
un-declare that), so not being built preemptively, but worth knowing if
some future use case needs to remove an entry.

### why `register_prune` must dedup before pushing

`base.execute_zenka_code` (the line-by-line bracket-command `eval` loop)
runs a zenka's own start file exactly once, ever. But it also runs for
*other* config files loaded via `[load_config_file:...]` (e.g.
`shared-params`) — and those **do** get fully replayed through this same
function on every single reload, via `<system.config.reload_order>`
(unlike the zenka's own start file, which is excluded from that list and
routed through the values-only `base.reload_values` path instead). So a
`register_prune` call living in a shared/reloadable config file — not
the current use case, but a latent possibility if this primitive gets
reused elsewhere — would re-fire every reload cycle and push a duplicate
entry unless the function checks before pushing. Cheap to build in now,
expensive to discover missing later.

## related, already-resolved context (do not re-derive)

- **`base.p7_mod.loaded` / `base.register_p7_mod_load` /
  `base.clear_p7_mods`** already provide reload-safe tracking of *which
  modules are currently loaded*, regardless of what variable name (if
  any) originally fed the `[load_modules:...]` call that loaded them.
  `base.cmd.reload`'s `source` path already unions this runtime registry
  with a fallback read of `<modules.load>` specifically — the registry
  half was never actually a real gap; this design doesn't change that
  part of `reload`'s behavior at all.
- **Separate, smaller, still-open item**: `base.cmd.reload`'s fallback
  for *newly-added-but-never-yet-loaded* module names only checks
  `<modules.load>` by name, missing `<modules.preload>` or any other
  convention. Confirmed real (7 zenki use `modules.preload`) but low
  blast-radius (only bites "add a brand-new module to a preload-style
  zenka, then reload without restarting"). Not fixed by this design —
  a hardcoded 2-name union was considered and explicitly rejected as
  "chasing an arbitrary convention," same reasoning as the rest of this
  doc. No resolution decided; left open.
- **`devmod.cmd.unload-devmod`'s read/write of `<modules.load>`** is
  dead/vestigial, not a real dependency blocking this design: the
  function's *actual* persistent state is `<base.devmod.keep_on_reload>`
  (a dedicated flag) and `<base.p7_mod.loaded.devmod>` (the same runtime
  registry above) — its `<modules.load>` block is guarded and
  self-labeled in its own comment as `## account for deprecated
  configuration style ##`. Safe to delete independently of whether this
  design ever lands.

## current state / how to resume

- `src/base.del_key`, `src/base.prune_key` — landed, `0425b210f`.
  Useful standalone regardless of this design.
- `cfg/zenki/mod-test/start` — carries
  `[base.prune_key:'modules.load']` as a **known-incomplete**
  placeholder: fixes the boot case only, resets on reload exactly as
  described above. Intentionally left in as an active reminder rather
  than reverted.
- Not yet done: name the shared "process the registry" routine (not
  validated via `harmony` yet), decide `config.reload.prune`'s exact
  `push`/dedup implementation, write `base.register_prune`, add the
  `base.pre_init` and `base.reload_config` call sites, then re-pilot
  `mod-test` with the *complete* mechanism (register_prune, not the
  standalone prune_key line) and verify a live reload actually removes
  `modules.load` afterward (not just boot).
- Once verified on `mod-test`, resume the tiered start-file migration
  plan: low-traffic zenki first, then the 7 `modules.preload` zenki
  plus other irregular start-file shapes, then the bulk of ordinary
  zenki, then `cube`/`v7`/`system` last — each tier actually restarted
  and live-verified (not just `ptd -c`, since start-file syntax isn't
  Perl), one commit per tier.

#,,,,,.,.,,,.,,,,,...,.,.,,.,,,,.,.,,,,.,,..,,..,,...,...,,,.,...,,,.,..,,.,,,
#RQ5ET436KBAAMMH472NBXUXESN7TXYSOTSNX4AKDWIKNBPVQADF54AYULHXVH5OZYA6H7ZO33WP6C
#\\\|WRX7QIAIHCSH6VMGN27A5YTF673ZAKMX4HGG5QQPNM3SJ6LRFHK \ / AMOS7 \ YOURUM ::
#\[7]RL3QSN56U6A4DIIA6QBF7VKSWK5ACJVGWRPZLSGENPRXWGY4SOCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
