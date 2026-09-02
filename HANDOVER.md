# Session Handover — 2026-09-02

## Completed This Session

### v7 -> v7-zenki: full identity rename (the bulk of the session)
Renamed the `v7` management zenka to `v7-zenki` across `src/` (158
`git mv`d files), `cfg/` (including the `cfg/zenki/v7` ->
`cfg/zenki/v7-zenki` directory move), and `bin/Protocol-7` itself —
data-key sugar, code-sugar, quote-word/string identity comparisons,
config keys, the `cfg/zenki/cube/access.zenki` auth-identity key
(`access.cmd.usr.v7` -> `access.cmd.usr.v7-zenki`, a real gap: this is
what cube checks against the connecting zenka's own session username,
so leaving it as `v7` would have denied v7-zenki's own heartbeat/
session-key traffic post-restart), and a runtime temp-path
(`/var/run/.7/v7/tmp_paths` -> `.../v7-zenki/tmp_paths`).

Domain name `v7.ax` (real, user-owned) and the `zenka.v7` file-
extension convention were deliberately left untouched throughout —
recurring false-positive class, checked every pass.

Live-restart-verified multiple times, including a full
`base.cmd.reload` on the running instance with zero errors.

Commits: `23a0e8d53` (main rename), `3f1d6b40f` (follow-up: `bin/`
tooling cleanup across ~35 files in `bin/dev`, `bin/admin`,
`bin/test-scripts`, plus two things the main rename's sweep missed —
see below). Both pushed.

### Zenka-name resolution now follows the symlink chain (todo `MPV`, done)
`bin/Protocol-7` used to pattern-match only the single directly-
invoked name (`$PROGRAM_NAME`). It now walks the actual filesystem
symlink chain (`$FindBin::Bin/$FindBin::Script`, verified to compile
before `PATH` gets clobbered by security hardening) until it hits a
recognized terminal segment (`p7-<zenka>` / `v7.<zenka>` /
`Protocol-7.<zenka>`, basename-only — fixes a real over-greedy bug
where a nested path like `.../v7.tools/bin/foo` could wrongly resolve
to `tools`). Intermediate link names collected along the way surface
as launcher context (`<system.start.launcher_chain>` etc.) for the
zenka the chain terminates at, instead of being discarded — this is
the parameter-propagation primitive `install_workflow_shortcuts`'
disabled fourth symlink form (`p7.<shorthand>`) was blocked on; not
yet wired up, see Open Items.

Also fixed a real pre-existing bug found along the way: the lib-path
`readlink` walk in `p7_security_hardening` never resolved *relative*
symlink targets, so any relative-target chain aborted at boot before
resolution even ran.

New registry modules under `path-template.*`
(`base.path-template.zenka-name-from-link`, `.zenka-symlink-chain`,
`.zenka-symlink`) as thin delegators — the real implementation has to
stay inline in `bin/Protocol-7` since it runs before
`base.path-template.pre_init`'s own boot-time namespace swap is live;
documented as a deliberate tradeoff, not an oversight.

Design doc: `data/md/design/ZENKA-SYMLINK-CHAIN-RESOLUTION.md`.

Note for later: this `path-template.*` namespace is *also* where the
planned Unix-domain-socket directory structure for the multi-zenki
setup is meant to live (AMOS+BMW-checksum-based nested directories,
per the user directly, not yet designed) — future work here should
stay coherent with that, not just this session's symlink-chain need.

### bin/Protocol-7 purge-exclusion-list fix
The `p7_purge_code` reload-purge-exclusion list (protects a narrow
window inside `base.cmd.reload` only — everything's back once reload
completes regardless, log buffers are async and just queue through
the gap) had two stale `qw| v7.foo.bar |` entries the earlier sweep's
regex missed (extra internal padding broke the pattern). Investigated
both via `git log -S` before touching:
- `v7.handler.zenka_output` — removed entirely, confirmed dead
  regardless of rename: the containing `if` already excludes any
  `.handler.`/`.callback.`-matching name earlier in the same
  condition, so this entry could never have mattered.
