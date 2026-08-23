---
name: vision-httpd-adaptive-defense-and-honeypot-framework
description: long-horizon idea (2026-08-23, pure ideation, no design decisions yet) for a context-aware adaptive defense system on httpd/httpsd -- dynamic per-connection trust scoring, escalating responses, native forensic collection, and optional honeypot/deception response modes
metadata:
  type: vision
---

**2026-08-23**, growing out of [[topic-next-steps]]'s httpd/httpsd
long-lived-connection investigation (confirmed as an automated
`.env`-credential-scanning sweep — see that file for the concrete
evidence). Paced explicitly per [[feedback-security-design-pacing-avoid-overreaction]]:
user wants this designed step-by-step, deliberately not rushed, precisely
because the classic scanner vectors don't apply to Protocol-7's actual
architecture (no PHP/Docker/`.env` convention) — there's no forcing
urgency, so the design can be done right rather than fast.

## the shape of the idea, as the user described it

1. **Context-aware dynamic timeouts, scored per-connection.** A
   connection that can authorize itself — "perhaps beyond an ip address
   even" — doesn't need time restrictions at all. Anomalous activity
   should self-score into shrinking timeouts; matching a known scan
   pattern escalates into rate-limiting; a positively-recognized scanner
   (by multiple parameters, not just one signal) escalates further into
   more aggressive responses. Explicitly a *graduated* response model, not
   a binary block/allow.
2. **Native forensic data collection and analysis** — automatically
   collecting and analyzing exploit/scan attempts, generating forensic
   reports and overviews, built into the system rather than bolted on
   via external log-scraping.
3. **Customizable response types**, several distinct strategies floated:
   - tarpitting — slow a scanner into "a ridiculously slow grind"
   - simulate no interesting content at all (bore it into leaving)
   - mocking/ridiculing responses (a personality-driven deception layer)
   - the inverse: simulate the *presence* of vulnerabilities or rootkits
     — a real honeypot, not just a decoy

## why this connects directly to work already landed this session

The "beyond an ip address" trust dimension isn't hypothetical — it's
almost exactly what [[project-keys-zenka-integration-direction]]'s
TOFU-pin/authorized-client work (commits `ddd5418c0`,
`f14c524d4`, plus the `keys.console.{incoming,list-authorized,authorize,
drop-authorized}` batch) already built: `.n/remote-keys/known` (outbound
TOFU pins) and `.n/remote-keys/authorized` (inbound client authorization)
are exactly the kind of identity substrate a "connection that can
authorize itself" would key off of, for httpd/httpsd traffic specifically
rather than the zenka-to-zenka `auth-keypair` protocol these were built
for. Worth treating as the same trust-identity question, not a separate
one, when this gets designed for real.

## background context: not a first attempt at this class of system

User's own framing: "my first ever project at an internet provider was
about writing a honeypot system like that." This is domain expertise
already held, not a novel exploration — see
[[user-professional-background-honeypot-systems]].

## open design tensions flagged during the same conversation, unresolved

Raised as things worth deciding early since they shape everything
downstream, not yet decided:

- **Scoring substrate**: where does per-connection suspicion state live,
  and keyed on what identity (raw IP? TCP session? a longer-lived
  fingerprint surviving reconnects, tied into the C25519 identity system
  above)? Everything else — timeouts, escalation, forensic correlation —
  depends on this being decided first.
- **Response-shaping layer as a distinct stage**: tarpit/honeypot/mock
  responses need to hook in *before or instead of* httpd's normal
  file-serving path (`send_error_page` et al.) — architecturally a
  classify → decide → respond pipeline with three separable stages, not
  one function doing everything.
- **Safety boundary on the honeypot/deception mode specifically**: a
  simulated-vulnerability response is powerful but double-edged on a real
  production internet-facing server — needs airtight isolation so it can
  never (a) accidentally expose something real, or (b) become a real
  attack surface itself (e.g. an abusable open relay/proxy an actual
  attacker could pivot through). Flagged as a first-class constraint to
  design in from the start, not patch in after.

## representative example worth keeping for the forensic-classification design

