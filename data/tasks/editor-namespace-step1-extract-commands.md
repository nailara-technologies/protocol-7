## [:< ##

# name  = task: editor.* step_1 — extract buffer.memory + control.* (single field, isolated)
# descr = build the new editor.buffer.memory / editor.control.* modules by
#         porting AMOS7::TERM::editor_process_key's logic to character
#         offsets and a semantics-only return contract, proven by parity
#         testing against the existing byte-offset implementation.
#         nshell is NOT touched in this task — that is step_2, separate.

## context

Read `data/yaml/coding-tasks/editor-namespace-interface-design.yaml` in
full before starting — this task implements pieces of it, and getting the
contracts wrong here means step_2 (wiring nshell to call these instead of
AMOS7::TERM) breaks. Specifically read: `schema`, `position_units`,
`field_types`, `control_ui_boundary`, `editor.control.*` (all subsections:
create/process_key/commands/accessors/submit), `editor.buffer.*` (contract
+ memory), `migration_path.step_1` and `step_1_is_not_mechanical`.

`data/tasks/nshell-editor-accessor-port-step0.md` (done, committed
`290a8f72f`) was step_0 — it added `editor_get_cursor`/`editor_set_cursor`
to `AMOS7::TERM.pm` and routed nshell's direct hash-key touches through
accessors. That work is NOT part of this task's scope; it's prerequisite
context only. This task builds parallel NEW modules — it does not modify
`AMOS7::TERM.pm` or any `nshell.*` file.

## why isolated (no nshell wiring yet)

This is deliberately safe to get wrong on the first attempt: nothing calls
these new modules yet, so there is no live behavior to regress. The
correctness bar is parity with `AMOS7::TERM::editor_process_key` under a
fixed keystroke script, not "nshell still works" (that's step_2's job,
against a version of this code already proven correct here).

## scope

### 1. `modules/editor.buffer.memory` (or split into per-operation files if
that matches this project's module-per-file convention better — check
`modules/data.mount.shm.*` for the convention of one topic split across
many small `topic.verb` files vs one file per contract method)

Implements the buffer contract from the design doc's `editor.buffer.*`
section, for ONE in-memory scalar text buffer:

```
load( $buffer, $source )
save( $buffer, $destination )
insert( $buffer, $position, $text )      # $position in CHARACTERS
delete( $buffer, $start, $end )          # char offsets, half-open [start,end)
get_line( $buffer, $line_num )           # line 0 only for this field type
get_text( $buffer )
length( $buffer )                        # in characters
```

CHARACTER offsets, not byte offsets — this is the design doc's
`position_units` decision, not a suggestion. `AMOS7::TERM` today uses byte
offsets with hand-rolled utf-8 continuation-byte scanning (see
`editor_process_key`'s Ctrl-D/Ctrl-W/left/right/delete/backspace branches,
lines ~1231-1466, for the exact scanning logic being replaced) — that
scanning is being replaced by proper character-aware operations
(`substr`/`length` on a UTF-8-flagged string do the right thing without
manual byte-width detection; confirm the string is actually decoded, not
byte soup, at buffer creation).

### 2. `editor.control.create( $schema ) -> $editor_state`

