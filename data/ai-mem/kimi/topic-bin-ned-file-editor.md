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

#,,..,.,,,,..,,,,,.,.,,.,,,,.,.,.,,..,,..,..,,..,,...,...,.,.,,,.,.,.,.,.,,,.,
#OBR63PTUEDKYYQYIZCLMW44KWM6WTST6IZWVK3ZAEEBPHTXX227EYMJNVDKN3AVJI4OLY5JY4YWRC
#\\\|JFTG6LX5DQVR5YMYRUSX6DO3XNXD7OGGSLSZLDWVM3L74JGZLQU \ / AMOS7 \ YOURUM ::
#\[7]CQLLAW46HB74K2HNDCEFLURZNAHMR2CPIM5QKV6NNWAXKPGRYCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
