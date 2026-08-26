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

- `src/forensics.cmd.sweep.run` — bare command `sweep.run`
- `src/forensics.cmd.investigate.finding` — bare command
  `investigate.finding`
- `src/build.cmd.recipe.run` — bare command `recipe.run`
- `src/ext-pkg.cmd.package.ensure` — bare command `package.ensure`
- `src/calc.cmd.val.eval_bigrat` — bare command `val.eval_bigrat`
- `src/calc.cmd.val.format_truncated` — bare command
  `val.format_truncated`

(`src/forensics.investigate.finding`, no `.cmd.` in the name, is a
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
  `src/calc.cmd.val` — the real, correctly-named command. Read
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
(`src/base.regex`):

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
- `cfg/zenki/cube/access.zenki:331`:
  `access.cmd.usr.openvas = forensics.investigate.finding` — the actual
  openvas phase-2 report-to-forensics handoff grant.
- `cfg/zenki/forensics/zenka.v7`'s `access.cmd.usr.cube` includes
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

**A second, distinct `cmd_re` violation found 2026-08-22 — leading
digit, not a dot**: `storage.cmd.9p-connect`/`storage.cmd.9p-scan`
(external names `9p-connect`/`9p-scan`) start with the digit `9`.
`$cmd_re = qr|[a-z][$anum\-_]{1,22}|` requires the FIRST character to be
`[a-z]` specifically — a leading digit fails exactly like a dot does,
just for a different structural reason. Confirmed live: `p7c storage.
9p-connect` (any args) gives "protocol mismatch" (cube's generic
"command syntax not valid" response, `base.handler.command.route_to_
target`'s `YYOPDKA` message), while `p7c storage.whoami` (valid shape,
just unregistered) gives a *different* error, "command does not exist"
— the same discriminator technique this file's `calc.commands` check
used to separate "not live-routed" from "live-routed", applied here to
separate "regex rejects the shape entirely" from "regex matched, target
just isn't registered." These two commands were unreachable through
cube routing since the day they were written (2026-03-27) — fixed by
renaming to `plan9-connect`/`plan9-scan` (see commit `599a24103` and
`data/tasks/completed/plan-9-server-event-loop-wiring.md`).

**The `[a-z]`-only restriction may itself be stricter than intended,
not a deliberate protocol rule** — `src/base.regex` has its own
commented-out TODO block sketching a more permissive design that was
apparently never finished: `my $cmd_str_re = qr|[$anum_lc][$anum_lc\-_\.]
{0,}|;` (`$anum_lc` = `[0-9a-z]`) allows a *leading digit*, just not
all-uppercase (reserved for reply codes like `TRUE`/`FALSE`/`SIZE`/
`STRM` — see `'base_32' => qr|[A-Z2-7]+|`) or all-digits (reserved for
session ids, `'sid_str' => qr|\d{3,17}|`). A command like `9p-connect`
can never collide with either reserved shape (it has letters, isn't
pure digits). Deliberately **not changed this session** — relaxing
`base.regex`'s live `cmd`/`cmd_str` patterns has much wider blast radius
than any one rename (it's the regex for cube's entire command-routing
surface) and deserves its own dedicated audit of every caller first,
not a rushed fix bundled into an unrelated task. If picked up later:
the fix is almost certainly swapping `cmd_re`'s `[a-z]` for `[$anum_lc]`
(or equivalent), not inventing a new pattern from scratch — the design
already exists, dormant, in the same file.

**Instance found and fixed, 2026-08-22**: `amos-term.cmd.mount-
9p-client`'s own help text suggested `p7c plan-9.client.list-dir <name>
/path` and `p7c plan-9.client.read-file <name> /path` as the follow-up
commands after connecting — neither was reachable via cube.
**Correction**: my first pass mis-attributed this to the dots-in-name
`cmd_re` rejection (the same class as `9p-connect`/`9p-scan` above) —
the user caught the sharper, more basic diagnosis: `ls src/*.cmd.*
list-dir` returned nothing. There was no `.cmd.`-prefixed wrapper file
at all under `amos-term` for either operation — `plan-9.client.list-dir`/
`.read-file` are plain internal subs, not cube commands, regardless of
what name you'd try to route to them. The dots-in-the-suggested-name
issue was real but secondary; a hyphenated rename alone (the
`9p-connect`→`plan9-connect` fix) would NOT have fixed this one, since
there was no wrapper to rename. Fixed by adding real
`amos-term.cmd.list-dir`/`amos-term.cmd.read-file` wrapper files
(mirroring `storage.cmd.plan9-read-file`'s shape, calling
`<[plan-9.client.list-dir]>`/`<[plan-9.client.read-file]>` — those
underlying subs already worked correctly, just had no cube-routable
front door), updated `mount-9p-client`'s help text to the real
`amos-term.list-dir`/`amos-term.read-file` command names, and added
both plus the already-existing-but-ungranted `mount-9p-client` to
`amos-term`'s `access.cmd.usr.cube` list. Live-verified: connect,
list-dir, read-file all round-trip correctly end to end.
**Lesson**: when a command is unreachable via cube, check for the
existence of a `.cmd.` wrapper file FIRST (`ls src/<zenka>.cmd.*<name>`)
before reaching for the naming/regex-shape diagnosis — a missing
wrapper is a more fundamental, more common cause than a
regex-incompatible name, and the naming diagnosis doesn't even apply
if there's no wrapper to rename in the first place.

#,,.,,..,,,..,.,.,..,,,..,,..,...,...,,,,,,.,,.,.,...,..,,.,,,,.,,,..,.,,,,.,,
#S5YD7N7KAC5672WIKCCBH4JWY3MQ3JNTN5UCVDX66YS7S6CLKTXQ3FG4MVXG34EL5XV2CYFDSYDK4
#\\\|JG2HULY2J3WA7ISWUEJHOQCHFVZAU2IFSCWX57GCBVEWA5GPCPO \ / AMOS7 \ YOURUM ::
#\[7]57XLACX7K55PYPIQ7ZRWGTLC23K2XF4M7MTTVNYV7OMHPNUIDQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
