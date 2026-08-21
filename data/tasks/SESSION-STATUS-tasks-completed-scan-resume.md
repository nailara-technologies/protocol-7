## task: resume the data/tasks/ backlog completion-scan

### status [ 2026-07-16 ] — round 3 reconciliation pass complete

round 1 (2026-07-15) moved 25 verified-complete tasks. round 2 was interrupted
by idle-shutdown after partial progress; per-buffer verdicts were rescued from
`/var/protocol-7/coding/completed-task-backups/178416910{2,3}.*/` into
`data/tasks/rescued-last-night.txt` and independently re-verified in that pass.

**this pass (2026-07-16):**
- 22 active/load-bearing task files from the remaining list were scanned
  against actual code. 8 were confirmed complete and moved to
  `data/tasks/completed/`; 9 classified as possibly completed pending human
  review; 5 left open. 3 additional jobsite UI files were already handled
  in a previous pass and were skipped this round.
- **total moved this pass: 9** (`jobsite-scan-state-slim.md`,
  `jobsite-sync-push-status-dir.md`, `jobsite-ui-card-refinements.md`,
  `credential-fabric.md`, `mcp-claude-dispatch.md`,
  `mcp-coding-summarize.md`, `mcp-server-p7-external-commands.md`,
  `git-hooks-version-auto-stage.md`, `jobsite-ui-reassess-button.md`,
  `jobsite-ui-interviewed-tab.md`, `jobsite-ui-flexible-export.md`,
  `jobsite-cmd-progress.md`, `jobsite-checksum-store-dirs.md`,
  `jobsite-progress-bar-review-fix.md`, `memory-cmd-focus.md`,
  `sourcecode-normalize-endline-paths.md`, `credential-fabric-integration-test.md`).
  **remaining truly never-scanned: 52**.

  `credential-fabric-integration-test.md` needed real new infrastructure,
  not a quick fix: a generic per-invocation env-override capability for
  `v7.start` (`:env:KEY=VALUE:` tag, same shape as the codebase's existing
  `:model:...:`/`:sign-silent:` tag convention), gated by a new
  `env_override_allowed` directive each target zenka declares in its own
  trusted `start.cfg` (not caller-controlled — a caller can only
  supply a *value* for a key the target zenka itself opted into, closing
  off arbitrary env injection like `LD_PRELOAD`). `cred-mesh`/`proxy`/
  `transport` now declare `env_override_allowed = PROTOCOL_7_VAR`;
  `base.path-set-up.zenka-directories` honors that env var for `var_P7`;
  the two test scenario scripts derive `relay_pending.yaml`'s path from it
  instead of hardcoding `/var/protocol-7/...`. Caught and fixed a real
  injection bug during review: the exec-external code-generation path
  used shell-style quote-escaping (`'\''`) on a value embedded in
  generated Perl source text, which doesn't neutralize a `'` in Perl
  syntax — fixed to proper `\'` escaping (also fixed the same latent
  pattern in the pre-existing, dormant `env_include` loop next to it).
  User confirmed v7 reloads clean, signed and staged. Live end-to-end run
  of `bin/dev/cred-mesh-test` still pending.

  `sourcecode-normalize-endline-paths.md`: parts 1 (canonical-path
  normalization in `source.cmd.get-code-signed`) and 3 (underflow guard in
  `source.restore_payload_endline_state`) were already done; only part 2
  (the standalone `normalize-endline-state` command) was missing. New
  module dynamically re-decodes the actual post-resign state rather than
  assuming the task file's illustrative "state → 6" example literally —
  confirmed via `source.harmonize_payload_line_feed`'s own comment that
  state 5 is the true idempotent/canonical target, not 6.

  `memory-cmd-focus.md`: the `set`/`boost`/`apply`/`clear` mutation
  branches returned `mode=>'size'`; switched to `mode=>'true'/'false'`
  per the `.cmd.` reply contract (matching `jobsite.cmd.blacklist-add`'s
  established convention), `get` correctly stays `size`. Verified via
  `ptd -c` (plain `perl -c` chokes on this codebase's `<var> = value`
  tree-assignment syntax — use the project's own checker, not bare perl).

  `jobsite-progress-bar-review-fix.md` was ~95% done already — both spec
  parts (directory-authoritative status sync in `jobsite.job.load_all`,
  index-scanned counts in `jobsite.cmd.progress`) were fully implemented;
  only `$applied`/`$rejected` were computed but dead. Added them to the
  right-bracket display, one-line fix.

  `jobsite-checksum-store-dirs.md` was a genuine gap, not a scan
  false-negative — actual title-dedup code, dispatched to kimi and
  landed. (Initially looked like ANOTHER false-negative when the user
  found real files under `/var/protocol-7/jobsite/checksum-store/titles/`,
  but those were confirmed orphaned/stale — dated 2026-06-25 to 07-01,
  from an abandoned status-subdir design that predates and doesn't match
  this task's flat `titles/<chksum>` spec. `jobsite.checksum.index`'s
  `check`/`add`/`stats` actions genuinely had no title-dedup logic before
  this fix — verify claims like this against code AND timestamps, not
  just directory existence.)

  `jobsite-cmd-progress.md` was flagged "possibly completed" pending two
  gaps: (1) missing `access.cmd.usr.taeki = jobsite.progress` line — moot,
  user confirmed taeki already gets `access.cmd.usr.<admin-user> = ** ..*.**`
  (wildcard) via `cfg/zenki/cube/access.users`, and the task's own
  spec says only add the line if no wildcard exists; (2) idle-bracket text
  differs from the spec's example — confirmed real but cosmetic: actual
  code shows `new/rev/assessed/apply` (superset, extra field) vs spec's
  `assessed/review/new`, same stats just reordered/reformatted. Moved.

  all three files in the jobsite-ui trio (`reassess-button`,
  `interviewed-tab`, `flexible-export`) had been flagged "still open" by a
  *previous* round-1 scan — all three verdicts were WRONG. reassess:
  `.btn-reassess` wired to `pushChange(id, {action:'reassess'})` +
  `jobsite.sync.apply_reverse`. interviewed-tab: full stage/filter/
  amber-gold styling/gesture-flow/export support, landed 2026-05-31 per
  git log. flexible-export: `#export-panel` with stage checkboxes/sliders,
  `.export-since-last-cb` filter, `showPrintTable()` — user confirmed live
  use sending reports. All three confirmed live by the user directly.
  Caught because round 3 was told to skip this trio as "already handled" —
  a reminder that round-1 "still open" verdicts aren't automatically
  trustworthy just because they're old.

all "move to completed" verdicts were independently verified against actual
modules / git log before `git mv`; do not trust model verdicts alone — see
`data/yaml/context-templates/tasks-completed.yaml` for the scan instructions.

### what's left

52 files below still need a real scan pass (verified against the live
`data/tasks/` directory listing, not batch bookkeeping — task IDs get
confusing across restarts).

**lesson for next run: do not reload/restart the coding zenka while a batch
scan is in flight.** roughly 37 of 54 batches failed this session because of
GPU backend restarts triggered by `coding.reload` / `v7.restart coding`
calls made mid-scan for unrelated work. in-flight requests get orphaned
(dangling `http_state`, `completed=1` with 0 bytes received — check via
`p7c coding.tree-read "coding.async.task_state.<task_id>.http_state"`) or
fail outright with `connection refused`. use `coding.round-time` /
`coding.round-progress` / `coding.status` (failed count) to check zenka
health before and during a scan, and `coding.abort-inference` (only affects
`<coding.task.active>[0]`, call repeatedly) to clear anything genuinely
wedged — verify with `p7c coding.failed` for the real error before assuming
a stall.

resume by submitting these in batches of 3 via:
```
bin/coding-task -template tasks-completed "focus only on these task files, \
don't scan the whole directory: <file1>, <file2>, <file3>. read each with \
read_file, check for matching commits or existing code, and report per the \
template's output format."
```
or non-blocking via `p7c coding.submit "B32:<b32r-encoded prompt>"` +
`p7c coding.get-result <task_id>` polling (see git history around commit
5a5da2707 for the batch-runner script pattern — it lived in a scratchpad
dir, not committed). submit all batches up front (the queue is a real FIFO
with priority scoring, not naive serial) then harvest results out of order
by checking `/var/protocol-7/coding/results/<task_id>` directly rather than
polling strictly in submission order.

### already verified this session, don't re-scan [ still open / possibly completed ]

- `amos7-shm-log-channel-handshake.md`, `amos7-shm-coding-zenka-prompt-transport.md` —
  design-only, no integration code (directly grepped)
- `amos7-shm-use-case-taxonomy.md` — consolidating design doc, not a code deliverable
- `amos7-chksum-consolidation.md`, `base-parser-list-width.md`,
  `base-callback-data-tree-modes.md` — no matching code found
- `bmw-truth-template-family.md`, `branch-calc-bandwidth-temporal.md`,
  `branch-layer3-routes-keys.md` (partial), `branch-layer4-storage-data.md`,
  `branch-layer5-9p-bridge.md`, `branch-layer6-file-abstraction.md`,
  `branch-session-dag.md` (8/17 modules, partial) — no/partial matching code
- `coding-self-error-processing-cycle.md` — `coding.error.*` namespace empty
- `twin-drain-cube-backchannel.md` — 3/4 modules exist, recovery path unverified
- `v7-console-log-filter-overlay.md`, `v7-console-per-zenka-tree-view.md`,
  `v7-stdout-foldable-relay.md` — no matching modules
- `v7-lpw-sync-debug.md` — partial fix applied, core issues still open
- `valued-node-list.md`, `valued-tree-task-zenka-integration.md` — no matching code
- `visual-feedback-capture-analyzer.md`, `visual-feedback-vision-loop.md`,
  `visual-mask-model-layer.md` — no matching code, stub/spec-only tasks
- `wayland-screenshooter-perl-prototype.md`, `web-auth-plugin.md`,
  `web-browser-input-capture-replay.md` — no matching code
- `repo-root-cleanup-var-local-batches.md` — tracked files still at original
  repo-relative paths; `web.assets.load_registry` still uses `$project_root/var/httpd/static/`
- `task-archiving-with-context-templates.md` — no `bin/dev/archive-task` script;
  dispatch-workflow context templates exist but core intelligent archiver missing
- `task-summary-topic-tree.md` — phase 1 implemented and live-verified
  (`task.cmd.summary-tree-*`, `coding.cmd.summarize-context tree=1`, mcp-server-p7
  relay); phases 2-4 (tree structure/routing/classification, delta storage,
  idle integration) still open
- `context-management-system.md` — no `coding.context-*` modules exist
- `cosmic-space-visualization-layer.md` — no `cosmic.scene.from-coordinate`
  module or iris integration found
- `glitter-cosmology-priming.md` — no reasoning-template YAML conversion found
- `git-watch-zenka.md` — no `git-watch.*` modules or configuration exist
- `mcp-regex-approval-system.md` — no `approval-patterns.yaml` or
  `approval_review` tool; `llm.service.consensus_vote` exists but is not wired
  to MCP approval

**round 3 additions:**
- `jobsite-sync-multiplex.md` — `jobsite.cfg.sync_urls` list iteration and
  per-URL `last_ntime` implemented; multi-jobsite reverse fan-out and
  `connected_jobsites` not implemented
- `web-jobs-status-dir-layout.md` — web cache uses status subdirs,
  atomic rename, in-memory index, merge function and two-phase prune;
  `assessed` is mapped to `review` in the web store and no `id+status`
  path helper is exposed
- `credential-fabric-ui-interactive.md` — phase 2 selection/actions
  (up/down/refresh/select_view/action/input) and prompt templates
  implemented; phase 3 key-holder unlock dialog and `UNLOCK` op missing
- `index-cube-storage-cache.md` — no `index.cube.cache`, LRU, or
  `index.cmd.cache-stats` found
- `index-cube-storage-format.md` — cube format exists but is schema v4
  with JHash checksums, not the task's schema v3 with AMOS7 checksums
- `index-cube-storage-migrate.md` — no `index.migrate.v2-to-v3`,
  `index.cube.detect_schema`, or migration trigger in
  `index.persist.cube`
- `index-cube-storage-verify.md` — no per-compartment checksum
  verification, `index.cube.verify_chain`, or `index.cmd.verify-cube`
- `x11-capture-commands-rewrite.md` — `X-11.cmd.capture-window` and
  `capture-region` still use `system()` and accept `output_path`; no
  `X-11.handler.capture_reply`

### remaining files [ 52, never scanned ]

branch-dep-graph.md
branch-field-open-state.md
branch-fraction-cluster-validate.md
calc-truncated-rational-output.md
claude-design-suggest-templates.md
coding-task-model-pinning.md
command-relay-zenka.md
configure-zenka-fallback-ui.md
console-foldable-render-baseline.md
console-fold-primitive.md
context-aware-scale-navigation.md
crop-circle-acquisition-pipeline.md
crop-circle-assertion-mask.md
dispatch-create-template.md
dispatch-template-param.md
epoch-bmw-l13-truth-templates.md
epoch-chksum-path-helper.md
epoch-validity-search-protocol.md
external-zenka-completion.md
generate-all-spec-pages.md
harmonic-quality-correlation-study.md
index-cmd-replace-remove.md
index-contribution-vector-store.md
inline-subs-batch-3.md
inline-subs-batch-4-final.md
inline-subs-batch-misc.md
inline-subs-batch-weather-language.md
installer-zenka-template-flow.md
keyring-phase1.md
kitten-acquisition-pipeline.md
litter-row-encoding.md
log-anonymization.md
memory-maintenance-2026-05-29.md
ncode-workflow-patterns.md
ncode-zenka-modules.md
network-elf-avatar-pipeline.md
research-knowledge-base-extraction.md
ring-routing-phase1.md
screenshot-zenka-style-refresh.md
select-region-zenka-clone.md
SESSION-STATUS-tranche1-followup.md
shm-streaming-payload-pipeline.md
signal-cancel-log-library.md
space-engine-grid-orbit.md
space-engine-template.md
stdio-frame-encode-inline-subs.md
sub-bit-element-definition.md
sys-deps-zenka-audit.md
taws-integration.md
transport-selector.md
tree-sort-trunk-route-page.md
web-sessions-distributed.md

#,,..,,.,,.,,,,,.,,..,.,.,.,.,,..,.,.,.,.,,,.,..,,...,...,,,,,.,.,..,,,,,,.,,,
#L5Y7LOI5E4JVEBLEHVNJJFUYTOYCKISHWS6GQ5UJ6RVSFFZIZFFTTZXSYKIKIUSKZPPB3BD3E4HM6
#\\\|3V6M5NM7EMHKWBMEZQS5ZJB5GECZDERNRGSHWTBDSO4T3NK5UX7 \ / AMOS7 \ YOURUM ::
#\[7]PKZPQLP7ZEBJMCJ5TADRPCNI6ZVUCXCDLYMG42R3G5WORKTGDYDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
