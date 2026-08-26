# task: AMOS7::SHM phase 4 (part A) — real cleanup-on-normal-exit, creator-owned only

## status [ 2026-06-22 ]

this is **part A** of phase 4 (full scope in `data/tasks/amos7-shm-paging-
feedback.md`'s phase 4 section and reiterated as a hard prerequisite in
`amos7-shm-coding-zenka-prompt-transport.md` / `amos7-shm-log-channel-
handshake.md`). part A is **only** graceful-exit cleanup [ zenka SIGINT/SIGTERM,
standalone process exit ]. the TTL safety-net sweep for crashed/SIGKILL'd
writers [ part B ] is **explicitly out of scope for this task** — it needs its
own design pass on what unit `created` timestamps are stored in and where a
sweep gets invoked from ; do not attempt it here.

## what is actually true today — verified in source, do not assume the docs'
## summary is already built

read `src/data.mount.shm.init_code`, `src/data.mount.shm.create`,
`src/data.mount.shm.open`, and `data/lib-path/pm/AMOS7/SHM.pm`'s
`shm_create`/`shm_open` before writing anything. the actual current state,
confirmed this session:

1. `data.mount.shm.init_code` initializes `$data{'mount'}{'shm'}{'segments'} //=
   {}` and registers a `$SIG{'INT'}` handler that iterates
   `keys %{ $data{'mount'}{'shm'}{'segments'} }` to unlock mlocked segments.
   **but nothing ever writes into that hash** — `data.mount.shm.create` calls
   `AMOS7::SHM::shm_create` and returns the mount hashref directly ; it never
   registers the path into `$data{'mount'}{'shm'}{'segments'}`. so today the
   `$SIG{'INT'}` handler's loop is a no-op over an empty hash, and **no segment
   is ever unlinked on shutdown, zenka or standalone.** this is the actual gap,
   confirmed empirically, not just "design pending."
2. **two already-existing zenka subs already correctly unlink both the
   segment AND its phase-3 notify FIFO together**: `src/data.mount.shm.unlink`
   and `src/data.mount.shm.remove` [ both have `## the phase-3 notify fifo
   shares the segment's lifecycle ##` + an `unlink($notify_path)` call ]. **do
   not duplicate this logic** — call the existing `<[data.mount.shm.unlink]>`
   from the zenka-side fix below. [ note, not in scope to fix here: these two
   subs are near-duplicates of each other — `unlink` takes
   `(pub_key, sub_path)` and rebuilds the path, `remove` takes the path
   directly. don't consolidate them in this task, just use whichever fits ;
   flag the duplication in your final summary so it can be cleaned up later. ]
3. `AMOS7::SHM.pm` [ standalone core ] has **no `END` block at all** — a
   standalone script that calls `shm_create` and then dies, is killed, or
   simply exits leaves the segment [ and FIFO, if `AMOS7::SHM::Feedback` was
   used ] in `/dev/shm` forever.

## the critical correctness rule — creator-owned only, never reader-opened

**a reader must never unlink a segment it only `shm_open`'d.** shape 1
[ one-shot transport, `amos7-shm-coding-zenka-prompt-transport.md` ] and shape 3
[ live-mounted state, `amos7-shm-use-case-taxonomy.md` ] both depend on a
segment surviving independently of any one reader's lifecycle — shape 3
explicitly assumes **many readers** can mount the same live segment. if
cleanup-on-exit fires for *every* path a process has touched [ created or
merely opened ], a reader closing or crashing would delete content other
readers — or the actual writer — still depend on. **so**: only register a path
for cleanup at the point of **creation** [ `shm_create` ], never at `shm_open`.
`shm_open` must remain completely untouched by this task.

## what to change

### 1. zenka side — register on create, unlink on shutdown

in `src/data.mount.shm.create` [ the **zenka** thin wrapper, not the
standalone core ], after a successful `AMOS7::SHM::shm_create` call, register
the created path:

```perl
## phase 4 : track creator-owned segments for cleanup-on-shutdown.        ##
## shm_open must NEVER write into this registry — only the creator may ; ##
## see "the critical correctness rule" in the phase-4 task doc.          ##
$data{'mount'}{'shm'}{'segments'}{ $mount->{'path'} } = {
    'mmap_ptr' => $mount->{'mmap_ptr'},
    'mlocked'  => $mount->{'header'}{'flags'}{'mlocked'},
    'pub_key'  => $mount->{'pub_key'},
};
```

