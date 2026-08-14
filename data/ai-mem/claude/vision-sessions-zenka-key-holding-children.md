---
name: vision-sessions-zenka-key-holding-children
description: "2026-08-13 design thread: sessions zenka (v7-managed, clones users' etc_P7+var_P7 pattern) as cross-cutting session orchestrator over keys/credentials/cred-mesh/credential_fabric/users; spawns chmod_child-style minimal per-key child processes as the actual trust boundary, resolving subname-not-a-trust-domain"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3d67d3e5-c27e-4366-b904-c135559a9394
  modified: 2026-08-14T01:43:08.617Z
---

**2026-08-13, still forming — user explicitly said "still thinking about
the structure."** Long single-session design thread, capturing the shape
reached so far so it survives a context reset. Not yet reduced to a task
file or design doc.

## starting point — why `sessions`, not just `users`-clone

Per user: `sessions` is "the missing component between what the user-edit
session can do and a running system with all existing service accounts
attached" — i.e. `users`/user-edit hold *declared* identity records, but
nothing tracks which accounts are actually *live/attached* on a running
host. Concrete first exercise already named in
[[project-credential-types-into-user-edit]]: the still-uninstalled fanless
desktop needing both `taeki` and `root` to become p7-managed accounts.

Storage layout clone of `users`' proven pattern (`users.init_code`,
`users-zenka.yaml`'s `var_vs_etc_tier`): `etc_P7/sessions/` = durable/
declared bindings (survives rebuild), `var_P7/sessions/` = live/current
attachment state (transient, rebuildable) — same durability split
`discover.*` already uses for its own var_P7 state.

## scope grew: orchestrator across 4 existing namespaces

"service" clarified to mean protocol-7-internal AND internet/external
services both — user wants `sessions` to be "the perfect orchestrator or
platform transcending session types," unifying:

- `keys` — C25519 keypairs, TOFU host pins, github-pat credential
- `credentials` — typed credential entries incl. `web-session` type,
  `spawn_web_session`
- `cred-mesh` — slots (already named `session.<domain>`, see
  `cred-mesh.util.complete_approval:8`), rotation, key_holder
  parent/child
- `credential_fabric`/`proxy`/`transport` — proxy auth sessions, transport
  profile matching
- `users` — canonical records, remote/ peer sync, key-authority role

All four already have open reconciliation gaps against each other
(github-pat duplicated keys-vs-credentials, TOFU pins duplicated
keys-vs-users.remote, cred-mesh's `session.*` vs credentials'
`web-session`) — see [[project-keys-zenka-integration-direction]]. Not
resolved yet, `sessions` is the candidate unifying layer, not necessarily
the owner of any one piece.

## the external/native asymmetry — no single schema

User's own framing: "no 'default' choice — external sites define the
available options we recombine; our own code has pressure towards native
structures." Concretely:

- **external-facing**: must be a composable field/capability model
  (cookie jar / OAuth refresh / API-key+HMAC / whatever the site
  demands) — a closed enum (like `credentials.cmd.add`'s current
  `web-session api-key smtp imap ssh-key` whitelist) is the wrong shape,
  it can't recombine.
- **internal-facing**: nothing external constrains it, so convergence on
  one native session format is natural — `base.session.init`/
  `init_state` plus `users`' "directory-as-session" concept are already
  that pull, just not yet named as such.

## cross-host sync — reuse, don't rebuild

User wants `sessions` instances synced across hosts via "flexible mapping
profiles." Two existing, already-proven subsystems cover this:

- **transport**: `users.remote/{incoming,outgoing}/` sync-cache +
  `discover.orbital.known` + the working p-7-r/link-upgrade/ssh-tunnel
  stack, adoption-tested in commit `e4185e78b` — see
  [[project-users-zenka-unblocks-cross-host-testing]].
- **mapping-profile shape**: `transport`'s existing profile format
  (`data/yaml/transport/profiles/*.yaml`) — `context.destination`/`tags`
  match key, ordered `transports` list w/ `credential`/`min_quality` per
  entry, `fallback`. Concrete precedent: `atom.yaml` matches
  `destination: atom.host, tags:[mobile,high-loss]` and tries
  `udt-tunnel` → `quic-hysteria` → `direct-tcp` in quality order. A
  session mapping profile would reuse this shape rather than invent a
  second profile format.

## namespace isolation via zenka subnames — and the trust gap it opened

User's insight: existing zenka subname/child-forking mechanism (per-zenka
`%data`/`%code`/`%keys` isolation, unlimited nesting, e.g.
`weather.child.command`) gives real process isolation "for free" — no new
code needed to isolate `sessions.native.*` from `sessions.external.*`
etc.

This collided with [[topic-subname-not-a-trust-domain]]: subname/tree
position was already explicitly ruled to carry **zero** trust weight —
only session id + actual auth counts. Also connects to
[[topic-multidimensional-identity-session-topology]]'s "everything may be
a session, some eternal until a parent reference is cleared" and
`namespace-tree-intelligence`'s (2026-05-11) already-seeded ref-count-
driven branch/prune mechanism — user independently proposed "reference
count based automatic tree topology generation" for zenka subnames,
which is that same mechanism applied to process topology instead of the
data/code dedup tree. Caution carried forward: an auto-generated deep/
heavily-referenced branch must never be read as more trusted — topology
stays structural only.

## RESOLUTION — chmod_child-style children as the actual trust boundary

User found the fix: `sessions` spawns **minimal perl-template child
processes**, one per decrypted user/session key held in memory, each with
altered subnames/process names — explicitly citing the **already-working**
`coding.start.chmod_child` / `ncode.start.chmod_child` pattern as the
precedent (identical code in both):

- spawned via `IPC::Open2::open2($perl_bin, '-e', $heredoc_code)` — no
  module loading, no zenka config dir, lighter than even an on-demand
  zenka
- `$PROGRAM_NAME` rewritten (`"$zenka_name-<$admin_user>-chmod-child"`)
  for `ps`-visible identity without being a registered zenka name
- privilege dropped to the narrowest principal (`$UID=$EUID=$admin_uid`),
  never stays root
- closed, individually-validated command vocabulary over the pipe (not a
  general eval channel)
- **local `open2` pipes only** — NOT cube-routed, not even a
  socketpair-style `child.*` alias. This is the deliberate fork from the
  normal nested-child model: CLAUDE.md's ordinary child zenka stays
  "network-accessible" (`weather.child.command`); a key-holding child
  should NOT be, since the entire point is zero network surface for a
  process holding decrypted secret material.

This resolves the trust gap architecturally: the subname/tree shape stays
pure routing (satisfying `topic-subname-not-a-trust-domain`), while
**actual** trust rides on (a) process isolation — one secret per minimal
child, nothing else reachable in that address space, and (b) a real
signature check on privileged operations.

## root key — operational definition, not a privilege flag

User's derived definition, e.g. for a "taeki root key": it can only
add/remove keys from the keyring, and only when given a **timestamp +
signature from its own main session**. Root-ness is defined by what it's
allowed to authorize and how, not by a flag.

