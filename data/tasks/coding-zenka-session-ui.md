## [:< ##

# name  = task: coding-zenka session ui, terminal typer first
# descr = phased plan for an integrated, own-built ui to coding-zenka
#         sessions (terminal first, web/gtk3 later, same descriptor) --
#         streaming, interactive stop/restart, round rewind, shared-pty
#         shell integration; explicitly chosen over adopting opencode

## context

raised 2026-09-13. started as a question about bridging the coding
zenka to opencode (an external agentic coding cli) for trying the
Ornith-1.5-9B model, which recommends opencode as its client. redirected
once the user named the actual problem: not "which external tool should
we integrate," but "we have no good window into coding-zenka sessions at
all, and want our own -- better than opencode or any other terminal
agent tool -- across terminal/web/gtk3, eventually working host-
transcendently between zenki." external-api backend support for the
coding zenka (an `api` backend, cloud models like Claude, alongside
existing `local`/`external`/`kimi_web`) is a separate, smaller, already-
partially-designed thread -- see `data/md/documentation/MODELS-BACKEND-
INTEGRATION.md`, `api` marked `[TODO]` there -- not blocked by this task
and not a prerequisite for it either.

**not a new architecture.** [[topic-ascii-desktop-domains]] already
named this shape in June 2026: one reverse-template frame descriptor,
rendered by different "typers" -- `ascii.frame.render` (terminal),
`ascii.frame.render.html` (web), and explicitly "a gtk3 GUI typer a
fourth" -- same logical desktop, different material per domain. status
there was "vision only," and it had stalled under too much parallel
design breadth (frame-plugin-slots, ascii-minimap, tile-window-place-
hybrid-desktop, global-ui-menu-tree, cred-mesh-console-ui, ui-show-
security-levels all touching adjacent ground with no one concrete
deliverable forcing convergence). this task's whole point is to break
that stall by shipping one thin vertical slice at a time.

**user's explicit sequencing preference, 2026-09-13:** clean steps, one
at a time, no rush to bundle -- the only failure mode to avoid is
stalling overall, same as what happened to the frame/desktop thread
before. terminal typer first because web/gtk3 typers need the same
underlying session-state/streaming work "only translated into a
different representation" -- do that work once, against the cheapest
typer to iterate on.

## existing infra this composes with [ added 2026-09-13, don't duplicate ]

three separate already-real layers, at three different maturity levels
-- checked live against `src/` and `data/tasks/completed/` before writing
this section, not assumed from docs alone:

1. **transport/addressing -- LANDED, has a real working consumer.**
   `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md` +
   `STDIO-MULTIPLEX-PROTOCOL.md` + `CONSOLE-FOLD-TREE-PHILOSOPHY.md`
   already generalise a zenka's stdio into an addressable, typed,
   foldable stream (`EOUT`/`TOUT`/`NUM`/`STR`/`SIN`/`RIN`/`ERR` tags
   over the 3+1-bit framing protocol). fully shipped:
   `console-fold-primitive`, `console-foldable-render-baseline`,
   `console-stdio-slot-addressing`, `stdio-multiplex-unix-socket-
   transport`, `stdio-multiplex-type-tag-codec`, `zenka-side-stdio-
   multiplex-emitter`, `v7-console-stdio-multiplex-demux` (all in
   `data/tasks/completed/`) -- and the `calc` zenka is already wired
   into it end to end (`calc-stdio-multiplex-wiring`). this is the
   layer that gets a coding-zenka's live round/tool-call/output stream
   out to a ui attach point at all, addressably and typed. **build
   phases 1-3 directly on this, don't invent a parallel transport.**
