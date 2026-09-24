---
name: reload-success-doesnt-guarantee-new-file-loaded
description: mostly a non-issue -- 'reload source' explicitly excludes plugin.* modules by design (base.cmd.reload, grep $ARG !~ m{^plugin\.}); use 'reload plugins' or 'reload all'/bare 'reload' for those, always zenka-prefixed. The 2026-08-04 .cmd.-whitelist-gate bug below is a separate, narrower historical issue.
metadata:
  type: feedback
---

## CORRECTED 2026-09-16: the 2026-09-15/16 "recurrence" was not a bug

Root cause found in `src/base.cmd.reload` itself (confirmed by reading the
source, not just symptom-testing): the `source` keyword's reload set is
built with an explicit namespace exclusion --

```perl
my @previously_loaded
    = grep { $ARG !~ m{^plugin\.} } <[base.clear_p7_mods]>;
my @configured_modules = grep { length and $ARG !~ m{^plugin\.} }
    split( m| +|, <modules.load> // '' );
```

`reload source` (and therefore the `source` half of bare `reload`/`reload
all`... no wait, `all` DOES also run the separate `plugins` branch, see
below) never touches anything under the `plugin.` namespace, by design.
There is a dedicated `plugins` keyword (`base.cmd.reload`, ~line 138) that
calls `base.reload_plugins` for exactly that set. `reload all` and bare
`reload` (no keyword, defaults to `all`) run BOTH the `source` and
`plugins` branches, so either of those picks up a `plugin.*` edit too --
only the specific `source` keyword alone excludes it.

**During the 2026-09-15/16 usage-zenka session**, the files that seemed to
need a restart were `plugin.usage.kimi.handler.response` and
`plugin.usage.claude.handler.response` -- both genuinely `plugin.*`
namespaced, so `reload source` structurally could never have picked them
up, restart or no restart wasn't really the deciding factor there. The
`usage.cmd.*` / `usage.format.report` files are NOT `plugin.*` namespaced
and should reload fine via a correctly zenka-prefixed `reload source` --
one of the failures on those was very likely a bare, unprefixed `p7c
reload source` not even targeting the `usage` zenka in the first place
(never isolated which zenka a bare unprefixed reload actually hits --
treat as a separate open question, not resolved either way).

**Corrected guidance**: don't default to `v7-zenki.restart <zenka>` as a
blanket "reload can't be trusted" fallback -- that was an overcorrection
from incomplete diagnosis (found a workaround, didn't find the cause).
Instead:
- always prefix reload commands with the target zenka (`<zenka>.reload
  <keyword>`), never a bare `reload`/`p7c reload ...` when a specific
  zenka is intended
- for anything under the `plugin.*` namespace, use `<zenka>.reload
  plugins` or `<zenka>.reload all` -- `<zenka>.reload source` will never
  pick it up, that's not a bug to work around, it's how the keyword is
  defined
- a full `v7-zenki.restart` is still the right move for the genuine,
  narrower 2026-08-04 `.cmd.`-whitelist-gate class of bug below, or for
  anything registered as a raw `Event->io`/`Event->var` watcher callback
  (see [[event-watcher-callback-reload-needs-restart]]) -- but reach for
  the matching reload keyword first, restart is not the default anymore

---

## original 2026-08-04 entry [ separate, narrower issue -- .cmd. modules only ]

## RESOLVED 2026-08-04

Root cause and fix: [[loader-reload-stale-cmd-modules]]
(`data/tasks/completed/loader-reload-stale-cmd-modules.md`). Not
`$is_reload_batch` as suspected below — the actual bug was in
`p7_load_code`'s whitelist-gate block (`bin/Protocol-7` ~line 1586-1621):
once a non-whitelisted `.cmd.` module got real compiled code installed
(via `base.load_runtime_modules`'s whitelist-bypass on first runtime
access), the gate's `if (not exists $code{$file_name})` guard treated
"already exists" as "nothing to do" and unconditionally skipped the file
on every future `p7_load_code` pass — it never re-entered
`@compile_order`, so no `reload` could ever pick up further edits, only
`v7.restart`. Fixed by distinguishing "still an uncompiled deferred
stub" (unchanged: skip) from "real code already there" (now: falls
through to normal recompilation, like any other file).

Verified live on `mod-test`: two consecutive `reload source` calls
correctly picked up edits with no restart needed.

**Updated guidance**: the "default every live-fix dispatch's
verification to `v7.restart <zenka>` instead of `<zenka>.reload`"
workaround below is no longer necessary as a blanket default — plain
`<zenka>.reload` can be trusted again for modules reached via the
normal load path. Still worth a literal-marker sanity check on
first verification of any given fix, as general hygiene, but not
because reload itself is suspect anymore.

---

## the trap [ historical, pre-fix ]