[ adjust field names to whatever's actually cleanest given what you read in
`data.mount.shm.create` — the point is: register at create time, with enough
info for the existing mlock-unlock loop to keep working unchanged, plus the
path itself as the key for the new unlink step. ]

then extend `src/data.mount.shm.init_code`'s `$SIG{'INT'}` handler [ and
add the identical body for `$SIG{'TERM'}`, since process managers commonly send
TERM, not INT, and the existing handler should cover both ] to, **after** the
existing unlock loop, unlink each registered path:

```perl
for my $path ( keys %{ $data{'mount'}{'shm'}{'segments'} } ) {
    my $seg = $data{'mount'}{'shm'}{'segments'}{$path};
    if ( $seg && $seg->{'mlocked'} ) {
        eval { <[data.mount.shm.lock.unlock]>->( $seg->{'mmap_ptr'} ) };
    }
}

## phase 4 : unlink every creator-owned segment [ + its FIFO, handled        ##
## already inside data.mount.shm.unlink ] on graceful shutdown. reader-     ##
## opened segments are never in this hash — see "the critical correctness  ##
## rule" — so this never touches a segment this process did not create.    ##
for my $path ( keys %{ $data{'mount'}{'shm'}{'segments'} } ) {
    my $seg = $data{'mount'}{'shm'}{'segments'}{$path};
    eval { <[data.mount.shm.unlink]>->( $seg->{'pub_key'}, ... ) };
    ## work out the right call shape from data.mount.shm.unlink's actual
    ## signature [ pub_key_b32, sub_path ] vs what you have on hand [ a full
    ## path ] — you may need data.mount.shm.remove instead [ takes the path
    ## directly ], whichever fits without modifying either sub ##
}
```

read both `data.mount.shm.unlink` and `data.mount.shm.remove` and pick whichever
matches what data you actually have in the registry without reconstructing a
path/pubkey awkwardly — **do not modify either of those two subs**, this task
only adds a caller.

### 2. standalone side — an END block in AMOS7::SHM.pm, creator-owned only

in `data/lib-path/pm/AMOS7/SHM.pm`, add a package-level tracking list,
populated **only** inside `shm_create` [ never `shm_open` ], **only when
running standalone** [ `not defined $main::PROTOCOL_SEVEN` — same gate
`shm_create` already uses for its self-locking logic, mirror it exactly ]:

```perl
## phase 4, standalone only : track creator-owned segment paths for an END-  ##
## time cleanup. zenka mode handles this via its own SIGINT/TERM handler    ##
## [ src/data.mount.shm.init_code ] instead — this list stays empty     ##
## whenever $main::PROTOCOL_SEVEN is defined.                               ##
my @_standalone_owned_paths;
```

inside `shm_create`, near the existing `if ( not defined $main::PROTOCOL_SEVEN
&& $header->{'flags'}{'mlocked'} ) { lock_memory(...) }` block, add the path to
`@_standalone_owned_paths` under the same `not defined $main::PROTOCOL_SEVEN`
condition.

add a small standalone-only unlink helper inside `SHM.pm` itself [ do not call
out to the zenka `data.mount.shm.unlink`/`remove` subs from here — standalone
code cannot reach `<[...]>` zenka dispatch at all ] :

```perl
sub _standalone_unlink_segment {
    my $shm_path = shift;
    unlink($shm_path) if -f $shm_path;
    my $notify_path = $shm_path . '.notify';
    unlink($notify_path) if -p $notify_path;
    return;
}

END {
    _standalone_unlink_segment($_) for @_standalone_owned_paths;
}
```

[ name the sub / list whatever reads cleanest to you, this is illustrative, not
mandated verbatim. the structural requirements are: only fires standalone, only
unlinks paths *this process created*, and removes the FIFO alongside the
segment exactly like the two existing zenka subs already do. ]

