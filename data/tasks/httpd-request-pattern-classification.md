## [:< ##

# name  = task: httpd request pattern classification (phase 1: observation only)
# descr = per-connection / per-peer rolling request history + classification
#         against a small explicit set of known-scanner-shaped patterns.
#         phase 1 is OBSERVATION ONLY — no drop, no ban, no rate-limit,
#         nothing that touches an actual connection. later phases add
#         optional, opt-in, config-gated action layers with an explicit
#         self-inflicted-harm safety argument per step.

## context

on 2026-08-23 a live automated `.env`-file credential-scanning sweep was
observed against the public-facing httpd/httpsd deployment — dozens of
Laravel/Docker/AWS-style probe paths pipelined down one persistent
keep-alive connection. no rate-limiting / ban / abuse-detection
mechanism exists anywhere in `httpd.*` or `io.ip.tcp.*` today.

the actual threat model here is near-zero: protocol-7 has no PHP
interpreter, no Node/Docker `.env` convention, no Laravel/Django-style
framework — the classic vectors these scanners target structurally do
not exist. the bots leak more information to us than they extract.

the governing constraint on this whole task is
`data/ai-mem/claude/feedback-security-design-pacing-avoid-overreaction.md`.
short version: prioritize correct/elegant/self-harm-resistant over
fast; observation and classification come BEFORE any blocking action;
blocking action (if any) must be opt-in, never the default. the
canonical failure mode being designed against is the badly-configured-
fail2ban outcome — locking out admins / shared-IP clients / CDN-fronted
legitimate traffic while providing near-zero real security benefit.

related vision (broader, longer-horizon, mostly design-only):
`data/ai-mem/claude/vision-httpd-adaptive-defense-and-honeypot-framework.md` —
graduated trust scoring, forensic feed, curves-driven response shaping,
optional deception/honeypot layer. THIS task file is the concrete,
minimal, phase-1-only foundation that vision expands on later; it
deliberately does not attempt the full vision in one pass.

related infrastructure already built, worth reusing rather than
duplicating:

- `signal.cancel.*` (see `data/tasks/signal-cancel-log-library.md`) —
  the mirror-image pattern library: cancellation of KNOWN noise so
  unknowns surface. this task's classifier library and signal-cancel
  should share the YAML pattern-file shape where sensible.
- `ncode.regex.*` — real self-refining regex engine with confidence /
  applicability / requires-chain scoring. its schema is a candidate
  ancestor for the classification pattern schema below; explicitly
  NOT its diff-based candidate-proposal algorithm (patterns here have
  no before/after pair).
- `base.curve.{register,cancel,eval,compose,tick}` — real, driving
  mpv/radio fades today. its own doc names "rate limiting" as a
  future consumer. reserved for phase 4, not phase 1.
- `channels` zenka — real transport, `security.events` /
  `security.tofu-requests` are canonical shapes; zero subscribers
  today. httpd can emit into it with no upstream change required.
- `forensics.event.rule-synthesis` — real, unprocessed-anomaly →
  LLM → candidate-regex → gated-review pipeline. httpd findings can
  eventually feed this, out of scope for phase 1.

## placement recommendation: library loaded by httpd/httpsd, NOT a new zenka

recommendation: implement as a set of `httpd.classify.*` modules loaded
directly into the httpd (and httpsd) zenka process, not as a standalone
`abuse-detect` / `security` zenka.

reasoning, not "TBD":

1. classification input is inherently per-request/per-connection
   context (request path, method, status, keep-alive session id,
   peer socket). every piece of that data is already in-process
   inside httpd's request handler chain. routing each classified
   request over cube to a separate zenka would add IPC latency to
   every single HTTP request handled — a real cost for zero
   architectural benefit at phase 1.
2. the observed action-side of phase 1 is exactly two things:
   annotate the existing httpd log line with a classification tag,
   and expose an in-process stats hash via a cmd handler. neither
   crosses a process boundary.
3. protocol-7 already has this shape: `httpd.benchmark.*` and
   `httpd.diagnostic.*` are in-process instrumentation submodules
   loaded directly by httpd. `httpd.classify.*` fits the same slot.
4. later action-side phases (3+) act ON the connection they were
   classifying — hangup this keep-alive, adjust this connection's
   read timeout. all of that requires the classifier and the
   connection state to live in the same process. a remote zenka
   would either need to be given a handle back (adds a whole RPC
   surface for something local) or the action would need to be
   duplicated in httpd anyway.
