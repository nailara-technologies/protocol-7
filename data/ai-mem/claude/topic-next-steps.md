---
name: next-steps
description: "active task queue, roadmap items, open bugs, and planned work"
metadata:
  node_type: memory
  type: project
  originSessionId: 56cce73a-933a-4992-96e4-4d88e138e8f6
  modified: 2026-07-29T01:43:23.992Z
---

## done (2026-07-24, continued — ncode write path)

- **`ncode.cmd.suggest`/`ncode.cmd.apply` wired up + live-verified end to
  end** — was unreachable via `p7c` at all (expected a hashref, cube
  dispatch passes a `$call_args`/string-args object), had a dead
  `<[base.time]>` call, and had never actually written a file. Full arc:
  [[project-ncode-write-path-2026-07-24]]. Fixed `bin/ptd -c` (was
  decorative — always exit 0) and `bin/format-code`'s temp-file naming
  (dot-prefixed, collision-abort, [[feedback-ptd-syntax-check]]) along the
  way. Core bug: chmod-child write grants must set group-write (`0020`),
  not other-write (`0002`) — see [[feedback-posix-group-write-precedence]],
  which is a **repeat** of a 2026-06-06 finding in `write_append` that
  never got its own memory file and so didn't stop the same bug landing in
  `write_with_perms` afterward.
- **`ncode.cmd.assess` wired up + live-tested** — exposed the
  never-before-used `ncode.regex.assess` pattern-extraction pipeline to
  `p7c`. Root cause of it silently failing: `context` (its own zenka
  namespace) was missing from `ncode`'s `modules.load` entirely — same
  incomplete-port class as `chmod_child` below. Live test against an
  `open()`→`<[file.open]>` rewrite came back honestly low-confidence
  (0.65, capture groups the `replace` doesn't reconstruct from) — correct
  behavior, not a bug: this is the tier-B "needs a human/LLM to author the
  real pattern" case, not a tier-A auto-apply case. Full design for what
  comes next: [[topic-ncode-pattern-learning-loop]] (two-tier model,
  reuse `stats`/`applicability.confidence` fields for self-reinforcement,
  LLM-prefers-editing-patterns interaction model, namespace scope gating,
  nested-dispatch for batch-apply without confirmation storms).
- **all four mechanical follow-ups from the previous round now done, same
  day (`85ea963b2`, `988e0de43`, `cb45d56d0`):**
  - `coding.tools.handler.write_with_perms`'s grant fixed `| 0002` →
    `| 0020` (`85ea963b2`) — matches [[feedback-posix-group-write-precedence]]
  - `stats.applied`/`false_positive` now increment in `apply` on real
    outcomes (`85ea963b2`)
  - `apply`'s revert path now uses the same chmod-child grant dance as
    the write path, plus a real bug fixed along the way: a failed revert
    used to `next` before setting `$fix->{'status'}`, leaving it stuck at
    `pending` forever instead of recording `failed` (`85ea963b2`)
  - **pattern schema fix landed (`cb45d56d0`)** — the big one, closes the
    loop that was blocking [[topic-ncode-pattern-learning-loop]]'s whole
    tier-A auto-apply path. `ncode.regex.load` now synthesizes a `steps`
    entry from top-level `pattern`/`replace` when none is explicit;
    `ncode.regex.save` preserves genuinely custom `steps` on export but
    omits synthesizable ones. Dispatched via `claude_dispatch`
    (session `92fe0c68`) + `claude_continue`, independently re-verified
    live afterward rather than trusting the dispatch's own self-report
    (which came back garbled on the second continue — see
    [[feedback-claude-dispatch-summarize-hang]] for a related but
    distinct known failure mode in this same infra). The dispatch also
    found and fixed a real bug the synthesis exposed that wasn't in the
    original plan: `$1`/`$2` backreferences in a YAML `replace` string
    were being inserted as literal text, not the matched value — a plain
    `s///` only interpolates the replacement *variable*, not numbered
    captures embedded inside its string content. Live-verified:
    `single-quote-to-qw-scalar` (pure `pattern`/`replace`, no
    hand-authored `steps`) now correctly rewrites `'active'` →
    `qw| active |`; `p7-arg-regression` (hand-authored `steps`, literal
    `$ARG` replace, no numbered backrefs) unaffected.
- **`bin/ncode search` recursion bug found + fixed (`988e0de43`),
  unrelated to the write-path work — surfaced while adding `ai-mem`/
  `yaml` as new search targets** (both previously unreachable despite
  being directly relevant to pattern/memory work). `parse_file_options`
  defaulted `recurse => 0` (a *defined* value), which silently defeated
  `files()`'s `$options->{'recurse'} // $legacy_recurse` fallback — every
  recursive target's `..,` marker (`docs`, `tasks`, `zenki`, and the two
  new ones) has been silently ignored this whole time unless the caller
  manually passed `rec:1`. Fixed by defaulting to `undef` instead.
  Live-verified across old and new targets. Also deleted a stray
  personal job-assessment record (`data/yaml/assessment-alexander-
  mettenmeier.yml`) found via this work, introduced by `4564d3577` and
  never touched again.
