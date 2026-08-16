---
name: project-loader-deferred-compile-disabled-cmd-fix-2026-08-16
description: "root-caused and fixed the crash consequence of the recurring crypt.C25519.cmd.get-public-key whitelist-drop bug ([[project-coding-zenka-bug-catalog-2026-08-15]]'s 'HIGH SEVERITY' entry) -- two real bugs in bin/Protocol-7's p7_load_code, not dep-graph/gen-sub-whitelist itself"
metadata:
  type: project
---

**What this fixes, and what it does NOT fix**: the 2026-08-15 catalog entry
([[project-coding-zenka-bug-catalog-2026-08-15]]) documented `gen-sub-
whitelist` silently dropping `crypt.C25519.cmd.get-public-key` from user-
edit's `subroutines.load-early`, crashing the zenka on next start (`no
routines were loaded` flood, then `FATAL ERROR : deep recursion on anonymous
subroutine`, emergency exit). It recurred a 4th time on 2026-08-16. This
session root-caused the CRASH and fixed it at the source -- but did **not**
re-test whether a fresh `gen-sub-whitelist user-edit` regen still drops the
entry in the first place. Read `dep-graph`'s own `.cmd.`/`.console.`
reachability walk (`bin/dev/dep-graph` ~line 947, gated on `$loaded_set->
{'net'}`) before assuming that half is fixed too -- it wasn't re-verified.

**Root cause of the crash, two independent bugs in `bin/Protocol-7`'s
`p7_load_code`**, found by adding temporary `warn` instrumentation and
reproducing live (real pty, `expect`) with the whitelist entry deliberately
still missing:

1. `crypt.C25519.cmd.get-public-key` is *intentionally* disabled for every
   non-cube zenka -- `base.init_code` calls `<[base.disable_command]>` on a
   whole list of cube-only commands (`get-public-key`, `get-session-sig`,
   etc.) so cube never routes them externally to a non-cube zenka. Correct,
   deliberate security behaviour. The bug: `p7_load_code`'s `next if
   $cmd_type eq 'cmd' and exists $disabled_commands{$cmd_name}` used the
   SAME disabled-list check to skip **compiling the sub at all**, not just
   registering it in cube's external dispatch table
   (`$data{'base'}{$cmd_type}{$cmd_name}`). That silently broke every
   legitimate INTERNAL `<[...]>` call site within the same zenka's own code
   (here: `plugin.user-edit.key-details.render`'s `<[crypt.C25519.cmd.get-
   public-key]>`, a plain static call, nothing dynamic).
2. Separately, `p7_load_code`'s staged-hash-swap only ever promotes a
   successful compile into the live `%code` for two cases: the very first
   boot load (`not defined $active_version`) or an explicit reload batch
   (`$is_reload_batch`, which requires a sub in the batch having a PRIOR
   'no-error'/'warned' status). A module that was only ever STUBBED
   (whitelist-deferred, never previously compiled) being compiled for the
   first time via a LATER runtime/deferred call falls into neither case --
   compiles successfully, gets silently discarded. `base.handler.
   deferred_compile`'s own `goto &{ $code{$sub_name} }` handoff can't tell
   "still the stub" from "real code, same ref check (`ref eq 'CODE'`) is
   true either way" -- so it re-enters the still-a-stub sub, which re-enters
   deferred_compile, forever, until Perl's recursion-depth guard aborts.

**Fix**: `bin/Protocol-7`'s `p7_load_code` -- split the disabled-command
check (`$cmd_disabled`) so it only gates the dispatch-table registration
line, never the compile; and widen the swap condition from `$is_reload_batch
and not $err_count` to `defined $active_version and not $err_count`, so ANY
successful compile after the initial boot load gets applied, reload-batch or
not. Landed in commit `b056a04c4`. Verified live, repeatedly, with the
whitelist entry deliberately still absent: clean startup, correct rendered
value (`identity key : taeki.base <:ZITAETA:YKO7BCA:>`, byte-identical to
the eager-whitelisted path).

**How to apply**: if a FUTURE whitelist-drop of a disabled cube-only command
still crashes a zenka the same way, the bug is back or incomplete -- these
two conditions in `p7_load_code` are the first thing to check, not `dep-
graph`. If a whitelist-drop of an ORDINARY (non-disabled) command still
crashes, that's a different bug -- this fix only covers the "compiles fine
but the disabled-check or the swap-condition ate it" failure mode, not every
possible deferred-compile failure.

#,,.,,..,,,,,,...,.,.,,,.,,..,,..,..,,,,,,,..,..,,...,..,,..,,.,,,,..,,..,..,,
#YS4DTD37H2EAIKF5VPFVJPD4MBT2KUH7B3NRQJ3GMVV4GF5OTSUF2QPYU5SGMW4WMBOYF4WUK2WZO
#\\\|AUWOONGDDV4MRTS5SIODXUNXHPEY6VULWGHIBXXVJIN4544B2E5 \ / AMOS7 \ YOURUM ::
#\[7]3GOAWRFMC3ILC2L6QPKSTYQBYYZJ2NGK2M2YWPQZ3AXW7CRIF6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