- `v7-zenki.stdout_log.write` — restored after confirming via history
  it was added in the exact commit that introduced the feature it
  protects (2026-02-27, stdout-log-redirection). Keep until the whole
  exclusion-list mechanism is replaced by the planned version-aware
  code loader with parallel `%code` sub-hashes (user's own framing —
  the list is names-only and won't grow unboundedly meanwhile; other
  zenki simply never load these subs so the entries are inert no-ops
  for them).

### README.md + targeted data/md/ docs catchup
`read-me/md/README.md` had drifted significantly — one genuinely dead
link, stale command examples/output tables, a wrong claim about what
`p7c commands` outputs, drifted file-count claims, and the `p7-*`
symlink prefix (landed a separate session ago) was undocumented
anywhere, so `p7-nshell` would have appeared from nowhere. Fixed, plus
5 operational `data/md/` docs (notably `P7-LLM-REFERENCE.md`, an
LLM-facing command cheat sheet — every `v7.*` there was live-wrong
until now).

**Flagged, not fixed**: `/usr/local/bin/p7` is dead (a stub, prints a
rename notice, exits 311) but still referenced as a live command in
~17 places across `data/md/`/`read-me/` — an older, separate rename
campaign, unrelated to this session. Worth a future pass.

### zenki sandbox: root-independent front-door + start relay (todo cluster, prototype phase)
Built on the previously-unused `zenki` zenka as a deliberate low-blast-
radius sandbox (not `v7-zenki` itself) for a "hybrid" start-up pattern:
same zenka runnable either `v7-zenki`-managed (resident, root-dropped)
or directly by a plain user/LLM from the shell (root-independent,
one-shot). Recovered the zenka's real original intent from its own
2025-11-11 git history: a transparent front-door — `Protocol-7 zenki
start <name>` — that bootstraps `v7-zenki` if needed and relays the
start request over cube IPC.

Fixed 5 real bugs found along the way: `zenki.parent.check_running`
never matched `bin/Protocol-7`'s actual `$PROGRAM_NAME` rewrite form
(so `ensure_v7` always reported "not running"); `ensure_v7` still
invoked the pre-rename `v7` binary name; `start_via_v7`'s IPC call used
a nonexistent sub name (`protocol-7.command.route-send` instead of
`protocol-7.route-send`); its `inside_v7` probe checked the wrong sub
name; `v7_start_reply`'s handler used the wrong reply-signature
contract entirely (single hashref, not `($route_id, $params)`).

Also built genuine on-demand module loading — only `zenki`'s own
domain module loads up front; `zenki.parent.select-modules` loads the
rest based on which console command was actually invoked, using
*existing* `base.load_modules`/`base.init_modules` primitives (no new
loader needed). Measured real latency wins for local-only commands
(~2.0-2.3s -> ~1.3-1.6s); `start` itself is a wash since it needs the
full network stack regardless — reported honestly, not oversold.

Access grant is deliberately narrow: `access.cmd.usr.zenki =
v7-zenki.start` only. Found and recorded (not fixed, pre-existing,
shared by every other `:unix:`-hybrid zenka) that `plugin.auth.unix`
never actually compares the connecting peer against the resolved
allowed-user list — with a `:unix:` auth clause present, any local
unix user can currently claim the identity. Written forward-compatibly
so it self-corrects once that plugin bug is fixed elsewhere.

**Real gap found, deliberately left open** (touches `v7-zenki`/shared
`base.*`, out of sandbox scope): no `start.cfg` key distinguishes a
managed (resident) zenka from a console-only one — not even for
`zenki` itself anymore, now that its own loop moved out of the start
file. Asking `v7-zenki` to "start" a console-only zenka (`work`,
`session`) still triggers a pointless dump-then-restart-loop-until-
give-up. Three candidate fixes recorded in
`data/md/design/ZENKA-HYBRID-STARTUP-DISPATCH.md` (a declared
`zenka.managed` key; `base.call.console_command` declining to dump the
full listing in managed/stdin mode with no command given; converting
the console-only zenki to the hybrid shape, the likely real end
state).

