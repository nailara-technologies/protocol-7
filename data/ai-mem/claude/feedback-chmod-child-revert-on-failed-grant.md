---
name: feedback-chmod-child-revert-on-failed-grant
description: a chmod-child side effect (grant/create) needs cause-and-effect tracking so a later failure or staging-fallback path can revert it -- consuming the reply (see [[feedback-chmod-child-restore-readline]]) is necessary but not sufficient
metadata:
  type: feedback
---

Reading the chmod child's reply (readline, per
[[feedback-chmod-child-restore-readline]]) only fixes pipe desync. It does
not by itself mean anything is done with the reply's *content*. A second,
distinct bug class survives even when every reply is correctly consumed:
the caller grants/creates something, the reply is `ok`, but the caller
still can't write for some other reason (missing admin group, race,
whatever) — and the grant or created file is then abandoned on the failure
or staging-fallback path instead of reverted.

**Two concrete shapes, both found live 2026-09-23:**

1. **Abandoned permission grant**: `gw`/`gwd` succeeds (`ok`), but
   `-w $path` is still false afterward. If the caller only does
   `$mode_restore = $cur_mode if -w $path` (the OLD pattern — `mode_restore`
   never gets set when `-w` fails, so the later restore-if-defined block
   never fires), the file/dir is left permanently more permissive than
   before, with nothing ever put it back. Original symptom in
   `usage.status`... no wait, this is the coding-zenka side: found first in
   `coding.tools.handler.write_new_file`'s siblings
   (`write_append`/`replace_line`/`insert_line`/`delete_lines`/
   `replace_in_file`/`regex_replace_apply`/`regex_replace_undo`/
   `write_with_perms`/`apply-staged`/the inline `edit_file` in
   `coding.tools.dispatch`), then confirmed as the same class in the
   *separate* `ncode.cmd.apply` chmod-child system (two independent grant
   sites there).

2. **Abandoned empty file**: `create` succeeds, but a *later* step in the
   same function either returns early (e.g. `write_new_file`'s encoding
   validation used to run AFTER the create block) or falls through to a
   staging/failure path — leaving an empty, already-created, group-writable
   file sitting at the real target path while the actual content goes
   elsewhere (staged/) or nowhere. Worse: a retry is then permanently
   blocked by whatever "file already exists" guard the tool has. Found in
   `write_new_file` and `coding.tools.handler.scratchpad_rescue`.

**The fix pattern, applied across the whole sweep:**
- Reorder validation to run *before* any chmod-child side effect wherever
  the code structure allows it (removes the abandoned-empty-file case
  entirely rather than cleaning up after it — the same "fix the root cause,
  don't patch the symptom" instinct as always).
- Where a grant already happened and might need reverting: capture the
  reply (`my $reply = <[...readline]>`), then `if (-w $path) { set
  mode_restore } elsif ($reply eq 'ok') { send a restore back to the
  original mode, consume that reply too }`.
- Where a create already happened and content ends up going elsewhere: a
  `$created_via_child` flag set only on an exact `ok` reply (never assume
  from `-f $path` alone — a pre-existing file must not be mistaken for one
  this call created), and a new `remove <path>` chmod-child command sent on
  the abandoned-file path, guarded by that flag plus `-f and not -s` (empty
  check) so a partially-written real file is never touched.
- `remove` was a genuinely new command needed on `coding`'s chmod child
  (`src/coding.start.chmod_child`); `ncode`'s separate child never needed
  one since no `ncode` caller issues `create`.

**How to apply:** any *new* chmod-child (or similar privileged-helper)
caller that grants a permission or creates something must ask two
questions before considering itself done: (1) if the grant/create
succeeded but the intended write still fails for an unrelated reason, is
the side effect reverted? (2) if validation can fail *after* the side
effect in the function's current order, can it be reordered to fail
*before* it instead? Landed 2026-09-23 across `coding.start.chmod_child` +
12 coding-zenka tool handlers + `ncode.cmd.apply` — see git log around
commits `e71e5a099` (write_new_file/write_append) and `4f27f332e` (the
full sweep) for the reference shape to copy from.

Found by: a resilience-focused review session that started from an
unrelated bug report (originally misdiagnosed as UTF-8 encoding, actually
a `coding.async.backend_acquire` reentrancy race — see
[[project-coding-async-backend-acquire-reentrancy-race]]), then noticed
this class of bug while re-reading `write_new_file` for something else
entirely. Dispatched to kimi (k2.8 for the single-file fix, k3 for the
full ~14-file sweep) with each finding independently verified — every
touched file syntax-checked, several diffs read in full, one "ruled safe"
claim (`file_rename`) confirmed by direct inspection rather than trusted
on the model's word.

#,,.,,.,.,,.,,...,...,,..,.,.,,,,,,,.,..,,..,,.,.,...,...,..,,,.,,,,,,,.,,,,,,
#CGNTWTIYKY3UMHHOAY5IRF7FMVUJ5GZN3ZHZ437AH56XUP4GPG4R6IOQRZWGAWJNNX5YE2BD43ECK
#\\\|OANOOC26KJQGVPH2MI6UMRS4BOMTZDRUECRDUIMWHGYJVFHTZKW \ / AMOS7 \ YOURUM ::
#\[7]UE33GONGJA3I6FPN7Z362RJ634HHXXTCQ5SBGU76CDY36F3IRCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