For this task, `$schema` only needs to support ONE field, type
`freeform_line` (the only field type with a real implementation right
now — `enum`/`masked`/`readonly`/`freeform_multiline` stay interface-only
per the design doc's migration note, do not implement them).
`$editor_state` shape exactly as specified in the design doc's
`editor.control.create` section.

### 3. `editor.control.process_key( $editor_state, $key ) -> $result`

Port the KEY-DISPATCH LOGIC (not the ANSI-output-building) from
`AMOS7::TERM::editor_process_key` — same key bindings (newline, Ctrl-C
signal, Ctrl-D delete-at-cursor, Ctrl-A/E line-start/end, Ctrl-K/U kill
to-end/from-start, Ctrl-W kill-word-backward, Ctrl-Y yank, arrow
left/right, Delete key, Backspace, printable-char insert), but:

- `$result` contains ONLY `action`/`field`/`dirty`/`signal`/`passthrough`
  per `control_ui_boundary` — NO `output` key, no ANSI bytes, no
  `%colors` parameter. This is a deliberate contract break from
  `AMOS7::TERM`, already justified in the design doc (nshell's real
  caller already discards `{output}` except on the newline path).
- cursor arithmetic operates on CHARACTER positions via
  `editor.buffer.memory`'s contract, not byte positions with manual
  utf-8 scanning — the whole point of doing this now is to retire that
  scanning, not carry it forward.
- `action=signal` is advisory only (per design doc) — this module must
  NOT call `kill($sig, $$)` itself. Return `{action=>'signal', signal=>'INT'}`
  and let the caller decide (nshell will call `kill()`, a hypothetical
  GTK3 host would not).
- `field_next`/`field_prev`/`passthrough` for unrecognized keys: since
  this task's schema is always single-field, `field_next`/`field_prev`
  never fire (design doc: "a single-field schema never sees them") — but
  the dispatch code should still be structured so it doesn't crash if a
  future multi-field schema reaches this function; don't hardcode
  single-field assumptions where the design doc's contract implies
  multi-field will come later (see `editor.control.active_buffer`
  below).

### 4. `editor.control.commands.insert/.delete/.move_cursor`

Thin wrappers per the design doc's `editor.control.commands` section,
operating on `$editor_state->{fields}{$field}` via `editor.buffer.memory`.
`process_key` should call these rather than duplicating buffer mutation
logic inline — that's the actual point of extracting them as separate
commands.

### 5. `editor.control.load_field / get_value / get_cursor / reset`

Per the design doc's `accessors` section — these did not exist in
revision 1 and were added because `AMOS7::TERM::editor_load` has 8 call
sites outside the key loop in real nshell code (history recall x4,
reverse-search x3, ctrl-o cycling x2, empty-prompt) that this design must
eventually support in step_2. Build them now so step_2 has something to
call. `load_field`'s `$cursor` parameter (`'end'` default / `'start'` /
integer offset) as specified.

### 6. `editor.control.submit( $editor_state ) -> { ok, values | errors }`

Per the design doc: reset fields ONLY on `ok=>1` (this differs from
`AMOS7::TERM::editor_submit`, which resets unconditionally — safe there
only because no validators exist). Since no validator mechanism is being
built in this task either, `ok=>1` always for now — but write the reset
gate as a real conditional, not an unconditional reset with a TODO, so
adding a validator later doesn't require touching this function again.

### 7. `editor.control.active_buffer( $editor_state ) -> $buffer_ref`

Per the design doc — resolves the indexing bug flagged in revision 2
(`$editor_state->{fields}` is keyed by field NAME, `active_field` is an
INDEX into `$schema->{fields}`, so `$editor_state->{fields}{$active_field}`
is a type error). Any place that would otherwise need the active field's
buffer should call this helper instead of inlining that lookup.

### 8. kill_buffer placement (design doc left this open — resolve it here)

For this task's single-field schema, put `kill_buffer` on `$editor_state`
directly (not inside the per-field buffer) — simplest choice that behaves
identically to a per-field or shared-ring design when there is only one
field. Leave a one-line comment noting this is provisional pending the
design doc's open multi-field kill-ring question — don't design a ring
structure now, that's speculative for a schema shape that doesn't exist
yet.

## explicitly out of scope (do not build)

- anything touching `modules/nshell.*` or `data/lib-path/pm/AMOS7/TERM.pm`
  — step_2's job, not this task's.
- `enum`/`masked`/`readonly`/`freeform_multiline` field types.
- multi-field schemas, `field_next`/`field_prev` actual behavior,
  `render_form`.
- `editor.ui.*`, `editor.plugin.*`, `editor.buffer.shm/file/mount/virtual`.
- undo/redo journal (design doc left this as an open question — don't
  answer it here).
- the config-reload-survival open question.

## verification (required)