5. reuse by smtpd / nameserv (a real future direction per the
   vision doc) is achieved by promoting `httpd.classify.*` into a
   shared `base.classify.*` or `pattern.classify.*` library once
   a second consumer materializes — same trajectory `ncode.regex.*`
   is on. building it as a zenka first and then de-zenka'ing it
   later is strictly worse than the reverse.
6. the standalone-zenka option has one genuine advantage — process
   isolation for crash containment. phase 1 is pure read + regex-
   match + hash increment; the crash surface is negligible. if that
   changes (phase 5 deception/response-shaping introduces real
   complexity), revisit then; not now.

concrete non-negotiable: `httpd.classify.*` must never mutate
`$data{httpd}{connections}{...}` or the socket itself in phase 1.
its only side effects are: append to its own state hash, emit log
lines, expose stats via its own cmd handlers.

## architecture

### pattern library — `data/httpd-classify/patterns/`

YAML, one file per scanner family. shape deliberately close to
`signal.cancel`'s pattern files so the two can eventually share loader
code.

```yaml
# data/httpd-classify/patterns/env-credential-scan.yaml
family: env-credential-scan
descr: dotenv / laravel / docker credential-file probes
severity: probe                # probe | exploit-attempt | known-cve
patterns:
  - name: dotenv-root
    path_regex: '^/\.env(\.[a-z]+)?$'
  - name: laravel-storage-env
    path_regex: '^/storage/\.env$'
  - name: docker-env
    path_regex: '^/(config|app|api|prod)/\.env$'
```

initial family files, all keyed off patterns observed on this
deployment or covered by the CISA KEV catalog already at
`data/protocols/cisa/`:

```
env-credential-scan     .env family probes (2026-08-23 sweep)
git-config-leak         /.git/config, /.git/HEAD, /.gitignore
wp-admin-probe          /wp-login.php, /wp-admin, /xmlrpc.php
phpmyadmin-probe        /phpmyadmin, /pma, /myadmin, /dbadmin
path-traversal-cgi      /cgi-bin/../../... family (CVE-2021-41773
                        style; keep CVE id in the yaml for later
                        openvas.enrich.finding linkage)
generic-shell-probe     POST/GET of /shell, /wget, /curl, ?cmd=
admin-panel-probe       /admin, /manager/html (tomcat), /jenkins
```

each pattern file MUST include a `severity` field so later phases can
gate action on `severity: exploit-attempt` without also acting on
routine `severity: probe` noise.

### classifier module set — `httpd.classify.*`

```
httpd.classify.init             load pattern library, init state
                                hash + expiry timer
httpd.classify.load             load + compile YAML pattern library
httpd.classify.match            ( path, method ) → family+name or
                                undef ; single-request classification,
                                no state mutation
httpd.classify.record           ( peer_key, request_meta ) → append
                                to rolling per-peer history ;
                                classification-tag applied ;
                                stats counters updated
httpd.classify.expire           timer-driven sweep : evict stale
                                per-peer entries past ttl
httpd.classify.cmd.stats        expose in-process stats
                                (per-family counts, per-peer top-N,
                                total-classified vs total-requests)
httpd.classify.cmd.history      show rolling history for one peer_key
                                (safe: no raw request bodies, path +
                                status + timestamp only)
httpd.classify.cmd.reload       reload YAML library without restart
```

### integration point in existing httpd

`httpd.classify.record` is called from exactly one site in the request
lifecycle, immediately after the response status code is determined
and before the log line is emitted. it MUST be called from a
non-blocking code path (already true — this is a pure hash update),
and it MUST be a no-op on `<httpd.classify.enabled>` being false
(default: on for observation, but the guard exists from day one).

log-line annotation: existing httpd log emitter picks up a
`classify_tag` field if `httpd.classify.match` returned one, and
appends it as `[classify=env-credential-scan/dotenv-root]`. purely
additive — no existing log format changes; downstream parsers still
work.

### data tree layout — with expiry designed in from the start

```
$data{httpd}{classify}{library}{<family>}{...compiled patterns...}
$data{httpd}{classify}{peer}{<peer_key>}{first_seen}     = <ntime>
$data{httpd}{classify}{peer}{<peer_key>}{last_seen}      = <ntime>
$data{httpd}{classify}{peer}{<peer_key>}{request_count}  = <int>
$data{httpd}{classify}{peer}{<peer_key>}{classified}{<family>} = <int>
$data{httpd}{classify}{peer}{<peer_key>}{ring}           = <arrayref>
                                                          ( bounded ring
                                                            of last N
                                                            request tuples )
$data{httpd}{classify}{stats}{total_requests}            = <int>
$data{httpd}{classify}{stats}{total_classified}          = <int>
$data{httpd}{classify}{stats}{by_family}{<family>}       = <int>
```

