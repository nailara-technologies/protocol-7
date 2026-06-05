---
name: next-steps
description: "active task queue, roadmap items, open bugs, and planned work"
metadata:
  node_type: memory
  type: project
  originSessionId: 56cce73a-933a-4992-96e4-4d88e138e8f6
---

## completed this session (2026-06-06)

- **memory context pipeline** ✓ — `memory.render.context` writes cache file; `context.memory.load` reads scored tree; `memory.startup` primes on init (commit aa0b24c9d)
- **MCP memory tools** ✓ — `p7_memory_search` + `p7_memory_digest` in `bin/mcp-server-p7` (commit fae65a85d); live after MCP restart

## completed previous session (2026-06-05)

- **memory IDF search** ✓ — `memory.tree.score.idf_weight` + `wordcount` + `rebuild_idf`; pass-2b in scorer; live
- **memory.digest pipeline** ✓ — `memory.cmd.digest` + `memory.digest.done`; deferred SIZE reply via `cube.coding.summarize-context`; DeepSeek R1 0528 (8B Q8) confirmed working
- **DeepSeek-R1-0528-Qwen3-8B** ✓ — registered `CSABG4A:KENZBPY`; loaded as coding zenka backend

## open bugs

- ~~nshell (0) on first command~~ **FIXED 2026-06-02** — orphaned route handler in `base.handler.command` generated `(0)!TERM!` for prefix-less replies (`cmd_id == 0`); guard added
- **nshell stray cursor**: `index.cmd.search/lookup/stats` added trailing `\n` to inline SIZE replies (commit DE5EAEA4); nshell output handler may be double-newlining — check `nshell.handler.strm_reply`
- **STRM fix review needed**: `had_local_consumer` fix correct for local consumer; relay path unchanged; test needed on radio zenka and other STRM consumers

## iris visualization queue (dispatch to kimi one by one)

- **iris alpha-density v2**: data/tasks/iris-alpha-density-mode-v2.md — filter-safe, dispatch next
- **iris ring ledger**: data/tasks/iris-ring-ledger-mode.md — 3+1 octal counters, separator flash
- **iris route-commitment**: data/tasks/iris-route-commitment.md — future arcs bright/past dim
- **iris dimension-rotator**: data/tasks/iris-dimension-rotator.md — H/V view toggle
- **iris cascade-warning**: data/tasks/iris-cascade-warning.md — pre-flash amber warning
- **iris separator-pulse**: data/tasks/iris-separator-pulse.md — routing infrastructure visible
- **iris temporal**: data/tasks/iris-temporal-mode.md — radial=time, git blame as orbital map
- **iris boundary**: data/tasks/iris-boundary-mode.md — stained glass event horizons
- **iris negotiation-window**: data/tasks/iris-negotiation-window.md — floor budget urgency
- **iris oscilloscope**: route-send SIZE relay to index — verify working after httpd+index+zulum restart

## pending tasks (from session 37 queue)

- `data/tasks/weather-forecast-humidity.md` — re-enable humidity API field
- `data/tasks/mpv-xephyr-vo-override.md` — test gpu vs sdl under xephyr
- `data/tasks/diff-modified-no-color-mode.md` — --no-color flag
- `data/tasks/kimi-zenka-multiplexer.md` — STRM dispatch + queue + sudo auto-decline
- `data/tasks/credentials-zenka.md` — encrypted credential store, per-zenka authorization
- `data/tasks/x11-wait-visible-host-mode-skip.md` — capability flag, skip on WSL
- `data/tasks/zenka-window-placement-profiles.md` — window.* namespace (re-dispatch after rename)

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

## open bugs (session 37)

- source.extract_sig_body: YOURUM fake stubs 1 char too long → size mismatch → error instead of strip
- signature oscillation Variant B — double-footer on never-signed non-empty files
- ~~signature endline restoration~~ — FIXED session 48b: stale delta clamp + normalize recovery
- repo var/ cleanup — var/httpd/ tracked from Nov 2025 AI error
- kimi auto-approval regression (Apr 16) — some tool calls not auto-approved

## open bugs (session 39 — letsencr)

- visual.v7.ax ACME timing race — vhost rescan not complete before LE validates; cert renews on retry but needs proper fix
- letsencr cert PEM format — fix committed (remap bundle fields), pending next renewal cycle

## Glitter 4B quirk

After a failed tool-using task, Glitter backend needs restart before `:no_tools:` tasks work. Model gets stuck in tool-mode. Restart coding zenka or wait before dispatching `:no_tools:` priming tasks.

#,,..,.,,,.,,,,,.,.,,,,.,,...,.,,,.,,,,,.,.,,,..,,...,...,,.,,.,,,.,,,,,,,,,.,
#RKZZ5TTCQYDYGJZVHS64AG4UNR5Q4AH4WM54QNWFIMZOH5SGN6OAGYJ26CJRVK6XY5XLSEQOKOOWC
#\\\|YNXNVUT24EHFQQYNVBHDJ4ELZ2NHEMOSDPZLXOFFFORHLX6PV7W \ / AMOS7 \ YOURUM ::
#\[7]LU7RWZQB3YI3IJ56B54MPF7KJE2XMV2HO7IGSYSTCBKCXVDA7GAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