- **open, not yet decided:**
  - decide whether `suggest`/`apply`/`assess` stay open on `ncode`'s cube
    whitelist going forward, or get folded into
    [[topic-write-access-security-infrastructure]] once that exists
  - the tier-A loop in [[topic-ncode-pattern-learning-loop]] is now
    technically unblocked end-to-end (assess → expand → save → suggest →
    apply should all compose correctly) but hasn't been exercised as one
    continuous chain yet — only the individual pieces have been tested
    in isolation. Worth a real end-to-end run before trusting it for
    anything unattended.
  - `regex.expand`/`regex.assess` still aren't exposed to `p7c` for the
    "persist a new candidate pattern" step — `ncode.cmd.assess` only
    *returns* a candidate for review, nothing writes it into
    `<ncode.patterns>` yet. Next real gap for the pattern-learning loop.

## done (2026-07-24)

- **bin/format-code hardening + broad application** — 17 real bugs found
  and fixed via dogfooding (comment-loss, string splits, N-way split
  overflow, box/list/annotation detection gaps, fake-signature-footer
  detection, more) — full detail in [[topic-format-code-bugs-fixed]].
  Applied clean to 13 namespaces/areas: jobsite (discovery only, not
  applied), letsencr, bin/Protocol-7, web-browser, httpd, ticker, source,
  sourcecode, AMOS7 modules, base, coding, models, bin/. Two smaller
  spinoff findings got their own memory: a new LLM-hallucinated
  fake-signature-footer disguise in `source.extract_sig_body`
  ([[topic-fake-signature-footer-detection]]), and a still-open
  `Module::Refresh`/`cube reload perl-mods` "subroutine redefined"
  warning bug found live-testing
  ([[project-perl-mod-reload-subroutine-redefined-warnings]]). Also: a
  nested Agent dispatch with `isolation:worktree` escaped its isolation
  and corrupted the main working tree (fully recovered via
  `git checkout HEAD --`, no commits affected) — see
  [[feedback-agent-dispatch-worktree-isolation-escaped]] before trusting
  that isolation mode again for a shared-repo task.

## done (2026-07-23)

- **log-anonymization phase 1** ✓ (`dbd7ca8ba`, kimi K3 dispatch, timed
  during a weekly-token-reset window — was queued since 2026-07-19) —
  `p7-log.anon.*` (renamed from spec's `log.anon.*`: module group lives
  inside the `p7-log` zenka, not a standalone zenka). classify/replace/
  store/resolve + p7-log wiring, opt-in via `p7-log.anon.enabled`.
  home-root detection made configurable (`p7-log.anon.home_roots`,
  default home+users) instead of hardcoded `/home/`. table storage moved
  to `/var/protocol-7/p7-log/` via `file.zenka_dir.data_path` instead of
  a source-tree-relative path (would've collided with `git reset`/clean
  in dev). two real bugs caught by live round-trip testing, not syntax
  check: swapped-name mismatch (`base.file.zenka_dir.data_path` vs live
  `file.zenka_dir.data_path`, see [[feedback-swap-subs-not-fragile]]) and
  an `$EVAL_ERROR`-read-at-macro-call-site bug (see
  [[feedback-eval-error-macro-call-site]]). live-verified end to end
  twice (both home-root prefixes, real encrypted table, `p7c p7-log.
  resolve <checksum>`). phases 2-5 (timestamp/sign/full-encrypt, entropy
  classifier) still design-only. task archived to `data/tasks/completed/
  log-anonymization.md` with status notes.
- **ncode-zenka-modules.md confirmed already fully implemented** — kimi
  K3 dispatch (parallel with the above) found all modules already built
  in earlier sessions (2026-07-17/20), made no changes, live-reverified
  `p7c ncode.search`/`.doc`/`.parse-headers`. archived to `data/tasks/
  completed/`. See [[feedback-kimi-dispatch-idle-timeout-recovery]] for
  how this was confirmed despite the dispatch's MCP call itself timing
  out after 1800s idle (underlying kimi process finished normally;
  `session_catchup` recovered the result).

## done (2026-07-19)

- **base.strm.subscribe generic offline-safe subscription wrapper** ✓
  (`127cb7627`, kimi K3 dispatch) — 6 modules (base.strm.subscribe +
  .attempt/.wait-online/.reply-handler[.notify-online]/.pre_init,
  swapped to `strm.subscribe`), mirrors `base.zenka.push` pattern.
  Structurally closes the confused-deputy/reflection class fixed in
  `536c41877` (`data/tasks/completed/cred-mesh-subscribe-handler-
  reflection.md`, archived): handler validated as bare single-segment
  suffix, notify target always `<system.zenka.name>.<handler>`.
  Verified live vs real cred-mesh/proxy pair (offline wait,
  auto-resubscribe, real rotation event). Publisher-restart re-affirm
  deliberately left open (registry persists for a future hook);
  production proxy/transport call sites untouched by design.
  Self-recorded gotchas: `data/ai-mem/kimi/strm-subscribe-wrapper.md`.
- **log-anonymization.md checksum fix** (`0edadb2c7`) — corrected
  BMW-L12→BMW-L13 throughout (implemented function is
  `base.chk-sum.bmw-l13`, 13-char B32); task not yet dispatched, next
  in queue for K3 (phase 1: classify/replace/store/resolve, opt-in via
  p7-log, has ready dispatch prompt in the task file itself).

