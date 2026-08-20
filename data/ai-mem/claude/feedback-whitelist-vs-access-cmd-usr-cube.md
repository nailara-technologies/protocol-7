---
name: feedback-whitelist-vs-access-cmd-usr-cube
description: "subroutine.white-list was renamed to subroutines.load-early 2026-07-25 specifically to kill this ambiguity -- don't reuse 'whitelist' loosely for access.cmd.usr.cube (start-file command-routing registration), a different mechanism"
metadata:
  type: feedback
---

Two distinct, easily-conflated mechanisms in a zenka's config:

- **`cfg/zenki/<zenka>/subroutines.load-early`** (renamed
  2026-07-25 from `subroutine.white-list` — same file, same purpose, new
  name, see below) — governs **when** a module gets compiled. Listed:
  compiled eagerly at zenka startup, so a syntax/compile error surfaces
  immediately at load time. Not listed (or deferred): compilation happens
  lazily, so a compile error only surfaces later, at actual usage time.
  User's framing: "fully transparent and has no negative effect either
  way, except that when compilation is deferred with the enabled
  whitelist, compilation errors surface with usage instead of at module
  load time."
- **`access.cmd.usr.cube`** (inside `cfg/zenki/<zenka>/start`)
  — governs **whether cube routes a command name to the zenka at all**.
  Missing an entry here means the command isn't recognized as routable,
  regardless of whether the underlying module is already compiled and
  present in memory.

**Why this matters, and what actually got fixed:** a commit message
described a fix to `access.cmd.usr.cube` (adding `jobsite.group-jobs`) as
fixing "jobsite's own command whitelist" — technically pointing at the
right *effect* but the wrong *word*, since "whitelist" already named the
other, unrelated mechanism in this codebase's own vocabulary. The commit
had to be amended (see [[feedback-filter-repo-amend]] for the `AMEND=1`
requirement this surfaced) to describe it accurately. That prompted the
real fix, same day: **`subroutine.white-list` was renamed to
`subroutines.load-early`** — plural, and named for what it actually
controls (compile timing) instead of a word that sounds like access
control. Landed via `ncode.cmd.replace` for the string references (5
files: `bin/Protocol-7`, `bin/dev/gen-sub-whitelist`,
`src/base.reload_whitelist`, `src/coding.validate.module`,
`src/base.zenka.load_sub_list`) + `rename` for the on-disk
`cfg/zenki/*/subroutine.white-list` → `subroutines.load-early`
files themselves, then `bin/Protocol-7 sourcecode update-signatures`.
`bin/dev/gen-sub-whitelist` (the generator script) kept its own old name
— only its output filename and the header it writes changed. That
generator's header now states this distinction directly in every
generated file:
```
# .:[ regenerate with : bin/dev/gen-sub-whitelist <zenka> ]:.
# :
# : governs compile timing only [compiles:always|ondemand],
# : not access : see access.cmd.usr.cube or
# : access.zenki for reachability
# :.
```

**How to apply:** the file is `subroutines.load-early` now, not
`subroutine.white-list` — update any reference on sight if you encounter
the old name still in play (older memory files, task docs, etc. may still
say the old name; it's the same file). Still never call an
`access.cmd.usr.*` entry a "whitelist" — describe it as "added to
`<zenka>`'s `access.cmd.usr.cube` list" or "cube command-routing
registration."

**Recurring pattern, not a one-off — user's direct note:** models keep
assuming a new/unreachable command needs a `subroutines.load-early` entry
when the actual gap is almost always `access.cmd.usr.cube` (or the
cross-zenka `access.zenki` grant — see
[[topic-write-access-security-infrastructure]]'s access-control-gap
entries from the same session). `subroutines.load-early` only affects
*when* a compile error surfaces, never whether a command is reachable —
so if a command is "not known" or "no permission," check `access.cmd.
usr.cube`/`access.zenki` first, and only reach for `subroutines.load-early`
if the actual symptom is a deferred compile error.

#,,,,,.,,,,,,,...,,,.,.,,,,,.,.,,,.,,,,.,,,,.,..,,...,...,...,,.,,.,.,..,,..,,
#SYNBWUIW53EMLUPUTY4QBVRHR4N3Q3LHZ33WH4RWCSG675DDGKK5KKH7BNAWTIPS6GDHBGKECQPNE
#\\\|PZQDJJABPFKFSWXYHM4AJ5OLERWLMT47BPY3TYMR72R3WZBOK25 \ / AMOS7 \ YOURUM ::
#\[7]H63NZ5TRUIG6HUJSPEAFIWDNK2XI4W4SP7G5POUI5E6JHBW6WSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
