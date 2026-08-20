## [:< ##

# coding zenka access profiles
# composable path (ro/rw) + tool-capability scoping per coding task

---

## why this exists

fixing two real bugs in the coding zenka's http-inference and file-tool pipeline
(stall-timeout race + `context.file` forcing absolute paths into repo-relative
resolution — see git log on `modules/context.file`) reopened a real question:
once `read_file` honors absolute paths, matching what `list_files` already did,
the coding zenka can read anywhere the process user can, with zero scoping. the
write-side tools have the same gap. this document is the plan for closing it —
design only, no code written yet.

the posture this plan is built on already exists as its own document:
`data/md/philosophy/TRANSLUCENT-LAYERING-SECURITY-MINDSET.md`. read that first —
layers are translucent (visible, judged), not walls (blocking). the goal below
is to guarantee a reflective/judging layer is always in the loop before anything
irreversible happens through a mechanical step, not to distrust output.

---

## the load-bearing fact

`coding.tools.dispatch` is the one choke point every file tool passes through,
but it currently receives only `{function:{name,arguments}, id}` — **not**
`task_id`. `coding.async.tool_executor` has `task_id` in scope and even bakes it
into synthetic call-ids, but discards it building the dispatch payload.
threading `task_id` from `tool_executor` → `dispatch` → checker is the spine of
everything below. nothing else works until that thread exists.

a second fact reframes the goal: **the handlers don't just lack a gate, they
resolve paths three incompatible ways already** — which is the drift that
caused the original bug:

- `context.file` / `list_files`: honor absolute, else prefix `<system.root_path>`.
- `insert_line` / `replace_line` / `delete_lines`: `"$root/$path"`
  unconditionally + a string `m{\.\.}` reject — **cannot even express** an
  absolute path.
- `edit_file` / `write_new_file`: `Cwd::abs_path` + hard reject of anything
  escaping repo root.

so the checker must **own path resolution**, not just bless an already-divergent
`$abs_path` computed upstream. one resolver, one decision — handlers stop
computing paths themselves.

---

## ownership is already structural — no new mechanism needed for it

`modules/base.path-set-up.zenka-directories` and
`modules/base.path-set-up.check-zenka-paths` establish the real convention
already in force:

```
<var_P7>/<system.zenka.name>/     ## e.g. /var/protocol-7/jobsite
<etc_P7>/<system.zenka.name>/     ## e.g. /etc/protocol-7/jobsite
```

these two directories are `chown`'d to **that zenka's own unix user**
(`<system.zenka-user.current>`), distinct from the shared protocol-7 user used
for the top-level roots. this is not theoretical — it's live for at least two
zenki today:

```
cfg/zenki/httpd/start:   httpd.system.user   = httpd
cfg/zenki/httpsd/start:  httpsd.system.user  = httpsd
                                    ## httpsd runs as httpsd:httpd for /var/httpd access
```

each `start` file declares `<zenka>.system.user`, `[root.drop_privs:<...>]`
actually calls `setuid`/`setgid` to it (`modules/base.root.drop_privs`) and
records the result in `<system.zenka-user.current>`, which is exactly what
`check-zenka-paths` later chowns the zenka's own data/config dirs to. the first
path segment after `var_P7`/`etc_P7` **is** the ownership tag — already,
mechanically, with real, already-running OS permissions behind it.

