## [:< ##

# name  = task: editor.* step_2 — wire nshell to editor.control.*, drop AMOS7::TERM
# descr = switch nshell's live editing path from AMOS7::TERM::editor_* to
#         the new editor.control.*/editor.buffer.memory.* modules built in
#         step_1, single-field ('command') schema, zero behavior change

## context

Read `data/yaml/coding-tasks/editor-namespace-interface-design.yaml` in
full first, especially `control_ui_boundary`, `editor.control.*`, and
`migration_path.step_2`. Read `data/tasks/nshell-editor-accessor-port-step0.md`
(done, `290a8f72f`) and `data/tasks/editor-namespace-step1-extract-commands.md`
(done, `e039f1912`) for what already happened — step_0 added
`AMOS7::TERM::editor_get_cursor`/`editor_set_cursor` accessors (still
byte-offset, still `AMOS7::TERM`-backed); step_1 built parallel,
NOT-yet-wired-in `editor.buffer.memory.*` / `editor.control.*` modules
(character-offset, semantics-only), proven correct against `AMOS7::TERM`
by a parity test but never called by anything live.

THIS task is what actually switches nshell over. Unlike step_0 (pure
accessor rename, same object shape) and step_1 (new code, nothing called
it), this task changes the SHAPE of the object nshell's editor state holds
— from `AMOS7::TERM`'s flat `{buffer, cursor_pos, kill_buffer, color_set}`
hash to `editor.control.create`'s `{schema, fields=>{command=>$buffer_ref},
active_field, mode, kill_buffer}` shape. That means every remaining direct
hash-key touch on the editor object (not just the `AMOS7::TERM::editor_*`
call sites) must be found and converted, including ones step_0 correctly
left alone because at that time the shape hadn't changed yet. See the
CRITICAL section below — do not skip it.

## new schema constant

Create `src/editor.control.process_key` schema... no — create ONE new
small module, `src/nshell.editor.default_schema`, returning:

```perl
return {
    'fields' => [
        {   'name' => 'command',
            'type' => 'freeform_line',
        },
    ],
    'submit_on'    => 'enter',
    'active_field' => 0,
};
```

Use `<[nshell.editor.default_schema]>` at every place that currently calls
`AMOS7::TERM::editor_init()` (listed below) instead of inlining the schema
hash three times — it's the same literal at every call site and duplicating
it risks drift.

## exact conversions (verified against current file contents 2026-08-09)

### src/nshell.editor.process (the biggest change)

- line 7: `my ( $editor, $key, $colors ) = @ARG;` — unchanged, `$colors` is
  still used elsewhere in this file for terminal output, just no longer
  passed into process_key.
- line 10: `$editor //= AMOS7::TERM::editor_init();`
  → `$editor //= <[editor.control.create]>->( <[nshell.editor.default_schema]> );`
- line 13: `my $edit_result = AMOS7::TERM::editor_process_key( $editor, $key, %$colors );`
  → `my $edit_result = <[editor.control.process_key]>->( $editor, $key );`
  (drop `%$colors` entirely — `editor.control.process_key` takes no colors,
  per `control_ui_boundary`)
- line 67: `if ( $action eq 'newline' ) {` → `if ( $action eq 'submit' ) {`
  **action name changed**: `editor.control.process_key`'s Enter-key branch
  emits `action=>'submit'` when `schema.submit_on eq 'enter'` (which our
  schema sets), NOT `'newline'`. `'newline'` in the new contract is
  reserved for an actual newline-insertion inside a future multiline
  field type — never emitted for `freeform_line`. Get this wrong and the
  newline branch below silently never fires.
- lines 51-52 (inside the `signal` branch): `AMOS7::TERM::editor_get_cursor($editor)`
  / `AMOS7::TERM::editor_get_buffer($editor)`
  → `<[editor.control.get_cursor]>->( $editor, 'command' )` /
  `<[editor.control.get_value]>->( $editor, 'command' )`