## done (2026-06-18)

- **mpv async startup + jobqueue** ✓ — all paths deferred; open_control_socket
  async; dep chain fork_player→finalize; send_command no longer exit(2); deferred
  command queue; doc: `MPV-ASYNC-STARTUP-JOBQUEUE.md`
- **mpv command rename (snake→kebab)** ✓ — 10 modules true-renamed via git mv;
  parse-headers fixed headers; ncode replace all swept callers; whitelist + start
  configs updated; playlist_update → playlist-update extended to universal,
  web-browser, impressive, remote-cam (14 caller replacements with word boundary)
- **ncode TTY auto-detect** ✓ — `$AI_FRIENDLY = 1 if not -t STDOUT;` added after
  flag parsing; prevents stty ioctl errors when run from tools/pipes/scripts
- **X-11 multi-server + jobqueue architecture** ✓ — `<X-11.servers>` display
  registry; `x11_display_flag` dep type; `X-11.job.start_server`, `display_poll`
  handler, `X-11.job.finalize_server`; host-mode timing bug fixed (connected=TRUE
  only in callbacks.initialized coderef after X11::Protocol->new); WM.update guard
  added; tile display-awareness additions from kimi
- **cube command_aliases tile fix** ✓ — tile.get_geometry / assign_window /
  get_coordinates moved from source_zenka → source_zenka_sid; tile.get-screen-size
  added to source_zenka_sid (fixes "no zenka name received" errors in tile)

## open — mpv

- **sign all mpv session modules** — mpv.send_command, mpv.job.deferred_send_command,
  mpv.startup.job.fork_player, mpv.startup.job.finalize, mpv.callback.object.mpv_flag,
  mpv.open_control_socket, mpv.open_player, mpv.startup.handler.socket_poll,
  mpv.startup.init, mpv.init_code + configs
- **mpv state snapshot/restore** — full property map + curve phase; restore via
  deferred send_command queue on restart [[topic-mpv-persistence]]
- **visual curve automation** — extend base.curve.* to brightness/contrast/gamma/
  saturation/shader; same shape as existing volume fade
- **cross-mapped curve routing** — param driven by another param or external signal
- **player restart job** — re-fork binary on death, zenka stays alive, restore from snapshot
- **`:twin:` restart integration** — zero-downtime config reload

## done (2026-06-17)

- **tile kiosk-mode stop_display_zenki disabled** ✓ — commented out
  `tile.startup.stop_zenki`, `tile.startup.restart_zenki`, and
  `[tile.stop_display_zenki]` in `configuration/zenki/tile/start`; mpv
  and display zenki survive tile restart cleanly
- **X-11.get_pointer_scr_rect rename** ✓ — was `get_pointer_monitor_rect`
  (24 chars, too long for 23-char protocol limit); renamed + cube/access.zenki
  updated; window.geometry.resolve uses it for pointer-monitor fallback
- **27 reasoning templates batch** ✓ (`d1ed02aad`) — Opus dispatch session
  produced: FOUR-VISUAL-DOMAINS.md, HARMONIC-SILENCE.md (incl. active
  cancellation as sensing event horizon), THE-VIEW-FROM-OUTSIDE.md;
  templates: fossil-record, resonance-before-recognition,
  template-distribution-economics, key-tree-authority-field (namespace as
  C25519 key-tree + self-authorizing antenna + cancellation library),
  ring-key-routing (shared ring keys, self-removing layers, center-blind
  computation, tree+ring = full authority+routing topology); expansions to
  synesthetic-space, DREAM-EMBEDDING-LAYER, HYPERSPACE-RAMJET-SIGNATURE,
  SPATIAL-AUDIO-AND-PURR-CHANNEL, LLM-EXOSKELETON-INTEGRATION

## done (2026-06-16, cont.)

- **nshell.shell_loop `$cube_sid` fix** ✓ — credential-fabric UI block was
  inserted before the `my ($cube_sid)` declaration; moved declaration above
  the block. Signed + staged.
- **WSL window enumeration — diagnosis only, not yet fixed** — GTK zenki run
  as `GdkWaylandWindow` (no XIDs); `_NET_CLIENT_LIST` empty (no EWMH WM in
  WSLg). Attempted: global `GDK_BACKEND=x11` (reverted — broke `Gtk3->init`
  in `window.place.init_code` which runs before DISPLAY is set from X-11);
  QueryTree fallback in `get_window_ids` (reverted — compositor internals set
  `window_enumeration=TRUE`, causing `wait_visible` to poll forever).
  `X-11.cmd.get-xwindows` added as safe diagnostic command (QueryTree walk,
  not in hot path). **Correct approach**: iterate in
  `bin/dev/script-scratchpad/gtk_get_windows` until a method returns real app
  window XIDs on this WSL setup, then bring that one path into the zenki.
- **x11-wait-visible-host-mode-skip** ✓ — already implemented (was in
  needs-testing/); moved to completed/
- **zenka-window-placement-profiles** ✓ — pre-implementation task for
  `base.window.profile.*`; actual modules landed as `window.profile.*` +
  `window.gtk.profile.*`; ticker integrated; moved needs-testing/ → completed/
