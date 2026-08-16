---
name: topic-rename-empty-target-stuck-state-investigation-2026-08-16
description: "RESOLVED, 2026-08-16: root-caused and fixed the 'stuck status string' bug (key_actions row frozen after a rename/create guard failure, until zenka exit) -- a transient status keyword that nothing ever cleared, fixed at the plugin-mode entry trigger in user-edit.handler.stdin_key, not committed yet"
metadata:
  type: project
---

**Symptom, as user reported it**: after triggering rename (Right-arrow entry,
`r`, an existing key name, Enter to open stage 2, then Enter again on an
EMPTY target name to cancel), the `key_actions` row permanently shows
`[ last : no new key name entered, nothing renamed ]` -- no Esc, no
re-entering the tab, nothing but a full zenka exit ever made it show
anything else.

**Root cause, confirmed by direct instrumentation** (temporary `warn()`
calls added to every layer between stdin and the terminal -- stdin_key,
the plugin's own handler.key, editor.control.prompt.handler.key, form.escape,
esc_timeout, form.render -- then removed once the cause was pinned down; see
`git log`/diff on this date for the actual fix, no trace of the debug calls
remains):

`plugin.user-edit.key-actions.render` shows `<user-edit.key_actions.
last_result>` (`'last : %s'`) in PREFERENCE to the tab's own active hint
whenever that keyword is non-empty -- an OPEN prompt still correctly takes
priority over both [ that check was already fine ], but once the prompt
closes, the stale status has no expiry at all. FOUR
submit_* callbacks write it -- `submit_name`, `submit_passphrase`,
`submit_rename_from`, `submit_rename_to` -- covering both create AND rename,
not just rename. **Nothing, anywhere in the codebase, ever cleared it.**
`grep -rn "key_actions.last_result" modules/` showed 4 writers, 1 reader,
0 clears. Being a `%data` keyword, its lifetime is the whole zenka process
-- hence "until zenka exit" being literal, not a figure of speech.

**Why it looked intermittent in earlier (pre-fix) live testing**: it never
was intermittent -- the EARLIER `expect`-based repro attempts this session
used blind `sleep`-paced `send`s with no synchronization on actual process
output, and were **silently losing keystrokes outright** (confirmed by
instrumentation : `bytes_read=1 chunk=03` arriving as the very next FIRED
event after opening a prompt, with `r`, `another.1`, and both Enters never
having been read by the process AT ALL in that run). Switching to
`expect -re <pattern>`-synchronized waits [ matching actual DBG/frame output
before sending the next key, not fixed sleeps ] made the repro 100%
deterministic across every subsequent run. **Any future live pty testing of
this zenka should synchronize on output, never on sleep timing** -- the
earlier "rf3 vs rf4 inconsistent results" note from this same investigation
was this exact harness flaw, not a real nondeterministic app bug.

**The fix** (in `modules/user-edit.handler.stdin_key`, inside the
plugin-mode ENTRY-TRIGGER block -- the one that sets `$editor_state->{mode}
= 'plugin:<field>'` on a qualifying Right-arrow): clears
`$data{'user-edit'}{$focus_def->{'name'}}{'last_result'} = undef;`
right before the mode is set, namespaced dynamically off the field's own
name rather than hardcoded to `key_actions` -- a harmless no-op for any
plugin that never writes the keyword, and it covers every current writer
(create's AND rename's) the same shared way, per the fix's own comment.

**Why the clear had to go THERE and not in the plugin's own handler.key**:
first attempt put the clear at the top of `plugin.user-edit.key-actions.
handler.key` (reasoning: every submit_* callback that WRITES the keyword
runs later in the very same call, so the write would always win for its own
frame). **This did not work** -- verified live, still stuck after the fix.
Cause : `key_actions`'s own field is ALWAYS empty (a display-only pinned
field, never carries a real value), so `field_is_empty` is always TRUE, so
entry is ALWAYS single-stage -- the ENTRY-TRIGGER block itself sets mode and
`next`s immediately, WITHOUT ever calling the plugin's handler.key for that
keystroke. The clear has to live at the point that actually fires on entry,
which is the trigger block, not the per-tab dispatcher. Moved there,
verified live and reliable across 4/4 repeated runs for rename's own guard
failure and separately for create's (`submit_passphrase`'s empty-guard) --
both now show the tab's fresh hint immediately on re-entry after Esc.

**Status as of this note**: fix is written and live-verified but **NOT YET
COMMITTED** -- it's a genuine new diff against the already-committed
`user-edit.handler.stdin_key` (last touched in the reentrancy-hole commit,
`324066707`), separate from the still-uncommitted kimi rename-completion
work sitting in the working tree alongside it. Needs the user's own review
and signature before commit, same as every other change this session.

**How to apply**: if a similar "stuck last-action status" bug ever surfaces
in a DIFFERENT plugin using the same `<user-edit.<field>.last_result>`
convention, it's already covered by this fix (the clear is field-name-
generic) -- check `user-edit.handler.stdin_key`'s entry-trigger block is
still intact before assuming a NEW bug. If a plugin ever needs a
field-is-empty-but-genuinely-two-stage entry (unlike key_actions), the
single-stage-entry-bypasses-handler.key gotcha documented above applies to
it too.

#,,..,.,,,,..,.,,,..,,.,.,...,..,,.,,,,.,,,.,,..,,...,...,,.,,...,,.,,.,,,..,,
#DLUVWD5P3HPDJGAI64NAPAXBEHRPYVMIKAN3MSUP5BD2GGLZ7P37GEFS6TK4A4HV5TZPOISZMUMNQ
#\\\|7ACH4PPMWCFVBTOB7XRAQX776RE3D2AYIWKLYH34I56IOU3KJOI \ / AMOS7 \ YOURUM ::
#\[7]HSJAQHISWJAYAM22Y476A4XANENNIQODDMW5V7JSKPCVIRSL74AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
