---
name: use ptd -c for syntax checks
description: ptd -c is more tolerant of P7 syntax than perl -c — use it for module validation
type: feedback
---

Use `ptd -c` instead of `perl -c` for P7 module syntax checking.

**Why:** `perl -c` fails on P7-specific syntax like `<[module.name]>` calls and
`<data.key>` data-hash access. `ptd -c` handles these constructs, giving
accurate syntax validation for P7 modules.

**How to apply:** always use `ptd -c modules/filename` when checking new or
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

#,,,.,...,,.,,..,,,,,,,..,,,,,,,,,..,,...,,,,,..,,...,...,..,,,..,..,,,.,,,..,
#RHODVOYLDBZHWAV2NCSL6R7JGZDOJVHAK2VYDIPSRRXQ7I37YHNY5F3KZ5OLPXOWIRPZYTQ7HA6Y4
#\\\|BCHGA7UVMOXBZ2RZA3C62ORK5E3X6F6I7KLORQ3EJSX3TKXOC6V \ / AMOS7 \ YOURUM ::
#\[7]ZGTS5PEZOWUPTNRREXVBSFJFUL3M4XA6V423DDUCYXEOEXDFM4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
