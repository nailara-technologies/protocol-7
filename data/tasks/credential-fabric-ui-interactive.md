# task: credential fabric ui — interactive selection + actions [ phase 2 + 3 ]

## relation to CONSOLE-FOLD-TREE-PHILOSOPHY

the **interactive verbs** here (select / act / unlock) operate on
nodes that, per `data/md/design/CONSOLE-FOLD-TREE-PHILOSOPHY.md`, are
already foldable handles into the namespace. selection is "give this
folded handle attention" and unfold is the response — proving the
fold/unfold verbs flow naturally into interaction without a separate
interaction model.

## dispatch
add interactive selection, slot actions, and key-holder unlock to the
cred-mesh ui. requires `cred-mesh-ui-frames.md` to have
landed. read first:
`data/md/design/CRED-MESH-INTEGRATION-AND-UI.md` (part 2,
"selection layer", "actions", "key-holder dialog integration");
`data/tasks/cred-mesh-ui-frames.md`;
the render modules created by the frames task
(`cred-mesh.ui.render.*`);
`src/keys.console.list` for the ansi colorisation pattern that
highlight rendering will mirror;
`src/cred-mesh.rotate`, `src/cred-mesh.register`,
`src/cred-mesh.key_holder.parent`,
`src/cred-mesh.key_holder.child` for the operations the ui
will trigger and the unlock pipe contract.
this task does NOT add a new windowing system, vterm integration, or
multi-pane layout. it operates inside one tty session at a time.

## scope

three layers added on top of phase 1's read-only views:

1. **selection state + highlight rendering** — per-session focus row,
   re-render-on-input loop
2. **slot actions** — rotate, revoke, grant, approve
3. **key-holder unlock dialog** — phrase-prompt frame, no-echo input,
   pipe contract to key-holder.child for decrypting `fabric.secret`

## part 1 — selection state

### where state lives
`<session.$session_id.cred-mesh.ui.focus>` — per-session, so
multiple nshell users do not collide. shape:
```perl
{
    view      => 'slots',              ## current view name
    row_index => 3,                    ## 0-based row in current view
    row_count => 12,                   ## last-rendered row count, for clamping
    row_keys  => [ 'openweathermap.api-key', ... ],  ## resolved keys per row
    pending_action => undef,           ## or 'approve_payload', 'grant_zenka'
}
```

`row_keys` is filled by the render module — when a render layer produces
the rows, it ALSO returns the ordered keys to the dispatch layer. tiny
contract change on the render layer: instead of returning just the
string, return `{ rendered => $str, row_keys => \@keys }`. update the
phase-1 render modules to add `row_keys` (which can be `[]` for views
without selectable rows like `overview`).

[ note: this is a backward-compatible extension — callers that only
  want the string can read `$result->{rendered}`. the phase-1
  acceptance still holds. ]

### selection modules

under `src/cred-mesh.ui.interactive.*`:

- `cred-mesh.ui.interactive.up` — decrement `row_index`,
  clamp to 0
- `cred-mesh.ui.interactive.down` — increment, clamp to
  `row_count - 1`
- `cred-mesh.ui.interactive.refresh` — re-run the active
  view's render and reprint. returns the new rendered string.
- `cred-mesh.ui.interactive.select_view` — switches the
  current view, resets row_index to 0, returns first refresh

### highlight rendering

selection is colorisation, not a new frame primitive. each render
module receives an optional `focus_index` param. when present and
the row index matches, that row's content line is wrapped with the
project's ansi inverse marker (`$C{T}` background swap or
`\e[7m...\e[27m`). pattern: the row format is already a single line
inside the block slot; pre-render the row, then conditionally wrap.

update phase-1 render modules that have selectable block slots
(`registry-list`, `rotation-log`, `auth-relay-queue`) to accept and
apply `focus_index`. detail and key-holder-status views ignore it.

## part 2 — slot actions

### action dispatch
`src/cred-mesh.ui.interactive.action` — args: `action_name`,
`session_id`. reads focus state, finds the focused slot/req_id from
`row_keys`, dispatches.

```perl
my $key = <session.$sid.cred-mesh.ui.focus>->{'row_keys'}
    ->[ <session.$sid.cred-mesh.ui.focus>->{'row_index'} ];
```

### actions to implement

**`rotate`** — calls `cred-mesh.rotate` with the focused slot
name. on success, refreshes the current view. on failure, sets a
one-line status message in `<session.$sid.cred-mesh.ui.status>`
that the render layer prints below the frame.

