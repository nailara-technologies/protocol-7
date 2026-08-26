# coding zenka user-interaction surfaces

## motivation

the coding zenka's tool set is exhaustive for codebase search [ search_code, ncode_search,
tree_read, note_search, search_memory, ... ] but has no graceful path for "this question is
not a codebase question." observed failure mode: asked about an unrelated general-knowledge
topic mentioned alongside a P7-flavored one, the model correctly exhausted every search
variant, correctly concluded nothing matched, then talked itself back into re-searching rather
than surfacing that conclusion — because its only exits are `escalate` [ blocking, "something
is wrong" framing ] and `record_question`/`record_suggestion` [ fire-and-forget, no reply
loop ]. there is no tool that means "ask the user something small and keep going."

## fallback chain [ before reaching for a human ]

widen the search before concluding "not found":

1. code search [ search_code / ncode_search / module_deps / dep_graph ]
2. context + reasoning templates [ system-default and sibling templates ]
3. design docs [ data/md/design/, data/md/documentation/ ]
4. task files [ task_file_search, data/yaml/coding-tasks, data/md/coding-tasks ]
5. notes [ note_search, note_list ]
6. memory [ search_memory ]

only after all six come up empty does the model classify the query rather than assume it is
unanswerable:

- sounds like general knowledge → `offer_general_answer` [ answer, flagged as outside
  project scope, no UI ]
- sounds technical but genuinely unfiled → `suggest_new_topic` [ non-blocking, tagged
  `topic-proposal`, surfaces as a menu notification badge — not a modal ]
