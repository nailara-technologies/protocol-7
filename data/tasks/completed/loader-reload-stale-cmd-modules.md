## task: fix `.cmd.` modules not actually reloading on an already-running zenka

## RESOLVED 2026-08-04

root cause was not `$is_reload_batch` (the doc's own leading hypothesis) —
it was one level upstream, in the whitelist-gate block in
`bin/Protocol-7`'s `p7_load_code` (~line 1586-1621, the block right
before phase A's disk-read). for a non-whitelisted file, the gate's
`if ( not exists $code{$file_name} )` guard was meant to distinguish
"needs a fresh deferred stub" from "already handled" — but its else-branch
was an unconditional `next`, which also caught the case where real
compiled code already lives at that key (reached earlier via
`base.load_runtime_modules`'s whitelist-bypass, e.g. a zenka-local `.cmd.`
command invoked once at runtime after the zenka was already up). once
real code is there, `exists $code{$file_name}` stays true forever, so
every subsequent `p7_load_code` pass — including every future `reload` —
skipped the file entirely: never re-read from disk, never re-queued into
`@compile_order`, hence never recompiled. only a full `v7.restart`
(fresh `%code`, `$active_version` undef) could recover it.

fix: split the else-branch on `$data{'code'}{$file_name}{'deferred_stub'}`
— still-uncompiled stub → `next` (nothing to recompile yet, unchanged
behavior); real compiled code already present → fall through to the
normal read-from-disk + compile path instead of skipping, so it
participates in `@compile_order` like any other file on every future
reload. minimal, scoped to this one gap — no change to `$is_reload_batch`,
the staging/swap mechanism, or the nested-lifecycle-hooks task
(`loader-eager-compile-nested-hooks-under-loaded-ancestor.md`, left
untouched per its own caution against bundling).

verified live against the `mod-test` zenka (temporary
`mod-test.cmd.reload-probe`, added/removed for this test only): after
`v7.restart mod-test` to load the fixed `bin/Protocol-7`, probe returned
`probe-v1` on first (runtime-bypass) access, then correctly picked up
edits to `probe-v2` and `probe-v3` across two consecutive
`mod-test.reload source` calls with no restart — the exact failure mode
reported above no longer reproduces. `mod-test.reload all` (covering
`base.*`) also still succeeds with no regression.

---

**priority raised 2026-08-04 — second independent confirmation.** Hit again
on the `kimi` zenka this session: after landing the `QuestionRequest`
silent-hang fix (`modules/kimi.wire.question_respond` [new] +
`modules/kimi.handler.ws_message`), `kimi.reload source` reported success
but the edited handler branch did not actually take effect — the user had
to explicitly direct a `v7.restart kimi` instead, and K3 discovered the
staleness itself mid-verification rather than trusting the reload's own
"success" report. Same shape as the original `jobsite.cmd.reload-probe`
finding below: a `.cmd.`/handler-class module on an **already-running**
zenka silently keeps the pre-edit coderef after `reload`, full stop only
via `v7.restart`. Two unrelated zenki (`jobsite`, `kimi`), two unrelated
sessions, same failure mode — this is not a one-off. Raising priority: the
"use `v7.restart <zenka>` instead of `<zenka>.reload`" workaround noted
below needs to become the *default* guidance for every live-fix dispatch
until this actually lands, not just a footnote — every K3/Opus dispatch
this session that edits an already-loaded module and tries to verify live
is at risk of the same false-positive "reload succeeded" trap.

### symptoms

editing an already-loaded `.cmd.` module's source and running `<zenka>.reload`
(`base.cmd.reload`, `arg=source` or `all`) reports every step successful, but
the zenka keeps dispatching the **old** compiled code. only a full
`v7.restart <zenka>` (kill + fresh process boot) picks up the edit.

this was found on `jobsite` while adding new `jobsite.report.*` /
`jobsite.cmd.report-build` modules (2026-08-02). a brand-new file, added to
`access.cmd.usr.cube` and loaded via `reload` for the first time, worked
immediately. editing that *same, already-loaded* file and reloading again did
not — dispatch kept returning the pre-edit output.

reproduced cleanly with a minimal isolated probe, to rule out confounds from
the report-pipeline work itself (JSON parsing, encoding, etc):

```
modules/jobsite.cmd.reload-probe:
    return { 'mode' => 'true', 'data' => 'probe-v1' };
```
added `reload-probe` to `access.cmd.usr.cube` in
`cfg/zenki/jobsite/start`, `p7c jobsite.reload` → `p7c
jobsite.reload-probe` → `probe-v1` (correct, first load).

edited the file to return `'probe-v2'`, confirmed on disk, `p7c
jobsite.reload` again (full success reported: `reload config/p-mods/source/
plugins/reinit source [ success ]`, and the loader's own compile summary line
`..: 492 subs., 1192K src., no errors., =)`, including a `loading p7-source :
jobsite.cmd.report-build` line naming our files) → `p7c jobsite.reload-probe`
→ still `probe-v1`. `p7c v7.restart jobsite` → `probe-v2` (correct).

**strongest evidence** — the dispatched coderef never changes identity across
a reload of an already-loaded `.cmd.` module:

```perl
p7c jobsite.eval-code '"$code{q(jobsite.cmd.reload-probe)}"'
# => CODE(0x59b1d67e39a0)   -- before reload
# ... edit file, p7c jobsite.reload ...
# => CODE(0x59b1d67e39a0)   -- IDENTICAL address after reload
```

this is not "reverted to old behavior" — the sub was never replaced at all.

also checked: `$data{'code'}{'jobsite.cmd.reload-probe'}{source}` and
`{status}` are both `undef`, while `$data{'code'}` holds ~261 *other* entries
— all `base.*`-prefixed lifecycle/library subs, not a single `jobsite.*`
zenka-specific module among them. tested disabling
`<base.reload.success.clean-code>` (the `delete $data{'code'}` cleanup step
at the end of a successful reload, default `TRUE`) to rule out that wipe as
the cause of the missing status tracking — did **not** fix the staleness, so
that wipe is a red herring / separate concern, not the root cause of the
dispatch staleness itself.

---

### current best hypothesis

something in `bin/Protocol-7`'s `p7_load_code` silently excludes an
already-loaded `.cmd.`/`.console.` module (or possibly zenka-specific
namespaces generally, as opposed to `base.*`) from the actual recompile+stage
step on a **reload of an already-running process**, while still reporting
the batch as fully successful. the file gets *read* (it appears in the
"loading p7-source" log line), but either:

- it's filtered out of `@compile_order` before compilation happens, so
  `$staging->{$sub_name}` never gets overwritten and just carries forward
  the old coderef from `my $staging = {%code}` (the seed step) through the
  swap, or
- it compiles fine but the compiled cref is written somewhere other than
  `$staging->{$sub_name}` for this class of module.

the "initial load vs reload" distinction (`$is_reload_batch`, see below) is
the most likely place this diverges, since the *first* load of the probe
file (brand new, added this session) worked immediately via what is
presumably the direct-install path, while the *second* pass (same file,
already loaded) — which should go through the staged-swap path — silently
dropped it.

---

### regression history — when this was introduced

the whole staged-compile + atomic-swap mechanism is comparatively new and
was patched repeatedly over a short window, then left alone for ~4 months
before two more patches landed 6-8 days before this bug was found:

- **`4f64720b5`** 2026-03-13 00:55 — **origin**. *"feat: Version-aware loader
  phase 1 — staged hash + atomic swap"*. explicitly labeled **phase 1**; no
  phase 2 commit exists in history. introduced `my $staging = {%code}`,
  compile into staging, swap `%code = $staging->%*` only on full success,
  archive prior version for rollback.
- **`6b2a1f92a`** 2026-03-13 01:37 — *"fix: Reload abort path, compile-error
  buffer clearing, redefine warning"* — same-day follow-up fix.
- **`32d36ab47`** 2026-03-13 14:25 — *"feat: rollback window timer for
  version-aware loader"* — added the 93s archived-version expiry watcher
  (`base.callback.setup_rollback_timer` / `base.callback.expire_code_version`,
  confirmed by reading: this only frees memory, does not revert `%code`).
- **`12b944296`** 2026-03-15 — *"fix: runtime module loading, whitelist
  reload, sig_NUM53 devmod, .\7 ordering"*.
- **`aff545051`** 2026-03-18 11:26 — *"Add format.yaml module + fix whitelist
  loader case sensitivity"*.
- **`08b42f019`** 2026-03-18 19:32 — *"fix(p7_load_code): initial namespace
  loads no longer use staging swap"*. introduced `$is_reload_batch` detection
  (a batch counts as a reload only if some sub in `@compile_order` has prior
  `status` `'no-error'`/`'warned'` in `$data{'code'}`); gated the direct
  `$code{$sub_name} = $sub_cref` install on `not $is_reload_batch`; gated the
  atomic swap on `$is_reload_batch and not $err_count`. full reasoning in the
  commit message (three related fixes: is_reload_batch detection, direct
  install on initial load, cmd/console "replacing sub" false-positive fix).
  **this is the most likely place the `.cmd.` reload gap lives** — it's
  exactly the "initial load vs reload" branch point.
- **`e90dd04ae`** 2026-07-25 — *"loader: make swap_subs-moved namespaces
  reachable without whitelist regen"*.
- **`beb89d5b0`** 2026-07-27 00:39 — most recent, 6 days before this bug was
  found. *"loader: fix v7.reload init crash from swap_subs destructive
  wipe"*. note: this is about `base.swap_subs` (the `base.X` → `X` short-name
  aliasing family), a **different** mechanism from the staged-hash swap
  above that happens to share the word "swap" — don't conflate the two when
  reading further; confirmed by reading `base.cmd.reload` and the loader
  code directly, `.cmd.` dispatch is plain name-based lookup with no closure
  to hold stale, so this class of bug can't be the swap_subs closure-capture
  issue that `beb89d5b0` fixed.