Design doc: `data/md/design/ZENKA-HYBRID-STARTUP-DISPATCH.md`. Reusable
pattern captured separately:
`data/ai-mem/claude/reference-zenka-callback-wrapper-prototype-pattern.md`
— wire a single callback sub for any conditional start-up logic
(`zenka.v7` itself has no native conditionals), prove it on a
low-blast-radius sandbox zenka, transplant into the real target later.

Live-verified: relay confirmed via `weather`/`tile`/`ncode`/`git`/
`fetch-files`/`image2html`; resident restart clean afterward,
`zenki.heart` beating, no loop. Commit `ad956074e`, pushed.

## Known Infra Gotchas Found This Session

- **Don't preempt the pre-commit hook's version-mismatch gate by
  running `bin/dev/update-version` yourself** — if the version was
  already bumped through the user's own flow, this just forces a
  redundant second signing pass. If a commit attempt blocks on it,
  report and wait; the hook's own retry (once the user's tooling has
  actually bumped + signed) is what unblocks it, not you running the
  suggested fix-it command preemptively.
  `data/ai-mem/claude/feedback-dont-preempt-version-bump-before-commit.md`.
- **`bin/ncode`'s `bin`/`dev`/`admin` targets have incomplete
  coverage** — several genuine `v7`-reference hits fell outside all
  three targets' scope this session (confirmed by repeated manual
  sweeps with varying regex boundaries until one came back clean).
  Don't trust a single ncode-target pass as exhaustive for `bin/`.
- **Padded `qw| word |` literals with internal multi-space alignment
  defeat a plain `qw\| *word *\|` regex** — `bin/Protocol-7` has many
  hand-column-aligned `qw| v7.foo.bar       |`-style lists; a tight
  single-word pattern misses these. `bin/format-code` does not
  maintain this alignment — it's manual/length-based, the user
  reformats by hand after a content edit changes a token's length.

## Open Items — Not Started / Not Finished

1. ~~**`install_workflow_shortcuts`'s disabled 4th symlink form**~~ —
   DONE, live-verified: wired up as ordinary `p7.<shorthand>` ->
   `p7-<zenka>` chains (not a fourth recognized form), table in
   `src/base.path-template.console-shorthand`, expansion in
   `src/base.call.console_command`; decision recorded in
   `ZENKA-SYMLINK-CHAIN-RESOLUTION.md`. Confirmed live: `p7.wo` ->
   `p7-work` resolves and runs correctly, all 7 shortcuts installed.
   Commit `6089e8434`.
2. **`p7-`-prefixed zenka names are ambiguous** (`p7-log` resolves to
   `log`) — pre-existing, not a regression, now documented in
   `ZENKA-SYMLINK-CHAIN-RESOLUTION.md`, not fixed.
3. **~17 dead-`p7`-command references** across `data/md/`/`read-me/`
   docs (see above) — separate older rename campaign, not this
   session's scope.
4. **`v7-lpw-sync-debug.md`, `v7-stdout-foldable-relay.md`,
   `v7-console-log-filter-overlay.md`, `v7-console-per-zenka-tree-view.md`**
   (in `data/tasks/`) — pre-scoped, already-planned task cluster for
   the Unix-domain-socket / detach-reattach console-relay direction
   the user described this session. `v7-stdout-foldable-relay` is the
   dependency root (implements `STDIO-RELAY-FOLD-APPLICATION.md`'s
   foldable-stream primitives); the two console-view tasks depend on
   it. All four need a naming check against the `v7-zenki` rename
   before dispatch — written before this session, likely still say
   `v7.*`. Good candidate for the next full-budget Opus dispatch.
5. **`LYE`** (multi-cube architecture design) — vision-level, not
   started, needs a full time budget, not a squeezed-in dispatch.