**this generalizes further than it looks.** most zenki today share one user —
`system.amos-zenka-user = protocol-7` (`cfg/system-user-map`) is the
default `root.drop_privs` falls back to when a zenka declares no
`<zenka>.system.user` of its own — and httpd/httpsd/p7-ssh are simply the
current opt-outs. the auto-creation machinery
(`modules/base.root.check_system_user`) already does `useradd --system` on
first use of any username `root.drop_privs` is pointed at, and already
consults a preferred-UID map (`base.root.pref-uid.<name>`,
`cfg/system-user-map` — `protocol-7 = 777`, `p7-ssh = 722`) before
falling back to an OS-assigned UID. getting from "a few zenki have their own
user" to "every zenka has its own user, except small groups sharing one where
that makes more sense" is populating `<zenka>.system.user` +
`base.root.pref-uid.<name>` per zenka — not new infrastructure, the same chain
already running for httpd. **future hardening note**, not part of the phases
above: once application-level access profiles exist, per-zenka unix users
become an independent OS-level backstop underneath them — a bug in
`access_check` would still hit a real permission wall, not just an
application-logic gap. separate decision from this plan (do we actually want
many system users vs. today's few), not a blocker for phases 1–5.

**further still — shared filesystem read access to source is a practical
stand-in, not an architectural requirement.** the `source` zenka
(`modules/source.cmd.get-code-signed`) already delivers individual named
modules over the network, C25519-signed and verified per request, with no
dependency on the requester having filesystem read access to the file at all.
as this generalizes past `modules/*` to arbitrary files, `ro` scope for a
profile stops needing to mean "which directories can this unix user `stat()`"
— it can mean "which file/module names will the source zenka hand to this
requester," checked and signed per delivery. a zenka could be chrooted away
from the shared source tree entirely (or have no meaningful local filesystem
view of it at all) and still function, receiving exactly what it requests.
that's a tighter fit for the translucent-layering posture than a directory-level
grant: every crossing individually checked, not just gated by a boundary you
are or aren't inside. today's filesystem-permission approach (this whole
document, and the unix-user note above) is the practical, currently-necessary
layer while shared source access remains the norm — worth remembering it's not
fixed, so future phases aren't designed as if directory permissions were the
only possible enforcement point.

**planned, just not written down yet — long-standing intent, not a passing
idea.** a further direction: STDIN/STDOUT upgraded with a full IO multiplexing
protocol, so a zenka could log into a remote box over ssh with no protocol-7
installation present at all, and still be a complete zenka — config,
subroutines, and network access all carried over the multiplexed stdio stream
from the home instance, rather than anything local to the remote host. unlike
the two notes above there's no code behind this yet, but it's not speculative
in the sense of untested — it's a feature the project has been heading toward
for years, simply not yet formalized into its own design document. worth
flagging why it matters here: once it exists, it would be the tightest fit of
all three for the translucent-layering posture — no local filesystem, no local
install, nothing outside the one auditable stream a request travels through.
noted here as a marker pointing at a future design doc of its own, not
something this particular plan depends on or should design around
prematurely.

consequence for axis 1 (below): reachability/ownership needs **no cross-zenka
declaration channel**. resolve `<var_P7|etc_P7>/<name>/...`, check `<name>`
against the zenka roster, done. `/etc/protocol-7/jobsite/*` and
`/var/protocol-7/jobsite/*` are both jobsite-owned despite sitting in
traditionally-opposite unix zones — this is exactly why: the unix hierarchy
convention (etc=config, var=data) is a proxy for a trust question protocol-7
answers directly via the zenka-name segment instead.

content-**provenance** (axis 2, below) is a different, smaller problem that
genuinely has no existing mechanism yet — a zenka owning a subtree still needs
a way to mark parts of it as externally-ingested vs. operator-authored. that
piece is open (see "open questions").

---

## three composable axes — not a flat preset list

a profile is three orthogonal sections that multiply:

```
profile "<name>":
  paths:                    # axis 1: reachability / ownership
    ro:  [ list of allowed-read roots ]
    rw:  [ list of allowed-write roots ]
  tools:                    # axis 3: capability scope
    mode: allow-list | deny-list
    set:  [ tool names ]
  taint:                    # axis 2: content provenance
    untrusted: [ subtree roots whose content is externally-ingested ]
```

**axis 1 (ownership/reachability)** sets the ceiling — resolved structurally per
above, non-breakout across zenka domains is the default (granting jobsite reach
does not grant sibling-zenka reach just because both live under a `protocol-7`
prefix).

**axis 2 (taint)** does not gate reachability — it drives **write subtraction
within what's reachable**. per the correction already reached in
`data/ai-mem/claude/topic-coding-zenka-path-access-profiles.md`: this is
**containment during composition, not a trust judgment on the eventual
artifact**. a session holding read access to untrusted content gets write
dropped from trusted paths by default — even within the same zenka's domain —
not because the resulting fix would be untrustworthy (the same origin-blind
code-quality/review gate judges that later, same as any other change), but
because an adversarial prompt embedded in that content could act *before* any
review ever sees the output. there is no separate "trust pipeline" for
externally-inspired changes; normal engineering rigor already covers the
artifact.

**axis 3 (tools)** — which tools are even offered, independent of path scope.
enforced in two places: definition-time (disabled tools never offered to the
model — `coding.prompt.assemble` already receives the full `$task` before
calling `coding.tools.definitions`, so this is a clean wire) and execution-time
in `dispatch` as backstop, in case the model hallucinates a tool name anyway.

---

## profile carrier: the task record

`subtask_spawn` confirms tasks already carry an `execution => {...}` subhash.
bind here:

- `execution.profile` — profile name
- `execution.extra_paths` — per-task-assignable extra allowed paths (ro/rw),
  scoped to that task's lifetime only
- `execution.grants` — the resolved effective set, computed once at bind time
  by a compose step (not recomputed per tool call — cheaper, and auditable:
  the taint→write subtraction becomes a loggable, bind-time fact)

**no-task fallback is fail-closed**: any path where `task_id` is absent (manual
`coding.call-tool`, etc.) resolves to the config-seeded *default* profile —
never wide-open. consistent with the mindset doc: containment is the
guardrail present even when no profile was explicitly chosen.

---

## concrete named profiles

not a copy-paste of whatever's easiest — derived to cover the real coding-zenka
use surface, and critically, the first one **names the current status quo** so
migration has something correct to default to:

1. **`coding-self-dev`** — *today's actual behavior, must exist first*: rw =
   repo root, ro = anywhere the process user can read, full tool surface.
2. **`coding-debug`** — ro = repo + relevant data roots, **no rw** (writes
   stage instead of applying), full read/analysis tool surface, no write tools
   offered. the "full tools, read-only" combination a flat preset list would
   miss if profiles weren't actually composable.
3. **`coding-bugfix`** — rw = repo (or a narrowed subtree), ro broad, full
   tools — the normal fix-and-apply mode.
4. **`jobsite-review`** — scoped read into another zenka's domain: ro =
   `/etc/protocol-7/jobsite/*` + `/var/protocol-7/jobsite/*` (both
   jobsite-owned per the structural rule above), no rw, narrow tool set
   (read/search/note), isolated per-task memory. `jobs/*` declared untrusted
   → taint-subtraction guarantees no live write, live or dormant.
5. **`forensics-min`** — the reviewer role, deliberately the narrowest: ro =
   the raw untrusted subtree only, no write tools at all, minimal read/record
   surface. a reviewing role runs under a narrower profile than what it
   reviews, not the same or a broader one.

---

## interface surface

**durable config**: `cfg/zenki/coding/path-policy` (new file, loaded
from `cfg/zenki/coding/start` alongside the existing `coding.cfg.*`
block). declares the default profile, named profiles, and this zenka's own
taint declarations for subtrees it owns. resolves through the existing
`<coding.cfg.*>` template-accessor mechanism.

**runtime commands** (new `coding.cmd.path-*` modules, registered the same way
`coding.cmd.call-tool` is):

```bash
coding.path-allow ro|rw <path>
coding.path-deny <path>
coding.path-list
coding.profile-show [task_id]
```

ephemeral by default — mutate the in-memory policy for fast iteration; persist
only when explicitly saved back to `path-policy`.

**per-task override**: `coding.submit` gains an optional field carrying extra
ro/rw paths, landing in `execution.extra_paths`, lifetime-scoped to that task.

---

## migration path — smallest-first, no big-bang

**phase 1 — thread + centralize, behavior-preserving.**
thread `task_id` through `tool_executor` → `dispatch`. introduce
`coding.security.path_resolve` (resolve-then-compare via `Cwd::realpath` on the
existing parent for not-yet-created write targets, mirroring `write_new_file`'s
current `real_dir` approach — never compare-then-resolve, symlinks/`..` bypass
naive prefix checks otherwise) and `coding.security.access_check`. wire all
file-tool handlers to resolve through `path_resolve` and consult
`access_check`. seed **exactly one** profile, `coding-self-dev`, whose grants
reproduce today's behavior exactly — including its asymmetry: reads currently
honor absolute paths, writes are currently hard-jailed to repo root. phase 1
must preserve that asymmetry, not flatten it, or centralizing silently
strips the existing write-jail. after phase 1: zero behavior change, one
resolver, one gate, drift structurally impossible.

**phase 1 addendum — converge onto `base.file.*` instead of growing a second
funnel.** `base.file.open`/`base.file.read`/`base.file.put` (`<[file.*]>`
aliases) already exist as the project's single intended filesystem funnel,
deliberately built so it can later be upgraded to transparently reroute across
sources (local disk, inline-embedded bootstrap subs, network-signed source
delivery, eventually multiplexed stdio — see
`data/ai-mem/claude/topic-coding-zenka-path-access-profiles.md` for the full
four-layer picture). several of the handlers this phase touches broke out of
that funnel with raw perl: `context.file` and
`insert_line`/`replace_line`/`delete_lines` use raw `open my $fh, ...`;
`write_new_file`/`remove_file` use raw `Cwd::abs_path` instead of an
abstraction call. phase 1 should migrate these onto `<[file.*]>` as part of
centralizing — not just wrap the raw calls with a new coding-zenka-local
checker. that keeps `access_check` and the future dynamic-source-rerouting
work sharing one funnel instead of the coding zenka growing a second,
competing one, and it's the natural place for this repair since the handlers
are already being touched to thread `task_id` through.

**phase 2 — enforcement ahead of privilege escalation.**
write handlers currently escalate to the admin group via `chmod_child` to force
writes to otherwise-unwritable files. `access_check`'s rw decision must run
**before** that escalation fires, or rw-scoping is theater. denied-rw routes to
the existing staged-file fallback (`/var/protocol-7/coding/staged/`) rather
than a hard error — reuses containment machinery that already exists.

**phase 3 — profiles differentiate.**
add `profile_load` / `profile_compose`, the `path-policy` config file,
`execution.profile` binding at submit. add the named profiles above.
taint-subtraction goes live.

**phase 4 — axis-3 tool scoping.**
definition-time filtering via `coding.prompt.assemble` → `coding.tools.definitions`.
execution-time backstop already present in dispatch from phase 1.

**phase 5 — runtime commands + per-task overrides.**

---

## open questions — need a human decision before implementation

1. **provenance/taint declaration channel.** ownership resolves structurally
   (see above, solved). taint does not: there's no existing mechanism for a
   zenka to mark "this subtree of mine is externally-ingested" in a form
   another zenka's checker can read. options: a small addition to the owning
   zenka's own `start`/config (mirroring how `jobsite.cfg.profile_file` already
   declares a path, but as a tag not just a value), a shared registry file, or
   an on-demand cross-zenka query at bind time. smallest option is probably a
   config convention, not a new subsystem — but pick one before phase 3.
