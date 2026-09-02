---
name: reference-debug-via-proven-sibling-pattern
description: when a hypothesis-driven fix has zero effect on a live bug, stop theorizing and find a structurally-similar, already-proven-working piece of code to diff against directly -- cracked the debian apt_child EPERM/ESRCH bug this way after two wrong guesses
metadata:
  type: reference
---

When debugging a live bug and a fix based on a plausible hypothesis has **zero effect** on the
symptom, stop generating more hypotheses from first principles. Instead find a structurally
similar piece of code elsewhere in the codebase that is *already proven working* and diff
against it directly.

**Why**: confirmed effective 2026-09-02, chasing `debian`'s apt_child reporting false "not
available" for every install job despite a genuinely healthy, freshly-forked child. Two wrong
hypotheses were chased first (guard-clause return paths, then `IPC::Open2::open2`'s
filehandle-arg aliasing not surviving a deep `%data` hash-element passed directly) — both
disproven by diagnostic logging and a "fix" that changed nothing. The user's prompt broke the
loop: "did you look at the chmod child and similar child processes? if it works for them it will
for us." Comparing `debian.start.apt_child` against the structurally-identical, working
`coding.start.chmod_child` immediately ruled out the aliasing theory (same direct-sugar-argument
style, works fine there). Comparing the *consumer* side (`debian.job.apt_install`'s liveness
check) against `coding.tools.handler.write_with_perms` (the chmod-child's own consumer) surfaced
the real divergence: the working pattern never calls `kill(0,$pid)` at all. That absence was the
answer -- an unprivileged parent can't signal-check its own root-owned forked child (`EPERM`,
indistinguishable from `ESRCH`/no-such-process by return value alone), so the check always failed
regardless of child health.

The same technique cracked a *second*, independent bug immediately after: when the fix's
server-side evidence (real `apt-get` output, genuine install success) didn't match the
user-visible symptom (still reported "failed"), that mismatch was the signal the bug had moved
downstream rather than that the fix was wrong. Comparing `sys-deps.handler.install_reply` against
`zenki.handler.v7_start_reply` (fixed earlier the same session against the same reply-handler
contract) found it reading `$reply->{'mode'}`/`{'data'}`, fields that don't exist on the real
`{sid, cmd, call_args, params}` hashref `base.handler.command.process_reply` actually passes.

**How to apply**: after one hypothesis-driven fix attempt fails to change a live symptom, actively
search for a sibling implementation solving the same *shape* of problem (same fork-before-drop
pattern, same reply-handler contract, same event-watcher registration, etc.) elsewhere in the
codebase, and diff the two directly — both the producer/setup side and the consumer/check side —
rather than reasoning further from the failing code alone. A working analog often reveals the
missing or extra step directly, faster than continued first-principles theorizing.

#,,,,,..,,,..,.,,,...,,,.,,.,,.,,,,,,,...,,,,,..,,...,.,.,,,.,,.,,,..,,..,,,.,
#4X32GFQ6JXOWV3UHZQ7KPPPQXJV7GA3S3MUIMTHXQLOU26N6W3YBHG6DAB5LS7EB4YATDA3WIRL7O
#\\\|ZQOLGGAJYBV2S2JZSN33WW2L65D4PL5GQZA4YY5EWKTQVL4QECO \ / AMOS7 \ YOURUM ::
#\[7]MVCSJHJFC7ZPAFYNZQ3LGBMLBMAP3PRZGDDG6W3HVEPVJCJUMKBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