**known limitation, state it plainly in your summary, do not try to fix it
here**: `END` blocks do not run on `SIGKILL` — that gap is exactly what part B's
TTL sweep [ out of scope for this task ] exists to close. this task only
closes the *graceful* exit gap [ normal exit, most signals, explicit `die` ].

## verification

extend your verification with a **second standalone script** [ separate from
`bin/dev/script-scratchpad/test-shm-read-only-open.pl`, which you should leave
untouched — this is new, additive work, not a follow-up to that file ] :

1. **zenka path**: this one is harder to script standalone — at minimum, read
   `src/data.mount.shm.test.basic` for the project's existing pattern of
   exercising zenka-side SHM subs, and state honestly in your summary whether
   you were able to verify the zenka SIGINT/TERM path live [ requires a running
   `data` zenka, `v7.restart data`, then sending it a signal and checking the
   file disappeared from `/dev/shm` ] or whether you only verified it by
   careful code reading. **do not fake a passing zenka-side test** — if you
   cannot safely exercise it [ e.g. no running zenka network in this
   environment ], say so and stop there for that half ; the human will verify
   the zenka half directly afterward.
2. **standalone path** [ fully scriptable, do this for real, not just by
   reading ]: a script that `use AMOS7::SHM;`, calls `shm_create`, confirms the
   file exists in `/dev/shm`, then exits normally [ let the script just end —
   that triggers `END` ] and confirms **in a second, separate script
   invocation** [ or via a wrapper that checks afterward ] that the file is
   **gone**. also test that a segment created, then the process killed with
   `kill('TERM', $pid)` from a small wrapper [ fork a child that creates the
   segment and sleeps, send it TERM from the parent, check the file ] — `TERM`
   is not `KILL`, default Perl behavior for `TERM` with no handler is to exit,
   which **will** run `END` blocks, so this is a fair test of the "graceful
   signal" case this task claims to cover. **do not test SIGKILL** — that case
   is explicitly out of scope [ part B ], and a SIGKILL test would correctly
   show the file is NOT cleaned up, which is expected, not a bug to chase here.

paste full output of both test scripts. fix anything that fails before
reporting done.

## scope — do not go beyond this

- do not implement the TTL/reaper sweep [ part B ] — name it as future work in
  your summary, do not attempt it
- do not modify `data.mount.shm.unlink`, `data.mount.shm.remove`, or
  `shm_open` / `data.mount.shm.open` at all
- do not touch `bin/dev/script-scratchpad/test-shm-read-only-open.pl`
- do not build `AMOS7::SHM::Transport` / `::Channel` / `::Mount` — unrelated to
  this task

## style / pitfalls

- same hybrid-package rules as the read-only-open task: `AMOS7::SHM.pm` is
  plain Perl, no `<[...]>` / `<dotted.data>` syntax there. `src/data.mount.
  shm.init_code` and `src/data.mount.shm.create` ARE zenka module files —
  they use `<[...]>` / `<dotted.data>` syntax normally, opposite rule from the
  `.pm` file, do not mix them up.
- do not touch the trailing `#,,.,,,...` signature blocks on any existing file
  you edit — leave them stale, the human re-signs. do not add a fake stub to
  any new file either.
- `init_code` subs must return `TRUE` (5) or `FALSE` (0) for success/failure —
  check the existing `return TRUE` at the end of `data.mount.shm.init_code` and
  do not break that contract while adding the TERM handler.
- when done, state plainly: every file changed with line ranges, the exact
  content of both new/extended test scripts, full output of each, and an
  honest statement of what was and was not live-verified [ especially the
  zenka SIGINT/TERM half — see verification step 1 ].

#,,.,,.,.,...,,.,,.,,,.,,,,.,,...,,,,,.,.,...,..,,...,...,..,,,,,,,..,...,.,,,
#Q3CDRX6PYETNSKQOV4R2P5LU3MK5E5ANMUV6Q6JRQQXN6IWQMFGPH2BKB4FIGVJ5G66HSWTJZR66C
#\\\|OFQCPR7L6UPDL7AFV2PDBJVE3UZ6ENKY5X5R5NOK4ZMOKUC3YCG \ / AMOS7 \ YOURUM ::
#\[7]QLADYN67MOXYMWQJ5GXPTMCW265JZDDFXMUAIS72IFRYDK734YBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