**`revoke`** — sets `<cred-mesh.registry>->{$slot}->{'revoked'}`
= TRUE and persists the registry. `cred-mesh.resolve` returns
undef for revoked slots — small edit to `cred-mesh.resolve` to
check the flag and bail early. revoked slots stay in the list but are
rendered with a strikethrough marker (e.g. `[revoked]` suffix) so the
user sees them.

**`grant`** — opens a sub-frame prompt (`grant-prompt.yaml`, new
template) asking for a zenka name. sets `<session.$sid.credential_
fabric.ui.focus>->{'pending_action'} = 'grant_zenka'`. on the next
input cycle, the input is captured as the zenka name and appended to
the slot's `access_grants` list (new field; default `[]`). this is
**advisory** for now — the actual access check still belongs to
`cfg/zenki/cube/access.zenki`. mention this clearly in the
status line: `granted (advisory — update cube access for enforcement)`.

**`approve`** — only valid on the auth-relay queue view. opens
`approve-prompt.yaml` (new template) asking for the credential payload.
on submit, calls `cred-mesh.cmd.approve` (created by the wiring
task). for high-sensitivity types, the prompt routes through the
unlock-prompt frame instead (no echo).

### action key bindings

mapped at the nshell-side input handler — `nshell.editor.process` or
its key dispatch table — when the active view is one of the credential-
fabric ui views. bindings:

```
j / down arrow      → interactive.down
k / up arrow        → interactive.up
r                   → interactive.action rotate
x                   → interactive.action revoke
g                   → interactive.action grant
a                   → interactive.action approve
?                   → interactive.action detail   [ switch to registry-detail of focused slot ]
q / ESC             → exit ui mode, return to normal nshell
```

[ this is the only nshell-touching change in the task — confirm the
  key dispatch table location in `src/nshell.editor.process` or
  `src/nshell.handler.command_reply` during implementation. keep
  the bindings active only when the current command was a
  `cred-mesh.ui.show` view. ]

### action prompts

new frame templates under `data/yaml/ascii-frames/cred-mesh/`:

**`grant-prompt.yaml`** — one-line input frame:
```
.:[ grant access to ]:::::::::::::::::::::::::[ zenka name ]:.
:  > {{ZENKA_NAME}}                                          :
:............................................................:
```

**`approve-prompt.yaml`** — one-line input frame:
```
.:[ approve relay ]:::::::::::::::::::::[ {{REQ_ID}} ]:.
:  > {{PAYLOAD}}                                       :
:......................................................:
```

both have one editable slot (`ZENKA_NAME`, `PAYLOAD`). the editor
itself runs in the nshell-side input layer — the frame is the visual
container only.

## part 3 — key-holder unlock dialog

**revision**: the primary path is now `protocol-7-menu.cmd.input-
password` (gtk modal, masked entry — read that module). the custom
`unlock-prompt.yaml` + nshell no-echo handler described below is the
**secondary headless-fallback** path, used only when the gtk dialog
returns `{ mode => 'false', data => 'graphical mode not enabled' }`.

phasing inside this part splits accordingly:

- **phase 3a** (small): edit `cred-mesh.key_holder.parent` to
  route-send to `protocol-7-menu.cmd.input-password` when an unlock is
  needed. on `reply.mode == 'true'`, write phrase to the child pipe.
  on graphical-mode-not-enabled, branch to 3b. on cancellation, leave
  child locked and surface failure to the next resolve call.
- **phase 3b** (the original work below): the frame + no-echo nshell
  handler, only invoked when 3a falls back.

cross-zenka note: `cred-mesh` calling `protocol-7-menu.cmd.
input-password` is a new edge — see `cred-mesh-wiring.md` §5
for the same plumbing on the auth-relay path. land that first or in
parallel; the same access.zenki entry covers both call sites.

### the migration this assumes
currently `cred-mesh.key_holder.child` (src/credential_
fabric.key_holder.child) auto-generates `var/cred-mesh/
fabric.secret` unencrypted on first run. the design assumes this
secret will be twofish-encrypted with a user phrase. **migrating
existing unencrypted stores is out of scope of this task** — it is
flagged as a follow-up in the design doc's risks section. this task
implements the dialog and pipe contract assuming the encrypted form;
the actual encryption switch lands separately.

if no encrypted-secret form exists on disk when this task lands,
the unlock dialog is dead code — confirm with the design doc author
before merging.

### the contract
`cred-mesh.key_holder.parent` will get a new state machine:

```
start
  → read fabric.secret header
  → if header indicates encrypted form (magic prefix, e.g. "EU:")
      → fork child without phrase
      → child blocks on its pipe for an `UNLOCK <phrase_b32>` line
      → parent emits event cred-mesh.ui.event.unlock_required
      → ui renders unlock-prompt frame
      → user types phrase (no echo)
      → ui sends phrase via cred-mesh.cmd.unlock
      → cmd writes UNLOCK line to parent → forwards to child
      → child decrypts secret, derives keys, prints "READY"
      → parent unblocks
```