6. **`QP3`** (nshell -> cmd-term rename) — still queued, untouched.
7. **`v7-zenki.tmp-paths.global.clean-up` logs duplicate identical
   warnings on a no-root run** — found live testing item 1's fix
   without root. Two independent callers (`v7-zenki`'s stdout-log
   setup, trying to clean a stale symlink from a previous run before
   creating a fresh one, and `v7-zenki.teardown`'s own final cleanup
   call) both hit the same permission-denied path and log the
   identical `no whitelist permission [ unlink : ... ]` warning twice
   per tmp-path in one process run. Not a functional bug (shutdown
   still completes correctly, root enforcement works as intended) —
   just duplicate logging noise. Two fix options discussed, not yet
   decided: (a) track "already warned this path this run" inside
   `tmp-paths.global.clean-up` and skip re-logging an unchanged
   failure, or (b) don't call cleanup from both places, let teardown's
   final pass be the only one. Small, well-scoped, good next dispatch.
8. **DONE this session, found live-testing item 7 above**:
   `src/v7-zenki.call_cmd` had a redundant AND buggy flag-stripping
   regex (` *-+\w+...` with zero-or-more leading spaces, so it matched
   `-word` mid-string, not just at a real boundary) — `another-command`
   lost its `-command` tail before ever reaching the debug echo.
   `bin/Protocol-7` already filters `@ARGV` to non-flag tokens before
   `<system.args>` is ever built (two separate correct mechanisms, one
   per code path), so the extra pass in `call_cmd` was never doing
   legitimate work — removed rather than patched. Commit `9246d7209`,
   live-verified (`another-command` now prints intact).

## Verified Live

`v7-zenki` boots clean, fleet starts correctly (`cube`, `p7-log`,
`system`, on-demand `httpd`/`radio`), sessions authenticate under the
new identity, and a full `base.cmd.reload` on the running instance
completed with zero errors (also exercised the new
purge-exclusion-list state and confirmed `p-7-r` self-rebuilds on a
stale BMW checksum). Workflow shortcuts confirmed live end-to-end
(`p7.wo` -> `p7-work`, all 7 installed). `call_cmd` fix confirmed live
(`another-command` no longer truncated). Deliberate no-root run
confirmed `cube`'s own root-requirement enforcement is clean (no
redundancy there, unlike the tmp-paths cleanup path noted above).

Commits this session: `23a0e8d53`, `a43972791`, `3f1d6b40f`,
`f4c295824`, `6089e8434`, `9246d7209`, `ad956074e`. All pushed.

## Next Session Lead: dependency-installation queue (sys-deps/os-pkg/debian/ext-pkg/osf-cache)

Not started this session — reconnaissance only, at the user's request,
to plan real work next. User's framing: get this zenki group
"interacting smoothly... a true installation queue that always works,"
given recent investment across sessions that each ended right after
committing, so there's been no cross-session integration testing
beyond whatever each implementing session did itself.

**Current state, verified against the live tree** (not just docs):
- **`sys-deps`** — real, on-demand, thin command layer over the
  standalone `AMOS7::deps::*` library
  (`data/lib-path/pm/AMOS7/deps/{module,os_package,debp,dist_upgr}.pm`).
  Query/state front-end.