`p7c <zenka>.reload all` (or `reload source`) reporting
`reload source  [ success ]` is not proof the edited file's new content
is actually what's executing. Confirmed unambiguously in [[topic-job-pipeline]]'s
2026-07-23 session: added a literal marker field
(`$numeric_prefs{'_marker_v2'} = 1;`) to a command's JSON reply, reloaded
repeatedly (`reload source`, then `reload all`), and the marker never
appeared in the live HTTP response across multiple attempts — only a
full `v7.restart <zenka>` picked up the change.

This happened on a **freshly-created** `jobsite.cmd.*` file being edited
again shortly after creation, which may be a relevant factor (as opposed
to editing a file that's been loaded and stable for a while) — not
confirmed either way, treat any freshly-added file with extra suspicion
until proven otherwise.

**Why:** unclear. `base.cmd.reload source` deletes `<base.commands>`
and `<base.subroutines>` and calls `base.load_modules` over the
configured namespace list, which should re-glob and recompile
everything under that namespace — in principle this should pick up a
brand new or freshly re-edited file. Whatever the actual mechanism is,
it demonstrably didn't in this case, twice, on the same zenka in the
same session.

**How to apply**: don't trust a "reload success" message alone when a
just-made change doesn't visibly take effect. Before spending time
debugging the *logic* of a change that "isn't working," add an
unambiguous marker (a literal new field in a reply, a distinct log
line) and verify it actually shows up live. If it doesn't after a
reload, escalate straight to a full zenka restart rather than repeating
reload cycles — that's what actually resolved it both times this was
hit. This may also retroactively explain otherwise-confusing "why isn't
my fix working" sessions that got attributed to a different root cause
because the real one (stale reload) was never suspected.

**Third occurrence, 2026-08-04, `kimi` zenka**: after landing the
`QuestionRequest` silent-hang fix (new module
`src/kimi.wire.question_respond` + a `src/kimi.handler.ws_message`
branch edit), `kimi.reload source` reported success but the edit did not
take effect — the user had to direct `v7.restart kimi` explicitly, and K3
discovered the staleness itself mid-verification. Same shape, third zenka
(`jobsite` twice, now `kimi`), confirms this is a real, general loader bug
not specific to one zenka or one kind of edit. Root-cause investigation
and fix plan: [[loader-reload-stale-cmd-modules]] (`data/tasks/
loader-reload-stale-cmd-modules.md`, priority explicitly raised same day
given this third hit) — has already traced the likely faulty commit
(`08b42f019`'s `$is_reload_batch` staging-vs-direct-install fork) and a
minimal isolated reproduction via coderef-address comparison. Until that
lands: **default every live-fix dispatch's verification instructions to
`v7.restart <zenka>` after editing an already-loaded module**, not
`<zenka>.reload` — treat reload-then-verify as unreliable by default,
not just as a fallback for when something looks wrong.


**New commands [ 2026-09-24, per user ]**: adding a name to `access.cmd.usr.cube` in `zenka.v7` needs `<zenka>.reload config` -- it re-runs the access regex parser [ `base.parser.access_conf` ]. a new command usually also brings a new `<zenka>.cmd.<name>` module, which needs `reload source` too : do both [ source, then config ]. `reload source` alone leaves "command not known or no permission".

**Moved namespaces [ 2026-09-24, per user ]**: code in a namespace that is mapped elsewhere via `swap_subs` [ e.g. `base.file.*` moved to `file.*` ] also needs `<zenka>.reload init` -- the swap_subs calls are only processed in the pre_init / init_code / post_init files, so `reload source` alone leaves the old mapping pointing at the previous code.

**Default [ 2026-09-24, per user ]**: plain `<zenka>.reload` [ all phases ] is the safe default rather than picking the narrowest stage -- init phases are required to be reload-safe at any time, so if a full reload raises something that is a regression to fix, not a reason to reload less. see [[feedback-init-phase-idempotency-is-a-hard-invariant]]. narrowing to one stage is fine when obvious ; the full reload just leaves less to think about or double-check.

**Restart-only changes are defects [ 2026-09-24, per user ]**: the only remaining reason a zenka needs a restart for a code or config change is a handler that is neither registered reload-safe nor reinstalled in an init phase. when such an instance is found, fix it [ make it reload-safe or reinstall it at init ] rather than accepting the restart -- the goal is that no zenka ever needs a restart just for code or config changes.

#,,,.,,.,,,.,,.,,,.,,,..,,,,,,..,,...,.,.,.,,,...,...,...,..,,..,,...,..,,,..,
#CQVPVHRVPYMZPEY7BUAJGKONZUQKJUNHBQQNA7TF6DD4AM2GVNPLKJA7Z64VMXFVX6U6TQF6KMTHM
#\\\|XE2IB6ZG57DVLHMI3IXHFXUVCMA2K5FV4AK4LKXUZBNCYMYBG5H \ / AMOS7 \ YOURUM ::
#\[7]HTM7EQQIRJVVRDT74PJXEDZC6HY7F6LEYWFN7W5VQLHNXQ3IFCBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