2. **content buffer -- 22 modules, one commit (`6a4d32e92`), zero
   tests, zero real consumers.** `vterm.*` is a real `Term::VTerm`-
   backed terminal cell/cursor/damage-tracked buffer with SHM zero-copy
   multi-reader access (`vterm.init_code`/`.cell`/`.instance`/`.shm`/
   `.compositor`) -- see [[topic-vterm]],
   `data/md/design/VTERM-BUFFER-SPECIFICATION.md`,
   `data/md/design/DECODER-VTERM-ARCHITECTURE.md`. it also carries a
   5-of-7 byzantine "visual consensus" blend mode (`vterm.consensus.*`,
   `vterm.subbit.*`, `blend.consensus`) built for a genuinely different
   problem -- the `decoder`/`zulum` harmonic-truth-visualization use
   case (making distributed disagreement visually perceivable as
   blur/ghosts). **that consensus machinery is irrelevant to this task
   -- ignore it entirely**, only `vterm.cell`/`.instance`/`.shm`/
   `.compositor` with `blend.normal` are candidate substrate here, and
   only where a REAL terminal emulator is actually needed (see phase 4
   below). the fold-application doc already names vterm as its intended
   "unfolded form" rendering substrate, so this isn't a new pairing --
   it's just unproven in practice. confirmed live 2026-09-13: `decoder`
   and `zulum` zenki are scaffolded (`cfg/zenki/`) but nothing exercises
   `vterm.*` yet, no self-test exists anywhere in the tree.
3. **chrome -- partial.** `ascii.frame`/`ascii-desktop-domains` typers,
   as scoped above.

**how much this task should be vterm-aware, concretely:** phases 1-3
are plain event/text/metadata streams (round markers, tool calls, model
output tokens) -- no cursor tracking, no ANSI terminal emulation, no
scrollback-with-escape-codes problem exists there. the landed stdio-
multiplex transport plus ascii.frame content slots are sufficient;
**vterm buys nothing for phases 1-3 and should not be reached for.**
phase 4 is different: a real interactive shell fundamentally expects a
real terminal (cursor position, screen buffer, escape-sequence
interpretation) -- that IS the problem `vterm.cell`/`.instance`/`.shm`
plus real `Term::VTerm` were built to solve, and multi-reader SHM access
is exactly "the human ui and the model's tool-executor both attached to
the same live shell." treat phase 4 as the first real non-harmonic
consumer of `vterm.*`'s non-consensus half -- budget time to hardened it
(it has never been exercised), same way `configure`/`installer` were
named as the fold-application doc's first proving consumers for the
layer below it.

## why terminal, not web or gtk3, first

`ascii.frame.render` already exists and works. `ascii.frame.render.html`
exists but is a second typer for the same descriptor -- adding it before
the descriptor actually carries live session/streaming/round state well
would mean redoing typer work twice. a gtk3 typer doesn't exist at all.
building session-state and streaming plumbing once against the cheapest,
most already-working typer, then adding web and gtk3 typers against the
same proven descriptor, is strictly less total work than parallelizing
early -- this is the ascii-desktop-domains role/glyph decoupling
(`border_style: colon` / `thin` / eventually a widget-tree) paying for
itself.

## phase 1 -- read-only session viewer [ not yet started ]

render one coding-zenka task's live state (round markers, tool calls,
streaming model output) through `ascii.frame` in a terminal. no control
surface yet -- proves the descriptor and streaming render loop against a
real workload before adding interactivity.

**live-wiring mechanism, confirmed 2026-09-13 (user's own recall,
verified against source):** the same STRM subscribe pattern already
used by `X-11.cmd.subscribe-screen-change`, `radio.cmd.listen`, and
`kimi-web.cmd.dispatch_stream` -- `base.stream.open({sid, cmd_id,
type => 'STRM', total => undef})`, register the handle, return
`{mode => 'deferred'}`. closest template is `kimi-web.cmd.dispatch_stream`
(streams a live model response, registers the handle keyed by task id
in a registry, not a flat listener array -- needed here too since
multiple tasks can be live at once). new command:
`coding.cmd.subscribe-session <task_id>` opens the STRM handle and
registers it under `<coding.session.listeners>->{$task_id}`; the push
side hooks into `coding.async.state_machine`'s existing message-
transition points and `coding.async.chunk_handler`'s token-streaming --
both already fire exactly where a listener notification belongs, they'd
just gain "also `base.stream.push` to any registered session listener
for this task_id." close the handle on task complete/fail/abort. this
is purely additive to the coding zenka's existing async machinery, no
new transport concept.

practical note: the coding zenka is mid lora-training as of 2026-09-13
([[coding-lora-p7-idioms]], attempt-4 decision point) -- GPU-bound live
inference isn't available to test against right now. build and verify
phase 1's rendering against **recorded/historical task transcripts**
(`task.history`, existing coding-task logs) first; wire it to a live
streaming task once the GPU is free again. this decouples the ui work
from training's GPU claim entirely.

