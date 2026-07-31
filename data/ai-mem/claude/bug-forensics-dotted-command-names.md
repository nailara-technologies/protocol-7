---
name: bug-forensics-dotted-command-names
description: 6 modules codebase-wide (forensics x2, build x1, ext-pkg x1, calc x2) have dot-containing bare .cmd. command names, which base.regex's cmd_str pattern (used by all cross-zenka routing) cannot represent -- gets misparsed as a routing hop-chain instead of one atomic command. 4 of the 6 (forensics x2, build, ext-pkg) are live-routed today and need a hyphenated rename; calc's 2 aren't routing bugs at all -- they're private helpers of calc.cmd.val that should never have had the .cmd. segment, fix is to drop it, not hyphenate. build.cmd.recipe.run renamed 2026-07-31 (b7d9d163e); 5 remain.
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

**Fix in progress, done manually via `ncode` (not dispatched) — 1 of 6 so
far.** Two different fix shapes depending on tier:

For the 4 real routable commands (rename to a hyphenated single-segment
bare command — hyphens ARE in `cmd_re`'s character class, dots aren't —
matching this project's established precedent: the
`X-11.get_pointer_scr_rect` 23-char-limit rename and the
`ncode.cmd.review` → `pattern-review` collision rename, both in
`data/ai-mem/claude/topic-ncode-pattern-learning-loop.md`):

- `forensics.cmd.sweep.run` → `forensics.cmd.sweep-run`
- `forensics.cmd.investigate.finding` → `forensics.cmd.investigate-finding`
- [x] `build.cmd.recipe.run` → `build.cmd.recipe-run` — **DONE, `b7d9d163e`**
  (2026-07-31): `start`/`init_code`/`subroutines.load-early`/docs all
  updated, `ptd -c` clean, no stale references left. (Old name kept
  as-written above and elsewhere in this file's history/evidence
  sections deliberately — this is a bug report, rewriting the broken
  name in place would invert what it's documenting.)
- `ext-pkg.cmd.package.ensure` → `ext-pkg.cmd.package-ensure`

For calc's 2 (not routable commands at all — see the corrected tier
analysis above): **drop `.cmd.` entirely, don't hyphenate into a bare
command name**:

- `calc.cmd.val.eval_bigrat` → `calc.val.eval_bigrat`
- `calc.cmd.val.format_truncated` → `calc.val.format_truncated`

(check for an existing internal-helper namespace convention in `calc`
before picking the exact target — these two just need to stop being
in the `.cmd.`-triggered auto-registration table, the exact non-cmd
namespace they land in is a smaller detail)

For each: update the `name =` header comment, any `access.zenki`/`start`
grant lines, any direct `<[...]>` call sites elsewhere in the codebase,
and `subroutines.load-early` for the owning zenka (and any zenka with a
cross-zenka grant, e.g. `openvas` for forensics). Should not have been
caught by this project's own `gen-sub-whitelist`/access-grant tooling as
a length/shape violation — worth checking why not as part of the fix,
in case other zenki have a similar latent bug this scan's naive
`ack '\.'` filter didn't catch (e.g. a dot buried deeper than the first
one after `.cmd.`, or a non-`.cmd.` command path with the same shape
problem).

## related

`topic-ncode-pattern-learning-loop.md`'s "Bug A" — a different but
adjacent command-naming/routing gotcha (bare-name collision across
zenki sharing a process, not a regex-shape violation) found the same
general class of naming trap in this project before.

#,,.,,,,,,,,.,.,.,,,.,,,,,..,,,,,,.,.,,,.,,,.,.,.,...,..,,,,.,,..,,..,,..,.,,,
#BIZVSXOQ7OC3XECTTPKW4LH6PNY7ZPP3VZG3LQUKJHLRLZ5TGNI7RCO5NODRJEPL5IONOG35CRBIM
#\\\|5DYYTMGW4Y72JBVWHU7KBJ6C4WQHRJIPLKIX6DMSCEMX22L35QU \ / AMOS7 \ YOURUM ::
#\[7]4WXPZHXL2K72UXVVIBKV3RVUEFFXSFMWHWLFEP4DKTDIO2QNEUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