This likely doesn't need new crypto — `crypt.C25519.create_signature_
request:44` already stamps `<[base.ntime.b32]>->(1,TRUE)` and signs
`<ntime:subject-chksum:signer-chksum>`, and
`PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md:92-103` ("parent authorizes
child keys (signs them)") plus `discover.process_incoming_packet`'s key
cert pattern (line 197) is a real running instance of the same parent/
child signed-key hierarchy. Likely just needs wiring to gate add/remove
specifically, not a new mechanism. Supersedes/extends
[[topic-key-recovery-flexible-recreatability]].

## generalizes beyond key material — detach/reattach across a manager crash

User's extension: a child-process-based approach also allows detaching
and re-attaching a child independent of its parent zenka's own
lifecycle — e.g. surviving a backend restart without losing decrypted
key material. `ack -r detach data/` turned up two direct hits:

- **already real, partially built**: `credential_fabric.*`'s "detached
  key-holder child" (`CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md:9`,
  `key-holder-status.yaml` UI: pid/lock-state/decrypt-phrase-prompt) is
  this pattern already running, liveness checked via
  `base.exists.sub-process` (waitpid-based, survives the uid mismatch
  from fork-before-drop_privs — see `b27ebb655` in
  [[topic-credential-fabric-proxy-transport]]). NOT yet confirmed
  whether it currently survives `credential_fabric` itself being
  restarted by v7, or whether restart kills+reforks the child (losing
  decrypted state) — that gap is exactly what detach/reattach would
  close.
- **matching design, not yet built**: `V7-HOT-SELF-RESTART.md` — status
  "seed / not started" — sketches the general mechanism: a rescue-child
  transfers live fds (`SCM_RIGHTS`/`IO::FDPass` over a unix socket, same
  family as systemd `--deserialize <fd>` re-exec / nginx binary-upgrade
  handoff) from an outgoing process to a fresh one, which *resumes*
  rather than cold-inits. Doc explicitly names this as generalizing to
  "detaching and re-attaching the stdio of a regular zenka from its
  managing v7 instance" and to zenka migration between v7 instances/
  hosts — this whole thread's key-holding-children use case is a named
  instance of that same primitive, not a separate problem.
- **simpler interim shape** (doesn't need fd-rescue built first): child
  double-forks/setsids to survive its parent, listens on a well-known
  local unix socket under `var_P7/sessions/<key-id>.sock` instead of an
  `open2` pipe; a successor process reconnects to that socket on boot.
  Trades fd-transfer machinery for "child independently owns a socket
  path" — narrow surface increase, mitigated by file perms.

**Second concrete motivating case, found same thread**: X-11 zenka
against main-server crashes. Real incident on file,
[[topic-mpv-x11-dependency-cascade-restart]] — X-11 crashed
(compositor/mouse-event), v7's blanket dependency-cascade SIGKILLed
every dependent zenka including an audio-only `mpv[audio-0]` that never
touched a display; the landed fix (per-instance `dependency_exempt`)
only stops zenki that don't need X-11 from being caught, does nothing
for zenki that DO need the display. Precision on what actually needs
detaching: `X-11.job.start_server` already forks the X binary as a
genuinely separate process (`<X-11.servers>` stores its own pid/fh per
display, see [[topic-x11-multi-server]]) — likely already survives an
X-11 zenka crash on its own, unverified. What does NOT survive: the
`X11::Protocol` connection (`$server->{'conn'}`), `<X-11.obj>`,
`<X-11.WM>`, RANDR/DPMS/Composite init — all rebuilt from scratch via
`finalize_server` on every restart. The detach target for X-11 is that
connection/WM-state layer, not the X binary — same child-process-
survives-manager-restart shape as the key-holder case, different payload
(live protocol connection instead of decrypted secret).

## unifying principle — generic redirectable/re-creatable IO adapter

User's closing framing on the detach/reattach thread: the real direction
isn't three bespoke fixes (key-holder pipe, X-11 connection, later maybe
coding's inference server), it's **one generic IO adapter with
redirectable and even re-creatable streams**, built "deeply integrated
into unix and any useful mechanisms encountered" rather than reinvented
per case. Already named piecemeal in two docs, not yet unified:

- `SELF-CONTAINED-ZENKA-VISION.md:162-163` — `redirect.stdio`: "detach
  STDIO from terminal/log, hand it to a named handler," re-attach via
  unix domain socket.
- `STDIO-MULTIPLEX-PROTOCOL.md:346-349` — "detach = unbind the slot
  bindings without closing the socket; the META frames keep arriving and
  the store layer keeps storing. re-attach = bind a fresh slot at the
  corresponding address."
- `V7-HOT-SELF-RESTART.md` — `SCM_RIGHTS`/`IO::FDPass` fd-transfer is the
  same principle at the OS-mechanism level.

**How to apply**: any future detach/reattach work (key-holder children,
X-11 connection survival, eventually coding's inference server per
user's explicit "too leery for coding zenka yet, only once generic
routines make it transparent") should target becoming a consumer of one
shared adapter primitive, not grow its own bespoke logic. Coding zenka
is explicitly LAST in line — it lacks even the liveness/reuse groundwork
(no pidfile/registry) that credential_fabric's key-holder and X-11's
`<X-11.servers>` registry already have.

## closes the loop — a session is defined BY the adapter, not enumerated

User's final connection this thread: the generic IO adapter isn't just a
detach/reattach mechanism `sessions` happens to use — it's the thing that
*defines the domain* of what `sessions` orchestrates. "Between what can
there even be sessions" — answer: between anything that has (or is
fitted with) the generic redirectable/re-creatable-stream adapter. Not a
fixed enum of session types (OS account / zenka service account / web
cookie jar / key pipe / X11 connection) to special-case one by one — any
of those qualifies the moment it's wired to a rebindable stream endpoint,
and stops qualifying when nothing references that endpoint anymore (same
ref-count/prune angle as the earlier auto-topology point above).

This sharpens the previously-open question ("does attached mean OS
accounts only, or also protocol-7's own `system.amos-zenka-user` service
accounts?") — answer is neither is privileged, both qualify identically
via the same adapter mechanism, no special-casing needed. It also
concretely grounds `topic-multidimensional-identity-session-topology`'s
"everything may be a session" framing: something *becomes* session-able
the moment it carries the adapter, giving that framing an actual
mechanism instead of only a metaphor. `sessions` zenka's real spec
narrows from "orchestrate 4 known namespaces" (keys/credentials/
cred-mesh/credential_fabric) to "track and orchestrate whatever currently
holds the adapter" — smaller, and the namespace list becomes a
consequence rather than the starting scope.

## operating principle for the whole thread — generic-first, native-by-emergence

User's closing statement, ties every thread above together: everything
may be nested AND concurrent, yet always distributed; adjusting context
or sub-dividing is always a generic option/release-valve that absorbs
whatever complexity shows up, UNTIL some shape proves itself often enough
to emerge as a native primitive candidate. Native is not chosen up front
— it's what survives repeated contact with the generic mechanism. This
is the actual mechanism behind the earlier external-vs-native asymmetry
point (external sites recombine because there's no native pull there;
our own code has native pull because patterns repeat enough to earn it),
and matches two already-seeded principles with a mechanism rather than
just a metaphor:
- [[topic-multidimensional-identity-session-topology]]: "free, nested,
  non-exclusive grouping... don't collapse grouping into a strict tree
  even where a tree also exists in parallel."
- `namespace-tree-intelligence`'s (2026-05-11) model-scale note: "signal
  fires once, produces specialised tissue, tissue self-maintains without
  signal recurring" — stem-cell differentiation as the shape of
  generic-to-native promotion.

**How to apply**: do not pre-design a fixed topology/shape for
`sessions` (or the generic IO adapter, or the key-holding children) — keep
every mechanism generically composable (nestable/concurrent/subdividable)
first, and only harden a specific shape into a native/optimized primitive
once it's been observed recurring, not because it seems architecturally
tidy in advance.

## open / deferred by user

- **updated key "truth template"**: entries must carry a username (e.g.
  `'taeki'`) plus an AMOS checksum of **matching entropy** to the entry's
  own checksum. User said they'll explain with ascii-art examples later
  — do not guess at the shape before that. CONFIRMED 2026-08-13: session
  ids will be composed of AMOS checksums, BMW-L13 checksums, and
  combinations of those — at least one BMW-L13 checksum is locked in as
  part of the composition. Directory/parent structure (etc_P7/var_P7
  layout under `sessions`) remains explicitly open to restructuring —
  only the checksum-composition piece is fixed so far. Starting point
  identified: `base.p7ref.self`'s `TYPE:CHKSUM7:ADDR_B32` shape (C25519-
  pubkey-derived `ADDR_B32`, open `TYPE` vocabulary, no registry) is the
  identity-relevant P7REF scheme to extend — NOT `P7REF-STORAGE.md`'s
  `p7://checksum:...` storage-URI scheme or `base.p7refs.
  gen_template_chksum`'s live in-process Perl-ref encoding, which are
  two other, unrelated things also called "P7REF" in this codebase (see
  [[project-checksum-addressing-implementation-survey]], commissioned
  2026-08-10 specifically for users-zenka identity, same question).
  `discover.orbital.known` already keys peer entries by BMW-L13 of
  pubkey — live precedent for BMW-L13-as-identity-key one layer up.
  CONFIRMED 2026-08-13 further: nested AMOS checksums will also be part
  of the composition, "with appropriate multi-layered truth templates."
  Both terms are real existing machinery, not new: "truth template" =
  `AMOS7::TEMPLATE`'s actual mechanism (`assign_truth_templates`,
  `template_is_true`, `AMOS7::Assert::Truth::true_int`); "nested amos
  checksums" = `CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md §1`'s
  `[CHECKSUM:NAME]` pattern — `amos-chksum` of `<parent-checksum>.<name>`
  paired with the parent's own checksum, arbitrary recursive depth,
  collision-free (parent checksum is baked into child entropy), ancestry
  reconstructable without a lookup table. "Multi-layered" = one truth-
  template constraint validated per nesting layer, not one flat template
  over the whole chain. **Real gap to know about**: this works today for
  AMOS-only chains, but BMW-L13 has NO template support yet —
  `data/tasks/epoch-bmw-l13-truth-templates.md` tracks shipping
  `base.chk-sum.bmw.truth_template_L13` for parity with AMOS's
  `amos_template_chksum` (currently `base.chk-sum.bmw.calculate_L13_sum`
  has zero template support, `base.chk-sum.bmw.template_L13` handles
  only a single template, no ARRAY/CODE/Regexp, no exclusion-callback
  path) — itself layered on a prerequisite chokepoint task
  (`bmw-harmonize-l13-helper.md`), not standalone. Nested/multi-layered
  truth templates where a BMW-L13 layer is involved (confirmed as part
  of session-id composition) depend on that parity task landing first.
- exact subname axis (session-type vs per-peer-host vs per-key) not yet
  chosen — user said multidimensionality can wait for "a tree construct,"
  deferred deliberately.
- whether service-account attachment extends to protocol-7's own
  `system.amos-zenka-user` service accounts, not just OS-level
  host logins — asked, not yet answered.

## user-edit + keys — corrected scope, 2026-08-13 follow-on session

Corrected understanding (user directly corrected an under-informed answer):
`keys.*` module-safety-for-cross-zenka-loading is NOT open work — it
landed already, commit `f9c51a636` (2026-08-12), verified: `keys.*` has
zero `.cmd.` modules (pure `.console.*` + helpers, no network surface
added by loading it into a networked zenka), `Curses::UI`/`Term::Clui`
stay lazy. `user-edit` already loads `keys.*` directly (not proxied) and
has a real, landed, ascii-frame-integrated read-only key list+detail view
(`user-edit.menu.namespaces`→`.records`→`.show_key`, commit `c12351f92`,
2026-08-12) — calls `crypt.C25519.all_key_names`/`keys.checksum_href`
directly, explicitly NOT `keys.console.list` (would corrupt raw-mode
screen: baked ANSI + mid-flight autoflush).

Two known side effects of loading the FULL `keys` module set (not the
underlying library alone): `keys.init_code` overwrites
`<system.amos-zenka-user>` globally (fine for `user-edit`, which sets no
conflicting value; would clobber a zenka — like the planned `sessions`
zenka — that needs its OWN `system.amos-zenka-user`, connecting to the
per-zenka-OS-user thread earlier this session); `keys.post_init`
hard-exits the whole process on `crypt.C25519.key_vars_error` (acceptable
for a personal console, a real availability risk for anything meant to
stay up regardless of one bad key). **Per user**: use the underlying
library routines (`crypt.C25519.*`, `keys.checksum_href`-style helpers)
directly rather than loading the full `keys` module set (which pulls in
`init_code`/`post_init` and both side effects) — `user-edit`'s own code
already does exactly this.

**Scope correction, same thread**: `user-edit` does NOT need to work with
the main/permanent zenka keys yet. It CAN work with temporary keys local
to itself, held until verified and written through to the real store —
same shape as the already-established draft/outbox rule from
[[project-credential-types-into-user-edit]] ("drafts NEVER contain masked
values," a form holding a secret is never staged to the outbox at all).
`keys.console.*`'s output remains a useful REFERENCE for namespace wiring
even though it's not called directly: one key name groups
`.private`/`.secret`/`.public` under one checksum, shape-markers
(`[hostkey]`, `virtual`, `[enc-key]`) distinguish key kinds by naming
convention alone — worth copying that shape for a temporary key's own
namespace, without touching the console code or the main store.

## detach/reattach mechanism — SIGUSR1/SIGUSR2, reverse-connect socket, reused helper code

2026-08-13, same follow-on session as the `keys`/`user-edit` scope
correction above. User pointed at three existing standalone helper
scripts as direct code-reuse candidates for the key-holding-child design
(these are real, already-shipped, invoked via `popen()` from the C
clients `p-7-r.c`/`p7.c` — not design docs):

- **`bin/p7-auth-keypair-helper.pl`** — `IO::AIO::aio_mlock` on every
  sensitive buffer (long-term Ed25519 secret/private key, ephemeral
  session C25519 secret) plus `erase_buffer_secure` (double
  random-overwrite + truncate-to-zero) on exit. This is real, working
  memory-protection discipline for decrypted key material — exactly what
  the `chmod_child`-style children from earlier in this thread lack
  (chmod_child never touches secret material, only chmod ops) but a real
  key-holding child needs. Directly reusable, not a pattern to
  re-derive.
- **`bin/p7-tofu-helper.pl`** — implements the `remote-host.<host>_
  <port>.public` / `NTIME_B32:PUBKEY_B32` pin format under
  `~/.n/user-keys/` — confirms this is ONE consistent TOFU convention
  across the codebase (matches `discover.orbital.known`'s BMW-L13-of-
  pubkey keying and `keys.console.list`'s `[hostkey]` entries), not
  three separate schemes.
- **`bin/p7-link-upgrade-helper.pl`** — `gen-ephemeral`/`compute-dh`/
  `derive-key`/`encrypt`/`decrypt` as discrete, independently-invokable
  operations: a real, working DH-handshake-to-ChaCha20Poly1305-AEAD-
  channel implementation, already shaped as small stateless per-call
  operations rather than one monolithic session object — a structural
  precedent for a key-holding child's own command vocabulary (mirrors
  chmod_child's "closed, individually-validated command vocabulary,"
  applied to crypto ops instead of chmod ops).

**New design, per user**: key-holding children get a real attach/detach
control protocol, not just spawn-once-and-pipe like chmod_child:

- **`SIGUSR1` = attach, `SIGUSR2` = detach** — standard-unix signal pair
  controlling a long-lived child's active/dormant state, plus separate
  timeout and security-level settings (not yet specified in detail).
- **Reverse-connect socket direction, deliberately**: the CONSUMER zenka
  (e.g. `sessions`, or whatever needs the key) opens the listening unix
  domain socket; the key-holding child, upon `SIGUSR1`, is the one that
  connects OUT to it. This means the secret-holding process never has a
  listening/bindable surface at all — nothing can reach in uninvited, it
  can only be signaled to reach out. Stronger than the current
  chmod_child/`open2` model, where the parent at least opens the pipe.
  `SIGUSR2` drops the outbound connection, returns to dormant.
  **Open, not yet decided**: whether detach re-derives the key fresh on
  next attach (cheap, matches `cred-mesh`'s existing re-derive-from-
  `fabric.secret` pattern found during the earlier verification pass) or
  keeps it `mlock`ed and dormant (faster reattach, longer exposure
  window).
- **Authorization: "short ping, compared to a long passphrase"** — not
  literal passphrase-substring comparison; maps onto
  `p7-link-upgrade-helper.pl`'s `derive-key` step in miniature. The long
  passphrase (or a key derived from it) sets up a verifier once; each
  attach request produces a short value only derivable from that
  verifier (HMAC/truncated-hash-style challenge-response) — same
  DH-handshake-to-derived-key shape as `link-upgrade`, with a shared
  passphrase standing in for the DH-computed shared secret. The real
  passphrase is never transmitted or re-checked wholesale on every
  attach.

## refinement, 2026-08-14 — connect-on-fork, not attach-on-signal, for the first run

Per user: the `SIGUSR1`-to-attach handshake described above should NOT gate
the child's *initial* connection. Before a child has ever been detached
there is nothing to reattach to — the consumer spawned it on purpose and
already knows the connection is wanted, so paying a signal-then-
reverse-connect round trip for ordinary [non-timeout] usage is pure added
latency with no corresponding benefit. Refined shape: the consumer opens
its listening socket FIRST, forks the child with that socket path baked
in, and the child connects out immediately at fork time, already active —
no dormant-waiting-for-SIGUSR1 phase in the normal path.

`SIGUSR1`/`SIGUSR2` remain the right mechanism for every attach/detach
transition AFTER the initial fork — not narrowly "crash recovery." Per
user correction, 2026-08-14: idle-timeout detach and security-level-driven
detach (both already named in the original design) can cycle a child
dormant→active→dormant repeatedly over its life with no crash or restart
ever involved, so the signal path is not a rare fallback — it could be the
MOST exercised part of the lifecycle if timeouts are tight. Only the very
first connection, at fork time, skips the signal round trip; everything
after that — however often — still goes through SIGUSR2/SIGUSR1. The
reverse-connect *direction* (child dials out, never listens) holds
identically at fork time and on every later reattach.

## refinement, 2026-08-14 — the knock: non-replay signal sequence for attach/detach, settled shape

Per user: the `SIGUSR1`/`SIGUSR2` attach/detach signals should carry a
port-knocking-like non-replay sequence rather than being bare toggles.
Settled after back-and-forth in conversation (not written until agreed,
per the process note below):

- **What the knock actually protects — integrity/liveness, not attacker
  exclusion.** A key-holding child and its consumer (`sessions`) share a
  UID (the child drops to `$UID=$EUID=$admin_uid`, same principal
  `sessions` runs as). Anyone able to send it a signal is already that
  UID, and at that point `ptrace`/`/proc/<pid>/mem` hand them the
  decrypted key directly — a knock cannot exclude such an attacker, and
  isn't trying to. What it actually guards against: **PID reuse** (a
  detached child dies, the OS recycles the PID, a later signal reaches a
  stranger process) and **stale/duplicate signals** (a `sessions` restart
  racing a reattach, a leftover script, a double-send) — both are
  integrity/freshness problems, not secrecy problems. The real
  authorization already designed for this thread ("short ping compared
  to a long passphrase" → `p7-link-upgrade-helper.pl`'s `derive-key`
  step) runs AFTER connect, over the socket — the knock sits in front of
  it and doesn't need to carry that weight itself.
- **Real, live precedent for extracting a count from coalesced
  signals**: `modules/base.sig_NUM55` (log-prefix-width sync, see
  `data/tasks/v7-lpw-sync-debug.md`) already reads `$event->w->hints` —
  Perl's `Event::signal` combined-events count — as `$signal_count` and
  steps by that many. POSIX `SIGUSR1`/`SIGUSR2` don't queue at the OS
  level (several sends before delivery collapse into one), but the event
  library still recovers HOW MANY collapsed into that one delivery. A
  knock encoded as burst-counts (send N times fast, receiver reads
  `hints == N`) is a real, already-used technique here, not something to
  import from POSIX real-time signals.
- **But that same file documents a live, unresolved bug that's the actual
  caution**: `cube` gets `hints=7` delivered as one batch and jumps
  straight to max instead of stepping 1-at-a-time like `v7` does — the
  count that arrives depends on the relative timing of the sender's
  stagger against the receiver's event-loop drain rate, and that
  relationship isn't reliable even in this simple, already-shipped case.
  A knock design that demands an EXACT count match would inherit this
  same fragility. **Resolution**: given the knock's actual job is
  liveness/freshness, not exact-secret verification, read it with a
  tolerant/windowed count match (HOTP-style skew window) rather than
  requiring exact alignment — sidesteps the LPW bug's failure mode
  entirely, at no cost to what the knock is protecting.
- **Bandwidth note, not yet decided which is needed**: if the knock ever
  needs to carry more than a repetition count (e.g. a value fragment, not
  just presence+count), POSIX real-time signals (`SIGRTMIN..SIGRTMAX`) DO
  queue individually and can carry a small integer via `sigqueue(2)` —
  unlike `SIGUSR1`/`SIGUSR2`. Whether Perl's `Event` module exposes
  `sigqueue` here is unchecked. Likely unnecessary given the
  liveness-only scope above, but the option exists if the design grows.
- **Shared counter for computing the next expected knock without
  transmitting it**: `<[base.ntime.b32]>` is already the freshness stamp
  `crypt.C25519.create_signature_request` uses, and advances 1 harmonic
  position per real second (`4200 mod 13 = 1`, per
  [[topic-harmonic-mathematics]]) — both ends can derive "what knock is
  expected right now" from it without a round trip, same shape as a TOTP
  counter. This is a plain freshness counter, not a claim that
  division-by-13 arithmetic itself adds cryptographic strength — the
  actual unpredictability still has to come from whatever secret seeds
  the derivation (the child/consumer's shared verifier), same caveat as
  the harmonic-mathematics thread's own repeated self-discipline about
  keeping solid arithmetic separate from unproven security properties
  layered onto it. **Namespace note, per user correction**: use
  `base.ntime.*` (`epoch_timestamp`/`harmonized_epoch`/`delta_seconds`/
  `B32_2_unix` — the actual harmonic network-time counter) wherever a
  timestamp is needed for this, NOT `base.time.*` (a much smaller,
  unrelated namespace — just `is_leap_year`/`year_utc_float`, calendar
  utilities) and not raw system time. The two names look adjacent but
  are different systems; only `ntime` carries the harmonic-position
  semantics this design depends on.

**Process note**: this shape went through two premature memory writes
that the user corrected immediately after (attach-timing scope, then
"only place" framing) before landing here — settled in conversation
first this time, written once after user confirmation ("yes, sounds
good"), per advisor guidance to stop the write-then-get-corrected loop.

## closing synthesis — sessions as ramp, not destination

User's own close: the key tree (root-key contract + nested-checksum
addressing + auto-restructuring/first-seen priority, scoped explicitly
to the KEY tree) plus a real P7REF variant (per
[[project-checksum-addressing-implementation-survey]]: `base.p7ref.self`'s
`TYPE:CHKSUM7:ADDR_B32`, C25519-pubkey-derived, NOT the storage-URI or
in-process-memory P7REF variants) is "another remaining component" that,
once integrated, makes distributed applications with low latency, high
redundancy, and a permanent trust structure "instantly possible." Low
latency has its own already-seeded thread:
[[topic-latency-algorithmic-authority-entropy-toll]] — latency as a
third algorithmic authority alongside keys/checksums, self-organizing
grid placement.

**`sessions` zenka's actual role, per user**: a ramp toward that future,
not the destination — and should be "soon feature-present" rather than a
long design project, BECAUSE almost everything it needs already exists
scattered across the codebase (root-key contract via
`crypt.C25519.create_signature_request` + `PRIVACY-PRESERVING-IDENTITY-
CREDENTIALS.md`'s parent/child signed-key hierarchy, nested-checksum
addressing via plain `amos-chksum` chaining, the fallback-YAML hybrid via
`users.record.optional_fields`, chmod_child-style minimal children,
cross-host sync via `users.remote`/`transport` profiles, P7REF identity
via `base.p7ref.self`) — `sessions` is where these get exercised together
for the first time, against a real target (the uninstalled fanless
desktop's `taeki`/`root` accounts), not where any of them get invented.

## LANDED, 2026-08-14 — first key-holding child built and verified live; the
## knock design from earlier in this file did NOT survive contact with a
## real implementation

Uncommitted, working tree only (`modules/sessions.holder.*`,
`sessions.util.holder.*`, `sessions.cmd.*`, `base.buffer.erase_secure`,
plus `configuration/zenki/sessions/start` gaining the command list). Built
against a plan file, then debugged live for a long stretch — the section
below is what actually survived, not what was designed on paper.

**What works, live-verified**: `sessions.cmd.spawn` forks a child (real
distinct pid, confirmed via `ps -o ppid`, not just a thread), which dials
out to a parent-opened unix listener immediately at fork time (connect-
on-fork, no signal wait for the first connection — that part of the
original design held). `IO::AIO::aio_mlock` on a 32-byte test key,
confirmed via `VmLck` in `/proc/<pid>/status`. `sessions.cmd.encrypt`/
`.decrypt` round-trip through the live child (ChaCha20Poly1305, key held
in the child, never touches the parent). `sessions.cmd.detach` closes the
control socket (EOF-driven), the child survives — confirmed alive
afterward, unlike `cred-mesh.key_holder`'s always-refork model.
`sessions.cmd.attach` sends `SIGUSR1`, child wakes and redials the SAME
socket path, SAME pid, SAME mlock'd key — verified by decrypting a blob
encrypted BEFORE detach using the key held AFTER reattach, and by a fresh
encrypt/decrypt round trip post-reattach. `sessions.cmd.stop` sends
`SIGTERM`, child's own handler calls `base.buffer.erase_secure`
(extracted from `bin/p7-auth-keypair-helper.pl`'s script-local
`erase_buffer_secure` — now shared, `<[base.buffer.erase_secure]>->
(\$buffer)`) and exits; confirmed the child process actually disappears.

**What did NOT survive, and why — three real bugs, not one**:

1. **`base.event.add_signal` doesn't lazy-load its handler.** It checks
   `exists $code{$handler}` on a plain runtime string — P7's on-demand
   module loader only triggers on a literal `<[module.name]>` macro
   occurrence at compile time, never on a module name passed as data.
   Registering a signal handler by name-as-string silently failed
   ("nonexistent callback"), leaving the signal at its OS-default
   (terminate) disposition — the child was killed outright by its own
   detach signal. Confirmed by directly reading `base.event.add_signal`'s
   source, not inferred. **General lesson**: anything that takes a P7
   module name as a runtime value (not literal macro syntax) needs an
   explicit priming `<[module.name]>;` call first to force compilation,
   or it will not be `exists $code{...}` when something else checks for
   it later.
2. **A forked child inheriting a live `Event.pm` loop is unsafe** — the
   fork also inherits the PARENT's entire Event.pm internal state (its
   polling fd, existing watchers on the parent's own cube connection,
   etc). Calling `Event::loop()` in the child saw that inherited,
   unrelated state and returned IMMEDIATELY with no signal ever having
   arrived — confirmed by directly capturing `waitpid`'s `$?` before
   `base.sig_chld`'s own automatic reaper could race for it: exit status
   0, a clean voluntary exit, not a crash. This is exactly why
   `cred-mesh.key_holder.child` (the precedent this design was built
   from) deliberately uses NO Event.pm in its child at all — that was a
   correctness requirement, not a style choice, and this design initially
   missed it. **Fixed by matching cred-mesh exactly**: plain `%SIG{USR1,
   USR2}` closures + `POSIX::pause()` for the dormant wait, zero Event.pm
   involvement in the child. Perl's own deferred-signal-safety handles a
   plain `%SIG` handler correctly even mid-blocking-syscall (confirmed
   live and via an isolated reproduction script), which is what makes the
   ATTACHED state's plain `<$sock>` readline safe to interrupt.
3. **The ntime-bucket knock-count matching from this file's earlier
   "settled" design does not work.** `base.ntime` carries per-process
   harmonization/retry state (`$data{'base'}{'retry-count'}{'ntime'}`
   etc.) — it is not a deterministic function of wall-clock time two
   processes can compute independently and expect to agree on a fraction
   of a second apart. A freshly-forked child and its parent computed
   different bucket values immediately after fork, not after any real
   drift. **This directly contradicts the earlier "2026-08-14 refinement"
   section above** (`base.ntime` as a shared TOTP-style counter) — that
   section's assumption doesn't hold and should not be reused elsewhere
   without first confirming `base.ntime` is actually stable across
   processes for whatever new purpose is being considered.

**Net effect on the knock design**: the whole `NUM56`-counted-knock
mechanism from earlier in this file (realtime signal, `hints`-based
count, tolerant window) was cut entirely, not just simplified. What
shipped is a plain `SIGUSR1`/`SIGUSR2` pair — presence-only, no count, no
cross-process clock agreement. `SIGUSR2` is now pure after-the-fact
corroboration logging with zero effect on state (EOF is the sole
authority for the detach transition); `SIGUSR1` is the sole real actor,
safe because the child is genuinely parked in a signal-only wait
(`pause()`) with nothing else competing for signal delivery. The
integrity/liveness framing from the connect-on-fork/knock discussion
earlier in this file (PID-reuse detection, stale-signal rejection) is
NOT implemented by this — it's a real gap, not a solved-and-simplified
problem, if that property is ever actually needed. A future revision
wanting it back should design it against a verified-stable freshness
source, not `base.ntime`, and should not reintroduce Event.pm into the
child under any circumstances.

**Also cut, not yet extracted**: `bin/p7-auth-keypair-helper.pl`'s script-
local `erase_buffer_secure` was NOT switched to call the new shared
`base.buffer.erase_secure` — that script runs standalone via `popen()`
from C, outside any zenka process, so it cannot reach `<[module.name]>`
syntax at all. The shared module exists for `sessions`' own use and any
future P7-module-side caller; the standalone script keeps its own copy.

**Debugging method worth repeating**: black-box `p7c`-level testing
repeatedly gave misleading signal (stale/orphaned zenka instances still
registered with cube after `v7.restart`/`v7.stop` — confirmed via `ps -o
pid,ppid` cross-checking against `list subnames`; `p7c term-all <sid>`
was the reliable way to force a clean instance when `v7.restart`/`v7.stop`
left stale registrations, a pre-existing v7 lifecycle gap unrelated to
this work). The turning point was capturing `waitpid`'s raw `$?` directly
in the code path under test, before the framework's own automatic
`SIGCHLD` reaper (`base.sig_chld`, wired via `install_signal_handlers`'s
`chld` entry) could reap the child first and erase the evidence — inferring
cause of death from log silence alone produced two wrong theories in a
row.

The knock-mechanism design history earlier in this file (realtime signal,
`hints`-based count, ntime-bucket matching) predates this landing and is
kept for the record of how the design got here, not as a description of
the current implementation.

## LANDED, 2026-08-14 (later) — step A: real C25519/Ed25519 identity key,
## replacing the throwaway symmetric test key

Per user, approved as "A + B, in the order you suggested": A (this) swaps
the placeholder ChaCha20Poly1305 test key for a real identity key + a real
SIGN op; B (separate, not started) wires `user-edit` to route its own key
handling through this mechanism.

**A second real Event.pm-in-forked-child hazard found and avoided, same
family as the first**: `crypt.C25519.gen_keys` — the obvious "just call
the existing keypair generator" choice — is itself unsafe to call inside
the child. Confirmed by direct read (`modules/crypt.C25519.gen_keys:9,74,
78-79`): its harmonic-truth-checked key-search loop is hardcoded to run at
least once, and that loop's first statement is `<[event.once]>->(0.007)`
→ `Event::loop()`. Resolution: the child calls the bare `Crypt::Ed25519::
generate_keypair()`/`::sign()` primitives directly — exactly what
`gen_keys`/`crypt.C25519.sign_data` do internally, just without their
`%keys`-hash bookkeeping and (critically) without `gen_keys`'s
Event.pm-touching loop. **General lesson, extends the earlier finding**:
"does this touch Event.pm" needs checking transitively, not just at the
call site — a plain-looking library wrapper one level down can still pull
Event.pm in.

**`crypt.C25519.verify_key_signature` (the obvious "verify" choice)
doesn't fit arbitrary-data verification** — confirmed by direct read
(`modules/crypt.C25519.verify_key_signature:52`), it hard-requires the
signed payload be exactly 32 bytes because it verifies a signed PUBLIC
KEY specifically (the key-trust-chain use case), not arbitrary signed
data. `crypt.C25519.verify_sign` verifies arbitrary data but requires the
caller's own `%keys` to already hold the signer's pubkey — not stateless
either. Used the bare `Crypt::Ed25519::verify()` primitive directly for
external verification instead — no existing wrapper fit a stateless
arbitrary-data check.

**`crypt.C25519` added to `sessions`'s `modules.load`** (needed for
`Crypt::Ed25519` itself plus `crypt.C25519.key_bin_checksums` display
formatting) with `crypt.C25519.auto_load_keys = 0` set before
`[init_modules]` to keep its own auto-load/auto-create machinery fully
inert — confirmed via direct read of `crypt.C25519.post_init:20`
(`if (not <crypt.C25519.auto_load_keys> //= TRUE) { ...skip...; return
FALSE }`) that `0`, not the literal word `FALSE`, is what actually
disables it; config files here use plain `0`/`1`, not `TRUE`/`FALSE`
tokens. **Still deliberately NOT loading the full `keys` zenka family** —
`keys.init_code:17` unconditionally clobbers `<system.amos-zenka-user>`,
and `sessions/start` depends on that exact value for
`[root.drop_privs:...]` immediately after `[init_modules]`.

**Storage**: renamed `holder-test.secret` → `holder-identity.secret`,
same `/var/protocol-7/sessions/` mechanism (confirmed structurally
separate from `keys`'s `~/.n/user-keys/` — different root, different
per-zenka-vs-per-OS-user scheme, no collision risk). The 32-byte C25519
secret seed persists there; the Ed25519 keypair is re-derived from it on
every fork (cheap, deterministic), matching `crypt.C25519.gen_keys`'s own
convention of storing the seed rather than the derived keypair.

**Verified live, full chain**: distinct child pid (`ps -o pid,ppid`);
`VmLck: 8kB` (two mlock'd regions, 64B private + 32B secret, each
page-rounded); `sessions.cmd.pubkey`/`sessions.cmd.sign` round-trip;
signature verified via a STANDALONE `perl -MCrypt::Ed25519` one-liner
outside any `sessions` module, using only the returned pubkey + signed
string + signature (never touching the held private key) — `TRUE`;
detach → attach → same pid, same pubkey, a signature made AFTER reattach
verifies against the pubkey captured BEFORE detach (no re-derivation);
`stop` → child pid actually gone; **full zenka restart** (fresh main
process, `p7c term-all <sid>` used to force a clean instance per
[[feedback-v7-restart-stop-stale-zenka-registration]]) → fresh spawn →
IDENTICAL pubkey recovered from the persisted seed file — proves
persistence, not just in-process continuity.

Removed: `sessions.holder.op.encrypt`/`.op.decrypt`,
`sessions.cmd.encrypt`/`.decrypt` (the symmetric test key and the new
C25519 identity are two unrelated key types with no reason to coexist —
"swap the test key for a real one" read as replacement, not addition).
`sessions.holder.parent`/`.attach`/`.detach`,
`sessions.util.holder.start_child`/`.accept_with_timeout`,
`sessions.cmd.spawn`/`.detach`/`.attach`/`.stop`,
`base.buffer.erase_secure` — all untouched, none reference key material
directly; the lifecycle plumbing from the first landing carries over
unchanged.

## LANDED, 2026-08-14 (later still) — step B: named secret-holder +
## user-edit cross-zenka round trip, proven with synthetic values

Per user, chose "extend sessions + prove it with a synthetic value" over
the two other offered scopes (sessions-only, or building the secret-
entry widget first). Explicitly NOT the masked-field secret-ENTRY
mechanism — that's still unbuilt (see next paragraph) and stays a
separate, later problem; this only proves the holding/routing mechanism.

**Deliberate design choice, not a retrofit**: the identity holder
(`sessions.holder.*`, step A) was left completely untouched. A SECOND,
parallel module family (`sessions.secret.*`/`sessions.util.secret.*`)
holds arbitrary caller-supplied secrets, keyed by name in
`<sessions.secrets>->{$name}` (hash-of-hashes, live-process-only, never
persisted — unlike the identity holder's persisted seed, a temporary
secret must not survive a restart). Real precedent for the keyed-state
idiom: `cred-mesh.register`'s `<cred-mesh.registry>->{$slot}` pattern
(its YAML-persistence step deliberately NOT copied). No detach/attach
for named secrets — the identity holder's dormancy exists to preserve
*expensive derived* key state across a restart; a handed-back-once
caller secret has nothing worth preserving that way. One hold, one
release, child exits.

**Real correction caught before writing any network-facing code, not
live**: the draft plan assumed `sessions.cmd.hold`/`.release` would use
`mode=>'false'` for errors, mirroring `users.cmd.value-get`. Checked
directly against every `sessions.cmd.*` file actually shipped in this
build — they ALL use `mode=>'size'` uniformly for success AND failure,
signaling failure via a `"<< ... >>\n"`-phrased data string. Fixed
before implementation: `hold`/`release` follow that established
`sessions`-specific convention, and `user-edit`'s reply handlers check
the `data` string's `<<` prefix, not `cmd`/mode.

**Cross-zenka call pattern, verified against real working code, not
assumed**: `user-edit.console.show-form` + `user-edit.handler.
value_get_reply` (read in full) confirmed the exact reply contract
(`($info)` with `cmd`/`call_args`/`data`, SIZE mode carries payload in
`data`) and — the piece this design depends on — that firing a SECOND
`protocol-7.command.send.local` from INSIDE a reply handler, while still
in the event loop, is real proven code already running live in
`user-edit` (not a pattern being invented here). `user-edit.handler.
secret_hold_reply` chains straight into a RELEASE call the same way.

**Verified live, first try, no debugging needed this time** — the prior
two builds each needed multiple live-crash-driven fix cycles; this one
worked on the first real test:
- `v7.user-edit test-secret-roundtrip` → both synthetic cases (32 random
  bytes; a pathological string starting with the literal `OK ` prefix
  and containing embedded NUL/newline/space/0xFF, specifically chosen to
  probe the child's own line-framing) came back byte-identical,
  confirmed via printed hexdumps on both ends, not just a boolean.
- `sessions.pubkey` captured before and after the whole round trip —
  byte-identical, confirming the identity holder was genuinely never
  touched by the new code path.
- Manual `p7c sessions.hold`/`.secrets`/`.release` cycle: distinct child
  pid (parent lineage confirmed via `ps -o pid,ppid`), `VmLck: 4kB`
  (mlock confirmed on the 27-byte test value), `sessions.secrets` showed
  the entry during hold and correctly showed "no secrets held" plus a
  confirmed-gone child pid immediately after release.
- Deliberately did NOT test full-zenka-restart persistence — named
  secrets are explicitly non-persistent by design, so that would be
  testing correct behavior as if it were a bug.

**Accepted, stated limitation, not silently ignored**: the secret sits
as an ordinary non-mlock'd Perl SV in the `sessions` parent process's
own heap between arriving over the network (already base32-encoded) and
the `fork()` call in `sessions.util.secret.start_child` — `decode_b32r`
happens immediately before fork, `base.buffer.erase_secure` immediately
after (parent branch only; the child has its own COW'd copy from
`fork()` itself). This window is real and NOT mitigated — full pre-fork
mlock would need plumbing a locked buffer through the whole call-arg
pipeline, more invasive than this routing proof needed. Worth
addressing before routing anything more sensitive than a synthetic test
value through this path.

**CORRECTED same session, before any code was written**: the paragraph
above overstated the gap. Direct trace of `user-edit.handler.stdin_key`
→ `editor.input.next_key` → `editor.control.process_key` showed typing
into a masked field already worked perfectly — no field-type branching
exists anywhere in that path, `editor.control.create` treats `masked`
identically to `freeform_line` for the BUFFER (only `get_display_value`
differs, already giving correct-length live star-echo). The REAL gap
was narrower: no field was ever DECLARED `masked` (the add-field cycler
hardcoded `freeform_line`/`line`-or-`list` shape only), and submit sent
everything to `users.value-set` unconditionally, so a masked value had
nowhere safe to go. Both closed below.

## LANDED, 2026-08-14 (final this session) — step C: one real masked
## field, declared/offered/typed/submitted, routed to sessions.hold

Per user: "no worse than `AMOS7::TERM`'s password entry" was the quality
bar. Retype-to-confirm was explicitly decided AGAINST (user's call): the
form's in-place editing already shows length and allows correction,
which a blind terminal prompt can't, so the extra blind-confirmation
step retype-to-confirm exists to compensate for would be friction
without a matching safety gain here. That part of the parity check
holds.

**CORRECTED, same session, before this landed**: the star-echo/edit-key
parity claim did NOT hold, and was wrong to assert — checked properly
only after the user pushed back. `AMOS7::TERM::show_rnd_stars`/
`del_rnd_stars` (`data/lib-path/pm/AMOS7/TERM.pm:918-943`) print a
RANDOM 1–3 stars per real keystroke, at randomized inter-star delay
(`Time::HiRes::sleep rand(0.13/$rnd_keys)`) — defeating BOTH length
inference AND keystroke-timing analysis, two separate side-channels.
`@rnd_count` is a per-keystroke stack of "how many stars were shown for
this character," popped exactly on backspace so the display stays
consistent despite the non-1:1 ratio — that's what "tracking it for
corrections" meant. **A third property, also missed initially**:
`timeout_stars()` (`AMOS7/TERM.pm:945-954`) — when the read loop's
`$abort_mode eq 'timeout'` (no keystroke within the read-timeout
window), it pops the ENTIRE `@rnd_count` stack, erasing every displayed
star, with `$rewind_delay` starting at 0.777s and shrinking ×0.84 per
step — a visibly accelerating "trailing off" erase, not an instant
wipe. A partially-typed password left on screen while the user walks
away self-clears rather than sitting there. `editor.control.get_
display_value`'s masked rendering (`'*' x length($value)`, unchanged by
this landing) has NONE of these three properties — exact length leak,
no timing obfuscation, and a masked field left mid-edit in a running
form stays fully visible (as `*`s, but exact-length ones) indefinitely,
with no idle-timeout self-clear. A real regression relative to
`AMOS7::TERM`, not parity. **Not backported in this pass** —
`AMOS7::TERM`'s stack model is linear (backspace-from-the-end only, no
mid-string cursor); `editor.control`'s buffer supports arbitrary cursor
position/insert/delete-in-the-middle, so a direct port doesn't
generalize — it would need its own design (e.g. a random star-run
re-derived per edit, keyed by buffer position, not a linear push/pop
stack; and its own idle-timeout hook, distinct from anything currently
in `editor.control`/`user-edit`'s redraw-on-dirty model). Flagged as a
real, not-yet-scoped follow-up, not solved here.

**One real field**: `host_password` (`users.record.optional_fields`,
sentinel `\''` — a SCALAR ref, third shape alongside `ARRAY`→list and
plain-string→line, `ref()`-keyed same as the existing two).
`users.cmd.field-options` and `user-edit.form.parse_field_options` both
extended for the 3-way shape; the latter was a REQUIRED fix found by
direct read, not in the original framing — it silently drops any shape
token it doesn't recognize, so `host_password` would never have reached
the client's vocabulary without it.

**Submit split**: `user-edit.form.submit`'s `$values` used to carry a
masked field's plaintext straight into the `users.value-set` JSON
payload — now pulled out (`%secret_values`) before anything downstream
sees it, one `sessions.hold` call per masked field, keyed
`user-edit-<user>-<field>` (hyphens — dots fail `sessions.cmd.hold`'s
`^[\w\-]+$`, and username is only guarded against `/`/`\` upstream, not
`\w`-safety, so a new pre-submit guard checks the username itself
before `editor.control.submit` runs — refusing after that point would
destroy what the user just typed, same reasoning as the pre-existing
offline guard right above it).

**Fan-in, genuinely new, no exact precedent found**: a submit can now
have MULTIPLE outstanding cross-zenka replies in flight (one
`users.value-set` + N `sessions.hold`) that must all land before the
form can report a combined result and quit. `<user-edit.form.
submit_pending>` (mutable keyword-slot hash, matching this codebase's
existing style) tracks a pending-count, decremented by each of two new
per-leg reporter modules, `submit_maybe_finish` firing the combined
message and clearing the slot only once `pending` hits zero — cleared
BEFORE quitting so a late/duplicate reply is a harmless no-op. Guarded
against the send call itself failing (`base.protocol-7.command.
send.local`'s own comment marks its timeout handler unimplemented —
without an explicit `<=0` check on the return value, a failed send
would leave `pending` stuck forever and the form silently hangs after
reset). Left undef on every non-masked submit — the ordinary single-
reply path in `value_set_reply` is untouched, guarded behind `if (ref
<user-edit.form.submit_pending> eq 'HASH')` at the top.

**Collision, deliberately not auto-resolved**: `sessions.util.secret.
start_child` isn't idempotent (refuses if the name is already held) — a
second submit of the same field collides on the deterministic hold
name. Chose NOT to pre-emptively release-then-hold (would pull a
possibly-still-wanted secret back into `user-edit` just to discard it,
destroying data on behalf of an unwritten downstream consumer) — the
collision is reported plainly instead ("NOT held -- retype it").
Verified live: the pre-existing held value survived completely
untouched across a second, failed submit attempt.

**Verified live, full chain, first try**: cycler → `host_password` →
`[Enter]` materializes it → typed a real value via the network-driven
`char-add` test surface (`<sid>.char-add`, NOT `<sid>.user-edit.char-
add` — routing-by-name gotcha re-confirmed, `client not present`) →
live star-echo of correct length → `[Enter]` submits → combined message
`"saved : user '...' stored\n  host_password : held"` → `sessions.
secrets` shows the exact expected hold-name → `sessions.release` +
`decode_b32r` gives back the EXACT typed bytes, byte-for-byte → the
record's `details.yaml`, read directly, shows `fields: {}` — the secret
never touched permanent storage in any form. Collision path
independently verified: pre-held value survives a second submit
attempt untouched, reported plainly, no hang.

**Still open, unchanged from before**: the real long-term destination
for a held secret (credentials/cred-mesh integration) — this step is
explicitly staging, not permanent storage, `sessions.hold` doesn't
persist by design. Nobody currently calls `sessions.release` except a
human at the console; there's no automatic "credential now permanently
saved" consumer yet. That's the next real gap, not typing (proven) or
routing (proven) — where the held secret goes from here.

[[project-users-zenka-unblocks-cross-host-testing]]
[[project-keys-zenka-integration-direction]]
[[project-credential-types-into-user-edit]]
[[topic-subname-not-a-trust-domain]]
[[topic-multidimensional-identity-session-topology]]

#,,,,,,,.,..,,,,,,.,,,...,.,.,.,.,.,,,,.,,.,,,.,.,...,...,,,,,.,,,.,,,.,,,,,.,
#HEUAMWYYTFCF57OFA57NTT5W3G6JOJJSQWOKRCLNLY7X46AXKN32BRFRWMRNJTMHXIS426D7TN6DK
#\\\|YVLNACKHQF7IJHM6S4NAR4HXXO4NRUCAKKBWMNMIDJL4TRJBXRM \ / AMOS7 \ YOURUM ::
#\[7]S3NPBC3WUZVE3JUZPHAOWQH2TAOZXJOUUFDTFYWOMPC2IZAJVKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