**permission boundary, confirmed live 2026-09-13:** the real historical
data exists -- `/var/protocol-7/coding/completed-task-backups/<task_id>/
{meta.yaml,full.xz,compact.xz,thinking.xz}`, thousands of entries -- but
it's protocol-7-owned and a direct filesystem read as a regular user
gets `Permission denied`. do not sudo-read it. the offline viewer must
fetch/decompress historical transcripts through an existing (or new)
coding-zenka command running as the right user, same as any other
p7-owned-data access in this codebase.

## phase 2 -- interactive controls

wire stop/restart into the viewer. `coding.abort.*` (register/lookup/
list/remove/check_stream/task_bind) and `coding.async.round_soft_restart`
/ `coding.cmd.restart-round` already exist -- this phase is mostly ui
wiring onto existing command surface, not new zenka-side logic. confirms
the terminal typer as a real control surface, not just a viewer.

## phase 3 -- round rewind

goes beyond `round_soft_restart` (which restarts the *current* round on
stall/timeout): the ask here is to pick an *earlier* round and resume
from there with edited guidance, for manual optimization now and
automated optimization later (the user was explicit this is meant to
run unattended eventually too, not just from the ui).

design implication: rounds need to become individually addressable
history nodes with enough preserved state to actually re-enter one (the
prompt/context at that point), not just a soft-restart of "now." this is
the same shape [[topic-task-tree-design]] already describes for tasks
generally (`task.history` archive, tree fields, addressable nodes) --
rounds should be modeled as nodes under a task in that same tree, not as
a separate ad-hoc mechanism. build the rewind primitive as a coding-zenka
command (e.g. `coding.cmd.rewind-round`) with the terminal ui as its
first caller, so a future automated optimizer can call the same command
headlessly.

## phase 4 -- shell integration (shared pty, ytalk-style)

**correction, 2026-09-13 -- this is NOT greenfield, walk it back from the
original framing below.** user's reference point was unix `ytalk` (real
shared shell, not a typed buffer), and the first pass here wrongly said
"no existing primitive found." there is one, and it's more mature and
more idiomatic than building raw pty-sharing from scratch:

- **`amos-term`** (`cfg/zenki/amos-term`, `src/amos-term.*`, ~50
  modules) is a real, substantially-built 3D terminal zenka: AMOS-
  checksum-addressed windows, SHM-backed Z-layered buffers (8x7x13
  voxel grid, Z = scrollback depth), a hot-reloadable plugin system
  (`decoder`/`routing`/`render`/`input` types), FUSE + 9p mount
  (`amos-term.fuse.*`, `amos-term.cmd.mount-9p*`), and --
  **`amos-term.nshell.bridge` already wires a live interactive shell
  session into one of these buffers today.** that IS the ytalk shape:
  a real shell, rendered into a buffer multiple things can attach to.
- `data/md/design/CODING-ZENKA-USER-INTERACTION-SURFACES.md` already
  designs the coding-zenka-specific application of this exact
  mechanism: a 5th plugin type, `interaction` (hook `agent.query`,
  dir `src/amos-term.plugin-interaction/`), built directly on
  `amos-term.buffer-attach_generic( ..., read => TRUE, write => TRUE,
  on_buffer_change => ... )` -- "precisely how amos-term.nshell.bridge
  wires an interactive shell session into a buffer today," per that
  doc. lifecycle already resolved (2026-08-04): a dedicated named
  buffer `name:agent-interaction`, lazy GTK window, Z-shift scrollback
  history, headless-degrade to `record_question`.
- **status, confirmed live 2026-09-13**: prototyped and partially
  working, not just designed. `599440fde` ("feat(amos-term): interaction
  plugin prototype, fix real SHM bugs found along the way") landed the
  notify-on-write dispatch and verified an ask/reply round-trip
  headless in the amos-term zenka, archived at
  `data/yaml/archive/completed-coding-tasks/amos-term-interaction-
  plugin.yaml`. **remaining, per the design doc's own status section**:
  timeout-degrade timer, the inotify hot-reload watcher, plugin-type
  scaffolding for the 5th type, and the GTK `window-open` path.

**hard constraint, don't violate it:** [[reference-console-question-ask-
primitive]] records an explicit user rule -- FIVE existing places carry
"ask the user" interaction code (`AMOS7::TERM`, nshell, `amos-term.
interaction.ask`, `coding.tools.handler.ask_user_*`, user-edit's
`editor.*` form) and a sixth must never be added. phase 4 is squarely
medium #3 (`amos-term.interaction.ask` -- named-buffer, non-blocking,
agent side). **finish that thread, don't build a parallel shared-pty
mechanism next to it.** concretely: phase 4 = finish `CODING-ZENKA-
USER-INTERACTION-SURFACES.md`'s remaining steps (timeout-degrade,
inotify watcher, plugin scaffolding, GTK window-open) plus the coding-
zenka tool wrapper `ask_user_stream` that doc already sketches, wired so
the terminal session-ui from phases 1-3 can ALSO attach to the same
named buffer read-only (or read/write, for real two-way ytalk-style
use) -- not a new pty-sharing subsystem.

