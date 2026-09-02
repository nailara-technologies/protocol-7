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
`f4c295824`, `6089e8434`, `9246d7209`. All pushed.
