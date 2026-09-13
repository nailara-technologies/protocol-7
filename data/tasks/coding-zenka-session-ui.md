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

**status, live-verified 2026-09-14:** `coding.cmd.list-backups` and
`coding.cmd.show-backup` are implemented, reloaded into the running
zenka, and tested against real data. Real bug found+fixed along the
way: this codebase deliberately overrides `stat()` process-wide to
`File::stat`'s object-returning form (confirmed by the user, not to be
bypassed with `CORE::stat`) -- the classic `(stat $x)[9]` list-index
idiom silently returns `undef` instead of erroring, see [[feedback-
file-stat-object-override]]. Fixed with scalar-context `stat()->mtime`.

**finding that changes phase 1's remaining scope, 2026-09-14:**
`compact.xz` buffers are already pre-formatted with box-drawing chrome
by whatever wrote them live (`┌──[ assistant | round 0 ]──...└──`) --
verified live against a real backup. This means phase 1's "render
through ascii.frame" goal is already substantially met at the data
source: `list-backups` + `show-backup` together are a working offline
session viewer right now, no additional formatting layer required for
the basic case. Remaining for phase 1: wire the live STRM path
(`coding.cmd.subscribe-session`, designed earlier in this file, not yet
built) so the same view works on a running task, not just backups.

(aside, out of scope: `model`/`rounds` come back empty in meta.yaml for
a whole class of tasks -- checked 40 consecutive recent backups, all
jobsite bulk candidate-scoring calls, all blank. Real but pre-existing
gap in `coding.task.save_buffers`'s metadata collection for that task
type, unrelated to this work -- not investigated further.)

**PHASE 1 DONE, live-verified 2026-09-14** (`c51551b33`): both the
offline path (`list-backups`/`show-backup`) and the live path
(`coding.cmd.subscribe-session` + `chunk_handler`/`state_machine`
hooks) are landed and tested against real tasks. Along the way, found
and fixed `bin/mcp-server-p7`'s complete lack of STRM-reply handling
(`cube_command`/`cube_command_multiline` only knew TRUE/FALSE/SIZE/
NACK, silently corrupting the next unrelated call whenever a command
opened an STRM stream) -- see `data/tasks/mcp-server-p7-strm-support.md`,
implemented by Kimi against a task file an Opus-model agent wrote,
20/20 tests, live-verified clean. Real end-to-end test: subscribed to
a live task, got its streamed content plus a round-transition marker,
clean close, no corruption on the follow-up call. Terminal chrome
(ascii.frame wrapping) still not built -- phase 1 proved the data path,
not the UI presentation layer; that's the natural next slice.

**split-screen hardening round, live-verified 2026-09-14** (follow-up to
`bcf1b4cb5`): the initial cut had three real bugs, all found live by the
user and fixed in sequence:
1. the styled separator (`frame_rule_line`) filled the terminal to its
   exact width, triggering pending-wrap and bleeding the next print onto
   the same visual row -- fixed by reserving one column, same guard
   `nshell.render.viewport`'s own overflow path already uses.
2. `scroll_region_clear` only reset the DECSTBM boundary, never the
   actual screen content drawn into the reserved rows -- left visible
   debris on Tab-cycle-back and process exit. now takes the reserved-row
   count and clears + parks the cursor at the bottom row; the separator
   itself is redrawn by `render.viewport` on every render (not just once
   at Tab-press) so it self-heals after a `clear` command too.
3. the real "two cursors" bug: `render.viewport`'s input-line jump used
   to restore the cursor back to wherever it was before the jump --
   correct for background content, wrong for the input line itself,
   which should keep the cursor (matching nshell's existing single-
   cursor convention: the drawn highlight IS the cursor). fixed by
   removing that restore for the input case, and instead moving the
   save/jump/restore burden onto a new shared `nshell.render.content_print`
   used by every background-content print site (`command_reply`'s
   single-line and SIZE/multi-line paths, `strm_reply`'s chunk and
   status-line prints, and `read_from_buffer`'s two idle-cursor draws,
   which were ALSO split-unaware and are now unified to just call
   `render.viewport` instead of duplicating cursor-drawing logic).

