# bin/ned -- secure-by-default native file editor (2026-10-26)

combines the todo details editor + p7-vault scratchpad editor features
into a generic file-oriented driver around `AMOS7::TERM::Editor`
[ the shared library itself is untouched -- todo + p7-vault keep their
own callers ]. the `editor.*` / `user-edit.*` namespaces stay a separate
family [ structured form UI inside the running network ].

## v1 design [ settled with the user ]

- atomic save : `.ned-<pid>-<rand>.tmp` in the target dir, O_EXCL 0600,
  write+sync, chmod to the original mode when the file existed, rename,
  best-effort dir sync. new files stay 0600.
- preflight BEFORE the editor opens [ user call : detect early, exit
  clean ] : symlink resolve via abs_path [ dangling refused ], regular
  file, readable, writable, dir writable+searchable for the missing-file
  branch, 10 MiB size cap.
- change guard : size + `Time::HiRes::stat` mtime at load as the cheap
  filter, then elf checksum pair [ modes 4 + 7, AMOS-13 truth modes,
  keep in step with bin/harmony + bin/amos-chksum ] over the RAW BYTES
  as the authority. user picked elf over bmw384 because of the
  pure-perl fallback [ AMOS7::INLINE ]; bmw384 stays the N7FS rule for
  the later network-fs phase.
- refused save -> rescue file `<path>.ned-rescue-<pid>-<epoch>` mode
  0600 holding the exact final text [ no silent data loss ], exit 2.
- exit codes : 0 saved/unchanged, 1 aborted, 2 refused/error
  [ refuse() prints to STDERR + exit 2 -- plain die() would adopt $!
  from a failed file test as its exit status, e.g. ENOTTY=25 ].
- strict utf-8, FB_CROAK; non-tty refuses [ filter mode = later ].
- editor normalizes trailing whitespace + empty lines, so the file's
  own trailing-newline run is captured at load and restored on save;
  new files get one final newline; empty new buffer -> no file created.