- line 60: `my $sig = $edit_result->{should_signal} // 'INT';`
  → `my $sig = $edit_result->{signal} // 'INT';` **key renamed**:
  `editor.control.process_key`'s signal result uses `{signal}`, not
  `{should_signal}` (see `src/editor.control.process_key` line ~58).
- lines 68-69 (top of the renamed submit branch): same get_cursor/get_value
  swap as above.
- line 97: `print $edit_result->{output};`
  → `print "\n";` — the new contract has NO `output` key at all (that's
  the whole point of `control_ui_boundary`). On the old code path this was
  ALWAYS exactly `"\n"` for the newline action (see `AMOS7::TERM::editor_process_key`
  line ~1220: `$result->{output} = "\n";` for that branch) so hardcoding it
  here is not a behavior change, just removing a round-trip through a field
  that no longer exists.
- line 100: `my $result = AMOS7::TERM::editor_submit($editor);`
  → replace with:
  ```perl
  my $submit_result = <[editor.control.submit]>->($editor);
  my $result = ( $submit_result->{'ok'} ? $submit_result->{'values'}{'command'} : '' ) // '';
  ```
  `editor.control.submit` returns `{ok=>1,values=>{...}}` or
  `{ok=>0,errors=>{...}}`, not a plain string, and only resets the fields
  on `ok=>1` (no validators are wired anywhere in this schema, so `ok` is
  always 1 in practice today — but write the real conditional, don't
  assume, since that's the actual contract per the design doc's
  `editor.control.submit` section).

### CRITICAL — src/nshell.read_from_buffer, lines 162-163

```perl
$state_ref->{'editor'}->{buffer}     = '';
$state_ref->{'editor'}->{cursor_pos} = 0;
```

Step_0's task explicitly told the previous implementer to leave these two
lines untouched, because at that time `AMOS7::TERM::editor_reset()` would
have additionally cleared `kill_buffer`/`color_set` — a real behavior
change step_0 wasn't allowed to make. **That reasoning no longer applies
in this task**: the object's shape is changing entirely, so these two
raw writes are now simply WRONG (there is no top-level `buffer`/
`cursor_pos` key on an `editor.control.create` state — writing them
directly does nothing useful and leaves the real field data untouched).

Use `editor.control.reset`'s per-field mode, which was built specifically
to match this old behavior (see `src/editor.control.reset`'s own
comment: "per-field reset clears that field's text/cursor only... matches
`AMOS7::TERM::editor_reset` semantics" for the full-reset case; passing a
field name gives you the narrower per-field version, which does NOT touch
`kill_buffer` — exactly what the two old direct writes did):

```perl
<[editor.control.reset]>->( $state_ref->{'editor'}, 'command' );
```