**known follow-up, deliberately not done now**: `content_print`'s
content-area column tracking is an approximation (counts characters/
newlines in what was printed, not a terminal-verified position) --
correct for typical text, could drift for a genuinely wrapped line. user
raised using `Term::VTerm` directly (NOT the untested `vterm.*` P7
wrapper, which solves a different problem -- SHM multi-client sharing --
nshell doesn't need) as a more robust, ANSI-safe alternative: feed
content into a real local terminal emulator instance, blit its resolved
cell buffer onto the real terminal, eliminating the column-approximation
class of bug entirely. deliberately deferred -- current approach is
live-verified working (`clear` safe, replies visible, typing responsive)
and this would be a real rewrite, not a fix for a demonstrated problem.
revisit if the approximation ever visibly breaks on real streamed
content (long wrapped lines, ANSI-bearing model output).

**design note for when this IS revisited, recorded 2026-09-14 (not built,
just captured so the eventual design doesn't preclude it):** user's
direction -- a `Term::VTerm`-backed renderer, when built, should live as
a new shared library module (something like `AMOS7::VTerm`), not nshell-
embedded, not folded into `AMOS7::TERM.pm` (different concern -- that's
local line-editing/password/frame-drawing), and not the existing
`vterm.*` P7 wrapper (different concern -- SHM multi-client sharing +
consensus blending nshell doesn't need). reuse target: phase 4's real
host-shell/"bash tab" mode needs actual terminal emulation for the same
reason a coding-session content region would benefit from it -- one
primitive, two consumers, zero rework if built shared from the start.
Also: user wants vterm buffers to eventually be network-exportable/
importable ("there will be headless Term::VTerm instances, I am
certain") -- this is the SAME thread as the host-transcendent /
P7REF-addressable-panes vision recorded earlier in this file, not a new
idea -- a vterm buffer is exactly the "content + input-routing +
persistent state" object that vision already assumed. Keep the buffer's
internal representation cleanly serializable when it's eventually built,
so export/import isn't a later retrofit -- but do not build the
export/import mechanism itself until a real headless-instance need
exists.

**refinement, 2026-09-14: the module must be multi-buffer capable, not a
singleton.** maps directly onto `nshell.display.cycle`'s existing
`display_modes` list -- each mode needing real terminal emulation (a
coding session, a future bash tab, a remote nshell connection) holds a
KEY into a multi-buffer registry, not a shared implicit global instance.
matters beyond just "multiple tabs exist": a backgrounded shell command
needs to keep running and updating its terminal state while a DIFFERENT
mode is focused, not pause just because it isn't the visible one -- only
works if each buffer is independently addressable and persists
regardless of focus. API shape should be keyed (create/write/read/
destroy against a specific buffer id) from the start, not singleton-
then-retrofitted-to-keyed later.

**split-screen prerequisite DONE, live-verified 2026-09-14** (`bcf1b4cb5`):
nshell now supports a Tab-toggled split mode -- pinned input line at the
bottom, live-streaming content scrolls above it via a real DECSTBM
scroll region (`AMOS7::TERM::scroll_region_set/clear` + `pinned_row_print`),
so watching a live `coding.subscribe-session` stream and typing a
control command no longer corrupt each other. This is the piece phase 2
was actually blocked on -- recalled from an old unwritten plan ("nshell
template support, tab switches display modes"), not found in any doc,
built fresh. `ascii.frame` was confirmed as the right template/layout
layer for future chrome (it's a full-recompute renderer, fine for slow-
changing borders/status, not for token-by-token content -- that's what
the scroll region is for); `AMOS7::TERM.pm` confirmed as the right home
for shared low-level terminal primitives (raw-mode toggling, the
`editor_*`/`frame_*` families already lived there). Search order for
future "does X already exist" questions in this thread: check actual
module lists (`ls src/`) and full doc content, not just keyword grep --
`AMOS_TERM_NSHELL_INTEGRATION.md` and the full `AMOS7::TERM.pm` sub list
were both missed on a first keyword-only pass and only found when the
user pointed back at them directly.

**session-mode chat plugin BUILT, not yet fully verified live 2026-09-14**
(plugin.nshell.coding-session + hook call sites in nshell.editor.process/
nshell.handler.command_reply, generic buffer/redraw-on-focus in
nshell.display.cycle + nshell.render.content_print, resize handling
fixed in nshell.handler.term_resize -- all syntax-clean, not yet
committed/signed at time of writing). three real follow-ups found live,
none built yet:

1. **Esc -> coding.abort-inference**, a dedicated keybinding, intercepted
   the same way Tab is in nshell.editor.process (before the editor
   engine). small, do this first.
2. **raw commands typed in session mode are ambiguous** -- typing `clear`
   out of habit got sent as a literal coding.submit prompt ("clear") 
   instead of the terminal command, since on_submit currently treats
   ALL typed text as prompt text unconditionally. needs either an escape
   convention (e.g. a leading character that means "this is a raw
   command, not a prompt") or accept that session-mode is prompt-only
   and control actions are keybinding-exclusive (Esc for abort per #1,
   etc.) -- leaning toward the latter, matches the plugin's own
   on_submit contract cleanly, but not decided.
3. **`:stream:` parameter for `coding.submit`, coding-zenka side, NOT
   nshell.** current auto-subscribe (plugin.nshell.coding-session.
   on_reply parsing a `task:task-XXXX|...` ack, then queueing
   `coding.subscribe-session` as a SEPARATE follow-up command) is a
   two-step, timing-dependent dance. user's proposal: a flag/param on
   `coding.submit` itself that makes it open an STRM reply immediately
   instead of a quick ack -- task id delivered via the stream, one
   command instead of two, no race window. real architectural
   improvement over the current client-side workaround, not just an
   alternative -- worth doing instead of hardening the two-step dance
   further. touches `coding.cmd.submit`, a different zenka than nshell.
   still worth doing eventually, but see the bug below -- the two-step
   dance was not merely racy, it was structurally 100% dead until
   2026-09-14.

**real bug found + fixed 2026-09-14 : `on_reply` never fired at all,
for any task, ever.** live-tested Esc-abort and got the actual
"the task just keeps going" symptom the design was meant to prevent --
traced with `p7_command`/source-reading rather than guessing further.
root cause: `coding.cmd.submit` replies with `mode => 'size'`, not
`'true'`. Confirmed via `base.handler.command.process_reply`'s
`unknown-reply-route` hook call [ nshell never sets up route
correlation for its transparent-relay commands, so every reply lands
here regardless of mode ] -- it passes `'data' => undef` for
TRUE/FALSE/WAIT/GET/TERM, but a real extracted payload string for
SIZE/STRM/CHRSIZE/STRM-SIZE. `nshell.handler.command_reply` only ever
called the mode plugin's `on_reply` hook inside its
`if (not defined $payload_str)` branch -- exactly the branch a
SIZE-mode ack never takes. So `task_id` was never bound to the tab, on
ANY submit, ever: subscribe-session was never queued [ hence "never
actually streams, only shows the dispatch ack" -- this was NOT a
race, the follow-up command was never sent to begin with ], and
`on_escape` always saw an unbound mode and could only ever hit its
"clear leftover buffer" branch, never the abort branch [ hence Esc
looking like it "worked" once by coincidence -- it was clearing the
buffer, not aborting anything, and the earlier "clean completion"
observation was the task finishing on its own, untouched ].

fixed in `nshell.handler.command_reply`: the plugin dispatch now runs
once, before either branch, passing `payload_str` when defined
[SIZE/STRM/...] else `args` [TRUE/FALSE/WAIT/...] as the reply text --
covers both reply shapes uniformly instead of assuming TRUE-only. Also
added a "claimed" contract: a truthy return from `on_reply` now
suppresses the raw ack print in both branches [ was always printed
unconditionally before ], so a bound task hides its `task:X|...` ack
line and the live stream takes over the content area directly instead
-- addresses the user's separate observation ("shows the task
dispatched message instead of hiding it and starting streaming
directly") in the same fix, since both symptoms traced to the same
never-fires call site. NOT yet live-retested end to end at time of
writing -- do that before considering phase 1/Esc "done".

## phase 2 -- interactive controls

wire stop/restart into the viewer. `coding.abort.*` (register/lookup/
list/remove/check_stream/task_bind) and `coding.async.round_soft_restart`
/ `coding.cmd.restart-round` already exist -- this phase is mostly ui
wiring onto existing command surface, not new zenka-side logic. confirms
the terminal typer as a real control surface, not just a viewer.

**refined design, 2026-09-14 -- supersedes the "prefix aborted buffer to  
next message" idea below, don't build that separately.** grew out of  
designing Esc-to-abort for the session-mode plugin (phase 2 follow-up)  
and converged directly onto this phase. confirmed live via source  
(`coding.async.complete` line ~81): aborting mid-stream genuinely LOSES  
the partial turn -- `complete` only copies whatever is already in  
`$state->{'messages'}` into the archived task record, it never commits  
the still-accumulating `$state->{'content'}` [ the text the user actually  
watched stream to screen ] as a message first. This isn't just  
inconvenient, it's real data loss: the interrupted assistant turn never  
existed in the model's own conversational history at all.

**unified design, role-agnostic:**
- new coding-zenka command, `coding.cmd.restore-stream-state` [ or fold  
  into abort-inference itself, not yet decided which ] -- commits the  
  in-flight `$state->{'content'}` as a proper `{role: 'assistant', ...}`  
  message onto the task's `messages` array IF NOT ALREADY PRESENT, before  
  `coding.async.complete` archives the task. fixes the data-loss gap  
  directly, independent of anything nshell does.
- Esc mapping in the session-mode plugin, once this lands: **while  
  streaming** -> abort-inference (now also triggers the restore-stream-  
  state commit, so the interrupted turn is preserved). **while idle**  
  [ already aborted/completed, nothing running ] -> rewind one round-  
  history step back [ role-agnostic -- steps back through `messages`  
  regardless of who produced the last entry, not abort-specific ].  
  **Shift+Esc** -> redo [ step forward again ] -- makes rewinding safe to  
  use casually rather than something to fear as destructive.
- this makes the earlier "prefix partial output into the next flat-string  
  prompt" idea unnecessary -- role-blending was the problem with that  
  approach, and committing the partial turn as a REAL structured message  
  (via restore-stream-state) sidesteps it entirely: the next `task-append`  
  [ if rewind lands back on a resumable task ] or fresh `coding.submit`  
  seeded from the rewound history [ needs the same structured multi-  
  message seed capability flagged as missing from `coding.cmd.submit` a  
  few turns earlier in this file's history ] sees a proper conversation,  
  not concatenated text.
- open, not decided: exact addressing scheme for "one step back" through  
  `messages` [ probably ties directly into the round-as-addressable-node  
  design phase 3 already wanted -- a round may span multiple message-  
  array entries (tool calls + results), so "one step" likely means one  
  ROUND, not one raw array index ]; whether redo needs its own stack or  
  can be derived by re-walking forward through already-archived history;  
  whether restore-stream-state is its own command or folded into  
  abort-inference directly.

**BASIC VERSION BUILT 2026-09-14, not yet live-tested -- a genuinely  
simpler cut than the full rewind/redo design above, deliberately, to get  
something usable now rather than wait on phase 3's round-addressing:**
- folded the restore-fix directly into `coding.cmd.abort-inference`
  (not a separate `restore-stream-state` command) -- commits
  `$async_state->{'content'}` as a `{role: 'assistant', ...}` message
  before `coding.async.complete` archives the task, exactly the data-loss
  fix described above, live in the actual command now.
- `plugin.nshell.coding-session.on_escape` (new hook, third alongside
  on_submit/on_reply) + an Esc intercept in `nshell.editor.process`,
  placed the same way as Tab but only CLAIMED when the plugin actually
  wants it -- unclaimed falls through to the normal editor engine
  unchanged, so Esc's existing meanings (search-mode cancel,
  VIEWING_HISTORY exit) still work when there's nothing coding-zenka
  specific to do. Avoids the historical "Esc needs pressing twice" class
  of bug from claiming a key the editor engine already handles.
- behaviour is STATE-DEPENDENT, not the fuller round-rewind: task bound +
  actually running (checked via `<coding.task.active>`, same source
  abort-inference itself uses) -> abort it, unbind the task id (so the
  next message starts fresh rather than trying to task-append onto a
  now-dead task), keep the visible buffer. task unbound but buffer still
  has content (a second Esc, or the task already finished on its own) ->
  clear the buffer for a genuinely fresh tab. neither bound nor buffered
  -> don't claim the key at all.
- this is NOT the round-rewind/redo primitive above -- no Shift+Esc/redo
  built, no stepping back through arbitrary history. it's the smallest
  slice that makes Esc genuinely useful today (stop a bad generation
  without losing it, or clear a stale tab) without waiting on phase 3's
  addressable-round-history work. Building the fuller version on top of
  this later should be additive, not a rewrite -- the state-dependent
  shape here doesn't conflict with it.
- also not built yet: the `clear`-typed-as-a-prompt ambiguity (raised
  same session) -- planned fix is a Ctrl+L keybinding, NOT yet
  implemented. **expanded design, 2026-09-14, interrupted mid-discussion
  by imminent auto-compact -- capture only, not decided/built:** user's
  refinement is a repeat-press CASCADE, not a single fixed action --
  1st Ctrl+L -> redraw (cheapest, least destructive), 2nd (in quick
  succession) -> clear, 3rd -> restore [ presumably un-clearing, i.e.
  redraw the buffer that clear just wiped -- ties directly to the
  buffer already being kept in memory even after a screen clear ].
  ALSO: a timeout resets the cascade back to step 1 (redraw) rather than
  continuing to escalate -- i.e. press Ctrl+L, wait past the timeout,
  press again -> redraw again, not clear. exact timeout value and
  cascade-position storage (presumably another `$mode` field, e.g.
  `ctrl_l_stage` + `ctrl_l_last_press_time`) not designed yet. Revisit
  this fully before implementing Ctrl+L -- don't build the single-action
  version first and retrofit, the cascade shape changes the state model
  from the start.

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

#,,,,,...,.,.,.,.,,.,,.,,,..,,.,,,...,,,,,,..,..,,...,...,...,,,.,...,,.,,...,
#6AK57WPF3FS57VV62WYUSMPVHW7OHDVEBURLRAIFIJJJ3ATCCRCQSPBUTHGG7KH5S7ZYRJVH2CSFE
#\\\|N3HIG4ML3O2OVE4WYZWPDSNKICUOJP26SULBXI2KYOCDPVXF4DF \ / AMOS7 \ YOURUM ::
#\[7]MFZXLIH4GWSXLNA4YG42GT6HIS75NQ6L66OIZ7O7KD4QGG52WACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
