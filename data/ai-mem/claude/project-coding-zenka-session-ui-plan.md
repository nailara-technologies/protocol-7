---
name: project-coding-zenka-session-ui-plan
description: coding-zenka session ui scoped as own-built terminal-first, multi-typer, phased plan; opencode/external-model bridging explicitly rejected as the actual need; distributed task-state kept as a separate, later track
metadata:
  type: project
---

2026-09-13: user opened by asking whether to bridge the coding zenka to
opencode (OpenAI-compat interface) for trying a new model
(Ornith-1.5-9B) that recommends opencode as its client, and whether to
add native external-API backend support to the coding zenka for
self-optimization tasks. redirected mid-conversation to the real issue:
frustration at the lack of any good UI onto coding-zenka sessions, and
an explicit desire to build P7's own — better than opencode or any other
terminal agent tool — across terminal/web/GTK3, eventually working
host-transcendently between zenki.

**decision: build our own, terminal first.** not a new architecture —
[[topic-ascii-desktop-domains]] already named this shape in June 2026
(one frame descriptor, multiple "typers": terminal/web/gtk3 all render
the same logical desktop) but stalled at "vision only" under too much
parallel design breadth. full phased plan now written at
`data/tasks/coding-zenka-session-ui.md`: phase 1 read-only session
viewer (build/verify against recorded task history first — coding zenka
is mid lora-training as of this date, GPU-bound, see
[[coding-lora-p7-idioms]]), phase 2 interactive stop/restart (mostly UI
wiring onto existing `coding.abort.*`/`round_soft_restart`), phase 3
round rewind (new — resume from an *earlier* round with edited guidance,
explicitly meant to run automated later too, not just from the UI —
needs rounds to become addressable history nodes, not just current-round
soft-restart), phase 4 shared-pty shell integration (ytalk-style —
two-way live shell the model can act in AND the human UI can also
attach to, not a one-way log tail — no existing primitive, confirmed via
grep). Web/GTK3 typers deliberately deferred to phase 5+, only once the
terminal slice is solid.

**external-API backend for coding zenka** stays a separate, smaller,
already-partially-designed thread — `data/md/documentation/MODELS-
BACKEND-INTEGRATION.md` already has a `models` zenka with `local`/
`external`/`kimi_web` backends and `api` marked `[TODO]` for exactly
this. Not blocked by, and not a prerequisite for, the session-UI work.

**Why:** the user was explicit that the failure mode to avoid is
stalling overall (same thing that happened to ascii-desktop-domains
before) — clean incremental steps are fine, breadth-before-one-working-
deliverable is not.

**How to apply:** when this task resumes, read
`data/tasks/coding-zenka-session-ui.md` first — it has the full phase
breakdown, the reasoning for terminal-before-web/gtk3, and an "open, not
yet decided" list (attach wire shape, round-history retention policy,
shared-pty primitive shape). Do not start web/gtk3 typers or the
distributed-task-state tree-unification merge (see below) ahead of a
real second/third consumer needing them — that breadth-first pattern is
exactly what stalled the predecessor effort.

**Correction, 2026-09-13, same session, mid-scoping:** phase 4 (shell
integration) was first written up as "no existing primitive found" —
wrong. `amos-term` (`src/amos-term.*`, ~50 modules, real GTK3 3D
terminal zenka) already has `amos-term.nshell.bridge` wiring a live
interactive shell into an SHM-backed buffer, and `data/md/design/
CODING-ZENKA-USER-INTERACTION-SURFACES.md` already designs the coding-
zenka-specific application of that exact mechanism (a 5th plugin type,
`interaction`, built on `buffer-attach_generic`) — status confirmed
live: prototyped and partially working (`599440fde`, ask/reply
round-trip verified headless), remaining pieces named in that doc
(timeout-degrade timer, inotify watcher, plugin scaffolding, GTK
window-open path). [[reference-console-question-ask-primitive]] records
a hard user rule — five existing places carry "ask the user" code, never
add a sixth — so phase 4 must finish that thread, not build a parallel
shared-pty mechanism. Also: `amos-term` is a real, working GTK3 3D
terminal already, so phase 5's "gtk3 typer (new)" was also wrong —
evaluate adapting amos-term there before writing one fresh. Separately,
`vterm.*` (22 modules, one commit, zero tests/consumers) was evaluated
as a candidate content-buffer substrate and is NOT needed for phases 1-3
(plain text/event streams) — only possibly relevant if phase 4 ever
needs raw terminal-emulation state beyond what amos-term's own buffer
system already provides, which is not yet established.

**Separate track — distributed task state, corrected scope:** the
user's "host-transcendent" framing is NOT a UI feature; it's between
zenki. Already scoped in [[topic-task-tree-design]]'s "state sharing —
convergence point" (task zenka's and coding zenka's task trees unifying
into one addressed-not-owned tree — "local and distributed are the same
operation at different latencies") plus [[topic-distributed-consensus]]'s
independent-then-cooperative pattern and role fluidity, which already
covers "consensus review and decision steps" as one generic task type,
deliberately not LLM-specific. Deliberately NOT started speculatively —
wait until phase 3 (round history) and phase 4 (shared-pty sessions)
both actually need to be resumable/addressable nodes, same discipline as
[[topic-torch-worker-zenka-foundation]]'s primitive-vs-shape distinction.

#,,..,,,,,,.,,.,,,.,,,...,,,,,..,,,..,.,.,,,,,..,,...,...,...,,.,,,.,,..,,..,,
#3ZWXH5M5SHLQGDJP55D2W5TDBIWOS6SWAB3SVU56IQV3SMGTNGKIUDFIBBMQBJSSGKN4PKTQJZFBI
#\\\|PVP744RVSKJH5BYROZA6IA3IKSHPFV3JNFO4OW7L3FVAYBXNX6L \ / AMOS7 \ YOURUM ::
#\[7]YR22RSV7ZRGAT4WHQWZJMKWVE7N7KVLPXKUP52OKBJLCIPN2XCCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