no phase-2 commit for the version-aware loader exists yet; the design is
still "phase 1" five months later, with fixes landing in bursts and long
gaps. matches the shape of an incomplete refactoring rather than a single
clean regression commit.

---

### investigation steps

1. reproduce with the minimal probe method above (fastest signal: the
   `"$code{'ns.cmd.name'}"` stringified-address check before/after reload —
   don't bother with functional dispatch tests first, the address check is
   cheaper and unambiguous).
2. in `bin/Protocol-7`, re-examine the file-matching loop that builds
   `@compile_order` / `%module_code_map` (the `foreach my $file_name
   (@subroutine_names)` loop, roughly lines 1525-1620) for any condition that
   depends on `$is_reload_batch`, `$active_version`, or a "namespace already
   known" check, gating **whether a file is even queued for compilation**,
   as distinct from `$is_reload_batch` gating **how already-compiled subs get
   installed** (staging vs direct). the current code as read doesn't show
   such a gate at the file-matching stage, which suggests the file *is*
   queued and compiled — so also check:
3. whether `eval($sub_code)` for `jobsite.cmd.reload-probe` actually produces
   a *different* coderef each pass (add a temporary debug line printing
   `\$sub_cref` right after `eval($sub_code)` at ~line 2019, compare across
   two reload passes) — if the address differs there but `%code` still ends
   up with the old one after the swap, the bug is in the swap/staging
   write-back specifically for this sub, not the compile step.
