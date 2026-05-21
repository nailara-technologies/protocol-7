---
name: next-steps
description: "active task queue, roadmap items, open bugs, and planned work — full detail for planning sessions"
metadata: 
  node_type: memory
  type: project
  originSessionId: 56cce73a-933a-4992-96e4-4d88e138e8f6
---

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

- `data/tasks/v7-teardown-whitelist.md` — restrict teardown to system zenka (tiny)
- `data/tasks/source-code-header-check.md` — DONE ✓ already completed prior session (parameterized // TRUE, all headers valid)
- `data/tasks/weather-forecast-humidity.md` — re-enable humidity API field (tiny)
- `data/tasks/web-browser-evaluate-javascript.md` — DONE ✓ session 42
- `data/tasks/mpv-xephyr-vo-override.md` — test gpu vs sdl under xephyr
- `data/tasks/diff-modified-no-color-mode.md` — --no-color flag **[dispatched session 42]**
- `data/tasks/x11-gpu-monitoring-vendor-detect.md` — nvidia-smi + intel_gpu_top auto-detect
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
- **SIZE packet loss bug** — STRM interaction stops zenka returning SIZE replies until unrelated cmd sent

## open bugs (session 37 — still open)

- **source.extract_sig_body**: YOURUM fake stubs 1 char too long → size mismatch → error instead of strip
- **v7 start-once + error status**: "already running" when instance is in error state
- **config double-load bug** — duplicate config key warnings; see `bug-config-double-load.md`
- **signature oscillation Variant B** — double-footer on never-signed non-empty files
- [signature endline restoration](bug-signature-endline-restoration.md) — stale encoded delta after edit
- **repo var/ cleanup** — `var/httpd/` tracked from Nov 2025 AI error
- **kimi auto-approval regression** (Apr 16) — some tool calls not auto-approved

## open bugs (session 39 — letsencr, partially resolved)

- **visual.v7.ax ACME timing race** — vhost rescan not complete before LE validates; cert renews on retry but needs proper fix (wait for challenge file to be serveable before proceeding)
- **letsencr cert PEM format** — fix committed (remap bundle fields), pending next renewal cycle to verify httpsd loads correctly

## Glitter 4B quirk

After a failed tool-using task, Glitter backend needs restart before `:no_tools:` tasks work. Model gets stuck in tool-mode. Restart coding zenka or wait before dispatching `:no_tools:` priming tasks.

#,,,.,,..,.,,,,..,,.,,.,.,.,.,,.,,.,.,,..,,,.,..,,...,...,,,.,,,,,,,,,,..,..,,
#PUKORZBTMF2TNXWX5OCYGI7357WDBXVCER7RGZB6TBNZ6YFVBZBGCPGC5BKTTZLBDHQXWCDW2X2MA
#\\\|ZLHLCEUJUIX4SIMSW2FWXM4VJ7NZMBKZYARUHV667QKPFP2XXBW \ / AMOS7 \ YOURUM ::
#\[7]VXWOVHVTXXC53BXJNA3NRAUVK23KP76JA4KGXZBS7O3TKXGNEKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