Same conversation, user flagged as "[very representative]": a
`POST /cgi-bin/../../../../../../../../../../bin/sh` request —
CVE-2021-41773/CVE-2021-42013 (Apache path-traversal RCE), one of the
most widely mass-scanned-for exploits still in circulation years later.
Handled correctly by construction, not luck: Protocol-7's httpd has no
`cgi-bin`, no shell reachable via HTTP, so `POST not supported for: ...`
was just the ordinary method-dispatch outcome. Useful precisely because
it's a *named, fingerprintable* signature (a dateable CVE) rather than a
generic path probe like the `.env` sweep — the forensic-classification
layer should be able to tell these apart (unclassified noise vs. a
specific known exploit attempt against a vulnerability class Protocol-7
doesn't have), not just log both as undifferentiated 404/405 noise.

## ecosystem survey (2026-08-23, same conversation) — what's real vs. planned

User pointed at `netfilter`/CISA-CVE-collection/forensics-zenka as
existing pieces this should integrate with rather than duplicate.
Checked ground truth directly (lesson from `bin/remote-users` earlier
this session: verify actual code, task-spec existence isn't enough):

- **`netfilter` zenka: genuinely unbuilt.** No `src/netfilter.*`, no
  `cfg/zenki/netfilter/` — only `data/yaml/coding-tasks/netfilter-zenka.yaml`
  (UFW/iptables abstraction, zenka-port-awareness, port knocking with
  TTL'd temp rules). Would be the natural network-layer *enforcement*
  actuator for classified-scanner responses, once built.
- **`openvas`/`nessus`: real, and already wired into forensics.**
  `openvas.cmd.report-to-forensics` + `openvas.handler.forensics-reply`
  is a working handoff into `forensics.investigate.finding` —
  vuln-scan findings already flow into the forensics pipeline today.
- **`forensics` zenka: real, substantially more mature than assumed —
  but scoped to internal code-integrity, not external attack traffic.**
  `forensics.event.nightly-sweep` (04:07 daily) scans every zenka's
  `*.zenka.log` for exactly three pattern classes: `NOT-FOUND`/`MISS`/
  `BAD` — all about the AMOS7 code-signature system every `src/` file
  carries, not security/attack telemetry. httpd's `.env`-scanner or
  CGI-RCE-probe log lines match none of these classes today — this is
  the concrete gap behind the user's "not just internal system states"
  framing. Downstream machinery is the real prize:
  `forensics.event.rule-synthesis` takes unprocessed sweep anomalies
  (`class`/`zenka`/`message`/`count` shape, generic — not
  signature-specific), sends each to the local coding-zenka LLM with a
  structured prompt to generalize a detection regex, writes gated
  candidate rules to disk pending manual review before `rules/active/`
  promotion. This is already the "extrapolate/correlate new anomalies"
  mechanism the vision called for — built, just not yet fed anything
  from httpd/httpsd.
- **CVE mapping: also closer than "build a database."**
  `data/protocols/cisa/` holds 1655 CISA KEV-catalog entries —
  `CVE-2021-41773` (the exact CVE behind the cgi-bin RCE example above)
  is already one of them, full description included.
  `openvas.enrich.finding` does trained-embedding nearest-neighbor
  lookup across `cve`/`mitre`/`cwe`/`cisa` domains (`data/embeddings/
  <domain>.vec`) to attach context to any finding-shaped hashref
  (`oid`/`name`/`severity`/`target`), with a score-1.0 direct hit when
  a CVE ID is named literally. Wired for openvas findings today, but
  nothing about its shape is openvas-specific.

**Net conclusion: the right frame for this vision shifted from "build a
forensic/CVE-mapping system" to "extend one pattern-class list
(`forensics.event.nightly-sweep`'s `@pattern_classes`) and adapt one
enrichment call (`openvas.enrich.finding`) to accept an httpd-sourced
finding shape."** Still zero design decisions made on exactly how —
this just corrects what's actually being built on top of.

## feature/adapter survey (2026-08-23, same conversation, via fork)

User asked for a structured feature/adapter list across 6 named
categories, then pointed at `find data/ | grep -i forensic|security`
as existing planned components. Full survey (~20 docs + code
cross-checks) run via fork; condensed here, full report was ~3.5k
words — re-run the same survey scope if deeper citation detail is
needed later.

**1. Capture modes/buffers (httpd-specific): still a real gap.**
Nothing built. `httpd.http_post`'s body-accumulation is route-gated
(unsupported paths never read the body at all, confirmed earlier this
session). Two design precedents for the general "capture before you
lose it" shape exist elsewhere (`ZENKA-LIFECYCLE-ONDEMAND-HEARTBEAT.md`'s
forensic-first heartbeat-timeout mode; `NESTED-CUBE-NETWORK-SEGMENTATION.md`'s
pre-route-collapse chain logging at cube gateways) but neither is httpd
or built.

**2. Pattern matching/scoring + cross-zenka pattern DB: the strongest
substrate in the whole survey, AND a real duplication risk.**
`ncode.regex.*`/`ncode.cmd.*` (confirmed IMPLEMENTED, two independent
sources) is a working self-refining regex engine — applicability/
confidence/coverage scoring, hybrid regex+LLM escalation ladder,
LLM-diff pattern extraction. [[vision-shared-pattern-registry-ncode-smtpd-forensics]]
already proposes generalizing this into a shared `base.pattern-registry.*`
serving `smtpd.regex.*` + a forensics-child-zenka adapter — httpd
would be a natural 4th consumer of an already-half-designed
generalization, not a new idea. **But** `forensics.event.rule-synthesis`
(confirmed real, read earlier this session) is a SECOND, independently-built
anomaly→LLM→candidate-regex pipeline, not unified with ncode's engine.
Building a THIRD (httpd-specific) pattern system without reconciling
these two first would be a real mistake. CVE-side: `data/protocols/
{cisa,mitre,cwe}` are real/populated (1655/697/944 entries); `{cve,nvt}`
are genuinely empty (cve deferred, nvt bound to unbuilt openvas
feed-sync). The unified cross-domain loader task (`security-intel-embedding-domains.md`
task 2.1, `security.intel.*`) is NOT built — only the openvas-specific
`openvas.enrich.finding` exists; adapting it to an httpd-finding shape
means either extending its assumptions or building task 2.1 for real.

**3. Fine-grained timeout/behavior-mode by security level: a naming
collision waiting to happen, plus the exact "beyond IP" mechanism
already half-built.** TWO unrelated things are both called "security
level" in this codebase: (a) `ui.caller.security-level` — REAL, BUILT,
LIVE, integer 0/1/2/unbounded resolved from an authenticated caller's
group membership, gates `%data` field visibility. Its own design doc
(`UI-SHOW-SECURITY-LEVELS.md:79-87`) explicitly stubs a future
**"generic key-based authorization for levels," independent of group
membership** — this is precisely the vision's "connection that can
authorize itself, perhaps beyond an IP address" idea, already earmarked
as a hook, unbuilt. Same primitive is independently slated for a
second reuse already ([[topic-write-access-security-infrastructure]]'s
write/sign-command approval levels) — extending it a third time (httpd
behavior-mode gating) fits a pattern already in motion. (b)
`HARMONIC-TOPOLOGY-SECURITY-MODEL.md`'s 0-14 harmonic/mod-13 levels —
VISION ONLY, the doc's own roadmap says "Phase 1: Visualization
(Current)," no enforcement code exists. **Don't reuse "security level"
language for the new system without explicitly picking which of these
two it extends, or neither** — they're incompatible axes (identity/group
vs. harmonic-validation-distance) sharing one term today. Real precedent
for "detected bad pattern → connection consequence" already in
production: `plugin.auth.zenka`/`plugin.auth.unix` disconnect outright
on repeated failed-auth (a real fixed vuln, previously allowed unlimited
guessing). Philosophical grounding worth carrying forward, independently
converging with [[feedback-security-design-pacing-avoid-overreaction]]
from a different angle: `TRANSLUCENT-LAYERING-SECURITY-MINDSET.md` —
"the maximum damage an entropic attack can do is become a forensic
report," defensive layers should be translucent/legible, not silent walls.

**4. Admin control (mode switch, manual cleanup): unbuilt but the
most concretely spec'd category.** [[topic-write-access-security-infrastructure]]
+ referenced `SIGNED-COMMAND-INTERFACE.md` is the fullest existing
design for signed admin-approval actions (signature over
command+ntime+nonce, extendable to cover a content checksum so
"approver actually saw what they approved" is provable, self-vs-
independent-review detection via `signed_by`+`source_task`,
`protocol-7-menu` UI extension explicitly motivated by "many small
approval requests" — exactly the volume a scanner-response system
would generate). Not built. This session's own
`keys.console.{list-authorized,drop-authorized,authorize}` batch
(`ddd5418c0`) is a small real precedent for the same admin-control
shape in a different domain. Gotcha to avoid: [[bug-forensics-dotted-command-names]]
— any new dotted command name silently misparses as a routing hop-chain;
new admin commands need hyphenated names and BOTH a target-zenka
whitelist entry AND a `cube/access.zenki` grant.

**5. Generalization to smtpd/nameserv: already the direction multiple
designs converge on for smtpd, genuinely unexplored for nameserv.**
smtpd is already the named 2nd consumer in the pattern-registry vision
(independent motivation: `smtpd.classify`'s existing hardcoded
keyword-regex fallback needs externalizing regardless).
[[vision-forensics-stylometric-anomaly-child-zenka]] is smtpd's own
anomaly-scoring analogue (correspondent writing-style drift, not
network scanning) — same "child zenka does the dirty work, only a
generalized finding crosses back" isolation shape category 1 also
needs. `ui.caller.security-level`'s future key-based-auth hook is
inherently protocol-agnostic already. nameserv: zero mentions in any
security/scoring context across the whole survey — genuinely new
ground if pursued.

**6. Channels concept: real generic transport, one real emitter, zero
subscribers, and the "security zenka" concept it's meant to serve
doesn't exist at all.** `channels` zenka is real/substantial (30+
files). `channels.subscription.mapping`'s own canonical usage example
is LITERALLY security-channel-shaped: `DECLARE CHANNEL security.events
SUBSCRIBE-TO security.tofu-requests MAP .username TO tofu_user` — not
invented for this survey, the module's own docs use this. `plugin.auth.auth-keypair.tofu-notification`
(confirmed earlier this session) really does emit to
`security.tofu-requests` today. Grepped for any live `DECLARE CHANNEL`
subscribing to `security.*`/`forensics.*`: **none found** — wiring +
one emitter exist, nothing listens yet. `CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md`
(master design) specifies dedicated encrypted `security`/`forensics`
channels plus a 3-layer incident-escalation reachability ladder
independent of normal routing (normal → degraded-direct-to-channels →
last-resort-multicast-via-discover). **No `security` zenka exists at
all** — the "security zenki that patrol the network" concept is
entirely unbuilt; only the transport they'd ride on is real.

**Two findings worth flagging on their own:**
- **Documentation lag, code is ahead of its own tracking docs**:
  `forensics-agent.md`/`forensic-report-pipeline.md` status headers
  both say phase 2/3 "not started" — false, confirmed by direct code
  read earlier this session (`forensics.cmd.investigate-finding`,
  `forensics.event.rule-synthesis`, `forensics.report.assemble`/
  `.generalize` all real and substantial). Trust code over these two
  headers if referenced again.
- **Metaphysics vs. mechanism, keep separated when scoping**:
  `forensics-zenka.md`'s own gaps section admits no tracer module, no
  quarantine mechanics, no "council of 13" implementation exist — that
  whole harmonic/philosophical layer is explicitly NOT bridged to the
  real working sweep/rule-synthesis/report/enrich chain
  (`forensics-zenka.md:268-271` says the working pipeline deliberately
  ignores it). Any httpd integration should target the real chain, not
  the harmonic-topology material, even though docs file both under one
  "forensics/security" heading.

**Maturity context, per user directly (2026-08-23), qualifying the
survey above**: the entire forensics/nessus/openvas branch is very
young code — built in one intense extended session, Wed-Fri
2026-07-29 to 2026-07-31. "In terms of maturity or feature
completeness this represents just the beginning... but with a clean
working implementation to expand on." Recalibrates the survey's "real,
working code" findings: genuinely real, not aspirational, but freshly
built and still settling — not long-iterated/battle-tested
infrastructure. **The channels zenka's security/forensics wiring with
zero subscribers (category 6 above) was not an oversight — it was
deliberately built ahead of its consumers**, per user: "the 'channels'
plan was basically waiting for a forensics and a security zenka... or
however that one would be called when actually implemented." Forensics
now exists (young, per above). **A `security` zenka — name not yet
settled — is the specific, named missing piece** the channels design
was always anticipating, not a gap that emerged by accident. Today,
apart from chat/local-LLM interaction, nothing automated consumes
`security.tofu-requests` or acts on forensics findings — a human/LLM
looking at things ad hoc is the only "subscriber" that currently
exists.

**Correction, twice-refined (same conversation)**: assistant first
speculated the httpd-defense work "could be the first workload that
justifies building the security zenka now" (wrong — it's explicitly a
later, bigger component per plan). Then speculated its absence
"blocks the response/action side" (also wrong, per user's sharper
correction): **httpd can already act locally on its own patterns/
thresholds, and forensics can already receive and analyze patterns —
neither is waiting on the security zenka for anything.** The security
zenka blocks neither observe nor local-response; it's a categorically
different capability.

