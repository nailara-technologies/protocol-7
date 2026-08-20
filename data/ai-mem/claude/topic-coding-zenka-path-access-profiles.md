---
name: topic-coding-zenka-path-access-profiles
description: "design-only — composable read/write path-access profiles for coding zenka tools, zenka-scoped ownership + content-provenance taint, membrane concept"
metadata: 
  node_type: memory
  type: vision
  originSessionId: 6c5bf6bb-f449-443d-881c-738f9aa8aaec
  modified: 2026-07-21T10:38:03.207Z
---

design-only, triggered by discovering [[read-file-absolute-path-fix]] (context.file was force-repo-relative,
list_files already allowed absolute paths — the inconsistency that broke jobsite file reads). no implementation
yet, deliberately not rushed.

## the problem that started it
coding zenka tools (`read_file`/`context.file`, `list_files`, write handlers) each did their own path
sanitization independently, and drifted: `list_files` honored absolute paths, `context.file` didn't. fixing
the immediate bug (allow absolute paths in `context.file`) reopens a real question: once absolute paths work,
the coding zenka can read/write anywhere the process user can — no scoping at all.

## the model taking shape

**centralized enforcement.** one choke-point checker (e.g. `coding.security.path_allowed(path, mode, task_id)`)
called by every file tool, replacing the current per-tool ad-hoc logic. this alone would have prevented the
list_files/context.file drift.

**two independent axes, not one:**
1. **ownership / reachability (containment).** paths reduce to the *zenka that declared them*, not to
   "protocol-7-managed" as a monolith. `/etc/protocol-7/jobsite/*` and `/var/protocol-7/jobsite/*` are both
   jobsite-owned despite sitting in traditionally-opposite unix zones (etc=config, var=data) — the unix
   hierarchy is a proxy for a trust question protocol-7 can answer directly once it owns the whole host.
   default: access granted into a zenka's domain does NOT imply access to sibling zenki's domains, even though
   both live under `/…/protocol-7/`. non-breakout across zenka boundaries is the default.
2. **content provenance (taint).** independent of who manages the path, is the *content* operator/system-authored
   or ingested-from-outside (job postings, scraped pages, anything not authored by the operator)? this is the
   axis that actually correlates with prompt-injection risk — a path can be fully protocol-7-owned and still
   hold adversarial content (e.g. `/var/protocol-7/jobsite/jobs/review/*.yaml` — protocol-7-owned dir, external
   content). provenance should be a declared tag per subtree (the owning zenka declares it), not inferred from
   directory prefix.

**composition rule (tentative):** ownership sets the *reachable* ceiling for a task/profile (containment).
provenance tags drive *write* subtraction within whatever's reachable: any task session holding read access to
an untrusted/ingest-tagged path should have write dropped from trusted/operator-authored paths BY DEFAULT —
even ones inside the *same* zenka's domain (e.g. a task reading `jobs/` should not also retain write to
`profile.txt`, even though both are jobsite's). this subtraction is per-task-session, not a standing revocation
of the zenka's normal write capability in tasks that don't touch untrusted content.

**profile shape:** access profiles should be composable/subtractive (mixable "profile elements"), not just
additive allowlists. pre-declared combos (e.g. a `jobsite-review` profile = jobsite-ro + repo-ro, no writes) as
the primary interface — auditable, no surprise behavior — with tag-based auto-subtraction as a fail-closed
guardrail underneath, not the primary mechanism.

**interface surface (tentative):** config-seeded default policy (durable, e.g.
`cfg/zenki/coding/path-policy`) + a runtime command (`coding.path-allow ro|rw <path>` /
`path-deny` / `path-list`) for fast iteration, ephemeral-by-default unless explicitly saved back to config +
per-task-assignable extra paths (`task->{execution}->{allowed_paths}`), scoped to that task's lifetime only.

**gotcha flagged for whenever this is built:** path comparison must resolve-then-compare (`Cwd::realpath`
before matching against allowlist prefixes), not compare-then-resolve — symlinks/`..` can bypass naive
prefix checks otherwise.

