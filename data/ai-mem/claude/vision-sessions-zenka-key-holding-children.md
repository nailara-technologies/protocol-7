---
name: vision-sessions-zenka-key-holding-children
description: "2026-08-13 design thread: sessions zenka (v7-managed, clones users' etc_P7+var_P7 pattern) as cross-cutting session orchestrator over keys/credentials/cred-mesh/credential_fabric/users; spawns chmod_child-style minimal per-key child processes as the actual trust boundary, resolving subname-not-a-trust-domain"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3d67d3e5-c27e-4366-b904-c135559a9394
  modified: 2026-08-13T17:09:49.444Z
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

[[project-users-zenka-unblocks-cross-host-testing]]
[[project-keys-zenka-integration-direction]]
[[project-credential-types-into-user-edit]]
[[topic-subname-not-a-trust-domain]]
[[topic-multidimensional-identity-session-topology]]

#,,,.,,,.,,,.,.,,,..,,...,.,.,,..,,.,,.,.,,,,,.,.,...,...,...,,,.,..,,.,,,,.,,
#KCZRD6HSAIFRNSRYXQDUPYIELEO4R7DXOI2UKDIC6B5FVYWKHRECWED2OYVWBWSHT2ZYHVR2KZQFC
#\\\|JNO4SVVZWWNUYSS7R7VTR64SU47MZFXISM7I7LQIUVG35QY3TEU \ / AMOS7 \ YOURUM ::
#\[7]TQCYPGGHIQHVOX27VAE6S7WCVQKJJL6AJISAYFCB5BDAJK2PLUDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