- genuinely stuck / needs a decision → `escalate` [ unchanged, still the "something is
  wrong" path ]

the point of the chain: "no antecedent found in codebase" is not the same conclusion as
"no antecedent found, therefore null." the current prompt collapses those.

## two tracks for talking back to the user

two existing subsystems already cover the two shapes of interaction needed, and neither
needs to be built from scratch — both need a thin plugin layer added on top of what they
already do.

### track 1 — protocol-7-menu : discrete popups

`protocol-7-menu.cmd.input-text` and `.cmd.input-password` already do exactly this shape
of interaction: modal GTK3 dialog, transient-for the graphical window, RGBA visual when
composited, styled via `Gtk3::CssProvider`. good fit for: "ask a yes/no", "pick one of N
pre-generated options", "confirm before I do X" — short, blocking, model-initiated.

missing piece: `protocol-7-menu` has a *provider* registry [ push-based menu items, see
`protocol-7-menu.provider-register` ] but no *dialog-type* registry the way amos-term has
a plugin-type registry [ see track 2 ]. proposed addition, modeled directly on
`amos-term.plugin-init_code`:

```perl
<protocol-7-menu.dialog-types> = {
    qw| input-text     | => { qw| dir | => qw| src/protocol-7-menu.dialog-input-text     | },
    qw| input-password | => { qw| dir | => qw| src/protocol-7-menu.dialog-input-password | },
    qw| input-choice   | => { qw| dir | => qw| src/protocol-7-menu.dialog-input-choice   | },  # new
    qw| notification   | => { qw| dir | => qw| src/protocol-7-menu.dialog-notification   | },  # new
};
```

`input-choice` is the new primitive the coding zenka actually needs: same modal shell as
`input-text`, buttons instead of an entry field, populated from the model's pre-generated
option list.

### track 2 — amos-term : streaming / conversational interaction

amos-term is already a plugin-typed, hot-reloadable extension system [
`amos-term.plugin-init_code` ]: types `decoder` / `routing` / `render` / `input`, each with
a hook and a `src/amos-term.plugin-<type>/` dir, registry watched by inotify for
hot-reload. it already has the exact primitive needed for a live back-and-forth: 3D buffers
with `buffer-attach_generic( buffer_id, kind, { cursor_x, cursor_y, cursor_z, write, read,
data => { on_buffer_change => ... } } )` — which is precisely how `amos-term.nshell.bridge`
wires an interactive shell session into a buffer today.

proposed addition: a fifth plugin type, `interaction`, hook `agent.query`, dir
`src/amos-term.plugin-interaction/`. the coding zenka would:

1. open [ or reuse ] a buffer
2. `buffer-write` its question into it
3. `buffer-attach_generic` with `read => TRUE, write => TRUE`, `on_buffer_change` pointed
   at its own handler
4. keep working — the reply arrives as a buffer-change callback, not a blocking call

this is the track for genuinely open-ended exchanges [ "let's talk through this design" ]
where a modal popup would be the wrong shape — closer to how nshell already lives inside
amos-term than to a dialog box.

buffer lifecycle [ resolved 2026-08-04 ]: a dedicated, lazily-created, *named*, reusable
buffer — `name:agent-interaction` [ must match `<regex.base.usr>`, no dots:
`window-create` passes `client_name` as the session user name to
`base.session.init` ] — not an attachment into an arbitrary window the user
already has open. the zenka cannot know which existing window the user is watching, a
shared buffer interleaves question text with that buffer's own output, and the idle-fade
timeout semantics only make sense on a buffer the channel owns. nshell.bridge attaches
into a buffer created for nshell's own session; the interaction channel does the same.
consequences:

- `ask_user_stream` needs only the well-known buffer name [ `buffer-attach_generic`
  already resolves `name:<name>` ] — no window handle crosses the tool boundary
- multi-turn scrollback via Z-layer history shift [ Z+1, newest at Z=0 ], same as nshell
- window lifecycle is internal to the plugin: `window-create` + `window-open` on first
  question when a GTK session exists; headless → degrade straight to `record_question`;
  reopening a closed window re-attaches to the same named buffer, history survives

implementation caveat [ found 2026-08-04 ]: the amos-term plugin infrastructure described
above is only partially built — `<amos-term.plugin-watcher>` is declared but no inotify
watch is installed, the type hooks are never dispatched, and `on_buffer_change` is
registered by nshell.bridge but never invoked [ `buffer-write` does not notify
attachments ]. this track must add the notify-on-write dispatch, the hot-reload watcher,
and the timeout→`record_question` degrade timer as part of its scope.

### when to use which

- pre-generated, bounded options / confirmations / short text → track 1 [ protocol-7-menu ]
- open-ended, multi-turn, or the model wants to keep a persistent visible channel open →
  track 2 [ amos-term ]
- no graphical session available at all → falls through to `record_question` /
  `note_write`, same as today

## visual consistency

all three existing surfaces already sit in the same near-black navy-to-violet family —
this was not designed as one system, but it reads as one:

| surface                         | fill / background                | accent                              |
|----------------------------------|-----------------------------------|--------------------------------------|
| window-place [ selection frame ] | `rgba(0, 0, 0.24, 0.72)`          | `rgba(0.024, 0.278, 0.765, 0.9–0.95)`|
| protocol-7-menu [ input dialogs] | `#000013`                         | `#0055CC`                            |
| amos-term [ 3D buffer ]          | `rgba(0, 0, 0.024, alpha)`        | cursor `#4427AC`, depth-alpha 1.0→0.3 over Z=13 |

a new `input-choice` / `notification` dialog type should reuse the `#000013` / `#0055CC`
palette unchanged. a new amos-term `interaction` plugin should reuse the existing
`rgba(0,0,0.024,alpha)` background and `cursor-translucency` depth-alpha curve rather than
introduce a new value — an interaction buffer "recedes" the same way distance already does
in that system, so an idle question fades the same way an unfocused Z-layer does.

## coding-zenka tool additions [ sketch, not yet implemented ]

```
ask_user_choice(question, options[])   -> protocol-7-menu.dialog-input-choice   [ track 1, blocking ]
ask_user_text(question)                -> protocol-7-menu.cmd.input-text        [ track 1, blocking ]
ask_user_stream(question)              -> amos-term.plugin-interaction          [ track 2, non-blocking, callback ]
suggest_new_topic(title, rationale)    -> record_suggestion, tag=topic-proposal [ non-blocking, no UI ]
offer_general_answer(disclaimer)       -> no tool call, permission to answer flagged as out-of-scope
```

these would be presented to the model as peers to choose between based on the query shape,
not as a last resort reached only after `escalate` — the framing matters as much as the
tools: give it permission to pick the socially appropriate response instead of defaulting
to more search.

## complementary ideas

these extend the shape above rather than change it — none require picking a different
architecture, they change how the two tracks are *used*.

- **close the loop into memory** — a successful `ask_user_text` / `ask_user_choice` /
  `ask_user_stream` answer should get written back via `note_write` [ tagged e.g.
  `answered-question` ]. otherwise the fallback chain's step 5 [ note_search ] never finds
  it and the same class of question gets asked again next time. the point of the fallback
  chain is that the system should get *smarter* about what's already been settled, not just
  more thorough at re-discovering "not found."

- **batch instead of interrupt-per-question** — accumulate non-urgent `ask_user_choice`
  items during a work session rather than popping a modal the instant one arises. present
  them together at a natural checkpoint [ before `task_complete`, or on an idle timer ].
  matches P7's event-driven / non-blocking philosophy better than one-modal-per-uncertainty,
  and avoids the user being pulled out of flow for something that could wait five minutes.

- **timeout degrade for track 2** — an open amos-term interaction buffer that goes
  unanswered for N minutes should auto-degrade into a `record_question` entry [ with the
  model proceeding on a flagged assumption ] rather than sit blocked indefinitely. streaming
  interaction should never become a silent deadlock.

- **ambient pending-indicator, not a new dialog type** — rather than inventing new UI for
  "you have pending questions," expose it as an ordinary protocol-7-menu *provider* [ same
  push mechanism as the weather example in `protocol-7-menu.example-provider` ]: a small
  tray-style badge, "coding zenka: 2 pending." clicking it opens the oldest pending item via
  track 1. bridges both tracks with zero new plugin types.

- **audit trail on `suggest_new_topic`** — attach which fallback steps were actually
  checked [ search_code / templates / design docs / task files / notes / memory ] to the
  suggestion payload. lets a human reviewing it later trust the model didn't skip straight
  to "not found" without doing the widening search — same spirit as `record_suggestion`
  already being reviewable, but with the chain-of-checks visible instead of asserted.

## status

design only. nothing in this document has been implemented. next concrete steps, in order:
1. `protocol-7-menu.dialog-input-choice` [ smallest, most immediately useful, reuses
   input-text's dialog shell almost verbatim ]
2. `protocol-7-menu.dialog-types` registry + hot-reload wiring [ mirrors amos-term pattern ]
3. coding-zenka tool wrappers for track 1
4. amos-term `interaction` plugin type [ buffer-lifecycle decision resolved
   2026-08-04: dedicated named buffer `name:agent-interaction`, lazy window, Z-shift
   scrollback — see track 2 above. PROTOTYPED live 2026-08-04: notify-on-write
   dispatch added to `buffer-write`, ask/reply round-trip verified headless in
   the amos-term zenka; two `buffer-create` SHM bugs found + fixed [ mmap detach
   via whole-scalar assign, voxel/header offset ]. remaining: timeout-degrade
   timer, inotify watcher, plugin-type scaffolding, GTK window-open path —
   details in `data/yaml/coding-tasks/amos-term-interaction-plugin.yaml` ]

#,,.,,..,,,,.,.,.,.,.,,,,,.,,,...,..,,,.,,,..,..,,...,...,.,.,,,,,...,..,,,,.,
#TEFVMPGFZ63CPG4KRGADSWAH47WSP5ERDCQP3MXIKZ3GZ4VNGGJQGS2FYKWDUHXA44ET5BQ62X5ZS
#\\\|PSQTLIXYQOYL2YWQP757HLBMCJKMOV5FU3XVD5ZNU5F7VGRPAGP \ / AMOS7 \ YOURUM ::
#\[7]XGWPL3TAKXDNNNGIW3E7KRVUJ4SCC44QGTYYKQKGC6EJJBC5BOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
