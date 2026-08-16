---
name: project-coding-zenka-bug-catalog-2026-08-15
description: "2026-08-15: auto_summarize in kimi/coding dispatch tools bypasses coding.round-progress tracking (shows 'r0 | no data yet' after real round activity) -- first entry in a catalog for a future dedicated coding-zenka bugfix session, per user"
metadata:
  type: project
---

**Bug found live, 2026-08-15**: when a `kimi_dispatch`/`kimi_continue` call's
`auto_summarize` (default true) runs, the coding zenka's
`coding.round-progress` tracking does not reflect the round that actually
happened. Observed directly: real round-0 activity printed (gen-sub-whitelist
investigation, `ptd -c` checks, `script -qec` recon establishing field/row
order), immediately followed by `coding.round-progress` reporting
`task-WQKNTZY | r0 | no data yet` -- despite round 0 clearly having data.
`coding.progress`'s own active-task count also dropped (12 -> 11) between the
two prints with no obvious corresponding completion shown. Reads as
categorical, not a one-off glitch: summarization appears to bypass whatever
mechanism normally updates round-progress state.

**How to apply**: don't trust `coding.round-progress`/`coding.progress`
output as a reliable signal for whether a dispatched task's rounds actually
progressed when `auto_summarize` was used (the default). Verify via the
session's own `kimi_check_status` output or the raw session log
(`~/.kimi/logs/kimi.log`, or `~/.kimi-code/sessions/<wd>/session_<uuid>/`)
instead, when precision about round state actually matters.

**Per user**: this is likely one of several coding-zenka bugs already noticed
in passing across sessions -- worth a dedicated future session to catalog and
fix them together rather than one-off patching mid-task. **Add further
findings to THIS file as they surface, don't create a new file per bug** --
keep the catalog in one place until that dedicated session happens.

## `coding.list-tasks` -- three separate defects, same live output, 2026-08-15

Live capture, `coding.list-tasks` "active tasks" section, every row (11 tasks
shown, `task-6LMO4GI`/`task-WQKNTZY`/`task-WHT2OJA`/etc):

```
task-6LMO4GI | in_progress | ZDMAPAY:AR3OCKQ | -3205109490948s | r0 | [task 6FJPR4A]
:no_.,. jetzt mit: score:
```

1. **Every row shares the identical requester/source field**
   (`ZDMAPAY:AR3OCKQ`) across all 11 unrelated active tasks. Per user: "the
   tasks look all the same, from the jobsite zenka" -- reads as a real bug
   (a stale/hardcoded value, or a lookup that's resolving to the wrong
   record for every row) rather than a coincidence, given 11 distinct tasks
   would not plausibly share one source in reality.
2. **Delta-time field is garbage** -- values like `-3205109490948s`
   (~101,600 years negative) and `-3205302866886s` on other rows. Some kind
   of overflow, wrong-unit multiplication, or bad epoch/timestamp
   subtraction; not a plausible "time since" value for any real task.