4. check `$data{'base'}{$cmd_type}{$cmd_name}` (the `.cmd.`/`.console.`
   dispatch-name → filename table, set unconditionally at ~line 1900
   regardless of staging) against `%code{$sub_name}` after a reload — confirm
   whether the *dispatch table* is fine (still points at
   `'jobsite.cmd.reload-probe'`) while `%code{'jobsite.cmd.reload-probe'}`
   itself is what's stale, or whether both are somehow stale.
5. cross-check against `08b42f019`'s `$is_reload_batch` detection loop
   directly on a live process: dump `$data{'code'}{$sub}{'status'}` for a few
   of the ~261 tracked `base.*` entries immediately before a `jobsite.reload`
   to confirm `$is_reload_batch` really does evaluate `TRUE` for this batch
   (as hypothesized — driven by those `base.*` entries' status, since
   `jobsite.*` modules apparently never get `status` tracked in `$data{'code'}`
   at all, which is itself worth understanding — is that intentional for
   zenka-local namespaces, or a separate gap?).
6. once the exact skip point is found, fix minimally — do not restructure
   the staged-swap design further; this task is about closing the one gap,
   not a phase-2 rewrite.

---

### prior context

- `AI-COLLABORATION-GUIDE.md` / project memory references a separate,
  already-resolved `swap_subs` issue (`e90dd04ae`, `beb89d5b0`) — confirmed
  unrelated to this bug (see note under `beb89d5b0` above). don't reopen
  that one while chasing this.
