---
name: use ptd -c for syntax checks
description: ptd -c is more tolerant of P7 syntax than perl -c — use it for module validation
type: feedback
---

Use `ptd -c` instead of `perl -c` for P7 module syntax checking.

**Why:** `perl -c` fails on P7-specific syntax like `<[module.name]>` calls and
`<data.key>` data-hash access. `ptd -c` handles these constructs, giving
accurate syntax validation for P7 modules.

**How to apply:** always use `ptd -c src/filename` when checking new or
modified P7 modules. Reserve `perl -c` only for standalone scripts that don't
use P7 syntax.

**Update 2026-07-24:** `ptd -c`'s exit code used to be decorative — it always
`exit(0)` regardless of real syntax errors, and only ran the `perl -c`
fallback when perltidy itself failed (perltidy silently accepts plenty of
broken perl). Fixed: exit code now reflects real pass/fail, `perl -c` always
runs in `-c` mode, and the P7-false-positive filter was broadened to also
catch the `defined or assignment (//=)` variant that `<data.key> //= {}`
produces. Safe to script against the exit code now; see
[[project-ncode-write-path-2026-07-24]] for the fix and how `ncode.cmd.apply`
uses it as a hard write-gate.

**Gap found 2026-08-22**: `ptd -c` reports clean "syntax ok" for a file
that still produces a real Perl compile-time WARNING (not a fatal
error) — e.g. `0xFFFFFFFFFFFFFFFF` (a 64-bit hex literal) triggers
"Hexadecimal number > 0xffffffff non-portable", visible only via the
live zenka's own `<zenka>.show-buffer compile-errors` after an actual
restart, not via `ptd -c` at any point. `ptd -c` only validates that
the file compiles at all (exit code / fatal-error check) — it does not
surface non-fatal warnings. **How to apply**: `ptd -c` is necessary but
not sufficient before considering a file done — after restarting the
zenka that loads it, also check `<zenka>.show-buffer compile-errors`
(the buffer only exists/has content when there's something to report,
so "no such buffer" after a restart is itself the clean-pass signal).
Prefer `~0` over a literal max-value hex constant for a 64-bit
"unlimited"/sentinel value — it's both more portable (matches the
build's native word size) and avoids the warning outright.

#,,..,,.,,,..,,,,,...,,..,.,,,,,,,,,.,,.,,,.,,..,,...,...,..,,.,.,.,.,...,,..,
#UQGKMUIQJRFRMZS3ZF3VAVPBVO4ZYJAKW55BRBHIQ7FGG7IICKISYLLJ5N6LU6SGNHD2WOTN4UURK
#\\\|UJMYKDJE5A555J7HLPWLADMJF2XXBDRHNUHJLAYUMEHFCEADCVW \ / AMOS7 \ YOURUM ::
#\[7]BXZ52BQU34NMR34VA2VXIKZ3OBAPP6ZHPB4CDSLBV4ILFCGOOMAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