1. `perl -c` every new file.
2. Write a parity test (script under
   `/tmp/protocol-7-scratch/` or this project's normal test-script
   location if one exists for module-level tests — check
   `bin/test-scripts/` conventions first) that:
   - drives `AMOS7::TERM::editor_init` + `editor_process_key` (old path)
   - drives `editor.control.create` + `editor.control.process_key` (new
     path) with an equivalent single 'command' field schema
   - feeds BOTH the same keystroke sequence (reuse or adapt the
     22-chunk-ish script from step_0's verification if it still exists on
     disk, or reconstruct an equivalent one covering: typing (including
     multi-byte UTF-8), left/right arrow, Ctrl-A/E, backspace/delete,
     Ctrl-K/U/W/Y, yank, newline/submit, Ctrl-C signal)
   - asserts the resulting buffer TEXT and CURSOR POSITION (converted
     appropriately — old path's cursor_pos is bytes, new path's is chars;
     for pure-ASCII test input these are numerically equal, so include at
     least one UTF-8 multi-byte case specifically to prove the char-offset
     conversion is correct, not just coincidentally matching on ASCII)
     agree after every step, not just at the end.
3. Report the parity test's pass/fail output directly, plus the full diff
   of new files created — not a prose summary of intentions.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done (same as step_0 — will need taeki's passphrase, that's fine,
leave it pending and say so).

## status: done 2026-08-09 [ signatures pending: update-signatures needs
##   taeki's interactive sourcecode key passphrase — same as step_0 ]
##
## delivered [ all NEW files, nothing existing touched ]:
##   modules/editor.buffer.memory.{create,load,save,insert,delete,
##     get_line,get_text,length}                    [ 8 files ]
##   modules/editor.control.{create,active_buffer,process_key,load_field,
##     get_value,get_cursor,reset,submit,
##     commands.insert,commands.delete,commands.move_cursor} [ 11 files ]
##   bin/test-scripts/test-editor-control-parity.pl
##
## verification performed:
## - perl -c : all 19 module files + test script OK
## - bin/test-scripts/p7-module-syntax-check : all 19 modules OK
## - parity test : 334 checks, 334 passed, 0 failed
##   [ old AMOS7::TERM byte-offset path vs new char-offset path driven by
##     identical keystroke script incl. multi-byte UTF-8 fed as raw bytes,
##     buffer/cursor/kill_buffer compared after EVERY key, old cursor
##     converted bytes->chars ; newline -> submit both paths, submitted
##     text and reset state compared ; accessor API checks: load_field
##     'end'/'start'/int cursor, active_buffer name-vs-index resolution,
##     buffer contract, submit reset-gate with failing validator keeping
##     input, per-field vs full reset ]
## - negative control : same test against a copy with an injected 2-char
##   backspace bug -> 35 failures detected [ test is sensitive ]
## - design decisions per doc: CHARACTER offsets, semantics-only result
##   {action,field,dirty,signal?,passthrough?} with NO output/colors,
##   advisory signal only [ no kill() ], submit resets ONLY on ok=1
##   [ real conditional gate with coderef validator support ], kill_buffer
##   on $editor_state [ provisional, commented ], Enter -> action 'submit'
##   for freeform_line + submit_on=enter [ 'newline' is multiline-only ],
##   field_next/field_prev structured for multi-field but never firing
##   on single-field schemas, unclaimed keys returned as passthrough
## - NOT done by agent: bin/Protocol-7 sourcecode update-signatures
##   [ interactive passphrase ], no git commit

#,,,,,,..,...,.,,,,,.,...,..,,...,,,.,...,.,,,..,,...,..,,...,,,.,..,,...,,,,,
#Z2TSPCTMGH2URM23WI3IFCBSOP3PEFQ56AP7CCICA3HLWWTGXW34N4MI6LRYPNK5PJOV7OHL3TRHK
#\\\|NOIXJ3YNX7FVX75YKCJWAMQ3DCCWPWTP7ZABBXFQIXJ7FXNTGEM \ / AMOS7 \ YOURUM ::
#\[7]B5L6JG52EWH22JQPH2GN64QF6FAZ7M5RGZXPEN3KWW52NE63COAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