2. **default profile when `task_id` is absent.** fail-closed to
   `coding-self-dev` (today's broad status quo, preserves manual `call-tool`
   ergonomics) vs. something narrower (safer, will surprise existing
   workflows). human call.
3. **relationship to `subroutine.white-list`.** that's a flat allowlist of
   `%code` sub names for devmod/eval safety — a related precedent, different
   layer (eval-safety, not per-task LLM tool exposure). mirror its spirit for
   axis 3, don't merge into it.
4. **staging semantics under taint-subtraction.** when a tainted session's
   writes stage instead of applying, confirm the existing staged-file
   promotion flow (and its existing reviewer) is the right place for this to
   land, and that the model is told "staged, not applied" — handlers already
   emit that message for the existing staging path, reuse it rather than
   inventing a second one.

---

## explicitly out of scope

- **visibility-parity** — raw external content embedded in a file but never
  shown to the user (e.g. full job-posting text inside a yaml the user never
  reads). path/taint/tool scoping doesn't touch this; it's a separate concern,
  tracked in the memory doc, not solved here.
- **the forensics/incident-response machinery** in
  `data/md/concepts/CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md`. this
  layer scopes what's reachable *before* any incident-response would engage —
  complementary, not a replacement, must not duplicate it.
- **a separate trust-promotion pipeline for externally-inspired changes** —
  explicitly rejected; the uniform origin-blind review/test gate already
  covers artifact quality regardless of what inspired the change.

