---
name: feedback-nshell-debug-mode-persists-across-reload
description: <nshell.mode.no_tty_debug> left on causes visible display corruption (ghost/duplicate-looking lines) in normal interactive use, and survives nshell.reload since it lives in %data not compiled code -- only a full process restart clears it
metadata:
  type: feedback
---

2026-09-14: chased a real-looking "ghost command history" bug (old buffer
text lingering, replaced line by line as new characters were typed) through
several rounds of static code review of `nshell.render.viewport`/
`nshell.editor.process`/`nshell.split.toggle` (that session's actual new
code, a Tab-toggled split-screen scroll-region feature) before the user
correctly identified the real cause: `<nshell.mode.no_tty_debug>` was left
enabled, and its debug-logging side effects were producing the visible
corruption in completely unrelated, ordinary interactive commands
(`whoami`, `time`, `list`) — not the split-screen code at all, which was
independently confirmed inert (`split_active` was genuinely `undef` via a
live `eval-code` check, both before and unrelated to this).

**Why this was hard to diagnose**: `nshell.reload` (a module/source
recompile) does NOT reset `%data`, only `%code` — so a `no_tty_debug` flag
left on from earlier testing (this session's own diagnostic work, or an
earlier probe) survives every subsequent reload silently. Only a full
zenka process restart clears it. This made a stuck debug flag look
identical to "a regression introduced by the code that was just reloaded."

**How to apply**: before attributing a fresh-looking display/behavior bug
in nshell (or any zenka) to code that was *just* reloaded, check for and
clear any debug/diagnostic mode flags left on from earlier work in the
same session — `<nshell.mode.no_tty_debug>` specifically, but the general
rule is any `%data`-stored mode flag survives `reload` and needs an
explicit check, not just a code diff review. A full process restart is a
legitimate, fast diagnostic step precisely because it's the only thing
that resets `%data` state alongside code -- use it early when a bug's
timing coincides with a reload, not just at the end after exhausting code
review.

#,,,.,.,.,,..,.,,,.,.,,..,,..,,,,,,..,.,,,,.,,..,,...,...,,,,,,,,,.,.,..,,..,,
#RKLQAR2MQY3VDWUR6VHGXK5TUOYCJV6UBPL54PJZRXPSYRTOV33SOI44BREPYD54QAZKJ6Q42EQLW
#\\\|2RFHQT6CMJSIN6XAAA3P27P3EEEBIA7VCXKIWDJSYIR5NL7UN3S \ / AMOS7 \ YOURUM ::
#\[7]HIQLF44DUN2VHIHOO5V5MMCYYOEU2VA5HOROENFYT7KBRVW7HAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