- **`debian`** — real, on-demand, the actual install-*execution*
  backend. Forks a root child (`debian.start.apt_child`) *before*
  dropping privileges, then genuinely serializes installs:
  `debian.apt_enqueue_install` -> jobqueue -> `debian.job.apt_install`
  writes one line to the persistent child, `debian.apt_pump` only
  starts the next queued job once none is in flight (real guard —
  concurrent writes would corrupt the child's line protocol).
  `sys-deps.cmd.install` relays here via `<[protocol-7.route-send]>`
  (fire-and-forget IPC).
- **`v7-zenki.check_zenka_deps`** — pre-start hook (wired into
  `autostart_zenki`), scans a zenka's `deps/{p-mod,os/deb,os/bin}`
  dirs before starting it, auto-installs via the same route-send path
  when `v7.cfg.auto_install_deps` is on.
- **`os-pkg`** — still a bare stub (`src/os-pkg.init_code` is `0;`,
  no `.cmd.` files, no live zenka-to-zenka wiring at all). The real
  `os-pkg` functionality is a standalone CLI script
  (`bin/os-pkg`, 245 lines) that touches the same `var/sys-deps/
  tracked.yaml` independently, not a network participant.
- **`ext-pkg`** — real, resident, handles external/language package
  managers (pip/npm/uv-tool), install-if-missing-only lifecycle
  (registered tools self-update). Phase 1 DONE, live-verified
  (`e9b437f6c`). Phase 2 ("unified coverage audit") not started —
  referenced directly in `ext-pkg`'s own config comment.
- **`osf-cache`** — not built yet, todo `AT5` ("create osf-cache zenka
  design or task file", tag `new-zenki`). Per the user directly: a
  later complement to this group, nothing currently blocked by its
  absence.
- **`build-zenka`** — adjacent, not named by the user but structurally
  similar: phase 1 DONE, live-verified (`e73bf2274`); phase 2 ("patch
  drift detection") not started.

**The standout concrete task — real bug, fully traced, not yet fixed**:
`src/base.register_pm_deps` (lines ~25-26) writes per-zenka dependency
touch-files directly into the *tracked* `cfg/zenki/<zenka>/deps/p-mod/`
git tree instead of a runtime `var/` location. Three confirmed live
failure modes, all previously reproduced: silent failure on
read-only-root installs (no fallback), a `$EUID==0` chown-fixup branch
that can reassign ownership of files inside a dev's own git working
tree, and behavior that depends on each zenka's own
`init_modules`-vs-`drop_privs` ordering in its start file, which the
user has confirmed is "mixed throughout the zenki." Fully traced with
a fix direction already, dated addendums, in
`data/ai-mem/claude/project-deps-tracking-var-relocation.md`
(2026-09-01, actively maintained — read this first). This is exactly
the race-condition/early-startup-hole class the user named, and it's
the most concrete, bounded, ready-to-execute starting point found.

**Smaller confirmed gaps**:
- `cfg/zenki/cube/access.zenki:320-321` grants `sys-deps` access to
  `debian.install`/`.check`/`.scan` — all three retired in a July
  cleanup, only `debian.install-packages` still exists. Harmless
  (grant to a nonexistent command just goes unused) but a clean
  example of "nobody re-verified after the change."
- `base.known_dependencies`'s *content* is static/hand-maintained with
  no auto-update path (access to it was already consolidated to one
  reader, `AMOS7::deps::module::load_known_deps` — that part is done;
  the staleness of the data itself is separate and unaddressed).
- `.deps/profiles.yaml` — already flagged "still slightly chaotic" by
  the user (2026-09-01 note), no reorg plan yet.

**Key docs, in useful reading order**: `data/tasks/completed/
sys-deps-zenka.md` (original 3-phase build spec) ->
`sys-deps-zenka-audit.md` (disposition table for the old `debian`
zenka's dead code) -> `sys-deps-wiring-completion.md` / `data/ai-mem/
claude/project-sys-deps-wiring-completion.md` (2026-07-20, the cleanup
that executed that table — notably gated destructive deletion behind
"verify the replacement works live first," found and fixed 5 real bugs
doing so; reuse that verify-first discipline for the next round) ->
`data/ai-mem/claude/project-deps-tracking-var-relocation.md`
(2026-09-01, the live bug above) -> `data/ai-mem/claude/
topic-sys-deps-debian.md` (apt-child fork-before-drop-privs protocol
detail + a never-started "layered extensions" roadmap: auto-registering
invoked binaries/modules at runtime).

**Stale, do not trust**: `data/ai-mem/claude/topic-next-steps.md`
(~2026-07-29/31) claims a `sys-deps` zenka "exists in history but is
not an ancestor of current HEAD." That's superseded — `sys-deps`
demonstrably exists and works on current HEAD now, per the above. The
note predates the later wiring-completion work.

**Genuinely unclear, not found either way**: whether the
`topic-sys-deps-debian.md` "layered extensions" roadmap progressed
beyond baseline; exact behavior when an install request arrives at
`debian` via route-send before `debian`'s own on-demand start has
finished initializing (reachability is covered in the var-relocation
memory, this specific timing case isn't); whether two "closed,
verified" items in that same memory (bootstrap-ordering,
idle-timeout-vs-install-race) were confirmed by real live testing or
by code-reading + the user's own correction — worth an honest look
before treating them as settled, given this whole arc's stated concern
is exactly the gap between "reasoned through" and "actually run."