- workaround in active use until this is fixed: use `v7.restart <zenka>`
  instead of `<zenka>.reload` whenever editing an already-loaded module on a
  live process. `v7.restart` is confirmed reliable (kills + fresh boot, full
  `init_modules` path, not the incremental reload path).

---

### master design doc — `data/md/coding-tasks/version-aware-loader.md`

the whole staged-hash/atomic-swap mechanism this bug lives in is **phase 1**
of a five-phase design already documented there. cross-checked against the
live repo (2026-08-02):

- **phase 1's own checklist is entirely unchecked** (`- [ ]` throughout)
  despite the staging/swap code being live in `bin/Protocol-7` since
  `4f64720b5` — the checklist was never updated alongside the commits that
  implemented it.
- one specific phase-1 item, **"drop purge exclusion list from
  `p7_purge_code`"**, is confirmed still outstanding: the hardcoded 30+-entry
  exclusion list the design doc calls out as the thing phase 1 makes
  "structurally unnecessary" is still there, 43 entries
  (`grep -c 'ARG ne qw' bin/Protocol-7`), untouched. harmless in itself
  (`p7_purge_code` is only called on first load per `base.cmd.reload`, not on
  reload of an already-running process), but it's a second confirmed piece
  of unfinished phase-1 cleanup, not just this bug.
- **phases 2 through 5 have zero implementation** — no `force-replace` /
  `force-keep`, no `FINGERPRINT`, no `cfg/loader/rollback-rules/`,
  no `reload rollback` command, no `Protocol7::Source::*` tie backends
  anywhere in the repo. everything past phase 1 is design-only.
- **the likely key divergence from the documented design**: the doc states
  explicitly (line ~51) that for phase 1, `$active_version` "is still useful
  for logging, fingerprint comparison, and the rollback window timer, **but
  is not load-critical for the swap itself**" — the documented swap is
  unconditional (`%code = $CODE{$new_version}->%*` after a clean compile,
  full stop). the *actual* implementation, added later in `08b42f019` to fix
  a different problem (initial namespace loads incorrectly using the staged
  path and stranding successfully-compiled subs), introduced
  `$is_reload_batch` — gated on `$active_version` **and** on
  `$data{'code'}{$sub}{status}` from a prior pass — as a hard precondition
  for both which install path is used and whether the swap fires at all.
  that's a real behavioral fork the design doc doesn't describe or
  anticipate, bolted on to solve a narrower bug, and is the most likely home
  of this one.
- the original phase-1 checklist's own verification step — "verify reload of
  all **base** modules works without exclusion list" — only ever covered
  `base.*`. it never included a zenka-local `.cmd.`/`.console.` module in its
  test scope, which is consistent with this class of bug going unnoticed
  since March.

**recommendation**: the durable fix here is not another targeted patch on
top of `08b42f019`'s `$is_reload_batch` heuristic — it's finishing phase 1
per the doc's own (simpler, unconditional-swap) design, extending its
verification step to explicitly cover an already-loaded zenka-local `.cmd.`
module reload (exactly the probe-test gap that let this ship unnoticed), and
only then deciding whether phases 2+ are still wanted before touching this
code again. patch-on-patch on a half-finished design is how this gap
happened in the first place.

## signatures note

this codebase uses AMOS7 data signatures at the end of each module file
(4-line footer starting with `#,,.,,,...`). do NOT manually write or edit
signature lines. existing signatures on modified files will be regenerated
by the signing system. do not add fake/stub signatures to new files.

## dispatch

#,,,,,,..,.,,,.,.,..,,,..,.,.,,..,,,.,.,.,...,..,,...,..,,.,,,,.,,.,,,.,.,,.,,
#EHDB6YJK2PZ4D4HX3CLOJWQ4HQKMRWGDB2KZDBKAKLTCRCVKUFL4TFWT6LWHZKE3V6L4DQQQWXFPM
#\\\|3Z6CC2ZTTOHCGMZZZTCSB5IWECTHYRPSAJ4RXLL6JR7F3VPKIZD \ / AMOS7 \ YOURUM ::
#\[7]QWVCOBSNVWS7GYQD57T36YXJDCJWR4OROHZMYMTJGPXAJRJ5I2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
