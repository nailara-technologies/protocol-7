---
name: reload-success-doesnt-guarantee-new-file-loaded
description: the 2026-08-04 fix did NOT stay fixed -- recurred 2026-09-15/16 on the usage and coding zenki across many edit/reload cycles; default to v7-zenki.restart <zenka> for verification, don't trust reload
metadata:
  type: feedback
---

## RECURRED 2026-09-15/16, `usage` and `coding` zenki

During a multi-round `usage.format.report` redesign session, `p7c reload
source` (bare, no zenka prefix) AND `p7c usage.reload source` (explicitly
prefixed) both repeatedly reported success while live output kept showing
the pre-edit format -- across at least three separate edit rounds (the new
`pretty` format branch, the row-separator fix, the leading-blank-line fix).
Every single time, `p7c v7-zenki.restart usage` (or `restart coding` for
the coding-zenka side of the same work) was what actually made the edit
visible. Confirmed via literal before/after diffs of live command output,
not just a "reload said success" assumption -- e.g. a row-separator line
that provably was not there after `reload source`, then provably was
there after `v7-zenki.restart usage`, no other variable changed.

This directly contradicts the "resolved, reload can be trusted again"
update below from three weeks earlier. Either the 2026-08-04 fix was
incomplete/regressed, or it doesn't cover whatever load path `usage.cmd.*`
/ `usage.format.report` / `plugin.usage.*.handler.response` /
`coding.handler.*` / `coding.tools.handler.*` go through. Root cause not
re-investigated this session -- the restart workaround was cheap enough
(these are on-demand zenki, a restart just re-spawns them) that it wasn't
worth chasing further, but note: restarting the `usage` zenka clears its
in-flight state (e.g. `refresh_state` single-slot guards) and the
`coding` zenka's cached `<coding.account_usage>`, so a restart-based
verification loop will show a transient "no cached data yet" / cold-start
result on the very next call -- expected, not a new bug.

**Updated guidance**: revert to defaulting every live-fix verification to
`v7-zenki.restart <zenka>`, not `<zenka>.reload` / `reload source` --
across at least two zenki this session, reload's "success" was not a
reliable signal that new code was actually running. Don't re-trust reload
again without a fresh, deliberate re-test.

---

## original 2026-08-04 entry [ superseded by the recurrence above ]

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

#,,,,,,,,,,.,,,.,,.,,,,,,,,,.,..,,..,,..,,,..,...,...,...,,..,.,,,,.,,,.,,..,,
#E5RW3L5JNUGPWTE4JNQAHFYHR4HSIO5HVTTJHIZN47OZ5GEAEK5DM77WHZ6JHIEG3WF67ZBDWAIV4
#\\\|JAXLRKCCKOETM6FLICDTNDP42VSYKS4Y22DHVCTXAW5RFBPMCR2 \ / AMOS7 \ YOURUM ::
#\[7]5AOL62TVG6QPO7UUHN4NJE2HVLNMHCBHU55X4H6JCYSWEZWY7UAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