---

## connections

- `data/ai-mem/claude/topic-coding-zenka-path-access-profiles.md` — the full
  design conversation this document formalizes, including the trust-promotion
  correction
- `data/md/philosophy/TRANSLUCENT-LAYERING-SECURITY-MINDSET.md` — the posture
  this design embodies
- `data/md/concepts/CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md` — adjacent,
  complementary incident-response layer
- `modules/coding.tools.dispatch`, `modules/coding.async.tool_executor`,
  `modules/context.file`, `modules/coding.tools.definitions`,
  `modules/coding.prompt.assemble` — implementation entry points
- `modules/base.path-set-up.zenka-directories`,
  `modules/base.path-set-up.check-zenka-paths` — the existing per-zenka
  ownership convention this design relies on rather than reinventing

#,,.,,,.,,,,,,.,.,.,.,,,.,.,.,...,,,,,...,,..,..,,...,...,..,,,,,,..,,...,.,,,
#4VNRHOMCMXWR2LZQEQOSQOP775Z3BBVRYXQZLORKXSEVH3VCZORESWOYSAL7D6I5NAF7B7WJI2QOK
#\\\|IVX7SURG5IHXTNXSM4MBIIXO6B6RFOBDEJPIRJMZRSSBH3AG7XQ \ / AMOS7 \ YOURUM ::
#\[7]HE5CMPRSKMVJDPLBELATYA2EOAKVADZW335JDTMR5P5FR3RECICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