- follow-up : pgup \ pgdn [ \e[5~ \ \e[6~ ] page a visible content
  height per press in the shared editor, wheel semantics [ down stops
  at the last line, never grows ] ; hint + ned option list advertise
  it ; 3 new pty cases [ page lands 22 rows down on a 30x100 pty,
  EOF clamp + page back, page-up stays at top ]
- follow-up 2 : left click positions the cursor [ content geometry,
  chrome clicks + releases inert ] ; the wheel accelerates on a
  NON-LINEAR curve [ window 180 ms ; fast avg-gap < 70 ms collapses
  to one page ; medium rolls pay NOTHING for the first 4 ticks, then
  min(burst-4, 2) pages -- short rolls stay relative per user tuning ;
  payout lands when the wheel pauses via a select deadline ] ; a
  redraw signature gates repaints so no-op keys [ EOF tick, inert
  click, no-payout flush ] never flicker [ CONT clears it -- the
  shell may have repainted ] ; editor pty suite at 32 cases
- follow-up 3 : ONE kill register, two disciplines -- ctrl+. [ \x0e
  or CSI-u \e[46;5u ] restores OLDEST-first so kills rebuild their
  original order [ ctrl-v stays LIFO ] ; \x1c + \e[44;5u kill where
  the terminal gives ctrl-, its own byte ; the user's terminal sends
  ^L for ctrl-, [ byte-identical to ctrl-l, unbindable ] and literal
  ',' / '.' after reset -- the pair needs the terminal to emit a
  distinguishable encoding [ kitty \ foot legacy \x1c, CSI-u when
  registered ] ; editor-side protocol enabling [ modifyOtherKeys ]
  parked as a possible follow-up. test-expectation lesson : a
  restored line lands ABOVE the cursor and the buffer keeps the
  un-killed lines -- trace the buffer state before writing the
  expectation [ cost a long debug detour ] ; editor pty suite at 36
- follow-up 4 : ctrl+. restores IN PLACE -- $fifo_from records the
  kill index, the run rebuilds there [ a truncated tail appends after
  the line it followed instead of prefixing it -- the user's reorder
  bug ] ; modifyOtherKeys=1 [ \e[>4;1m ] enabled while open, disabled
  on every exit path incl. CONT \ signals [ level 1 keeps all legacy
  bytes, only ctrl-punct becomes CSI-u ] ; editor pty suite at 38
- follow-up 5 : bottom-up truncation rebuilt the tail UPSIDE DOWN [
  user report ] -- the ordered register now PREPENDS when a kill
  lands above the previous one [ @fifo_run + $fifo_last_idx ], so
  the run always holds the ORIGINAL file order regardless of kill
  direction ; registers keep independent scalar copies [ never share
  with the buffer ] ; editor pty suite at 39
- follow-up 6 : EMPTY LINES are file content -- the ordered register
  keeps every killed line incl. blanks [ the LIFO kill_stack keeps
  its long-standing skip-empty design for todo \ vault ], so a kill
  run over a blank rebuilds the exact text ; dropped blanks collapsed
  the gap and the next restore landed one line early = the user's
  reorder ; editor pty suite at 41. SAME expectation-lesson AGAIN :
  the blank-up case was first written with the blank after e instead
  of between d and e -- trace the buffer, THEN write the expectation
- porting question [ user ] : NOTHING to port -- every editor feature
  is library-side, so bin/todo details + bin/p7-vault note_editor
  inherit them all [ smoke-verified end to end for todo : frame,
  edit, ctrl-x save through its own on_save ] ; only ned's file-driver
  layer [ guard \ atomic save \ rescue ] is ned-specific. offered :
  a permanent bin/todo details pty integration test [ not built ]
- no Event.pm / no inotify by design [ user question ] : save-time
  detection is complete; live watch is a UX feature that drags the
  editor library's private select loop into event plumbing. revisit
  only as an optional library hook + optional Linux::Inotify2 dep.

## perl traps hit [ all verified on perl 5.42.3 ]

- **`use constant R => qw| a b c d |` in SCALAR context returns 4 [ the
  element COUNT ] on perl 5.42** -- not the last element. multi-word
  `qw| phrase |` constants silently become numbers. single-quoted
  strings for any scalar-context constant. [ produced the cryptic
  `::: not saved : 4 :::` symptom -- the reason string was the count. ]
- `Encode::decode/encode` CONSUME the source string unless
  `Encode::LEAVE_SRC` is in CHECK [ valid input too -- the buffer goes
  empty after a successful decode ]. checksums-before-decode ordering +
  LEAVE_SRC both applied.
- `AMOS7::CHKSUM::ELF::elf_chksum` aliases its first argument
  [ `\shift` ] and inline_elf flips its utf8 flag -- pass a copy
  [ `q{} . $bytes` ] when the bytes are reused afterwards [ decode
  after a flagged checksum silently re-interprets >= 0x80 bytes ].
- `check('label', $a and $b)` in test harnesses : `and` binds looser
  than the comma -- the condition truncates and the tail runs in void
  context. precompute booleans or use `&&`.
- `my $TTY = -t STDIN and -t STDOUT` : same precedence class, `=`
  binds before `and` -- $TTY gets only the first test.

## tests

`bin/test-scripts/test-ned-pty.pl` : 13 cases on a real pty [ IO::Pty,
frame-marker wait before keys ]. covers save/unchanged/abort, 0600 +
mode-preserve, the guard at both the mtime filter and the elf-fingerprint
level [ same-size change with nanosecond-restored mtime via
Time::HiRes::utime ], symlink target semantics, preflight refusals,
bare relative names [ parent_dir treats slash-less paths as cwd
members -- the first live bug report ], non-tty refusal, no temp
leftovers. multibyte round-trip verified manually. editor suites still
green : 22/22 pty + 26/26 unit.

## phase 2 [ discussed, not built ]

- encryption : reuse the `AMOS7::Vault` envelope [ same format
  bin/p7-vault uses ] behind a flag.
- network fs : `AMOS7::N7FS::*` [ Sum / Sign / Disk / Store / Convert ]
  already exists as the client-side library family.
- possible library hook for live external-change notification.

## editor wrap mode + regression fixes (2026-10-26)

user reported two regressions + requested the old Text::Wrap-style
behaviour back in the todo details editor.

- **wrap mode [ NEW, library param `wrap => 1` ]** : view-only soft
  wrap. the buffer keeps the raw lines and the saved file is never
  re-flowed -- rendering folds long lines into full-width rows, a dim
  TRUE blue `┊` [ U+250A ] under the ':' marks continuation rows.
  scroll mode
  [ horizontal, `<`/`>` tail window ] stays the default. `bin/todo`
  details editor passes `wrap => 1`; ned can opt in / toggle later.
  user notes wrap is ESSENTIAL for message reading/writing too [ chat
  clients write whole paragraphs as one line ]. internals:
  `detail_editor_wrap_rows` + `detail_editor_draw_wrapped`; scroll,
  hardware-cursor, click and pgup/pgdn all map visual rows back to raw
  buffer positions; `$first_visible` counts visual rows in wrap mode,
  logical lines in scroll mode.
- **scroll-mode `substr outside of string` fix** : EVERY content row is
  drawn with the CURSOR's column, so a shorter-but-longer-than-the-window
  line under a far-right cursor computed a start past its own end. the
  tail window is now clamped [ `Editor.pm` detail_editor_draw_line ].
- **CSI-u reader hardening** : an in-flight `\e[digits;...` sequence gets
  a 1 s collection deadline once its prefix is unambiguous [ was 0.1 s
  flat ] -- a lagging final byte used to return the prefix as an inert
  key and TYPE the tail into the text [ plausible ctrl-, / ctrl+.
  'stopped working' vector on a loaded line ].
- **the 28 MB padding flood** : wrap draw finished with
  `say $pad while $drawn < $content_rows` -- `$drawn` never incremented,
  a small buffer [ fewer rows than the window ] looped forever. the
  pgdn case passed because its 60-row buffer never reached the padding
  path. lesson : audit the loop variant on statement-modifier `while`.
- **ctrl-, / ctrl+. regression NOT reproduced** : every known byte form
  [ `^L`/`^N` legacy, `\x1c`, `\e[44;5u` / `\e[46;5u` CSI-u ] drives the
  real bin/ned end-to-end on a pty; all 46 pty tests pass. pending the
  user capturing the exact in-editor bytes with
  `printf '\e[>4;1m'; cat -v` [ plain `cat -v` runs OUTSIDE the editor;
  modifyOtherKeys=1 is enabled INSIDE and changes those encodings ].
- **wrap separator [ `wrap_sep`, default ON with wrap ]** : a wrapped
  block is followed by a dim dotted rule [ ':' + dim PURPLE `┄`
  [ U+2504 quadruple dash horizontal ] + ':' ] -- a visual blank line
  between paragraphs; none after the buffer's last line [ bottom
  padding is gap enough ]. continuation rows carry a dim TRUE-blue
  `┊` [ U+250A, the todo-list state-column glyph family ] under the
  ':' -- purple = structure between blocks, dim TRUE blue = content
  guide [ green stays RESERVED for selection modes ]. the editor
  speaks utf-8 end to end, so box glyphs need no detection.
  view-only, and the separator OCCUPIES a visual row : one
  `$block_rows` closure [ wrap_rows + separator ]
  serves every visual-row walk [ scroll fixup, drawing, hardware
  cursor, clicks, paging ] so a separator never shifts a position.
  pinned by a cursor case at row 9 vs 8 without. `wrap_sep => 0`
  opts out. the selected block darkens as ONE unit : every visual
  row of the cursor's logical line [ head + continuations ] renders
  with the text AND ┊ dimmed, the ':' borders keeping the bold
  TRUE-blue chrome ; non-cursor lines stay bright [ pinned by the
  wrapdarken colors case ]. **blank-after-block collapse** [ user
  call, 2026-10-26 ] : when the buffer itself has an empty line
  right after a wrapped block, that blank renders AS the separator
  row [ `detail_editor_draw_wrapped` `$as_sep` ] and no separator
  row is drawn after the block -- one gap row instead of two.
  **stability rule [ user-reported flicker ]** : the test is
  `_line_is_blank` [ whitespace-only counts ], NEVER `eq ''` -- the
  free cursor PADS a blank it arrows through with spaces so the
  column survives, and with `eq ''` the layout flipped per keypress
  [ clicking jumps past, so it never showed ]. one shared
  `$blank_as_sep` predicate drives `$block_rows`, the draw flag,
  and the cursor in-block offset [ zeroed for the collapsed row :
  it renders ONE row whatever the column, so the hw cursor sits ON
  the dots at `4 + col % vw` ]. **full filter [ user-reported
  phantom 'variable box' ]** : the generalization is that a
  whitespace-only line NEVER renders its padding as a wrapped run
  [ `detail_editor_draw_wrapped` collapses it to '' ; `$block_rows`
  returns 1 for ANY blank line ; the offset guard keys on
  `_line_is_blank`, not `$blank_as_sep` ] -- padding from cursor
  passes [ arrows AND paging AND clicks ] used to grow multi-row
  blocks of space rows that even collected a separator, esp. at
  trailing `\n\n`. pinned by wrapblankpad and wraptailpad.
- **the actual root : free-cursor PROPAGATION [ user-diagnosed :
  'horizontal offsets' ]** : `move_cursor` used to
  `editor_pad_line_to_col` EVERY line entered [ the column was
  preserved across vertical moves ], so scrolling down from a long
  line inflated each crossed line into a multi-row block ; and
  arrow-down on the LAST line used to APPEND `' ' x $cur_col` lines
  outright [ 'scrolling outside of the file grows a final section'
  ]. fix : vertical moves CLAMP `$cur_col` to the entered line's
  length [ the horizontal free-cursor stays on the line being
  edited : the main loop still grows the CURRENT line past EOL and
  `editor_leave_line` strips on leave ] , and the `extend` branch
  is gone -- down-at-EOF is a no-op. the pgdn + click paths now
  `editor_leave_line` too [ they jumped `$cur_line` directly,
  stranding pads ]. the render filter above stays as paste-hygiene.
  pinned by wrapblankpad [ cursor clamps to 7;4, never 7;60 ] and
  wraptailpad [ exactly 5 movement pairs for End + 4 downs at EOF,
  no phantom rows, buffer never grew ].
- **separator width contract** [ user caught the rule 2 cols short ] :
  the dotted rule spans ':' + '┄' x inner_width + ':' = inner + 2
  display columns -- the SAME span as the content rows [ they carry
  ':  ' .. '  :' around the segment ] and the frame border. an
  earlier 'x ( inner - 2 )' left the rule's trailing ':' two columns
  left of the frame edge ; both constructors [ the draw-loop
  `$sep_row` and the `$as_sep` return in
  `detail_editor_draw_wrapped` ] must stay in step.
- **box-drawing glyphs as future cursor language** [ user idea, parked ]
  : the ┊/┄ family could mark alternate cursors for different editing
  or parallelism modes -- keep them in mind when mode support lands.
  palette contract settled meanwhile : purple = frame structure, dim
  TRUE blue = content guides [ wrap continuation ], phosphor green =
  RESERVED for selection modes.
- **SGR dim bleeds** [ caught by the user's eye ] : `\e[2m` persists
  until reset -- a dim-wrapped glyph must re-emit the content colors
  after it, else the whole rest of the row renders dimmed. scoped dim
  to the glyph for NON-cursor rows : `dim . T . ┊ . R . T . B` ;
  cursor rows dim wholesale with the reset placed BEFORE the trailing
  border so the frame keeps full strength.
- **an accidental effect can become the user's selection language**
  [ 2026-10-26 ] : the wrap-continuation dim-bleed read to the user
  as "the line selection darkening", and they asked for the head row
  to join it -- scoping the "bug" then read as "the selection is gone
  fully". the border-color highlight alone never registered as
  'selection' to their eye. lesson : before removing an unintended
  rendering effect, check whether the user has adopted it as a
  feature ; the deliberate form of it now lives in
  `detail_editor_draw_wrapped` [ cursor block dimmed as one unit ].
  wrapdarken pins : dim head + dim continuation incl. glyph, scoped
  reset before the border, other line bright.
- suites after : 26/26 unit, 52/52 editor pty [ wrapdarken pins the
  one-unit block dimming, wrapblank + wrapblankpad + wraptailpad the
  blank-as-separator and its padding stability ], 13/13 ned.

#,,..,...,.,,,,,.,,,.,,,,,,..,,.,,,.,,,,.,..,,..,,...,..,,.,.,..,,,.,,..,,,,,,
#RQSVZH62L4SPYLVT3HLNTVOMF6AHBG25EHXIIT6CZZFX63DMXULT4XPNLOKDS2MWLO7NVLWTCRGBI
#\\\|DOCEHESI7RRELE2THFFJEDTBXR27QHZY2RTUWLF5QNWTCG5SG3E \ / AMOS7 \ YOURUM ::
#\[7]X3USO433U5YZ4IPELN56QKO3FX533RJ6XSYU6HVLS67A3IOPYWCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