3. **Garbled leftover template text** on a second line under every task:
   `:no_.,. jetzt mit: score:` -- mixes English/German ("jetzt mit" = "now
   with"), reads like an unfinished/untranslated debug placeholder string
   that leaked into real output rather than being filled in or removed.

**How to apply**: don't trust `coding.list-tasks`' requester attribution or
delta-time display as accurate until this is fixed -- cross-check against the
session logs / task IDs directly if either matters for a decision. Root
cause not investigated yet -- flagged for the same future dedicated
coding-zenka bugfix session as the round-progress bug above.

## Two more loose ends, found live during the `user-edit` key-actions rescue, 2026-08-15 -- log only, not chased

1. **`base.local_history.write:57` warns `expected absolute path [ to create ]`**
   (from `base.file.make_path`) during a `users.value-set` triggered by
   `user-edit`. Read `modules/base.local_history.write:52-57`: it builds
   `[VAR_P7]/history/<category>/<id>/<epoch>` and resolves it via
   `base.path.resolve_keywords` before calling `file.make_path`. Hypothesis,
   not confirmed: `VAR_P7` is a per-zenka keyword registered via
   `base.path.register_keywords` -- `user-edit` registers its own, but
   `local_history.write` (shared, added `7551e5be0`, wired into
   `users.cmd.value-set`) actually RUNS inside the `users` zenka process for
   this call path, which may not have `VAR_P7` registered at all -- leaving
   the literal, unresolved `[VAR_P7]/...` string passed to `make_path`,
   which is not absolute. Pre-existing, unrelated to key-actions. Not
   investigated further.
2. **The password-prompt-timeout kill, from `keys.console.create`'s
   documented residual risk, confirmed live**: per user, when the
   passphrase prompt (`AMOS7::TERM::read_password_repeated`, inside
   `keys.console.create`, called from `user-edit.excursion.key_create`)
   times out, `keys.console.create` reports "cannot create keys without -U"
   and the WHOLE `user-edit` zenka exits -- exactly the `base.exit` ->
   `CORE::exit` path `user-edit-key-actions-create.md`'s task file flagged
   as an un-pre-emptable residual risk (the password is read inside
   `keys.console.create` itself, can't be validated beforehand). Per user:
   "cosmetic warning issue we might want to catch later" -- not fixed now,
   deliberately deferred.

## HIGH SEVERITY, not just "log" -- `bin/dev/gen-sub-whitelist` silently
## drops still-live entries on a plain re-run, 2026-08-15

While rescuing the key-actions tab, running `bin/dev/gen-sub-whitelist
user-edit` (to pick up the new `user-edit.form.build_user_keys_field` /
`user-edit.excursion.key_create` / `plugin.user-edit.key-actions.*`
references, all newly added) **silently dropped an existing, still-live
entry**: `crypt.C25519.cmd.get-public-key`, called via a literal
`<[crypt.C25519.cmd.get-public-key]>->()` inside `plugin.user-edit.
key-details.render` -- a file this session never touched. Result: the
NEXT `user-edit` start crashed outright --
`[base.load_modules] no routines were loaded ..,` repeated, then `FATAL
ERROR : deep recursion on anonymous subroutine
[crypt.C25519.cmd.get-public-key:1]`, emergency exit. Confirmed live: the
crashed zenka would not start at all until the dropped line was manually
restored into `configuration/zenki/user-edit/subroutines.load-early`, after
which `commands` and `show-form taeki` both loaded cleanly again.

Per user: **this should never happen** -- the whitelist mechanism is
supposed to work transparently, and dropping a sub that is still statically
referenced by a literal `<[...]>` call in a scanned file is a real bug in
`bin/dev/gen-sub-whitelist`'s reachability logic (it shells out to
`bin/dev/dep-graph` for the actual analysis, not a flat grep -- read
`bin/dev/gen-sub-whitelist`'s own top-of-file header before digging in),
not an acceptable "sometimes you need to re-add things by hand" quirk.

## `kimi_dispatch`'s `model` parameter was not honoured, burned the account's
## remaining kimi quota on a pure-design run, 2026-08-16

Dispatched `mcp__protocol-7__kimi_dispatch` with `model: "k3-256k"` for the
`editor-inframe-prompt-primitive.md` task (explicitly chosen over full k3
for cost, per this session's own earlier budget discussion). The session's
own reported context window was **`context: 14.7% (154k/1m)`** -- a 1M-token
ceiling, which is full K3's window, not K3-256k's 256k cap. Per user: this
is why it hit its usage limit before writing a single line of code (pure
design/file-reading burn, ~87K chars of reasoning, zero `Edit`/`Write`
calls) -- the wrong, more expensive model ran despite the explicit
parameter. Process was terminated by the user; per user, roughly a 2-hour
cooldown before it can be told to continue (not the "next billing cycle"
wording the 403 error itself displayed -- trust the user's own account
knowledge over the API error text if they ever disagree again).

**How to apply**: do not trust `kimi_dispatch`'s `model` parameter to have
actually taken effect -- **check the session's own reported context-window
size in its output/log** (256k ceiling vs 1M) as the real signal of which
model actually ran, every time, especially before a long/expensive dispatch.
Root cause not investigated (harness-side default-model fallback? a
stale/ignored param?) -- flagged for the same future dedicated coding-zenka
bugfix session as the other items in this file, but this one has a direct
cost consequence, not just a display/UX one -- treat it as high severity
alongside the `gen-sub-whitelist` entry above.

**How to apply**: NEVER treat a `gen-sub-whitelist` re-run as a safe,
consequence-free step, even when only ADDING new references. **Always
`git diff` the regenerated `subroutines.load-early` file before trusting
it** -- check for REMOVED lines, not just the added ones you expected, and
restart-test the zenka before considering the regen done. This is now the
single highest-severity item in this catalog: unlike the display/tracking
bugs above, this one took a live zenka down and would silently repeat on
every future regen until the underlying `dep-graph`/`gen-sub-whitelist`
logic is actually fixed.

**UPDATE 2026-08-16, see [[project-loader-deferred-compile-disabled-cmd-fix-2026-08-16]]**:
this exact entry recurred a 4th time, and the CRASH consequence is now fixed
at the root -- two real bugs in `bin/Protocol-7`'s `p7_load_code` itself
(not `dep-graph`/`gen-sub-whitelist`, which was never actually confirmed to
be the thing dropping the entry). A dropped whitelist entry for a disabled
cube-only command now self-heals via deferred compile instead of crashing
the zenka. Whether `gen-sub-whitelist` still DROPS the entry on a fresh
regen was not re-tested -- the "always `git diff` the regen" advice above
still stands, the stakes of missing it are just much lower now.

#,,.,,,,,,,..,,.,,,,.,,,.,,,.,..,,,..,..,,.,,,..,,...,...,..,,.,,,,,,,...,,..,
#SMHTOLDQDX4SEQY7N2S7XNXUEIJN6ZYLOIYTWAIGAWUVO5CUR4SA5335OOPFPU3LKW57TNI42LRQ6
#\\\|OTIPL2SF5RNFTYGD5ESGYHASCUHK2JBRR634WAQVI4YGVUS423T \ / AMOS7 \ YOURUM ::
#\[7]BOEPQ33HUDAQHQDQX76FEQK7JSKJTEUAUEWTDYICPALHPQSACQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