`peer_key` is the string identity used for per-peer accounting. its
definition is deliberately a configuration knob, defaulting to remote
IP for phase 1 but designed so it can later be broadened (per the
vision doc's "beyond an ip address" hook) — see the "peer identity"
discussion below.

### expiry — mandatory, designed in from phase 1

this codebase has at least one confirmed bug of the exact shape being
designed against here: unbounded external-facing state accumulating
with no automatic reset. see
`data/ai-mem/claude/bug-jobsite-pending-count-leak-nonassessing-cycle.md`
for a fully-diagnosed case where a persist/reset invariant was too
narrow and a stray counter survived indefinitely, wedging the
containing cycle. treat that as a first-class hazard, not a hypothesis.

concrete requirements, all in phase 1:

1. `$data{httpd}{classify}{peer}{<peer_key>}{ring}` is bounded to a
   fixed maximum length (`<httpd.classify.ring_size>`, default 64).
   append past that overwrites oldest — never grows past bound.
2. per-peer entries have a hard TTL (`<httpd.classify.peer_ttl>`,
   default 3600 seconds). `httpd.classify.expire` is a periodic
   timer (default every 300s) that walks the peer hash and deletes
   any entry whose `last_seen` is older than TTL.
3. total peer-hash size has a hard cap (`<httpd.classify.max_peers>`,
   default 10 000). on cap breach, `httpd.classify.expire` runs
   immediately AND drops the oldest-`last_seen` entries until the
   hash is under cap. under load this may drop still-live entries —
   that is preferred over unbounded growth; the entries are
   observation data, not correctness state.
4. `httpd.classify.cmd.stats` must include current `peer_hash_size`
   and `oldest_peer_age` so an operator can see the eviction
   behavior working without needing to read code.

### peer identity — deliberately narrow at phase 1, broadenable later

`peer_key` for phase 1 is the remote IP address, and only that.

why not fingerprint / TLS session / authorized-key from
`.n/remote-keys/authorized`: those are legitimate upgrade paths
(the vision doc's "connection that can authorize itself, perhaps
beyond an IP address" hook, converging with
`ui.caller.security-level`'s planned key-based-auth extension), but
phase 1 is observation only — the wider the identity, the more
false-attribution risk if a later phase acts on it. keeping identity
narrow keeps the observation honest, and forces any later action
phase to explicitly re-open the identity question rather than
inheriting a decision made under observation-only assumptions.

## phased implementation order

### phase 1 — observation only, no connection effect

everything above. no phase 1 module writes to a socket, closes a
connection, alters a timeout, or rejects a request. the classifier
observes and annotates only. phase 1 alone should be indistinguishable
to any peer — legitimate or hostile — from the current unmodified
httpd, other than the added tag inside our own local log lines.

deliverable: patterns matched are visible in log tags and in
`p7c httpd.classify.stats` output; nothing else changes.

### phase 2 (still non-acting) — emit into channels + forensics feed

still zero connection effect. adds two outbound emissions:

- emit classified requests into the `channels` zenka on a
  `security.events` shaped channel — zero subscribers today by
  design, this is preparatory for the future `security` zenka the
  channels architecture was built anticipating. a channel with no
  subscribers is a no-op emit.
- emit a `forensics.classify-finding` message shape that the
  eventual `forensics.event.rule-synthesis` extension can consume
  as an anomaly candidate. deliberately fire-and-forget — never
  blocks the request handler.

safety of phase 2: emitting into a message bus is not action on a
peer. the peer's request completes exactly as it would without
classification. only local-side observers see anything.

### phase 3 (opt-in, config-gated) — SAME-CONNECTION-ONLY hangup

first phase that touches a connection at all.

behavior: if a single keep-alive connection accumulates ≥ N
(`<httpd.classify.hangup_threshold>`, default disabled=undef) requests
classified as `severity: exploit-attempt` OR `severity: probe`
within a single connection lifetime, close THAT keep-alive at the
end of the current in-flight response. do NOT retroactively affect
any in-flight request, do NOT record any per-IP ban.

why this is defensible against the self-inflicted-harm failure mode:

- action is scoped to the individual TCP session that itself
  provided the evidence. the peer can immediately reconnect and be
  served normally.
- no persistent list is written, no future connection from the
  same or any other IP is affected.
- shared-IP / CDN / NAT'd legitimate clients are not impacted:
  their DIFFERENT connections carry different request histories
  and are classified independently.
- an admin curl'ing `.env` deliberately (e.g. verifying a
  hardening claim) loses only that one keep-alive session and
  can reconnect.
- default is disabled. even after enable, the threshold is a
  configuration curve, not a hardcoded constant.

phase 3 must NOT be a global toggle; it must be per-vhost
(`<httpd.classify.hangup_threshold:<vhost>>`) so a low-traffic
public site can enable it independently of an internal-only vhost
where admin activity is common.

### phase 4 (opt-in, config-gated) — per-peer curve-driven soft rate-limit

introduces cross-connection per-peer state and the first mechanism
that could plausibly rate-limit a legitimate client. accordingly it
uses `base.curve.compose` (see
`data/ai-mem/claude/vision-httpd-adaptive-defense-and-honeypot-framework.md`
and the `base.curve.*` real-code notes there) rather than a discrete
threshold, per the "curves ARE the decision, not a separate layer"
principle.

behavior sketch: a `suspicion` curve per `peer_key` accumulates on
each classified match and decays continuously over configurable
half-life. curve value drives read-timeout curve for that peer,
composed with the base httpd read-timeout curve — so a "clean" peer
sees no change, a "suspicious" peer sees timeouts shrink smoothly,
a peer whose classifications stop sees the effect smoothly recover.

why this is defensible:

- decay is inherent to the mechanism, not a cleanup job that
  could be forgotten (the jobsite bug shape).
- composition with the base curve means the effect is a MODIFIER,
  not an override — the base timeout is always the floor, not the
  ceiling. an operator changing the base timeout is not silently
  overridden by a hostile-scoring peer.
- per-vhost gating carried forward from phase 3.
- explicit admin override: a peer_key present in
  `<httpd.classify.trusted_peers>` composes an infinity constant
  into its curve, making rate-limit effectively impossible for
  that peer regardless of classification. this is the safety
  valve for known-good administrative sources.
- `p7c httpd.classify.peer <peer_key>` shows the live curve
  value and its component factors, so an operator can debug a
  false-positive attribution without reading code.
- phase 4 still does not blackhole, ban, or reject a connection.
  it slows a peer's tolerable idle time. the peer can always
  complete a request.

### phase 5 (opt-in, most invasive) — response-shaping / tarpit / deception

deferred. only listed here for completeness of the roadmap:
tarpitting, mock/decoy responses, simulated-vulnerability honeypot
responses. every one of these is a real product surface with its
own isolation constraints (the vision doc flags "airtight isolation
so it can never (a) accidentally expose something real, or (b)
become a real attack surface itself"). do NOT design phase 5 in
this task file; when phase 5 is picked up it deserves its own task
file with its own safety analysis, precisely because "look
harmless" and "be harmless" are different properties and a mistake
here is a real vulnerability.

explicit phase-5 non-goals from day one, to prevent scope creep from
phase 4: no simulated file contents will ever be served from this
codebase without a dedicated task file that argues per-vhost
isolation, no open-relay-shaped mock response, no response whose
byte content is user-controlled by the classified peer.

### explicit permanent non-goals for this whole task

- no persistent IP-ban list, ever, at any phase.
- no cross-restart persistence of per-peer state — restart clears
  it. this is intentional: it forces the classifier to earn its
  claims against fresh evidence each restart, and eliminates the
  worst-case scenario of a poisoned persisted-state file surviving
  forever.
- no automatic promotion of a classification into `iptables` /
  `netfilter` rules. (a future `netfilter` zenka exists as a
  planned task; if used, it will be an explicit operator action,
  not an automatic classifier effect.)
- no exfiltration of request bodies into logs or stats. path +
  method + status code + peer-key hash only. this bounds the PII
  and secret-leak risk of the classifier itself.

## validation

phase 1 acceptance:

```bash
# with pattern library loaded and a live httpd running:
curl -s http://localhost/.env
curl -s http://localhost/.git/config
curl -s http://localhost/wp-login.php

p7c httpd.classify.stats
# expect: total_classified >= 3, by_family shows
#         env-credential-scan >= 1, git-config-leak >= 1,
#         wp-admin-probe >= 1

p7c httpd.classify.history <peer_key>
# expect: last 3 requests present, each with its classify tag
#         and status code, no request body content anywhere

# expiry sanity:
# wait past peer_ttl (or set peer_ttl low for the test)
p7c httpd.classify.stats
# expect: peer_hash_size drops toward 0 after the ttl passes;
#         oldest_peer_age never grows past peer_ttl + expire_interval
```

phase 1 must additionally demonstrate: with the classifier ENABLED
but pattern library EMPTY, request behavior and log content must be
byte-identical (except for zero classify tags emitted) to the
classifier DISABLED case. this proves the observation path has no
side effect on request handling.

phase 1 must additionally demonstrate: `httpd.classify.enabled = 0`
in config leaves `$data{httpd}{classify}` entirely absent, no
timers registered, zero cost. the feature is genuinely off when
off.

## dispatch prompt

implement phase 1 of `httpd.classify.*` — observation and
classification only. do NOT implement phase 2, 3, 4, or 5.

read first: this task file in full, and
`data/ai-mem/claude/feedback-security-design-pacing-avoid-overreaction.md`
(the pacing constraint is not optional).

create:

- `data/httpd-classify/patterns/` directory with the seven initial
  YAML pattern files listed in the architecture section
  (`env-credential-scan`, `git-config-leak`, `wp-admin-probe`,
  `phpmyadmin-probe`, `path-traversal-cgi`, `generic-shell-probe`,
  `admin-panel-probe`). each file MUST include the `family`,
  `descr`, `severity` fields and at least three real patterns.
  cite CVE ids in `path-traversal-cgi` where applicable
  (CVE-2021-41773 / CVE-2021-42013).
- `src/httpd.classify.init` — load YAML library via
  `httpd.classify.load`, initialize `$data{httpd}{classify}{peer}`
  empty hash, register the periodic expire timer
  (default 300s), guard entirely on
  `<httpd.classify.enabled>`.
- `src/httpd.classify.load` — YAML load + regex compile into
  `$data{httpd}{classify}{library}`.
- `src/httpd.classify.match` — pure function ( path, method ) →
  hashref { family, name, severity } or undef. must NOT mutate
  `$data`.
- `src/httpd.classify.record` — ( peer_key, request_meta ) →
  updates rolling ring (bounded to `<httpd.classify.ring_size>`,
  default 64), per-family counters, `first_seen`/`last_seen`.
- `src/httpd.classify.expire` — timer-driven sweep, TTL default
  3600s, max_peers default 10 000, evicts oldest-`last_seen` on
  cap breach.
- `src/httpd.classify.cmd.stats` — `<base.cmd>`-registered,
  returns per-family counts, totals, peer_hash_size,
  oldest_peer_age.
- `src/httpd.classify.cmd.history` — `<base.cmd>`-registered,
  takes a peer_key argument, returns bounded history (path +
  method + status + classify tag + timestamp only, never request
  body).
- `src/httpd.classify.cmd.reload` — reloads YAML library
  without touching per-peer state.

wire the single call site: `httpd.classify.record` is invoked from
the existing httpd request-completion path (adjacent to the log-line
emitter), guarded by `<httpd.classify.enabled>`. the existing httpd
log emitter picks up an optional `classify_tag` and appends
`[classify=<family>/<name>]` if present. NO other httpd file changes.

add `httpd.classify.init httpd.classify.load httpd.classify.match
httpd.classify.record httpd.classify.expire httpd.classify.cmd.stats
httpd.classify.cmd.history httpd.classify.cmd.reload` to httpd
zenka's `modules.load` and add `[httpd.classify.init]` after
existing httpd init runs.

verify all four phase-1 acceptance checks in the validation
section pass, including the "classifier-enabled-but-empty-library
behaviour is byte-identical to classifier-disabled" invariant and
the "classifier-disabled leaves zero cost / zero data-tree
presence" invariant.

do NOT add any code path that closes a connection, adjusts a
timeout, rejects a request, or writes any persistent peer-scoped
state — those are later, opt-in phases with their own safety
arguments in this task file. if unsure whether a change crosses
that line, do not make it — leave it for the phase-specific
follow-up task.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,.,,.,,,,.,,,,,,,,,.,,,..,,.,.,...,...,...,..,,...,...,.,,,,,,,,,.,,,.,..,,
#ZEOQVSIQ22PVRYEEUS4CIF6CAG5ZKQF7VQEZSWGPKJNUEFIXNSSYF7AZXZ5UH7AIQPDLACSPLV4KI
#\\\|4KYH4D2Y6CKNRH2WFP7MHHHCYUHWRAYNNSEJPJS2MF23QAQBCXQ \ / AMOS7 \ YOURUM ::
#\[7]NBXGOSSSD6W6ZFRUSJEL4PVWXURKAMQPMUD7JE5LOQZZOJQ2QQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
