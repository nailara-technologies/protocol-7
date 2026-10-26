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

#,,.,,..,,.,.,..,,,.,,.,,,..,,.,,,...,.,,,,.,,..,,...,...,.,.,,,,,,,.,,.,,,.,,
#2BLLYHAN44PPVR5NSIIONJ2NJT773RCF24K65XY7CLDEZSY5NM4HUDH2PCF6RWTCOSEXXSCLTH3P6
#\\\|JU3NV44SEBJSL7ZQZ7TEX2YF6V743TIOZUFCHK3KSJJ5R7B2ZNH \ / AMOS7 \ YOURUM ::
#\[7]DXEPCPV3ZIT3IGIW22O2JDOYJD44FT4QLFVHIS4E72YROABKX4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
