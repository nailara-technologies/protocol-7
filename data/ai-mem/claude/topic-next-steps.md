---
name: next-steps
description: "active task queue, roadmap items, open bugs, and planned work — full detail for planning sessions"
metadata: 
  node_type: memory
  type: project
  originSessionId: 56cce73a-933a-4992-96e4-4d88e138e8f6
---

## open bugs (session 63)

### nshell (0) on first command (each session) — partially fixed, source unknown
something in nshell sends `(0)<something>\n` exactly once per session at startup
(triggered visibly on first user command). `$re->{cmd_id} = \d{2,15}` — single
digit 0 fails the length check → cube logs "command id syntax not valid [0]",
nshell prints "invalid command id syntax or length". command still executes.
earlier form: explicit `(0)` check said "command id 0 not valid". partial fix
removed that check, now falls through to generic syntax error instead.
source UNCONFIRMED after prior kimi investigation (100 rounds, May 1):
NOT from log send system (`send.local` debug ruled it out). NOT from cmd_id
counter starting at 0 (user commands don't carry a cmd_id prefix in nshell).
likely from v7.notify_online reply or some other startup buffer entry.
related task file: data/yaml/coding-tasks/nshell-session-protocol-tunneling.yaml

### nshell stray cursor — commit DE5EAEA4 (2026-05-25)
`index.cmd.search/lookup/stats` — added trailing `\n` to inline SIZE replies
to match what `base.callback.cmd_reply` adds for deferred replies.
symptom: stray cursor in nshell after index search/lookup/stats output.
likely cause: nshell output handler was compensating for the missing newline;
fix double-newlines it. check `nshell.handler.strm_reply` or wherever nshell
processes SIZE responses for its own `\n` addition.

### STRM fix review needed (session 63)
`had_local_consumer` fix in base.handler.command STRM close path is correct
for local consumer case. relay path (no local consumer) still fires forward as
before. but test needed: radio zenka (uses both local consumers and relay paths),
and any other STRM consumer, to confirm no undefined state introduced.

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

**iris oscilloscope**: route-send SIZE relay to index — verify working after httpd+index+zulum restart

## session 37 task queue (kimi-cli dispatch)

- `data/tasks/v7-teardown-whitelist.md` — DONE ✓ session 48c (access.cmd.usr.system = v7.teardown + SOURCE alias already in cube/command_aliases; test with devmod switch-user — taeki has full wildcard so need to switch to verify restriction)
- `data/tasks/source-code-header-check.md` — DONE ✓ already completed prior session (parameterized // TRUE, all headers valid)
- `data/tasks/weather-forecast-humidity.md` — re-enable humidity API field (tiny)
- `data/tasks/web-browser-evaluate-javascript.md` — DONE ✓ session 42
- `data/tasks/mpv-xephyr-vo-override.md` — test gpu vs sdl under xephyr
- `data/tasks/diff-modified-no-color-mode.md` — --no-color flag **[dispatched session 42]**
- `data/tasks/x11-gpu-monitoring-vendor-detect.md` — DONE ✓ session 48c (needs longer soak test → needs-testing/)
- `data/tasks/kimi-zenka-multiplexer.md` — STRM dispatch + queue + sudo auto-decline (kimi-cli only)
- `data/tasks/credentials-zenka.md` — encrypted credential store, per-zenka authorization
- `data/tasks/x11-wait-visible-host-mode-skip.md` — capability flag, skip on WSL
- `data/tasks/zenka-window-placement-profiles.md` — window.* namespace (needs re-dispatch after rename)

## session 42 completed

- `data/tasks/source-code-header-check.md` — NOOP ✓ already done prior session
- `data/tasks/web-browser-evaluate-javascript.md` — DONE ✓ → needs-testing/ (evaluate_javascript+JSCValue migration)
- `data/tasks/kimi-web-session-cache-access.md` — DONE ✓ → needs-testing/ (7 new kimi-web modules)
- `data/tasks/diff-modified-no-color-mode.md` — still pending (not dispatched this session)

## infrastructure

- **:::: litter row**: data/tasks/litter-row-encoding.md — 15-bit zenka bitmap in footer
- **iris 63-ring labels**: DONE ✓ namespace63 mode with . at ring 27
- **iris logo overlay**: DONE ✓ nailara at darksun
- **plugin.web.* migration**: DONE ✓ web zenka owns all plugin.web.*
- **jobsite BMW384 dedup**: dispatch bmw384-arc-grouping-filter.md to kimi
- **route.bmw384 find-route testing**: register nodes, verify-coordinate

## roadmap (see IMPLEMENTATION-ROADMAP.md)

- **sub-bit element definition**: data/tasks/sub-bit-element-definition.md
- **generic content layer**: 4b.6 improvement-directed history, git supersession path
- **flexible offset mapping**: 4.7 angle_bits as φ_offset + seed per ring
- **orbital velocity signatures**: 4.8 per-ring speed multipliers, TRUE/FALSE CCW/CW lanes
- **network cycle clock**: 4.9 logically mapping orbital timebase

## jobs pipeline open items

- **profile.txt**: /var/protocol-7/jobs/profile.txt — CV/skills for LLM scoring
- **multi-page search**: stepstone 25/page; cfg.max_pages per category
- **orphan re-queue**: re-create tasks stuck in 'assessing' after restart
- note_read pagination (offset/limit on sections)
- active deps execution (requires list in task dispatcher)
- think-block stripping — `<think>...</think>` from Kimi/Deepseek leaks into output
- task.cmd.start — task zenka step 3
- **model selection for assessment**: `preferred_model` param on task.create needed
- **site-yaml 403 backoff**: currently fixed at 10s; should scale with consecutive count
- **sync ?since=N browser delta**: browser JS still sends full fetch; needs last_modified in index.yaml

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
- **namespace layers**: separate rings per namespace (base.*, kimi.*, jobsite.*) — layer boundaries visible
- **favicon/header**: 26-ring iris at thumbnail scale as live system-state favicon

## completed session 50 (2026-05-24)

- branch.calc.fraction.* + branch.cluster.*: kimi validation pass — 5 files fixed (TRUE/FALSE barewords, sub _gcd wrappers, $_ in map); all 6 acceptance checks pass ✓
- kimi_dispatch + kimi_continue timeout raised 47min → 77min (bin/mcp-server-p7)
- INTENT-CLASSIFICATION-AND-SELF-IMPROVEMENT.md: help-as-signal, regex tier 1, LLM tier 2, deferred self-improvement cycle, network patch sharing
- SEMANTIC-BACKCHANNEL-AND-DEDUPLICATED-COMMUNICATION.md: identity-content coupling as root failure; context alignment + dedup + normalization; suppression→forensic; no eviction by arithmetic impossibility
- semantic-dedup-tree.yaml: reasoning template — one currency, open mapping, overdetermined self-correcting correlations, inverse = other matches
- HARMONIC-TREE-ADDRESSING.md: minimal distance principle, route=address, rollover dialing, algebraic exclusion, self-annealing equilibrium, islanded data reintegration, living data eternal self-sustainability, pausing as cycle-based load balancing, active bit + inverse address + starting verse, computation placement = data placement, transport as eternal network work; preamble: tree/space/field/hyperspace/gate as coordinate systems for one structure

## session 50 potential next steps

- **tree.route.page Z.Y.X update**: word_graphical encodes col+row but not Z-depth
- **graphical word design doc**: character rotation (3 Z-states), X/Y symmetry collapse, edge-on semi-invisible state
- **branch.session integration with task zenka**: dag.open_list + policy.next_hop → task zenka scheduling loop
- **branch.cluster intent template (layer 4)**: only task (layer 1) + design (layer 3) exist
- **branch.calc.fraction intent template**: same — layer 4 missing
- **proxy-zenka-skeleton dispatch**: task file ready, not yet dispatched
- **transport-selector dispatch**: same
- **credential-fabric dispatch**: same
- **intent-classification modules**: intent.* + backchannel.* namespaces (task files not yet written)
- **overview + describe commands**: cube-level orientation commands from intent classification design

## completed session 49 (2026-05-24)

- branch unified theory: design doc (BRANCH-OPEN-CAPACITY-SESSION-DAG.md) + reasoning template extended
- 58 new modules: branch.field.*(9) + branch.calc.fraction.*(10) + branch.cluster.*(8) + branch.session.*(14) + tree.sort.trunk.*(5) + tree.route.page.*(12)
- Z.Y.X coords, rollover dual semantics, chained usefulness, mask/canvas orthogonality, holographic devices
- kimi_dispatch completed 4 task files; kimi_continue timed out on 2 (fixed in session 50)

## completed session 48c (2026-05-23)

- X-11 nvidia GPU monitoring: handler + 3 bug fixes (whitelist, fh scope, regex lvalue)
- X-11.init_code: intel binary noise fix (file.which silent lookup)
- GPU STRM subscription + coding zenka feed + sparkline (3 phases)
- MCP external command config table + kimi_dispatch tool
- `data/yaml/reasoning-templates/holographic-grid-interface.yaml` (733 lines)
- v7-teardown-whitelist: DONE ✓ — access.cmd.usr.system = v7.teardown in v7/start; SOURCE alias for v7.teardown already in cube/command_aliases (transmits caller identity); test pending with devmod switch-user (taeki has full wildcard, need non-taeki user to verify denial)
- MCP kimi_dispatch/kimi_continue: LIVE — 47min timeout, session resume via kimi -r <uuid>

## planned / future

- **SHM streaming pipeline** — data/tasks/shm-streaming-payload-pipeline.md
- **model self-selection** — data/tasks/coding-model-selection-template.md
- **sourcecode normalize-endline-state** — data/tasks/sourcecode-normalize-endline-paths.md
- **privacy credentials** — data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md
- **HTTP sync** — /api/jobs/sync httpd endpoint, C25519-signed YAML
- **USB backup zenka** — udev insertion → backup task tree
- **site-auth zenka** — session/auth for login-gated scrapers
- **job automation** — jobtracker integration (HTML/JS, CSV/PDF), email reply monitor
- **base.handler.command refactor** — data/md/development/BASE-HANDLER-COMMAND-REFACTOR-PLAN.md

## open bugs (session 37 — still open)

- **source.extract_sig_body**: YOURUM fake stubs 1 char too long → size mismatch → error instead of strip
- **signature oscillation Variant B** — double-footer on never-signed non-empty files
- ~~signature endline restoration~~ — **FIXED session 48b**: stale delta clamp + normalize recovery
- **repo var/ cleanup** — `var/httpd/` tracked from Nov 2025 AI error
- **kimi auto-approval regression** (Apr 16) — some tool calls not auto-approved

## open bugs (session 39 — letsencr, partially resolved)

- **visual.v7.ax ACME timing race** — vhost rescan not complete before LE validates; cert renews on retry but needs proper fix (wait for challenge file to be serveable before proceeding)
- **letsencr cert PEM format** — fix committed (remap bundle fields), pending next renewal cycle to verify httpsd loads correctly

## Glitter 4B quirk

After a failed tool-using task, Glitter backend needs restart before `:no_tools:` tasks work. Model gets stuck in tool-mode. Restart coding zenka or wait before dispatching `:no_tools:` priming tasks.

#,,,.,.,,,...,,.,,.,.,..,,.,.,..,,...,,.,,..,,..,,...,...,..,,,.,,..,,,,,,,,.,
#HBAYT2HAJIVYRXP7OZWTA43U7IVIWA2LCOXOSCX4SFNUCE2R5MW5WT4A6CP6ZBXBU2S45CWPM3WBQ
#\\\|2TKYMAASPYWQ3BCWKZVH34YBKMG3LPKOWL4JW2TMYGW2U6C7DFB \ / AMOS7 \ YOURUM ::
#\[7]W3I22Y5DFA5ETR7TKF2UK4ELUEF663OZIBND6EIVFBJPISRKRSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
