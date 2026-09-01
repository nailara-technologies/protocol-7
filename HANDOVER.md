# Session Handover — 2026-09-01

## Completed This Session

### ncpan — CPAN mirror + reliability fixes
Mirror index moved `/src/` → `/modules/`; added HTTPS, XDG cache dir, working
`clean`, auto-refresh on stale/missing list, stall-safe downloads, real HTTP
error text, Build.PL support, dependency-cycle guard.
Commits: `a1aeb2136`, `6138432d6`, `34db56b9b`, `b0d74e884`.

### kimi-web zenka — was essentially non-functional, now fixed
Missing from its own `modules.load`; all 8 `.cmd.` files assumed `$call->{args}`
was a hashref (it's a raw string for real cube-routed calls); sprintf/session
bugs. `data/ai-mem/claude/topic-kimi-web-*.md` if it exists, else see commit
`7030fb250`.

### debian/sys-deps — async apt-install pipeline
Was blocking the whole zenka event loop; now non-blocking I/O + jobqueue-
serialized. `v7.check_zenka_deps` rewritten to route through it too, plus a
binary-dependency gap fix and `known_dependencies` access consolidated to one
canonical accessor (`AMOS7::deps::module::load_known_deps`).
Commits: `7030fb250`, `34c2cd2bc`. Full trace in
`data/ai-mem/claude/project-deps-tracking-var-relocation.md`.

### base.zenki.pause_ondemand_timeout / resume_ondemand_timeout
New reusable pair to protect a zenka from ondemand idle-shutdown during real
background work, without relying on the implicit `Event->idle` timing alone.
Wired into `debian`'s apt-install job lifecycle; `debian` heartbeat also
re-enabled (the pipeline is fully async now, the old "duration uncertainty"
justification for disabling it no longer applies).
Commit `5cd3d50e4` (bundled with format-code work, see below).

### format-code — major expansion, four new opt-in steps
This was the bulk of the session. `bin/format-code` gained:
- `-d` / `-data-sugar`: `$data{'a'}{'b'}` → `<a.b>` sugar (451 real
  occurrences landed, commit `87b91fd5f`)
- `-m` / `-module-sugar`: `$code{'a.b'}->()` → `<[a.b]>->()`, empty-arg
  calls further compact to bare `<[a.b]>` (42 occurrences, `f43041e5a`)
- `-p` / `-postfix-deref`: `${<a.b>}`/`%{<a.b>}`/`@{<a.b>}` → postfix deref
  (271 occurrences, `82fdb008d`)
- `-r` / `-regex-style`: `m//`/`s///` → `m||`/`s|||` (541 occurrences,
  `d12228697`) — **found and fixed a severe bug before this ran repo-wide**:
  PPI misparsed `<sugar> // 'default'` as an empty regex match, would have
  broken 1354 files (`e4bb1a14e`)

Also hardened the `-c` syntax-check path itself: added `-Mutf8`, `-I` for
`AMOS7::*` lib-path, and a preamble providing everything `bin/Protocol-7`
sets up globally (List::Util, POSIX, Const::Fast, TRUE/FALSE/UNKNOWN,
declared_refs/bitwise features, Crypt::Misc, `our`-declared globals) so the
checker stops false-positiving on legitimate code (`a12b03f0f`). Quieted
`used only once` false positives on `main::` symbols (`b32a57834`). Added
signal-handling temp-file cleanup for INT/TERM/QUIT/HUP/PIPE (`e2b6ea1ef`).

Two rounds of stale-content cleanup followed (pre-fix tool output that had
ridden into earlier commits unnoticed): 42 files with a missing `->`
(`9b8eebca7`), one genuine remaining multi-line-wrap gap in that same fix
(`e2ac806fc`), two files restored after accidental deletion during an
interrupted kimi batch-test.

Full arc + all the individual bugs found dogfooding: `data/ai-mem/claude/topic-format-code-bugs-fixed.md`.

### cube — wrong !TRM! reply type
Orphaned-route cleanup was sending the stream-control `!TRM!` signal for
atomic `SIZE`/`CHRSIZE` replies too, not just `STRM`/`STRM-SIZE` — those two
are one-shot and already clean up their own route, there's no stream to
terminate. Fixed in `src/base.handler.command.process_reply`, commit
`4ada57380`.

### Misc
- `bench.key-32-iterations`: fixed a double-escaped backslash that would
  interpolate `\$shared_secret`/`\$session_id` as real (undeclared)
  variables instead of printing literally.
- `invoke.init_code` / `invoke-web.init_code`: fixed a real config-key bug —
  both were reading `$data{'invoke'}{'external.models.invokeai.url'}`
  (wrong key entirely; no `invoke` prefix exists, and the dotted config key
  nests into real sub-hashes, not one literal-dotted key), silently falling
  back to a hardcoded default the whole time. Fixed to
  `<external.models.invokeai.url>`.

## Known Infra Gotchas Found This Session

- **Never run `kimi_dispatch`/`kimi_continue` in parallel** — reproducible
  session collision, garbled results, early termination with budget to
  spare. Always sequential. `data/ai-mem/claude/feedback-kimi-dispatch-never-parallel.md`.
- **Stale tool output can silently ride into a later, unrelated commit** —
  this repo's pre-commit hook broadly re-stages everything modified, not
  just what you explicitly `git add`ed. Check `git status --short` on the
  whole tree before committing, not just the diff you intended.
  `data/ai-mem/claude/feedback-stale-tool-output-rides-into-later-commits.md`.

## Paced / Deferred — Not Started This Session

These were traced/discussed earlier in the session but deliberately not
started, per "step by step" pacing — pick up when asked, not proactively:

1. **`base.register_pm_deps` var/ relocation** — real, live-reproduced bug
   (read-only-install failures, dev-repo ownership hijacking via the
   `$EUID==0` chown-fixup path). Fully traced, task-file-ready, not
   dispatched. `data/ai-mem/claude/project-deps-tracking-var-relocation.md`.
2. **`.deps/profiles.yaml` reorganization** — acknowledged "still slightly
   chaotic" by the user, no concrete plan yet.
3. **BMW checksum JS port + composite AMOS chksum** — blocked on the BMW
   piece, not started (ELF-7 checksum JS port already landed, see
   `data/web-root/shared/templates/components/elf-checksum.js`).
4. **Background signing-acceleration idea** (Linux::Inotify2 watcher +
   Twofish-encrypted speculative signature precompute) — captured as an
   idea on todo item `ADR` only, no design pass done.
5. **Tree-based module storage / namespace manifest redesign** —
   vision-level, `data/ai-mem/claude/vision-tree-based-module-storage-and-namespace-manifests.md`.
6. **Inline-filesystem self-contained Protocol-7** — vision-level,
   `data/ai-mem/claude/vision-inline-filesystem-self-contained-protocol-7.md`.
7. **User-data-derived zenka config generation** (e.g. smtpd config from
   already-collected contact emails) — vision-level, not started.
8. **Config/installer zenka landscape** (set-up/settings/configure zenki,
   eventual installer zenka, user-edit CLI+web-UI) — vision-level.

## Verified Live

Coding, cube, and v7 zenki all confirmed reloading clean after the full
format-code batch landed. All commits pushed.
