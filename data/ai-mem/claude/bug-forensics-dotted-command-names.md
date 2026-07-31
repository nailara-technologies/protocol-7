---
name: bug-forensics-dotted-command-names
description: RESOLVED 2026-07-31 -- 6 modules codebase-wide (forensics x2, build x1, ext-pkg x1, calc x2) had dot-containing bare .cmd. command names, which base.regex's cmd_str pattern (used by all cross-zenka routing) cannot represent -- gets misparsed as a routing hop-chain instead of one atomic command. All 6 fixed across 4 commits (b7d9d163e build, 5e6987573 calc, be1e24add ext-pkg, 017d8c24b forensics). The forensics fix also caught the actual live breakage point: openvas.cmd.report-to-forensics was constructing the broken dotted command string for real cross-zenka dispatch.
metadata:
  node_type: memory
  type: project
  originSessionId: 8a65c64f-bcd4-43e6-9d47-e37ee5dc8750
  modified: 2026-07-31
---

User-spotted 2026-07-31 from a commit message mentioning
`forensics.cmd.sweep.run`, then user ran a full codebase scan
(`ls *.cmd.* | sed 's|^.*\.cmd\.|- |' | ack '\.'`) and found the complete
set — **6 files across 4 zenki**, not just the original 2:

- `modules/forensics.cmd.sweep.run` — bare command `sweep.run`
- `modules/forensics.cmd.investigate.finding` — bare command
  `investigate.finding`
- `modules/build.cmd.recipe.run` — bare command `recipe.run`
- `modules/ext-pkg.cmd.package.ensure` — bare command `package.ensure`
- `modules/calc.cmd.val.eval_bigrat` — bare command `val.eval_bigrat`
- `modules/calc.cmd.val.format_truncated` — bare command
  `val.format_truncated`

(`modules/forensics.investigate.finding`, no `.cmd.` in the name, is a
separate sibling — the internal implementation the `.cmd.` wrapper
calls directly via `%code`, not itself subject to this bug.)

**Risk tier confirmed by checking each zenka's actual access grants, not
assumed uniform**:

