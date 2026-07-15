## task: resume the data/tasks/ backlog completion-scan

### status [ 2026-07-15 ]

session moved 25 verified-complete tasks to `data/tasks/completed/` by running
the local coding zenka (9B model) against the `tasks-completed` context
template, in batches of 3 files, then independently re-verifying every
"move to completed" verdict against actual code (grep / test runs / git log)
before moving anything. do not trust the model's verdict alone — see
`data/yaml/context-templates/tasks-completed.yaml` for the scan instructions.

### what's left

113 files below (verified against the live `data/tasks/` directory listing,
not against batch bookkeeping — the batch runner's task IDs got confusing
after a mid-session restart resubmitted the same files under new IDs) never
got a real scan pass.

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

### already verified this session, don't re-scan [ still open, no action needed ]

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

### remaining files [ 113, never scanned ]

branch-dep-graph.md
branch-field-open-state.md
branch-fraction-cluster-validate.md
calc-truncated-rational-output.md
checksum-nested-addressing.md
claude-design-suggest-templates.md
coding-task-model-pinning.md
command-relay-zenka.md
configure-zenka-fallback-ui.md
console-foldable-render-baseline.md
console-fold-primitive.md
context-aware-scale-navigation.md
context-management-system.md
contextualized-error-replies.md
cosmic-space-visualization-layer.md
credential-fabric-integration-test.md
credential-fabric.md
credential-fabric-ui-interactive.md
credential-fabric-wiring-verify.md
crop-circle-acquisition-pipeline.md
crop-circle-assertion-mask.md
dep-graph-stdout-self-healing.md
design-template-suggestions.md
dispatch-create-template.md
dispatch-template-param.md
epoch-bmw-l13-truth-templates.md
epoch-chksum-path-helper.md
epoch-validity-search-protocol.md
external-orbital-connect-test.md
external-zenka-completion.md
fix-double-plugin-load-on-reload.md
generate-all-spec-pages.md
git-hooks-version-auto-stage.md
git-watch-zenka.md
glitter-cosmology-priming.md
graphics-matrix-voxel-space.md
harmonic-quality-correlation-study.md
httpd-web-relay-async.md
index-cmd-replace-remove.md
index-contribution-vector-store.md
index-cube-storage-cache.md
index-cube-storage-format.md
index-cube-storage-migrate.md
index-cube-storage-reader.md
index-cube-storage-verify.md
index-cube-storage-writer.md
index-job-control-multiplexing.md
index-lookup-search.md
index-persist.md
index-source-map-active-set.md
index-terminal-boundary-tracking.md
inline-subs-batch-3.md
inline-subs-batch-4-final.md
inline-subs-batch-misc.md
inline-subs-batch-weather-language.md
installer-zenka-template-flow.md
jobsite-checksum-store-dirs.md
jobsite-cmd-progress.md
jobsite-progress-bar-review-fix.md
jobsite-scan-state-slim.md
jobsite-status-dir-layout.md
jobsite-status-stage-reconcile.md
jobsite-store-prune-wiring.md
jobsite-sync-multiplex.md
jobsite-sync-push-status-dir.md
jobsite-ui-card-refinements.md
jobsite-ui-flexible-export.md
jobsite-ui-interviewed-tab.md
jobsite-ui-reassess-button.md
keyring-phase1.md
kitten-acquisition-pipeline.md
litter-row-encoding.md
log-anonymization.md
mcp-claude-dispatch.md
mcp-coding-summarize.md
mcp-regex-approval-system.md
mcp-server-p7-external-commands.md
memory-cmd-focus.md
memory-cmd-search.md
memory-context-pipeline.md
memory-maintenance-2026-05-29.md
ncode-workflow-patterns.md
ncode-zenka-modules.md
network-elf-avatar-pipeline.md
proxy-zenka-skeleton.md
reasoning-branch-orchestration.md
repo-root-cleanup-var-local-batches.md
research-knowledge-base-extraction.md
ring-routing-phase1.md
screenshot-zenka-style-refresh.md
select-region-zenka-clone.md
SESSION-STATUS-tranche1-followup.md
shm-streaming-payload-pipeline.md
signal-cancel-log-library.md
sourcecode-normalize-endline-paths.md
space-engine-grid-orbit.md
space-engine-route-travel-jump.md
space-engine-template.md
stdio-frame-encode-inline-subs.md
strip-dispatch-json-boilerplate.md
sub-bit-element-definition.md
sys-deps-zenka-audit.md
sys-deps-zenka.md
task-archiving-with-context-templates.md
task-summary-topic-tree.md
taws-integration.md
transport-selector.md
tree-sort-trunk-route-page.md
web-jobs-status-dir-layout.md
web-sessions-distributed.md
x11-capture-commands-rewrite.md
x11-monitor-registry.md
zenki-resolve-primary-sid.md

#,,,,,.,,,...,..,,,,.,,,.,,..,..,,,.,,..,,,,.,..,,...,...,,.,,,,,,...,,,.,.,,,
#R6DK5EQNPN3ZUL3ON3LINRV2STP64RMPVC5DJFEQC6RHOF6M6YWDA324HI3IZS6MJIVRFQRMCSIHC
#\\\|EKOZDPZNB26JF7TIFVOMM5ZC6FQ5YIGVD5PIIIOLCCPFHTA7X5R \ / AMOS7 \ YOURUM ::
#\[7]O5AJIM33T6UXZQTQ2W6U5VD7JPQOOWF6ZCI7UC26GVKDQDRIKACA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