Do not use `<[editor.control.load_field]>->($state_ref->{'editor'},'command','')`
here even though it would also clear the text — `load_field` additionally
clears `kill_buffer` unconditionally (see its own doc comment: "external
rewrite clears the kill buffer"), which `reset($state, $field)` does NOT.
Preserving kill_buffer here matches existing behavior; getting this wrong
is a subtle live regression (yank-after-search-select would silently stop
working), not a crash — verify this specific case manually, not just via
`perl -c`.

### src/nshell.read_from_buffer, other lines

- lines 28, 107: `$state_ref->{'editor'} //= AMOS7::TERM::editor_init();`
  → `$state_ref->{'editor'} //= <[editor.control.create]>->( <[nshell.editor.default_schema]> );`
- lines 35, 158, 261 (`AMOS7::TERM::editor_get_buffer( $state_ref->{'editor'} )`):
  → `<[editor.control.get_value]>->( $state_ref->{'editor'}, 'command' )`

### src/nshell.render.viewport, lines 12-13

```perl
my $buffer     = AMOS7::TERM::editor_get_buffer($editor);
my $cursor_pos = AMOS7::TERM::editor_get_cursor($editor);
```
→
```perl
my $buffer     = <[editor.control.get_value]>->( $editor, 'command' );
my $cursor_pos = <[editor.control.get_cursor]>->( $editor, 'command' );
```

### src/nshell.render.cursor, lines 9-10

Same conversion as render.viewport above.

### src/nshell.handler.ctrl_o_cycle

- line 8: `AMOS7::TERM::editor_get_buffer( $state_ref->{'editor'} ) // '';`
  → `<[editor.control.get_value]>->( $state_ref->{'editor'}, 'command' ) // '';`
- lines 70, 96: `AMOS7::TERM::editor_load( $state_ref->{'editor'}, $text );`
  → `<[editor.control.load_field]>->( $state_ref->{'editor'}, 'command', $text );`
  (3-arg call, cursor defaults to `'end'` inside `load_field` — matches
  `editor_load`'s own default, no 4th arg needed)

### src/nshell.handler.ctrl_o_render_preload, line 15

Same `get_value` swap as render.viewport.

### src/nshell.render.empty_prompt, line 23

`AMOS7::TERM::editor_load( $editor, '' );`
→ `<[editor.control.load_field]>->( $editor, 'command', '' );`

### src/nshell.history.arrow_up (line 80), arrow_down (line 66),
### page_up (line 77), page_down (line 60)

All four: `AMOS7::TERM::editor_load( $editor, $state_ref->{'display_buffer'} );`
→ `<[editor.control.load_field]>->( $editor, 'command', $state_ref->{'display_buffer'} );`

### src/nshell.search.handler, lines 131, 191, 237

Same `editor_load` → `load_field` conversion (3 sites, same shape as above).

### src/nshell.no-tty-debug.cmd.char-add, lines 250, 270, 310 (all
`$diag_editor`) and line 325 (`$editor`)

All four are `AMOS7::TERM::editor_get_buffer(...)` reads →
`<[editor.control.get_value]>->( ..., 'command' )`. Lower priority
(diagnostic tool) but convert for consistency — the object shape change
means the old calls would return garbage/undef here too if left alone,
not just look stale.

## explicitly out of scope

- do not touch `AMOS7::TERM.pm` itself — its `editor_*` functions stay as
  they are, for any other future caller; this task only stops nshell from
  calling them.
- do not add multi-field support, other field types, or any `editor.ui.*`
  — schema stays exactly the one-field literal above.
- do not touch `bin/test-scripts/test-editor-control-parity.pl` — it
  tests `editor.control.*` against `AMOS7::TERM` directly and doesn't
  care what nshell calls.

## verification (required, not optional — this is a live-path change)

1. `perl -c` every touched file.
2. Grep the whole `src/nshell.*` tree for `AMOS7::TERM::editor_` and
   for any remaining direct `->{buffer}` / `->{cursor_pos}` / `->{kill_buffer}`
   / `->{color_set}` touches on an editor object after your changes — there
   should be ZERO occurrences of either. If any remain, they were missed,
   not intentionally preserved (unlike step_0, nothing in this task should
   still be touching the old shape).
3. Live nshell exercise, the same coverage step_0 verified byte-identical
   transcripts for for: typing, left/right arrow, Ctrl-A/E, backspace/
   delete, Ctrl-K/U/W/Y (kill/yank), history recall (up/down arrow,
   page up/down), Ctrl-O cycling, Ctrl-R search (select AND cancel paths),
   submitting a command, Ctrl-C signal mid-line, UTF-8 multi-byte
   characters, and specifically: search-select a history entry, then
   Ctrl-Y yank — this exercises the CRITICAL fix above directly (confirms
   `kill_buffer` survives a post-search buffer clear).
4. Report the exact diff and what you observed in step 2 and step 3 —
   not a summary of intentions. If step 2's grep finds anything, say so
   explicitly rather than silently fixing it and not mentioning it.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done (will need taeki's passphrase — leave pending, that's fine).

## status: done 2026-08-09 [ signatures pending: update-signatures needs
##   taeki's interactive sourcecode key passphrase — same as step_0/1 ]
##
## delivered: 1 new module [ nshell.editor.default_schema ] + 13 nshell.*
## modules converted off AMOS7::TERM::editor_* onto editor.control.*
##
## verification performed:
## - p7-module-syntax-check on all 14 files: error sets normalized and
##   diffed against pristine HEAD copies -> IDENTICAL [ only pre-existing
##   checker limitation re runtime globals %colors/$call, no new errors ]
## - grep checks [ task step 2 ]: 'AMOS7::TERM::editor_' in src/nshell.*
##   -> ZERO matches. raw ->{buffer}/->{cursor_pos}/->{kill_buffer}/
##   ->{color_set} touches -> only nshell.hook.input_passthrough lines
##   20/29 remain, which are $session->{'buffer'}->{'input'} [ a session
##   object, NOT the editor object ] — zero editor-object touches remain
## - live parity [ step_0 harness, extended ]: same P7-loader-faithful
##   harness driving the real no-tty-debug input path, before = HEAD
##   modules + HEAD TERM.pm, after = converted modules + editor.control.*;
##   25-chunk keystroke script incl. typing, arrows, ctrl-a/e/d/k/u/w/y,
##   yank, page up/down, history up/down+submit, ctrl-o x2, ctrl-r select
##   AND cancel, >80col overflow, utf-8 multibyte [ raw byte input ],
##   ctrl-c mid-line, PLUS the critical case: kill-word, ctrl-r select
##   [ hits the lines 162-163 conversion ], ctrl-y yank, submit.
##   transcripts BYTE-IDENTICAL [ 15505 bytes each, diff empty ].
##   observed on the critical case: SUBMIT:git status after select, and
##   the post-select yank submits EMPTY in BOTH paths — because
##   search.handler's editor_load/load_field at select time already clears
##   kill_buffer, before lines 162-163 ever run. the reset-per-field
##   conversion [ vs load_field('') ] is therefore defensive: the two old
##   direct writes' kill-preservation is currently unreachable via
##   search-select. conversion followed the task's explicit instruction
##   regardless [ reset per-field, NOT load_field ].
## - char<->byte boundary [ not covered by the task file, discovered in
##   implementation ]: editor.control.* is character-based with decoded
##   text; nshell's terminal/history/execution paths are byte-oriented.
##   without conversion, a decoded é would print as raw byte 0xE9 instead
##   of utf-8 0xC3 0xA9. handled by reconstructing the byte view at each
##   output boundary [ utf8::encode + char->byte cursor prefix length ] in
##   nshell.editor.process, render.viewport, render.cursor,
##   handler.ctrl_o_cycle, handler.ctrl_o_render_preload,
##   read_from_buffer [ execution return + debug logs ].
##   pre_search_buffer deliberately kept character-based [ only
##   round-trips back into the editor via load_field, never printed ].
##   byte-identity of the idiom verified: 'hé' prefix -> 3 bytes 68c3a9.
## - step_1 parity test re-run: 334/334 pass [ untouched, still green ]
## - action rename 'newline'->'submit' and key rename
##   {should_signal}->{signal} applied in nshell.editor.process
## - NOT done by agent: bin/Protocol-7 sourcecode update-signatures
##   [ interactive passphrase ], no git commit

#,,.,,..,,,,.,,.,,...,,.,,,,.,.,.,,,.,,,,,.,.,..,,...,...,..,,,,.,.,.,.,,,...,
#L5SFAXLQNE7OQGUEFO6P4JS25SLCHEG7EUJSFU4ZE5BHZR2U3EVUP5Z6DNRCSEGEA772FSZQHRM4U
#\\\|F57ZFWRRKRZEFMVKWDY6ZBRHI7UOTMB3J4Q7WRSM6DGQLZ7QLTB \ / AMOS7 \ YOURUM ::
#\[7]TXST7GCMW4L5GF6GV3C56OTXMLKKQFFL27FPEDPG4RHRAGKVN6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
