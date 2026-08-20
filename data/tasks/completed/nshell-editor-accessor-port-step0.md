## [:< ##

# name  = task: nshell editor step_0 — port to AMOS7::TERM accessors, no code moved
# descr = de-risk the future editor.* extraction by routing all direct
#         $editor->{buffer}/{cursor_pos} touches through new accessors,
#         with zero behavior change

## context

`data/yaml/coding-tasks/editor-namespace-interface-design.yaml` is a
reviewed (twice) interface sketch for a future `editor.*` module namespace
that will eventually replace nshell's direct use of
`AMOS7::TERM::editor_*`. Read that file's `migration_path.step_0` and
`migration_path.step_1_is_not_mechanical` sections first — they explain why
this step exists and what it deliberately does NOT do yet (no new
namespace, no field/schema model, no byte->char offset conversion — those
are step_1+).

This task is ONLY step_0: prove the accessor boundary works, with the
running system behaving identically before and after. Do not implement
anything from the interface design doc beyond the two accessors below.

## why this order

`AMOS7::TERM::editor_process_key` bakes ANSI escape output + `%colors` into
its return value, and callers reach into `$editor->{buffer}` /
`{cursor_pos}` directly all over `nshell.*`. Before any real extraction
into an `editor.*` namespace, every direct hash-key touch needs to go
through an accessor — otherwise step_1 has to change both the storage
shape AND every call site at once, which is how these things break subtly.

## scope: exact touch points (verified 2026-08-09 via grep)

add two new subs to `data/lib-path/pm/AMOS7/TERM.pm` (near the existing
`editor_get_buffer`/`editor_submit`/`editor_reset`/`editor_load`, ~line
1495-1533):

```perl
sub editor_get_cursor {
    my $editor = shift;
    return undef if !defined $editor;
    return $editor->{cursor_pos};
}

sub editor_set_cursor {
    my ( $editor, $pos ) = @ARG;
    return if !defined $editor;
    $editor->{cursor_pos} = $pos;
    return TRUE;
}
```

then convert these direct touches to use `editor_get_buffer`/
`editor_get_cursor`/`editor_set_cursor` instead of reaching into the hash
directly (do NOT touch `editor_process_key` itself, and do NOT touch
`$editor->{kill_buffer}` or `$editor->{color_set}` — those are out of
scope for step_0):

- `src/nshell.editor.process` lines 51-52, 68-69: read-only
  `$editor->{cursor_pos}` / `$editor->{buffer}` -> accessors.
  Lines 103-104 (`$editor->{buffer} = ''; $editor->{cursor_pos} = 0;`) are
  VERIFIED REDUNDANT, not merely convertible: two lines above (line 100)
  `AMOS7::TERM::editor_submit($editor)` is called, and `editor_submit`
  already calls `editor_reset($editor)` internally (sets buffer, cursor_pos,
  kill_buffer, AND color_set). Lines 103-104 re-zero two of those four
  fields a second time for no effect. Delete lines 103-104 outright — this
  is a correctness cleanup, not a risk, since the state was already reset.
- `src/nshell.render.viewport` lines 12-13: same read-only pattern.
- `src/nshell.render.cursor` lines 9-10: same read-only pattern.
- `src/nshell.handler.ctrl_o_cycle` line 8: `$state_ref->{'editor'}->{'buffer'}` read.
- `src/nshell.handler.ctrl_o_render_preload` line 15: `$editor->{'buffer'}` read.
- `src/nshell.read_from_buffer` lines 36, 154, 256: reads.
  Lines 157-158 (`$state_ref->{'editor'}->{buffer} = ''; ...->{cursor_pos} = 0;`,
  in the Ctrl+R search "command selected" branch) are DIFFERENT from the
  case above — NOT preceded by an `editor_submit`/`editor_reset` call on
  this path, so calling `editor_reset()` here instead would additionally
  clear `kill_buffer`/`color_set`, a real (if probably harmless) behavior
  change. Step_0's mandate is zero behavior change — leave these two lines
  as direct writes, do not substitute `editor_reset()`, no note needed
  (this is settled, not a judgment call to make at implementation time).
- `src/nshell.no-tty-debug.cmd.char-add` lines 249, 266, 303, 316: reads
  (diagnostic/debug tool, lower priority, but part of the direct-access
  surface — convert if straightforward, skip and note if the debug output
  format depends on hash internals in a way that resists a clean accessor
  swap).