- **zenka-side-stdio-multiplex-emitter** ✓ — `base.stdio_multiplex.connect` +
  `emit_eout` + `emit_str` + `emit_num` all in modules/; moved to completed/

## done (2026-06-16)

- **weather-forecast-humidity** ✓ — humidity field re-enabled in forecast API;
  `weather.parent.extract_forecast` + `format_current_widget` already wired;
  task file in `data/tasks/completed/`
- **diff-modified-no-color-mode** ✓ — `--no-color` flag already in
  `bin/dev/diff-modified` (lines 85-98): `$args->{'no-color'}` → `$no_color_mode`,
  strips all ANSI escapes; no task file was ever created
- **x11-wait-visible-host-mode-skip** ✓ — `X-11.cmd.wait_visible` lines 28-38
  already check `<X-11.window_enumeration>` and return false+log when unavailable
  (host-mode / WSL headless); no task file was ever created
- **mpv-xephyr-vo-override** ✓ — `mpv.init_code` line 51 sets
  `<mpv.xmode.xephyr.vo> //= qw| gpu |`; `mpv.open_player` passes `-vo=<mpv.vo_backend>`;
  gpu default for xephyr mode already live; no task file was ever created

## done (2026-06-13, cont.)

- UI-SHOW-SECURITY-LEVELS queue steps 1-4 ALL COMPLETE: `ui.caller.security-level`
  real implementation (`5c5deed50`, + new shared helper `base.session.user`
  used by `base.handler.command`/`base.cmd.whoami`), then step 4 `*.ui-show`
  generic grant in `cube/access.zenki` (`687f7daba`). task files moved to
  `data/tasks/completed/`. see [[topic-ui-show-security-levels]] for detail.
  steps 5-6 (per-zenka level 1+ fields, key-based auth) open.

## done (2026-06-13)

- `base-handler-command-split.md` landed as `5dcbf0296` (opus dispatch,
  fable rejected unavailable): base.handler.command 2319->1037 lines,
  + base.handler.command.process_reply (1004) +
  base.handler.command.route_to_target (361). verified live, no
  behavior change. open follow-up: optional dedupe of 4x repeated
  route-delete block + SIZE/CHRSIZE merge in process_reply (low
  priority, quality-only).

## done (2026-06-11)

- `ui-namespace-extraction.md` landed as `f753e1a5d`: `base.ui.*` ->
  `ui.*` (10 modules incl. `base.cmd.ui-show` -> `ui.cmd.ui-show`),
  `base.slot.fold/move/refresh` updated to call `ui.fold`/`ui.unfold`
  (left in `base.*`, eval-wrapped so they degrade gracefully),
  104 whitelist files updated, design docs updated.
  `console-fold-primitive` follow-up `base.cmd.ui-show` landed as
  `1cf36cb34` just before this.

## done (2026-06-11, cont.)