**What the security zenka actually is, per user + primary-source read of
`CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md` (full 130-line doc,
read directly this session, not secondhand via the fork survey)**: a
more generic, active, roaming *admin/recovery* agent operating BEYOND
Protocol-7's own zenka network — user's examples: core-dumping a
potentially-compromised UNIX process (any process, not just P7 zenki)
and making off with the live memory capture; carrying its own trusted
checksums inline when visiting a potentially-compromised host system,
since that host's own logs/binaries may already be altered — i.e. it
brings external ground-truth rather than trusting local state, a
classic incident-response posture. The doc confirms this shape
directly (§"security zenki and network patrol"): "agents that roam,
respond, and can be called by any other zenka," core-dump triggering
("process state preserved at the moment of suspicion, not
reconstructed after the fact"), forensics export. Also present but not
yet read in depth: the `nodes` zenka's planned wake-on-lan P0-P3
priority system, explicitly designed to make "the forensics and
security pipeline fully autonomous end-to-end" (P1 = wake on demand
for security incident/active forensics need, P2 = scheduled nightly
forensics).

**Forensics zenka's distinct character, confirmed**: "always present"
— the nightly 04:07 slot "has existed for years, wakes when
implemented" (`cfg/zenki/events/event-setup.base`, `type =
zenka-present`) — a standing, continuously-scheduled analysis layer,
not spawned on demand the way security zenka would be.

**Relationship between the two, per user, genuinely undecided**:
forensics' analysis CAN trigger security-zenka instantiation, but the
exact triggering mechanism isn't settled. Most likely starting shape:
a common security channel that forensics is DEFINITELY a member of
(matches the doc's "security and forensics zenki are natural
subscribers to dedicated security and forensics channels"), and
security zenka would LIKELY listen to — but whether security zenka
ever decides on its own to approach an incident zone (autonomous
patrol) versus only responds when called (dispatched) is explicitly
unresolved, confirmed by the doc itself using both framings without
resolving which/when.

**Doc's own four-layer mental model, worth holding onto**: "every
zenka is a potential sensor, security zenki are the response layer,
forensics zenki are the analysis layer, and the llm is the
rule-synthesis layer" — httpd would slot in purely as a sensor in this
model; nothing about being a sensor requires the response layer to
exist yet.

**Practical implication, still holds**: httpd-side capture/
classification/forensics-feed work can proceed now and even emit into
a `security.events`-shaped channel with zero listeners today (a
channel gaining a subscriber later requires no upstream change) —
this was the one part of the earlier reasoning that survived both
corrections.

## proposed starting point, per user (2026-08-23, same conversation)

Generalize three things together rather than build httpd-specific
versions of each: (1) the updatable regex pattern-matching component
(from `ncode` — confirmed real, see category 2 above), (2) httpd's
hooks/adapters, (3) an internal scoring system — generalized because
`smtpd` will need the same scoring shape too, not just httpd. Proposed
mechanism for the scoring/threshold/mode-trigger piece: **curves**,
not discrete threshold branches.

**Grounded in real, existing infrastructure — read directly this
session, not assumed:**
- `src/base.curve.{register,cancel,eval,compose,tick,init}` — REAL,
  BUILT, already driving mpv volume/crossfade fades and radio-relay
  BPM ramps (see [[topic-base-curve-system]]). `compose` combines
  independently-registered curves via `product`/`sum` with optional
  clamp — e.g. mpv's real volume chain is `daytime envelope × ambient
  compensator × immediate fade`. **The doc's own "future consumers"
  line already names "rate limiting... sensor-driven parameter
  adjustment"** — this use case was anticipated, not invented today.
- [[topic-implicit-perspective-navigation]] — the governing principle,
  proven in a different domain (camera/perspective nav): "curves/
  thresholds ARE the decision, not a separate layer bolted on top." No
  code should ever branch on "is this too suspicious" as a discrete
  check sitting beside the curve — the curve's shape produces the
  qualitative behavior directly.
- [[vision-consensus-vote-as-curve-decision]] — the closest existing
  worked example: `llm.service.consensus_vote`'s two real bugs
  (comparing against `distances[0]` instead of per-candidate distance;
  a self-comparison grep) were diagnosed as symptoms of exactly the
  discrete-winner anti-pattern the nav principle warns against, not
  independent mistakes. Recommended fix there: redesign as a
  `base.curve.compose`'d continuous certainty value, with the
  magnetic-clustering principle applied — several close-scoring
  candidates form a cluster to act on, not ambiguity to force a single
  winner from. **Same shape maps directly to security scoring**:
  several sources/patterns scoring similarly suspicious shouldn't force
  individual discrete triage, they'd cluster naturally. Status there:
  vision-only, deferred by user choice — same pacing posture as this
  file.

**Confirmed**: "nshell" was a slip for "ncode." User's added context:
the generalization was "only slightly postponed" deliberately — ncode's
pattern engine was proven working within ncode's own domain first,
before generalizing out, but "it was clear from the beginning this
will be a feature [group] that many zenki will need internally and
should be able to load as module." I.e. the shared-module shape was
always the intended end state, not an afterthought bolted on after
noticing duplication — ncode was just the first proving ground. Now
that smtpd and httpd both want the same shape, real multi-consumer
demand exists to justify doing the generalization for real (avoids the
premature-abstraction trap the other direction).

## ncode.regex.* real-code read (2026-08-23, same conversation)

Read directly: `ncode.regex.{load,save,assess,apply}`,
`context.pattern.calculate_confidence`. User confirmed forensics zenka
is ALSO a likely consumer of the generalized version, not just
httpd/smtpd (reconciling `forensics.event.rule-synthesis` — the
2nd, independently-built pattern-gen pipeline flagged in category 2 of
the earlier survey — is therefore part of this same work, not separate
cleanup later).

**Pattern storage schema** (`ncode.regex.load`): name/descr/pattern/
compiled-qr/replace/steps/verify/applicability{file_type,confidence,
coverage,scope,scope_active_idx,requires}/origin(`loaded`|`llm-extracted`)/
source_task/note/stats{applied,false_positive,skipped}. The `steps`
field (`[{tool,search,replace}]`) and `replace` are code-editing-specific
— security patterns are pure detection, nothing to replace.

**`ncode.regex.apply` (matching/decision engine) IS genuinely
reusable in shape, and already has a graduated-response structure**:
(1) hard status gate — `status: llm-required` never auto-fires
regardless of confidence, always flagged; (2) confidence-threshold gate
— below threshold (or `mode: scan`) → report-only; (3) `requires`:
prerequisite-pattern chaining, a pattern only fires if named OTHER
patterns already matched (real escalation-logic precedent already
built); (4) `scope_match` applicability gating against a namespace
hierarchy. Direct conceptual parallel to the original vision's
graduated timeout/response idea.

**Where it doesn't transfer**: `context.pattern.calculate_confidence`
penalizes patterns lacking a `replace` field ("flag-only patterns less
confident") — backwards for security (every pattern is detect-only by
design). Extraction algorithm (`context.pattern.extract_from_change`)
needs a before/after diff PAIR (ncode always has one: old code line →
LLM-edited new line) — security/forensics patterns don't have a
natural pair, which is exactly why `forensics.event.rule-synthesis`
independently took a different approach (single anomalous example →
ask LLM directly to generalize a regex, no diff needed).

**Working conclusion**: the storage/scoring/gating LAYER (schema,
tiered apply/flag decision logic, applicability gating, stats
tracking) looks genuinely shareable across ncode/smtpd/httpd/forensics.
The candidate-PROPOSAL algorithm (how a new pattern gets suggested)
probably should NOT be forced into one shared function — diff-based
(ncode) and single-example-LLM-generalization (forensics/security) are
legitimately different problems that can share the same downstream
schema without sharing that one step.

**Correction on the `slow_down`/GPU-alert precedent, per user**: it is
NOT a curves-based example — it's a more primitive, pre-`base.curve`
mechanism (percent values, manual auto-mode flags, alert-counter
threshold). Its real significance: it's a **working feedback loop** —
GPU load drives scroll-speed reduction, and scroll speed itself
influences GPU load, closing the loop — proving the *problem shape* is
real and has been solved before, crudely, not validating curves as the
mechanism already used there. Per user: "the curves are the
generalized upgrade or evolution of those prior approach types." Don't
cite `slow_down` again as a curves precedent — cite it only as
evidence the feedback-loop problem class is real and prior art exists
for the *shape*, with `base.curve.*` as the intended successor
mechanism, not a peer implementation of it. Worth carrying forward:
`slow_down` is a genuine closed loop (response affects the very signal
being monitored) — worth being aware a security response (e.g.
rate-limiting) could analogously feed back into its own input signal
(a throttled attacker's observed request-rate drops, which could
relax the curve again) — not designed/resolved, just flagged as the
same dynamic class.

**User confirmed the proposed scope (2026-08-23): rolling-window
filtering → curve composition → tiered precedence response → four
concrete outputs (rate-limit/timeout/disconnect/mode) is agreed as
the right size — "yes, the scope sounds good."**

**Complementary relationship with the curves idea (still open, this
session's other thread)**: `ncode.regex.apply` is single-shot
classification (does this input match, at what confidence, right now)
— no notion of a score accumulating over time across repeated matches
from the same source. `base.curve.compose` would add exactly that:
each pattern match becomes a factor curve, composed into an evolving
per-source score. Not overlapping mechanisms — apply-layer decides
"did this match," curve-layer decides "what does the accumulated
pattern of matches mean over time."

**Status: still design conversation, zero code written for any of
this.**

**Status: still pure vision, zero code, zero committed design
decisions — this entry is now the ground-truth map to design against,
not a proposal.** Next step per the user is still open — they were
asked whether to start with an observation/classification-only first
step (no blocking action at all) but hadn't answered as of this entry.

#,,,,,...,.,,,,.,,.,.,,..,..,,,..,,,.,...,,.,,..,,...,...,..,,...,,.,,,,.,...,
#EZKRKU6OGXS5MFEBFMFRG6QDKDJYN3VRCC6CASRD3YKELI34GVN3SIJGCYA6H27SYIGTLVWQFIFY2
#\\\|ZOJBEHWJLSJVLWZVCBMZO5NWJB4UURVPYPXAMHWNE5LLATHGHZX \ / AMOS7 \ YOURUM ::
#\[7]ZTATL2C3EDPKZP5RUMTUYVAC3ZN45NHM7UM2XVNVJT4P36MHIICA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