Leave `$edit_result->{output}` consumption in `nshell.editor.process`
exactly as-is — the design doc's `control_ui_boundary` section already
established it's vestigial (only the `"\n"` on the newline path is used),
but actually removing it is step_1's job, not step_0's. Don't touch it here.

Leave every `AMOS7::TERM::editor_load(...)` call site untouched (there are
10: `nshell.handler.ctrl_o_cycle` x2, `nshell.render.empty_prompt`,
`nshell.history.page_up`, `nshell.history.page_down`,
`nshell.history.arrow_up`, `nshell.history.arrow_down`,
`nshell.search.handler` x3) — `editor_load` already exists as a proper
function, this task is only about the raw hash-key reads/writes that don't
go through an existing accessor.

Leave `view_offset` handling untouched entirely — it's `$state_ref`
(nshell) state, not `$editor` state, and out of scope here regardless of
what the design doc says about where it belongs eventually.

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures`
when done.

## verification (required, not optional)

1. `perl -c` every touched file.
2. Start nshell live (however this project's convention normally verifies
   nshell changes — check for a running dev harness/instructions before
   assuming) and manually exercise: typing text, left/right arrow, ctrl-a/
   ctrl-e, backspace/delete, ctrl-k/ctrl-u/ctrl-w/ctrl-y (kill/yank),
   history recall (up/down arrow), ctrl-o cycling, ctrl-r search, submitting
   a command. Confirm every one behaves identically to before your change —
   this is a pure refactor, any observable behavior difference is a bug in
   this task, not an acceptable side effect.
3. Report the exact diff (`git diff --stat` and the full diff), not just a
   summary — this is a refactor task where "it compiles" proves nothing;
   only live behavioral parity does.

## status: done 2026-08-09 [ signatures pending: update-signatures needs
##   the interactive sourcecode key passphrase — run by taeki ]
##
## verification performed:
## - perl -c data/lib-path/pm/AMOS7/TERM.pm : syntax OK
## - bin/test-scripts/p7-module-syntax-check on all 7 touched modules:
##   error set byte-identical to pristine HEAD versions (only pre-existing
##   checker limitations re runtime globals %colors/$call), no new errors
## - live behavioral parity: standalone harness (/tmp/p7-harness/drive.pl)
##   loading all nshell.* modules exactly like the bin/Protocol-7 compile
##   path (eval STRING, same lexical globals), driving the real
##   no-tty-debug input path with a fixed 22-chunk keystroke script covering
##   typing, ctrl-a/e, arrows, backspace/delete, ctrl-k/u/w/y, submit,
##   page up/down, history up/down + submit, ctrl-o cycle x2, ctrl-r search
##   select + cancel, >80col overflow line with navigation, utf-8 multibyte
##   backspace, ctrl-c signal path with buffer preservation:
##   before [ HEAD modules + HEAD TERM.pm ] vs after [ modified ] transcripts
##   are BYTE-IDENTICAL (14568 bytes each, diff empty)
## - src/nshell.no-tty-debug.cmd.char-add: 4 diagnostic reads converted
##   (equivalence: (($e // {})->{buffer} // '') == (editor_get_buffer($e)
##   // '')); not exercised by the harness [ it IS the debug entrypoint ],
##   covered by syntax parity + trivial read equivalence
## - read_from_buffer 157-158 direct writes left untouched as settled
## - editor_set_cursor added per spec but intentionally has no call sites
##   yet [ step_0 converts no writes to it ]
## - NOT done by agent: bin/Protocol-7 sourcecode update-signatures
##   [ requires interactive key decryption password ], no git commit

#,,,,,,,,,,,.,.,.,..,,,..,.,.,,..,,,,,,,.,,,.,..,,...,...,..,,,,.,,.,,,,,,,,,,
#YU4O6SDAOSYAYWR662DSINEOR6ABQEMB7M5SYZOOJ32NNFPGGY3XZVY2GTCL4ZC45WD64574MVAKS
#\\\|O37I3GGQQXBJRQHYKAOOB3CCAKWKR7QIQNYIJNJS2JBFHEYTCJC \ / AMOS7 \ YOURUM ::
#\[7]IJGQ5276M7DYL6ZKFMUFYEEMTFO4C3YCTCVO7YLGLZ2HGDDKQCBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