- `ui-namespace-modules-load.md` landed as `5306f6450`: `ui` added to
  `modules.load` for 104 zenki + whitelist refresh. `v7.ui-show` verified
  live (folded tree render). `coding.ui-show` returned "no permission" —
  investigated, NOT a bug: `ui-show` access is currently scoped same as
  before (credential_fabric-only in `cube/access.zenki`'s `usr.*` block).

## OPEN: ui-show generic access — blocked on security-level design

opening `*.ui-show` to `access.cmd.usr.*` (the obvious next step) was
considered and explicitly deferred: `ui.unfold`/`ui.render.fallback`
currently render raw `%data` tree contents with no filtering, so a
generic grant would leak any zenka's internal state to any caller.
design doc written: `data/md/design/UI-SHOW-SECURITY-LEVELS.md` —
security-level field maps (level 0 = pid/paths/stats/idle/source-age,
always safe), caller level via existing admin-group resolution
(`<admin-user>`/`<AMOS-user>` already grant `taeki` `..*.** **`), future
key-based level auth. implementation queue is in the doc; not yet split
into task files. DO NOT add `*.ui-show` to `cube/access.zenki` until
step (1)-(3) of that queue (level-0 field map + filtering) lands.

note: the literal `harmony <module>` checks in task files don't map to
the real `/usr/local/bin/harmony` binary (an unrelated AMOS7
harmonic-truth tool, returns exit 202 for almost everything including
pre-existing modules) — kimi substituted `perl -c` and that's fine;
stop asking for literal `harmony` in future task files, or clarify
what it should actually invoke.

## queued for next opus task-file-generation dispatch (2026-06-10)

- `data/md/design/CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md` — raw
  ideation captured mid-dispatch (interrupted by bmw-harmonize-l13 v7 boot
  crash, now fixed in `ede1a3441`): (1) `[CHECKSUM:NAME]` recursive
  collision-free nested addressing, (2) v7 epoch as temporal network root +
  rollover validity windows + checksum-based search/route/cache protocol,
  (3) coding zenka model self-test cycle / model-cycling fallback +
  consensus ranking. needs folding into 2-3 task files.
- `stdio-multiplex-type-tag-codec.md` already in `data/tasks/completed/`;
  `zenka-side-stdio-multiplex-emitter.md` is the live follow-up (pending,
  task file exists on disk). `console-fold-primitive.md` resolved vs
  `console-foldable-render-baseline` (landed `2560c5499`);
  `amos7-template-epoch-exclusion.md` landed `8cf4fda11`

## completed this session (2026-06-09)

- **route.bmw384 signature indexer** ✓ (`6dee838d5`) — 5 modules: `index.from-file`, `index.register-digest`, `index.from-path`, `cmd.index-path`, `cmd.verify-coordinate`; kimi dispatch
- **coding drain-pipe watcher fd-fix + EOF requeue** ✓ (`159d8dc88`) — `cancel_watcher.backend_monitor` fileno comparison fixed; `callback.http_error` requeue regex extended to catch 0-byte EOF
- **base.zenka.push helper + base.cmd.when-present** ✓ (`92e4fb16c`) — offline-safe push with notify_online + backoff; `when-present` stub completed; stale-state leak fixed in reply-handler.offline
- **coding timeout fixes for omnicoder** ✓ (`e0868b1e6`, `9bd84f73b`) — ctx-reduction gating: skip when `ctx_pct < 70%` (model latency ≠ VRAM pressure); `prefill_tokens_per_sec` 1200→600; `data-start` floor 13→25s
- **base.parser.list width fix** ✓ (staged) — removed stale `-= 2` workaround on last column; separator width now always `sum(max_len) - 1`; kimi dispatch
- **OmniCoder 9B Claude Opus High Reasoning Distill** loaded as coding zenka model (`DVEAZIA:GPAKBLA`); dolphincoder-starcoder2-7b also registered as lighter option
- **future task**: statistical adaptive timeout — record TTFT per completed request by ctx% band, use p95×1.5 as scaled floor; self-calibrating per model; data in `coding.cfg.timeout_stats`

## completed this session (2026-06-07)

- **credential-fabric integration + UI plan** ✓ (34e3bee78) — `data/md/design/CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md` + 4 task files (wiring, integration-test, ui-frames phase-1, ui-interactive phase-2/3); dispatched to Opus via claude_dispatch + one revision pass via claude_continue (session 17b14f6a-2d5d-4836-a7ba-d3b7a0777ee0). Key design call: auth-relay approval + key-holder unlock route primarily through `protocol-7-menu.cmd.input-text`/`input-password` (existing GTK3 dialogs — works regardless of which browser triggers the proxied request), with the original frame-based design demoted to a headless/no-X11 fallback (phase 3b). Open: `protocol-7-menu.cmd.input-*` has never been called cross-zenka — cube routing of that namespace needs confirming during wiring. NEXT: dispatch `credential-fabric-wiring.md` (the foundational task — others depend on it landing first).
- **write_append chmod-child fix** ✓ (00d29a793) — replaced racy 10ms `select`-yield with blocking `<[coding.chmod_child.readline]>` (matches insert_line/delete_lines pattern); ALSO fixed root cause in `coding.start.chmod_child`'s `gw` handler — granted other-write (0002) but coding zenka holds admin group as supplementary gid (assume_admin_group), so group bits govern; changed to group-write (0020) matching `gwd`. Verified live: write_append + insert_line both write directly to taeki-owned files now, mode restored correctly.

## completed this session (2026-06-06)

- **memory context pipeline** ✓ — `memory.render.context` writes cache file; `context.memory.load` reads scored tree; `memory.startup` primes on init (commit aa0b24c9d)
- **MCP memory tools** ✓ — `p7_memory_search` + `p7_memory_digest` in `bin/mcp-server-p7` (commit fae65a85d); live after MCP restart
- **coding zenka tool search_memory** ✓ — `coding.tools.handler.search_memory` + definition; DeepSeek can call mid-task (commit 36f2e9df6)
- **memory summarize wave** ✓ — `memory.tree.summarize.node` routing fixed (cube. prefix + b32); `p7c memory.summarize` fires 9 tasks to coding zenka; `p7c memory.dedup` working (commit a18205f6d)

## completed previous session (2026-06-05)

- **memory IDF search** ✓ — `memory.tree.score.idf_weight` + `wordcount` + `rebuild_idf`; pass-2b in scorer; live
- **memory.digest pipeline** ✓ — `memory.cmd.digest` + `memory.digest.done`; deferred SIZE reply via `cube.coding.summarize-context`; DeepSeek R1 0528 (8B Q8) confirmed working
- **DeepSeek-R1-0528-Qwen3-8B** ✓ — registered `CSABG4A:KENZBPY`; loaded as coding zenka backend

## open bugs

- ~~nshell (0) on first command~~ **FIXED 2026-06-02** — orphaned route handler in `base.handler.command` generated `(0)!TERM!` for prefix-less replies (`cmd_id == 0`); guard added
- **nshell stray cursor**: `index.cmd.search/lookup/stats` added trailing `\n` to inline SIZE replies (commit DE5EAEA4); nshell output handler may be double-newlining — check `nshell.handler.strm_reply`
- **STRM fix review needed**: `had_local_consumer` fix correct for local consumer; relay path unchanged; test needed on radio zenka and other STRM consumers

## iris visualization queue — COMPLETE ✓ (2026-06-06)

- **iris alpha-density v2**: DONE ✓
- **iris ring ledger**: DONE ✓
- **iris route-commitment**: DONE ✓
- **iris dimension-rotator**: DONE ✓ (8e66b0044) — H/V floor-depth view
- **iris cascade-warning**: DONE ✓ (497976067) — amber depletion overlay
- **iris separator-pulse**: DONE ✓ (9c5b107d0) — sep toggle + 100ms refresh
- **iris temporal**: DONE ✓ (2b8b6ea0c) — radial=time, hue by age
- **iris boundary**: DONE ✓ (71cb6e025) — stained glass gap boundaries
- **iris negotiation-window**: DONE ✓ (a6a62fb16) — floor budget urgency
- **iris oscilloscope**: route-send SIZE relay to index — verify working after httpd+index+zulum restart

## pending tasks (from session 37 queue)

- **zenka-side-stdio-multiplex-emitter** ✓ — `base.stdio_multiplex.connect` + `emit_eout` + `emit_str` + `emit_num` all present in `modules/`; task file moved to `data/tasks/completed/`
- `data/tasks/kimi-zenka-multiplexer.md` — STRM dispatch + queue + sudo auto-decline (no task file yet)
- `data/tasks/credentials-zenka.md` — encrypted credential store, per-zenka authorization (no task file yet)
- `data/tasks/zenka-window-placement-profiles.md` — window.* namespace (re-dispatch after rename; no task file yet)

## infrastructure

- **:::: litter row**: data/tasks/litter-row-encoding.md — 15-bit zenka bitmap in footer
- **iris 63-ring labels**: DONE ✓ namespace63 mode with . at ring 27
- **iris logo overlay**: DONE ✓ nailara at darksun
- **plugin.web.* migration**: DONE ✓ web zenka owns all plugin.web.*
- **jobsite BMW384 dedup**: dispatch bmw384-arc-grouping-filter.md to kimi
- **route.bmw384 find-route testing**: register nodes, verify-coordinate

## roadmap

- **sub-bit element definition**: data/tasks/sub-bit-element-definition.md
- **generic content layer**: 4b.6 improvement-directed history, git supersession path
- **flexible offset mapping**: 4.7 angle_bits as φ_offset + seed per ring
- **orbital velocity signatures**: 4.8 per-ring speed multipliers, TRUE/FALSE CCW/CW lanes
- **network cycle clock**: 4.9 logically mapping orbital timebase

## session 67 completed (2026-05-25)

- jobsite dedup false positive fix ✓ (f70d841eb); 64 blocked jobs reset
- jobsite.cmd.reset off-memory ✓ scans job files for status=blocked
- fix_encoding inline sub extraction ✓ mojibake-table + score-candidate
- filesystem checksum store ✓ (5846902bc) dir-based, no load/persist
- jobsite status-dir layout ✓ kimi dispatch; per-status job subdirs live
- job.read utf8 fix ✓ utf8::encode before YAML::XS::Load
- checksum store status-dir expansion ✓ titles/ per-status, resolved_status, interviewed
- jobsite.cmd.progress ✓ index-based counts
- scan-state slim ✓ 4 fields only
- status/stage reconcile ✓ assess-done writes status=review
- UI card refinements ✓ badges, dims row, error tab, NaN fix
- reassess ↺ button ✓ full loop working (00c2e2605); 5 bugs fixed
- flexible export ✓ stage checkboxes + since-last-export
- web plugin phase 2 ✓ status-dir layout, merge, prune
- sync push status-dir ✓ status injected, blocked skipped, delete via index
- ES5 compat ✓ ?./??→&& ; mobile rendering fixed
- sync_urls multiplex config ✓ //→|| fallback fixed
- web-auth-plugin ✓ (142da4c44) POST /jobs-sync gated
- import-atom-jobs script ✓ (142da4c44) bin/dev/import-atom-jobs
- CSV/HTML import ✓ 47 applied, 3 interviewed, 16 apply imported
- jobsite.status fix ✓ (4b930b439) index-based counts, base.sort
- atom browser localStorage extraction ✓ DevTools key `jobs_[vhost]_v1` → POST reverse-sync batch
- multi-endpoint sync — after auth settled
- web-sessions-distributed — lower priority, task written

## jobs pipeline open items

- profile.txt: /var/protocol-7/jobs/profile.txt — CV/skills for LLM scoring
- multi-page search: stepstone 25/page; cfg.max_pages per category
- orphan re-queue: re-create tasks stuck in 'assessing' after restart
- note_read pagination (offset/limit on sections)
- active deps execution (requires list in task dispatcher)
- think-block stripping — `<think>...</think>` from Kimi/Deepseek leaks into output
- task.cmd.start — task zenka step 3
- model selection for assessment: `preferred_model` param on task.create needed
- site-yaml 403 backoff: currently fixed at 10s; should scale with consecutive count
- sync ?since=N browser delta ✓ DONE session 66 — server filters by last_modified, browser sends ?since=<B32ntime>; key bug: lastNtime > 0 fails when B32 string (NaN > 0 = false), fixed to truthy check
- inline subroutine warning ✓ DONE session 66 — extracted to plugin.web.space.orbital.synthetic-zenka-node; double-load root cause fixed in base.cmd.reload
- repair-jobsite-encoding: committed (1916318) but damages files (zeroes text fields); do not run again without investigation
- bin/dev/merge-jobsite-from-backup: useful script, exists on disk, not yet committed
- assessment re-run: 306 jobs status=new (294 reset from repair_failed + 12 new); coding zenka scan in progress

## shm pipeline (next major infra)

- task file: data/tasks/shm-streaming-payload-pipeline.md
- replaces chunked sync with single authenticated streaming POST
- ntime:bytes:lines:BMW384 header, C25519 sig, Twofish per-zenka encryption
- progressive validation gates — reject at cheapest gate first
- two-layer replay protection (time window + per-sender ntime watermark)
- dispatch to kimi when clients.http.* is proven stable

## model self-selection

- task file: data/tasks/coding-model-selection-template.md
- model selects backend via subtask dispatch with preferred_model + mandatory reason
- reason field as confusion filter AND forensics audit trail

## BMW384 iris — future directions

- **animated**: auto-refresh as modules are signed, live topology monitor
- **interactive**: click node → highlight color-radius neighbors, show routing candidates
- **route arcs**: find-route result drawn as arc across wheel, color-coded by resonance
- **namespace layers**: separate rings per namespace (base.*, kimi.*, jobsite.*)
- **favicon/header**: 26-ring iris at thumbnail scale as live system-state favicon

## completed session 50 (2026-05-24)

- branch.calc.fraction.* + branch.cluster.*: kimi validation pass — 5 files fixed (TRUE/FALSE barewords, sub _gcd wrappers, $_ in map); all 6 acceptance checks pass ✓
- kimi_dispatch + kimi_continue timeout raised 47min → 77min (bin/mcp-server-p7)
- INTENT-CLASSIFICATION-AND-SELF-IMPROVEMENT.md: help-as-signal, regex tier 1, LLM tier 2, deferred self-improvement cycle, network patch sharing
- SEMANTIC-BACKCHANNEL-AND-DEDUPLICATED-COMMUNICATION.md: identity-content coupling as root failure; context alignment + dedup + normalization; suppression→forensic; no eviction by arithmetic impossibility
- semantic-dedup-tree.yaml: reasoning template — one currency, open mapping, overdetermined self-correcting correlations
- HARMONIC-TREE-ADDRESSING.md: minimal distance principle, route=address, rollover dialing, algebraic exclusion, self-annealing equilibrium, islanded data reintegration, pausing as cycle-based load balancing, computation placement = data placement, transport as eternal network work

## session 50 potential next steps

- tree.route.page Z.Y.X update: word_graphical encodes col+row but not Z-depth
- graphical word design doc: character rotation (3 Z-states), X/Y symmetry collapse, edge-on semi-invisible state
- branch.session integration with task zenka: dag.open_list + policy.next_hop → task zenka scheduling loop
- branch.cluster intent template (layer 4): only task (layer 1) + design (layer 3) exist
- branch.calc.fraction intent template: same — layer 4 missing
- proxy-zenka-skeleton dispatch: task file ready, not yet dispatched
- transport-selector dispatch: same
- credential-fabric dispatch: same
- intent-classification modules: intent.* + backchannel.* namespaces
- overview + describe commands: cube-level orientation commands

## completed session 49 (2026-05-24)

- branch unified theory: design doc + reasoning template extended
- 58 new modules: branch.field.*(9) + branch.calc.fraction.*(10) + branch.cluster.*(8) + branch.session.*(14) + tree.sort.trunk.*(5) + tree.route.page.*(12)
- Z.Y.X coords, rollover dual semantics, chained usefulness, mask/canvas orthogonality, holographic devices
- kimi_dispatch completed 4 task files; kimi_continue timed out on 2 (fixed in session 50)

## completed session 48c (2026-05-23)

- X-11 nvidia GPU monitoring: handler + 3 bug fixes (whitelist, fh scope, regex lvalue)
- X-11.init_code: intel binary noise fix (file.which silent lookup)
- GPU STRM subscription + coding zenka feed + sparkline (3 phases)
- MCP external command config table + kimi_dispatch tool
- data/yaml/reasoning-templates/holographic-grid-interface.yaml (733 lines)
- v7-teardown-whitelist ✓ — access.cmd.usr.system = v7.teardown in v7/start; SOURCE alias in cube/command_aliases; test pending with devmod switch-user
- MCP kimi_dispatch/kimi_continue: LIVE — 47min timeout, session resume via kimi -r <uuid>

## planned / future

- SHM streaming pipeline — data/tasks/shm-streaming-payload-pipeline.md
- model self-selection — data/tasks/coding-model-selection-template.md
- sourcecode normalize-endline-state — data/tasks/sourcecode-normalize-endline-paths.md
- privacy credentials — data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md
- HTTP sync — /api/jobs/sync httpd endpoint, C25519-signed YAML
- USB backup zenka — udev insertion → backup task tree
- site-auth zenka — session/auth for login-gated scrapers
- job automation — jobtracker integration (HTML/JS, CSV/PDF), email reply monitor
- base.handler.command refactor — data/md/development/BASE-HANDLER-COMMAND-REFACTOR-PLAN.md

## in flight (session 2026-07-26)

- **perlmod load/autoload cleanup**: 152 candidate call sites categorized by
  K2.7 (`data/tasks/perlmod-categorization-results.md`); human review found
  6 misclassifications and a broader templated-reasoning problem, so a K3
  re-verification of all 59 current MOVE rows was dispatched
  (`data/tasks/perlmod-move-reverification.md`). Re-verification confirmed
  11/59 (`perlmod-move-reverification-results.md`), and the actual refactor
  (`perlmod-move-confirmed-refactor.md`) **LANDED `d3f3ac001` (2026-07-26)**
  — all 11 confirmed hot loads moved into init_code. Closed; corrected
  2026-07-30 (this entry previously said "expected results", which was
  already stale by then). See
  [[feedback-perlmod-categorization-review-catches]] for the full trail.
  Two real fixes landed ahead of the bulk cleanup: `Perl::Tidy` →
  `coding.init_code`, `AMOS7::Twofish` → `p7-log.init_code`.
- **`base.devmod.dump_var` / `*main::dump_var` wrapper**: implemented in
  `modules/base.init_code`, gated on `ref($code{'devmod.dump'}) eq 'CODE'`
  (same canary `devmod.cmd.unload-devmod` already uses) — confirmed
  committed as of 2026-07-30 (working tree clean, wrapper present); the
  "unstaged, pending sign/stage" note above was stale.

## open bugs (session 37)

- source.extract_sig_body: YOURUM fake stubs 1 char too long → size mismatch → error instead of strip
  (still open; a DIFFERENT fake-footer disguise — sequential-pattern, not size-mismatch-triggered —
  was found+fixed 2026-07-24, see [[topic-fake-signature-footer-detection]])
- signature oscillation Variant B — double-footer on never-signed non-empty files
- ~~signature endline restoration~~ — FIXED session 48b: stale delta clamp + normalize recovery
- repo var/ cleanup — var/httpd/ tracked from Nov 2025 AI error
- kimi auto-approval regression (Apr 16) — some tool calls not auto-approved

## open bugs (session 39 — letsencr)

- visual.v7.ax ACME timing race — vhost rescan not complete before LE validates; cert renews on retry but needs proper fix
- letsencr cert PEM format — fix committed (remap bundle fields), pending next renewal cycle

## Glitter 4B quirk

After a failed tool-using task, Glitter backend needs restart before `:no_tools:` tasks work. Model gets stuck in tool-mode. Restart coding zenka or wait before dispatching `:no_tools:` priming tasks.

## queued (2026-07-29) — security task-tree: deferred domains + zenki

security agent task tree (`data/tasks/openvas-agent.md`, `nessus-agent.md`,
`forensics-agent.md`, `forensic-report-pipeline.md`,
`security-intel-embedding-domains.md`, `build-zenka.md`, `ext-pkg-zenka.md`)
landed this session. openvas-agent phase 1 (zenka scaffold + `openvas.scan.run`
backend wrapper, greenbone-container/gvm-tools control path) is implemented
and file-verified but NOT yet boot-tested live. deliberately deferred, so
they don't get silently dropped:

- **security-intel-embedding-domains task 1.1b** — cve (NIST NVD, large
  multi-decade archive), mitre ATT&CK, cwe, and nvt (reuses openvas's feed
  sync) domains still unfetched. only cisa KEV (task 1.1a, 1655 entries,
  `data/protocols/cisa/`) is done. task 1.2 (train fasttext embeddings per
  domain) and phase 2 (unified loader, retrain triggers) also untouched.
  CVE/NVD size needs its own scoping pass before dispatch — do not assume
  the cisa-KEV size/tracking precedent extends to it.
- **build-zenka.md and ext-pkg-zenka.md** — both fully drafted (git-build/
  tarball-extract/vendor-deb/pip-venv recipe kinds; pip/npm/uv-tool
  package-manager zenka for kimi-cli + claude) but neither dispatched at
  all — greenfield, phase 1 not started.
- **os-pkg zenka** — still a bare stub (`modules/os-pkg.init_code` is
  `0;`), referenced by build-zenka/ext-pkg-zenka as the apt/dpkg sibling;
  its own implementation was never scoped as a task file.
- **forensics-agent, forensic-report-pipeline, nessus-agent** — task files
  only, correctly self-gated (forensics needs the topic-10 research
  extraction first; report-pipeline needs openvas+forensics phase 1-2;
  nessus is explicitly after openvas) — not a gap, just not reached yet.
- kimi_dispatch reliability note for next time: `auto_summarize`'s local-9B
  summarization step can hang independently of kimi's own work completing
  (kimi exits clean, coding-zenka queue shows real completion, but the MCP
  tool reports "failed" after a 30min idle timeout waiting on the
  summarizer) — pass `auto_summarize: false` for tasks like these, or
  cross-check `p7_task_queue`/`coding.show-buffer model_output` before
  assuming a reported failure means no work happened.

#,,,,,,.,,.,,,.,.,,..,,.,,,..,,.,,,..,.,.,.,,,..,,...,...,...,,..,,,.,,..,,.,,
#B2FJLPOEQA6SCY2W33PIOSU3ZHSINY22DJZCWZQT625UTCKQSWQSYF6DSZFFRTD24BPQ4DCQWK34Y
#\\\|XEOEFVUUCCXSTM5HBUCGJQVIEXNSIT2LO6TFGZYWTUYTBCMPJVQ \ / AMOS7 \ YOURUM ::
#\[7]CHIAW4ZZKH24OPQ62GYL2W532OOCDCKIWVX7C3ZWVYKMISH2KKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