### new template

**`unlock-prompt.yaml`**:
```
.:[ key-holder ]::::::::::::::::::::[ phrase required ]:.
:  > {{PHRASE_MASKED}}                                  :
:.......................................................:
```

`PHRASE_MASKED` is `*` per character, length = phrase length. echo
suppression lives in the nshell-side input handler — the frame just
renders the mask.

### new modules

- `src/cred-mesh.cmd.unlock` — receives the phrase from
  the ui, forwards to `key_holder.parent`. clears the phrase from
  memory after send (set to undef, no logging).
- `src/cred-mesh.ui.interactive.unlock_dialog` — renders
  the unlock-prompt frame, sets `<session.$sid.cred-mesh.ui.
  input_mode> = 'no_echo'`, registers a one-shot input handler that
  sends the phrase to `cmd.unlock` then closes.

### edits to existing modules

- `cred-mesh.key_holder.child` — add UNLOCK op alongside
  ENCRYPT/DECRYPT/SIGN. when received, decrypts `fabric_secret` using
  the phrase via `AMOS7::13::key_32` + `AMOS7::Twofish::decrypt`.
  responds `READY\n` on success, `ERR <msg>\n` on failure.
- `cred-mesh.key_holder.parent` — buffer pre-unlock requests,
  flush them once child sends `READY`. on `ERR` from child, do NOT
  retry automatically — emit a fresh `unlock_required` event so the
  user can correct the phrase.

## what NOT to do

- do not add a new zenka.
- do not extend `ascii.frame.*` or `pager.*` or `vterm.*` internals.
- do not write the actual fabric.secret-encryption migration here.
  that is its own task — flag it in the design doc and stop.
- do not log the phrase, ever. not at level 5, not at trace level,
  not in error messages. an accidental log line here is a hard
  failure of this task.
- do not add the `#,,..` signature stub to any new file.

## acceptance

phase 2 (selection + actions):
- with the ui active, `j`/`k` move the highlight up/down in the slot
  registry view. row count is clamped correctly.
- pressing `r` on a focused slot rotates it; the view re-renders with
  a new `last_rotated` timestamp visible in the detail card.
- pressing `x` marks the slot revoked; `resolve` returns undef for it
  afterwards; the row shows `[revoked]`.
- pressing `g`, then typing a zenka name, then enter, appends the
  zenka to `access_grants`. status line shows the advisory message.
- pressing `a` on a pending relay row, typing a payload, hitting
  enter, calls the wiring task's `cmd.approve` and removes the relay
  entry.

phase 3 (unlock):
- with an encrypted fabric.secret in place, starting the credential_
  fabric zenka renders the unlock prompt automatically.
- typing the wrong phrase shows an error status and re-prompts.
- typing the right phrase unblocks the holder; subsequent
  `cred-mesh.resolve` calls succeed.
- the phrase never appears in any log file or in-memory data tree.

## harmony checks
```
harmony cred-mesh.ui.interactive.up
harmony cred-mesh.ui.interactive.down
harmony cred-mesh.ui.interactive.refresh
harmony cred-mesh.ui.interactive.select_view
harmony cred-mesh.ui.interactive.action
harmony cred-mesh.ui.interactive.unlock_dialog
harmony cred-mesh.cmd.unlock
```

re-run harmony on edited modules (`cred-mesh.resolve`,
`cred-mesh.key_holder.parent`, `cred-mesh.key_holder.
child`, the phase-1 render modules that added `row_keys`).

## signatures note
do not add the `#,,..` stub to any new file. lowercase comments,
`[ word ]` annotations. no emoji.

#,,..,...,,,..,...,,,..,..,,..,..,,.,,..,,,..,,..,...,...,..,,,,.,,,..,..,...,

#,,.,,.,,,,.,,.,,,,,,,.,,,...,.,.,,,.,.,,,,,.,..,,...,...,.,.,,.,,,..,.,,,,,.,
#AAPOVPMXP3TGOK6EVDCNLLVMSHHFH6JICKFVUQHLEKQ5YZ2MOXVNJDAPG37CQAPBB2N47T3RCYSAQ
#\\\|W5M7D63ILXPARKEDINXEFXQJRULW5D6YL4ETKDXO45W3TBHTVCO \ / AMOS7 \ YOURUM ::
#\[7]VUBJ4DYFDWUGFXEZ5TBYDKSCEIEJK77WB4FCCX23NDPKUWKBNEBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
