## task: resume the data/tasks/ backlog completion-scan

### status [ 2026-07-16 ] — round 2 reconciliation pass complete

round 1 (2026-07-15) moved 25 verified-complete tasks. round 2 was interrupted
by idle-shutdown after partial progress; per-buffer verdicts were rescued from
`/var/protocol-7/coding/completed-task-backups/178416910{2,3}.*/` into
`data/tasks/rescued-last-night.txt` and independently re-verified in this pass.

**this pass (2026-07-16):**
- 21 candidate files previously marked "move to completed [high confidence]" by
the 9B model were re-verified against actual code. 20 confirmed and moved to
`data/tasks/completed/`; 1 (`repo-root-cleanup-var-local-batches.md`) left open.
- 10 files with unclear/cut-off/misleading rescued verdicts were freshly scanned.
2 confirmed complete and moved (`sys-deps-zenka.md`,
`contextualized-error-replies.md`); 2 classified as possibly completed pending
human review; 6 left open.
- **total moved this pass: 22**. **remaining truly never-scanned: 77**.

both rounds ran the local coding zenka (9B model) against the
`tasks-completed` context template, in batches of 3 files, then independently
re-verified every "move to completed" verdict against actual code (grep / test
runs / git log) before moving anything. do not trust the model's verdict alone
— see `data/yaml/context-templates/tasks-completed.yaml` for the scan
instructions.

### what's left

77 files below still need a real scan pass (verified against the live
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
- `graphics-matrix-voxel-space.md` — phases 1-4 modules and UI toggle exist;
  end-to-end behavior not fully exercised; needs human look before moving
- `glitter-cosmology-priming.md` — no reasoning-template YAML conversion found
- `git-watch-zenka.md` — no `git-watch.*` modules or configuration exist
- `mcp-regex-approval-system.md` — no `approval-patterns.yaml` or
  `approval_review` tool; `llm.service.consensus_vote` exists but is not wired
  to MCP approval

### remaining files [ 77, never scanned ]

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
credential-fabric-integration-test.md
credential-fabric.md
credential-fabric-ui-interactive.md
crop-circle-acquisition-pipeline.md
crop-circle-assertion-mask.md
dispatch-create-template.md
dispatch-template-param.md
epoch-bmw-l13-truth-templates.md
epoch-chksum-path-helper.md
epoch-validity-search-protocol.md
external-zenka-completion.md
generate-all-spec-pages.md
git-hooks-version-auto-stage.md
harmonic-quality-correlation-study.md
index-cmd-replace-remove.md
index-contribution-vector-store.md
index-cube-storage-cache.md
index-cube-storage-format.md
index-cube-storage-migrate.md
index-cube-storage-verify.md
inline-subs-batch-3.md
inline-subs-batch-4-final.md
inline-subs-batch-misc.md
inline-subs-batch-weather-language.md
installer-zenka-template-flow.md
jobsite-checksum-store-dirs.md
jobsite-cmd-progress.md
jobsite-progress-bar-review-fix.md
jobsite-scan-state-slim.md
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
mcp-server-p7-external-commands.md
memory-cmd-focus.md
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
sourcecode-normalize-endline-paths.md
space-engine-grid-orbit.md
space-engine-template.md
stdio-frame-encode-inline-subs.md
sub-bit-element-definition.md
sys-deps-zenka-audit.md
taws-integration.md
transport-selector.md
tree-sort-trunk-route-page.md
web-jobs-status-dir-layout.md
web-sessions-distributed.md
x11-capture-commands-rewrite.md

#,,,.,.,,,,.,,,.,,.,,,.,.,,,,,,,,,...,.,.,,..,..,,...,..,,.,.,..,,..,,,..,,,,,
#2JQJKS62QPYV57MJYGLHCKHVOGJP67V22ENQQLMZ3VBKW6R4NGZQXAI24RQGCTMOWPICVEHWMKDZ6
#\\\|DMBKUTUKUVP63HIR6V67B24O3DHPMOKDL2IEFA24HSQ3BB5OB2L \ / AMOS7 \ YOURUM ::
#\[7]SRWJVWNEAJVRQ6BPFGQXOYPGUU5PI3MWHDSYFCQOBZJMCEDFXMCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
