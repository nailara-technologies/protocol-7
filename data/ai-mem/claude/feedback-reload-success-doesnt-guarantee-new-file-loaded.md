---
name: reload-success-doesnt-guarantee-new-file-loaded
description: base.cmd.reload can report "reload source [ success ]" without actually recompiling a freshly-created or freshly-edited module — confirmed twice in one session, only a full zenka restart picked it up
metadata:
  type: feedback
---

## the trap

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

#,,,.,,..,,..,..,,,..,.,.,,,,,,,,,,,,,...,...,...,...,...,,,,,.,.,,,.,.,.,.,.,
#4TEDBRKE6S7X3HSV55VRHKONLSCMLO73CW5HFOXBXFIQFLRB2GZQGAAKM7A3MR5BWN67XIJRRRUBI
#\\\|PCNTNQLDS4ULHTKGTNALDI3OJF2TXJMB222APJVOUPKH3TOMVDU \ / AMOS7 \ YOURUM ::
#\[7]O7KWYJCDBQ6TSDNHWEKT2BIUZIWO4G5XWMVLGXAIFFG3FPB2D6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