- **live-routed today (real bug, 4 files, 3 zenki)**: both forensics
  commands (see below), `build.cmd.recipe.run` (bare `recipe.run` is in
  `build/start`'s active `access.cmd.usr.cube`), `ext-pkg.cmd.package.ensure`
  (bare `package.ensure` is in `ext-pkg/start`'s active
  `access.cmd.usr.cube` — the *other* per-consumer grant below it is
  commented out, but this one isn't).
- **not a routing bug at all, confirmed by user 2026-07-31 — a
  misapplied `.cmd.` segment (2 files, 1 zenka)**: `calc/start`'s
  `access.cmd.usr.cube` grants bare `val`, which routes to
  `modules/calc.cmd.val` — the real, correctly-named command. Read
  `calc.cmd.val` directly: it calls both
  `<[calc.cmd.val.eval_bigrat]>->($formula)` and
  `<[calc.cmd.val.format_truncated]>->($bigrat, $digits)` as plain
  internal Perl subroutine calls, never through cube routing. These two
  are **private helpers of `calc.cmd.val`, not commands at all** — the
  `.cmd.` segment on them is simply wrong (the loader auto-registers
  anything with `.cmd.`/`.console.` in its name into the global
  bare-command table, per the collision mechanism documented in
  `topic-ncode-pattern-learning-loop.md`'s "Bug A" — these two get
  registered as routable commands nobody ever intended to expose).
  Confirmed directly via `calc.commands`, the zenka's own live operator
  command listing: only `val` appears, `val.eval_bigrat`/
  `val.format_truncated` are absent entirely — they were never live,
  registered commands from the operator's side at all.
  **Correct fix is different from the other 4**: don't hyphenate them
  into a new bare command name (that would just invent a routable
  command that was never supposed to exist) — **drop the `.cmd.`
  segment entirely**: `calc.cmd.val.eval_bigrat` → `calc.val.eval_bigrat`,
  `calc.cmd.val.format_truncated` → `calc.val.format_truncated` (or
  wherever this project's convention puts internal non-routable helpers
  — check for an existing `calc.val.*`/similar sibling pattern before
  picking the exact target namespace). This removes them from the
  auto-registration table entirely rather than giving them a
  syntactically-valid-but-pointless bare command name.

**Root cause, confirmed via the actual protocol regex**
(`modules/base.regex`):

```perl
my $cmd_re = qr|[a-z][$anum\-_]{1,22}|;   ## command [name] string: LEN=1-23
...
'cmd_str' => $cmd_re,
```

`$anum` is `0-9A-Za-z` — the character class has **no dot at all**, and
caps total length at 23 chars (same limit that forced the
`X-11.get_pointer_scr_rect` rename precedent — `get_pointer_monitor_rect`
was 24 chars). `$re->{cmd_str}` is exactly what
`base.handler.command.route_to_target`'s main routing regex uses for the
final command segment of ANY cross-zenka dispatch.

**Why this isn't just a style violation — it actually misroutes**: the
same routing regex supports chained zenka/session hops
(`(($re->{sid_str}|$re->{usr_str}|$re->{usr_subn_str})\.)*$re->{cmd_str}`,
the mechanism that makes legitimate nested child-zenka routing like
`weather.child.desc` work). Since `cmd_str` can't match a dotted string
at all, the ONLY way the overall regex can match `investigate.finding` as
a trailing segment is by parsing it as **hop `investigate` + final
command `finding`** — `investigate` happens to be a syntactically valid
`usr_str`-shaped segment (plain lowercase letters), so the parser accepts
it as an intermediate routing hop that doesn't correspond to any real
zenka/session, rather than as one atomic command name.

**Both affected commands are live-routed, not just internal calls** —
confirmed via grep:
- `configuration/zenki/cube/access.zenki:331`:
  `access.cmd.usr.openvas = forensics.investigate.finding` — the actual
  openvas phase-2 report-to-forensics handoff grant.
- `configuration/zenki/forensics/start`'s `access.cmd.usr.cube` includes
  both `sweep.run` and `investigate.finding` — operator-facing
  (`p7c forensics.sweep.run` / `p7c forensics.investigate.finding`).

(Separately, `<[forensics.investigate.finding]>->(...)`-style direct Perl
sub-calls from `openvas.cmd.report-to-forensics`/`openvas.init_code`/
`forensics.init_code` are fine — those go through the `%code` hash
directly, no protocol regex involved. It's specifically the
cube/access.zenki-routed paths that are broken.)

**ALL 6 FIXED, 2026-07-31 — done manually via `ncode` across 4 commits.**
Two different fix shapes were used depending on tier:

The 4 real routable commands, renamed to a hyphenated single-segment
bare command (hyphens ARE in `cmd_re`'s character class, dots aren't —
matching this project's established precedent: the
`X-11.get_pointer_scr_rect` 23-char-limit rename and the
`ncode.cmd.review` → `pattern-review` collision rename, both in
`data/ai-mem/claude/topic-ncode-pattern-learning-loop.md`):

- [x] `build.cmd.recipe.run` → `build.cmd.recipe-run` — **`b7d9d163e`**:
  `start`/`init_code`/`subroutines.load-early`/docs all updated.
- [x] `ext-pkg.cmd.package.ensure` → `ext-pkg.cmd.package-ensure` —
  **`be1e24add`**: also caught two stale docs (`README.md` usage
  examples, a commented-out per-consumer grant placeholder) still
  showing the old name after the initial rename.
- [x] `forensics.cmd.sweep.run` → `forensics.cmd.sweep-run` and
  `forensics.cmd.investigate.finding` → `forensics.cmd.investigate-finding`
  — **`017d8c24b`**: the important one. First pass renamed only the
  module files; a follow-up check caught 3 more real gaps —
  `forensics/start`'s `access.cmd.usr.cube` whitelist AND its
  `access.cmd.usr.openvas` grant, `cube/access.zenki`'s openvas
  phase-2 handoff grant, and — the actual live breakage point —
  `openvas.cmd.report-to-forensics`, which constructs
  `cube.forensics.investigate.finding` as a real routed command string
  via `protocol-7.command.send.local`. Every enriched-finding handoff
  from openvas to forensics would have hit the hop-chain misparse this
  whole bug report describes, until that call site was fixed too.
  `forensics.investigate.finding` (no `.cmd.`, the internal
  implementation the wrapper calls directly) correctly left untouched —
  never part of the bug.

calc's 2 (not routable commands at all — confirmed via `calc.commands`,
the zenka's own live listing, which never showed them): `.cmd.` dropped
entirely rather than hyphenated into a bare command name that was never
meant to exist —

- [x] `calc.cmd.val.eval_bigrat` → `calc.val.eval_bigrat`,
  `calc.cmd.val.format_truncated` → `calc.val.format_truncated` —
  **`5e6987573`**.

**Lesson for next time a rename like this lands**: don't stop at the
module file + its own `start`/`subroutines.load-early` — grep the whole
tree for the bare old name afterward. Every one of these renames except
the first turned up at least one more live reference (docs, a second
zenka's grant, or — in forensics' case — the actual call site
constructing the broken routed command string). Should not have been
caught by this project's own `gen-sub-whitelist`/access-grant tooling as
a length/shape violation in the first place — worth checking why not,
in case other zenki have a similar latent bug this scan's naive
`ack '\.'` filter didn't catch (e.g. a dot buried deeper than the first
one after `.cmd.`, or a non-`.cmd.` command path with the same shape
problem).

## related

`topic-ncode-pattern-learning-loop.md`'s "Bug A" — a different but
adjacent command-naming/routing gotcha (bare-name collision across
zenki sharing a process, not a regex-shape violation) found the same
general class of naming trap in this project before.

#,,,.,,,,,.,,,.,.,..,,,..,.,.,...,,..,,,.,..,,.,.,...,..,,...,,,,,..,,...,..,,
#2QZFAYW3UHGUUDPKXUQTMALNVDYMRL7GURZFQETS3XMTBBJI3Z7BD7L7WQBECRIJYJUDZVRC6AOKA
#\\\|UPG6IBXNRS7HM7LFVMDAPGFRWJLTMMJCM2O3BKZ3A7RXRIRBORJ \ / AMOS7 \ YOURUM ::
#\[7]QSA2CJOTUITMPUHMS3HTZMVQNGKHA4GI6QHGJ3656CRLH3AFG2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