**the wider frame** (user's framing, worth preserving): in a host/network protocol-7 fully manages — including
eventually mobile devices "wired in" — it can reason about its own trust boundaries directly rather than
inheriting unix-era conventions built for multi-vendor systems. the goal is a network that reacts with the
same fine-grained situational awareness a skilled admin would apply to their own hardware, continuously, since
LLM-driven agents don't tire and can queue work indefinitely rather than deferring for external circumstances.
"membrane" (semi-permeable, direction/context-dependent boundary) is better terminology than a fixed
allowlist wall for this.

## third axis: tool-capability scope
profiles aren't just path+taint — which *tools* are enabled is a third independent axis, composing the same
way. examples given: `jobs-ro-access` (narrow path, narrow tools, isolated per-task memory), `coding-debug-jobsite`
(broad read access to code+data, full coding-tool surface, still no write), `coding-bugfix-jobsite` (adds write,
further gated to only fire on test/review data). "full tools, read-only" is a real combination a flat list of
hand-enumerated presets would miss — the axes need to multiply, not be pre-baked into a fixed preset list.

## trust-promotion pipeline (forensics zenka) — bigger than a static tag
provenance shouldn't be just a static per-path tag; it can be a **pipeline**: raw external content (untrusted)
→ summarizing/filtering zenka → security-review ("forensics") zenka validates the filtered result matches an
expected shape/frame → only the validated output gets promoted into the working context at elevated trust.
the reviewing zenka is a distinct role and should itself run under an even narrower profile than what it's
reviewing (a forensics zenka examining raw postings should not hold coding-zenka write tools). this is the
piece that turns "tag this path untrusted" into an actual mechanism for *earning* trust rather than just
gating on it.

## visibility-parity gap (separate problem, not solved by profiles)
concrete case: the jobsite yaml contains the full original posting text, which is never displayed to the
user — the model sees a larger context than the user knows exists, even under a correctly-scoped, correctly-
tainted, read-only profile. path/taint/tool-scoping does not touch this at all; it's a different requirement
— something like the pipeline surfacing "N chars of raw unreviewed external content included in this task's
context" as a visible fact to the user, independent of whether access was otherwise deemed safe. keep this as
its own line item, don't fold it into the access-profile work.

## async, layered promotion instead of synchronous gating
real-time human gating doesn't scale to the pace/volume of decisions a fast, non-tiring LLM-driven system
generates (analogy given: fast LLM code generation throws up questionable moments too fast to interrupt
without breaking flow — you address them later, not synchronously). conclusion: promotion of content/changes
across a security/trust boundary should happen in a later, asynchronous review layer, timing-unconstrained,
with the bar for autonomous (unattended) promotion being that the change is unambiguously a clean, validated
improvement. this generalizes [[write-access-security-infrastructure]] (signature-gated approvals/PIN/review
UI) from "human approves every write" to "promotion requires passing through a reviewing layer, whenever that
happens" — same shape as the forensics-zenka pipeline above, applied system-wide rather than just to jobsite.

## correction: "async layered promotion" is not new machinery
the previous section overreached. review/tests/staging/rollout/revertability are not a novel mechanism this
design needs to invent — they already exist, uniformly, for exactly this reason: **provenance of an idea has
never been what makes a change safe to merge.** a bugfix is valid or not based on whether it passes the same
code-quality/context-match gate every change passes, regardless of whether the hint that led to it came from
internal reasoning, synthetic test data, or an adversarial external source (rival interest group, hostile
input, doesn't matter) — all software is already built on other people's code, so origin-based trust ladders
for the *artifact* are incoherent on their face. there is no separate promotion pipeline to design here; the
uniform gate already exists and already covers it.

what the taint/subtraction axis (see above) is actually for, correctly scoped: **containment during
composition, not a trust judgment on the eventual artifact.** reading untrusted content shouldn't grant live
write access mid-session not because the resulting fix would be untrustworthy — the uniform gate judges that
later, same as anything else — but because an adversarial prompt embedded in that content could act *before*
any review ever sees the output. two different jobs that were previously conflated into one "pipeline":
containment while composing (session-scoped, taint-driven) vs. rigor at promotion (uniform, origin-blind,
already-existing engineering practice, not something to build).

reframe for the whole thing: not "trust pipeline" but coherent-enough internal process that external coupling
(other people's code, external content, external hints) doesn't destabilize it — isolation was never the goal,
it's structurally impossible for an open system built on others' work by construction.

## a formal design doc now exists
`data/md/design/CODING-ZENKA-ACCESS-PROFILES.md` formalizes this into a phased implementation plan (Opus-drafted,
grounded in real code: `coding.tools.dispatch` never receives `task_id`, three incompatible per-handler path-
resolution styles already exist, `chmod_child` escalation must be gated before write-check fires). key discovery
during that pass: axis-1 (ownership/reachability) needs **no new declaration mechanism** — it's already structural
via `src/base.path-set-up.check-zenka-paths` (`<var_P7|etc_P7>/<zenka-name>/`, chowned to that zenka's own
unix user). axis-2 (taint/provenance declaration channel) remains the one genuinely open piece.

## the base.file abstraction was built for exactly this — and several coding-zenka call sites broke out of it
`base.file.open`/`base.file.read`/`base.file.put` (and `<[file.*]>` aliases) already exist as a single funnel for
all filesystem touches — user confirms this was deliberate: the intent all along was a dynamically mappable
zenka-internal filesystem (at minimum for repo files) that could transparently reroute to "whatever is most
desirable / available at any given time" — local disk today, but the same funnel is exactly where the layers
below plug in later, once implemented, with zero per-call-site rewrite needed elsewhere.

confirmed several coding-zenka file-tool handlers broke out of it with raw perl instead of routing through the
abstraction: `context.file` and `insert_line`/`replace_line`/`delete_lines` use raw `open my $fh, ...`;
`write_new_file`/`remove_file` use raw `Cwd::abs_path` directly rather than `base.file.path.validate` or similar.
implication for the access-profiles design doc (`data/md/design/CODING-ZENKA-ACCESS-PROFILES.md`): phase 1
shouldn't just gate these raw calls in place with a new parallel checker — it's the natural moment to migrate
them onto `<[file.*]>`, so the profile/access-check logic and the future dynamic-source-rerouting share one
funnel instead of the coding zenka growing a second, competing one.

## four enforcement/source layers for reachability, foundational to most-capable, in order of how much already exists
0. **inline `__DATA__` bootstrap subroutines (exists today, `bin/Protocol-7`'s trailing `__DATA__` block —
   `base.parser.pattern_split`, `base.protocol-7.source-key`, etc.).** bootstrap code embedded directly in the
   executable, available with zero I/O before any filesystem tree or network connection exists — the layer
   beneath even local disk. a roaming zenka (see STDIN/STDOUT item below) landing on a fresh host with nothing
   installed still has this to bootstrap from. intent (per user, this message): upgrade these to be layer-compatible
   with the same internal-FS abstraction, so "give me module X" can transparently mean "check inline-embedded, else
   local disk, else network source delivery, else multiplexed stream" through one accessor.
1. **filesystem/unix permissions (today's practical layer, this whole design doc).** most zenki share one user
   (`system.amos-zenka-user = protocol-7`); httpd/httpsd/p7-ssh already have their own (`<zenka>.system.user` in
   their `start` files) via a fully-working auto-creation chain (`root.drop_privs` → `base.root.check_system_user`
   → `useradd --system`, with a preferred-UID map in `cfg/system-user-map`, e.g. `protocol-7 = 777`).
   generalizing to "every zenka has its own user, small groups sharing one where sensible" is populating config,
   not building infrastructure.
2. **network-mediated signed source delivery (partially exists now).** the `source` zenka
   (`src/source.cmd.get-code-signed`) already delivers individual named modules over the network, C25519-signed
   and verified per request — no filesystem read access to the file required at all. as this generalizes past
   `src/*` to arbitrary files, "read scope" for a profile can mean "which names will source hand to this
   requester," checked per delivery, rather than "which directories can this uid `stat()`". a zenka could be
   chrooted away from the shared source tree entirely and still function. tighter fit for translucent-layering
   than a directory grant: every crossing individually checked, not just gated by a boundary.
3. **STDIN/STDOUT IO multiplexing (planned, long-standing intent — zero code exists yet, but not a passing idea).**
   user has been thinking about this feature for years; not yet written down as its own design doc. direction:
   stdio upgraded to a full multiplexing protocol so a zenka could ssh into a remote box with **no protocol-7
   installation present at all** and still be a complete zenka — config, subroutines, network access all carried
   over the multiplexed stream from the home instance. once it exists, this would be the tightest fit of the three:
   no local filesystem, no local install, nothing outside one auditable stream. flagged here as a pointer toward a
   future dedicated design doc — worth writing that up properly on its own terms rather than as a footnote here.

## status
pure discussion until the design doc above; that doc is now the actionable artifact (phases 1–5). the
containment/taint axis, the forensics-zenka *filtering* role (distinct from "trust promotion," see correction
above — filtering still has real value: reducing what raw content a session is exposed to at all), and the
taint-declaration channel (open question in the design doc) are the remaining open threads. see also
[[write-access-security-infrastructure]] (signature-gated approvals/PIN/review UI — a different, complementary
mechanism: that one gates *write actions* on approval, this one scopes *what's even reachable* per task/profile
before approval would apply).

#,,,,,...,..,,.,,,.,,,..,,,..,.,.,..,,,..,,..,..,,...,...,,.,,,..,..,,,..,,..,
#CRTFHFUDIYXD2XRK5SS4KV53WZKT2MOAVODHLQHF36CJON3XAX67LLMBRTPJMRTTODZ347JCKX4HK
#\\\|CFGHNYQ5BUKEFCSRCLB7PWPFMPQP5MVPO77QL5DKIQKPIHHUB2H \ / AMOS7 \ YOURUM ::
#\[7]NJUMTKVLQKZNLVK3OFJSMY5HSAE2MVS2MAUPKPRC3IP2UYG57UCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
