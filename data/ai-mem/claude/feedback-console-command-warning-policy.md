---
name: feedback-console-command-warning-policy
description: policy — interactive console-facing commands must never leak raw subroutine warn()/s_warn() noise to the user; catch it and report one specific, actionable reason instead
metadata:
  type: feedback
---

stated directly by the user (2026-07-30), triggered by `keys list` spamming
~13 warning lines for what was actually one fact repeated (3 key files with
uppercase characters in their names, rediscovered redundantly by multiple
internal call paths — see the `crypt.C25519.get_keyname` memoization fix,
same session).

**the rule**: internal subroutines are allowed to `warn`/`<[base.s_warn]>`
liberally for logging/debugging — that's fine and expected, "subroutines
have warnings all over... they are not supposed to break though." what's
not allowed is a user-facing *console command* (the actual entry point a
human runs — `keys list`, and by extension any `*.console.*`/`*.cmd.*`
command meant for interactive use) letting those raw warnings stream
straight through to the terminal.

**why**: raw warns give the user no way to infer the actual cause. the
user's own words: "as user i would not exactly know what the problem is,
only infer that from 3 warnings matching 3 same looking keys that it is
something about 3 of them.. but never that it is uppercase characters in
the name." three generic "does not match any defined type" lines don't
tell you *why* — only a specific diagnosis does.

**how to apply**: when a console command's underlying subroutines can hit a
known-fallible path (unrecognized input, missing file, format mismatch),
the command itself — not the subroutine — is responsible for:
1. suppressing the subroutine's generic warn for that call (a quiet-mode
   flag is one working pattern — see `<crypt.C25519.get_keyname.quiet>`,
   set at the top of the command, cleared once the command has done its own
   collection pass),
2. collecting what went wrong itself, and
3. emitting exactly one clean, specific block explaining what happened and
   why, in place of the noise — not merely suppressing it silently, and not
   merely relabeling the same generic message.

concretely worth checking whenever a fix will touch a console command:
does the underlying subroutine already warn on this path? if so, that
warn should not reach the user unfiltered — wrap/collect/diagnose instead
of letting it pass through, even if the fix "works" without doing so.

see also: `crypt.C25519.get_keyname`'s new memoization cache — a large
chunk of the noise in the triggering incident wasn't unique warnings at
all, it was the same fact rediscovered by every independent call path that
hadn't cached its own answer. worth checking for that shape of redundancy
too, not just adding a quiet flag over noisy-but-correct repetition.

#,,,.,...,.,,,,,,,,,,,,..,,..,...,.,,,...,.,,,..,,...,...,..,,..,,.,,,,,.,,,.,
#OFVQSDMZN5LHF552A4UMBTECBGQIQSP5K7BQ3ZDIM7FP7EYLHG6JMSDNIPLYJCVKYFY2N7WZALWV4
#\\\|7PHBU3GIEUV4EP3JZ2S5XM6JI3XKSMWQRZ6NRGGA4T5TOES7XA5 \ / AMOS7 \ YOURUM ::
#\[7]HF56YA4PP5SFVSOIVREBFL3PUG6ODZUKUFRENMFC4KPJCNLE5CDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