can proceed in parallel with phase 2/3 once phase 1's viewer exists --
it's a different subsystem (amos-term's own buffer/plugin machinery),
just not one that needs inventing.

**caveat, user-confirmed 2026-09-13: amos-term has never actually been
seen running.** all verification to date is headless (the `599440fde`
ask/reply round-trip). confirmed live: `amos-term` is not in v7's
always-on `start-set-up.base` -- it's manually/on-demand started
(`base.cmd.ondemand-zenka` etc. present in its `subroutines.load-early`)
and needs a real GTK/X11 display, which on this WSL host has its own
known hazards (see [[topic-gtk-wsl-window-positioning]],
[[feedback-wslg-deiconify-limitation]] -- unrelated bugs, but the same
GTK-on-WSLg surface). expect real visual/UX optimization once it's
actually looked at for the first time -- headless-correct is not the
same as usable, per this repo's own rule for UI work (launch it, use
it, don't just trust logic tests). when that happens, the palette
already exists and should be reused, not reinvented: `CODING-ZENKA-
USER-INTERACTION-SURFACES.md`'s visual-consistency table (near-black
navy backgrounds `rgba(0,0,0.024,alpha)` / `#000013`, accent `#0055CC`,
cursor `#4427AC`) already spans window-place, protocol-7-menu, and
amos-term consistently, and already matches [[feedback-user-screen-
brightness-sensitivity]]'s dark violet/blue-toned requirement -- treat
a first real look as a verification + bugfix pass against that existing
direction, not a fresh design pass.

## phase 5+ -- additional typers [ deliberately deferred ]

web typer (reuse `ascii.frame.render.html`), then a gtk3 typer, once
the terminal slice (phases 1-4) is solid and in daily use against the
same descriptor. do not start before then -- this is the exact breadth-
before-convergence pattern that stalled the original ascii-desktop-
domains thread.

**correction, 2026-09-13:** "gtk3 typer (new)" was wrong -- `amos-term`
(see phase 4) is already a substantially-built gtk3 3D terminal with its
own window/buffer/render/plugin system. when phase 5 arrives, evaluate
adapting amos-term as the gtk3 typer before writing a fresh one against
the ascii.frame descriptor -- it's a different visual paradigm (3D
voxel/Z-layer grid vs. a flat bordered frame) so the two may end up
staying genuinely separate typers rather than one adapting to the
other's descriptor, but that's a decision for phase 5, not now.

## separate track -- distributed task state (not a ui concern)

user's transcendence framing, corrected 2026-09-13: NOT a ui feature.
between zenki -- "an addressable distributed buffer concept amending a
more distributed task state system with universal dependency resolution
and references that is generic enough for zenki, host or network without
necessarily an LLM involved, but that those tasks would be covered too,
including consensus review and decision steps."

this is already scoped, not new: [[topic-task-tree-design]]'s "state
sharing -- convergence point" section (task zenka's `task.queue` and
coding zenka's `coding.task.queue` unifying into one tree where nodes
are addressed, not owned by location -- "local and distributed are the
same operation at different latencies") is exactly this. [[topic-
distributed-consensus]]'s independent-then-cooperative pattern plus role
fluidity (delegator/executor as parameters, not fixed roles) already
covers "consensus review and decision steps" as one task type in that
same generic system, and is deliberately not llm-specific (passive/
active deps, `await-event` slots, `worker`/`tool-set`/`zenka` requires
types already exist as generic primitives).

**extension, 2026-09-13 -- panes/tabs as checksum/C25519-addressable
objects, input and output alike.** user's vision: a tab/pane's identity
should be separable from where it's currently served, so routing a pane
is "swap an address," and with C25519 identity, secure enough to
distribute across hosts. not new mechanism to invent -- descends the
same addressing model one level, from whole zenki/tasks down to
individual panes:

- **`plugin.storage.p7ref.*`** (confirmed live: `.parse`/`.resolve`/
  `.nested-resolve`/`.search`/`.index`, plus `base.p7refs.
  gen_template_chksum`) already implements `TYPE:CHKSUM7:ADDR_B32` --
  identity (CHKSUM7) separated from current resolution (ADDR_B32). a
  pane's P7REF would stay stable while ADDR_B32 (where it's actually
  served from -- local zenka today, a different host later) gets
  swapped underneath it, same "re-point without changing identity"
  property [[topic-global-ui-menu-tree]] already establishes for whole
  zenki.
- security precedent, also not new: the vterm/decoder SHM layer design
  already gates per-path access with Ed25519 ("each zenka writes only
  to authorized paths"), and C25519 is already the project-wide zenka
  identity/signing substrate. pane read/write authorization would
  follow that same per-path-keyed pattern, not a new scheme.

**do not start the tree-unification merge speculatively.** start it when
phase 3's round-history-as-addressable-nodes and phase 4's shared-pty
sessions both actually want to be resumable/addressable nodes -- real
second and third consumers of the same shared-state primitive, not a
foundational merge built ahead of demand. same discipline as [[topic-
torch-worker-zenka-foundation]]'s "abstract the primitive once real
evidence exists, not the orchestration shape early."

## layout -- tabs vs split, scoped narrowly [ added 2026-09-13 ]

question raised: does the terminal ui need tab support (vertical split +
switchable/cycling tabs per segment)? checked live -- no existing tab/
split/pane primitive anywhere (`nshell`, `ascii.frame`, `amos-term` all
lack one). the only existing small-set-cycle convention in the codebase
is the editor's inline field-cycler (Left/Right, wraps, [[reference-
editor-add-field-cycler]]) -- worth staying consistent with for any
future tab-cycle keybinding, not a windowing precedent.

answer: yes, but split by actual need, not as one generic framework:

- **tabs, one per active session** -- needed once phase 1 shows more
  than one concurrent task (`coding.task.active` can already hold
  several). switching/cycling across tabs = choosing WHICH task to
  look at, one at a time. add this when phase 1 actually needs it, not
  before.
- **split, not tabs, for phase 4** -- the ytalk point was seeing shell
  + model narration SIMULTANEOUSLY, so that pairing wants a real
  vertical split, not a tab you'd switch away from to see the other
  half. two adjacent `ascii.frame` regions don't need a new primitive
  unless resizing/dragging is wanted (not asked for yet) -- just render
  both.
- **round history (phase 3) is neither** -- linear/temporal browsing
  through one session's rounds, closer to scrollback than to a
  parallel-content tab.

don't build a generic tab/split manager as its own phase -- same
discipline as the distributed-task-state deferral above: build each
piece directly into the phase that actually needs it.

## open, not yet decided

- exact wire shape for the terminal ui's live attach to a running task
  (poll vs push/watcher -- `task-tree-design`'s `await-event` slot
  pattern is the likely fit, not yet confirmed against streaming token
  volume)
- round-history storage format/size bound (unbounded round history per
  task could grow large for long-running tasks -- needs a retention
  policy, not designed yet)
- shared-pty primitive's exact shape (new `coding.shell.*` namespace vs
  reusing the existing child-zenka fork pattern) -- not designed yet

#,,.,,,,.,,,,,,,,,.,.,,..,,,,,.,,.,,,,,,,,..,,,.,,.,,,,.,,,..,..,,,,,,,..,,,,,,

#,,,.,,,.,,,.,,.,,..,,...,..,,,.,,,.,,...,,,,,..,,...,...,,,.,.,,,..,,.,,,.,.,
#XUXGAODQCEUSQZAWVL5P44I427DWYACJWY5SYVHFCDNM6NE2DEYQDH4QBBSMTD3VB5V36A7YTPOXU
#\\\|74EFFHZRHRVCCXWM7XBVPGB7TSNG2AZ5ZSDIWDWTL6NM5XCSOON \ / AMOS7 \ YOURUM ::
#\[7]OOKS7TBZ7LVUYCRDUCFGHIS5HT56T5KELKQ6IVJR3MOCWX7XXCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
