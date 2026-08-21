# task: AMOS7::SHM phase 4 (part B) — TTL safety-net sweep for crashed writers

## status [ 2026-06-22 ]

this is **part B** of phase 4, the second and final half. part A [ landed,
`data/tasks/amos7-shm-phase4-cleanup-on-exit.md` ] handles graceful shutdown
[ normal exit, SIGINT/SIGTERM, zenka end_code callback ] — it does **not**
cover `SIGKILL`, which runs no cleanup code at all in either zenka or
standalone mode. part B closes that gap with a separate, explicit sweep — read
`data/tasks/amos7-shm-paging-feedback.md`'s phase 4 section and
`amos7-shm-coding-zenka-prompt-transport.md`'s "phase 4 is a prerequisite, not
a fast-follow" section first ; both describe this as "a safety net, not the
primary path" — part A is the primary path, this is the backstop.

## two facts established this session, grounding the design — read before
## writing anything

### 1. `created` is plain unix epoch time, not ntime

`AMOS7::SHM::shm_create` sets `created = defined $time_source ? $time_source->()
: time()`. the zenka wrapper [ `src/data.mount.shm.create` ] injects
`$options->{'time_source'} //= sub { <[base.time]>->(2) }` — and `base.time` is
installed from `Time::HiRes` [ `bin/Protocol-7` ~line 325,
`$code{'base.time'} = \&{ $TH_aref->[0] }` ], so `<[base.time]>->(2)` returns
**unix epoch seconds with 2 decimal digits of sub-second precision** — a plain
float, not the project's `ntime`/base32 network-time format used elsewhere
[ e.g. p7-log work ]. standalone mode's `time()` fallback is also unix epoch,
integer. **so**: age comparisons in this task are just `time() -
$header->{'created'}`, plain seconds, no ntime conversion anywhere. do not
import or reference any `ntime` helper for this task.

### 2. `/dev/shm` has the sticky bit set — this changes what a sweep can do

confirmed this session: `stat -c '%A' /dev/shm` → `drwxrwxrwt`. the trailing
`t` is the sticky bit, same as `/tmp` — **only a file's owning UID [ or root ]
may unlink it**, regardless of the file's own read/write permission bits.
consequence, stated as a hard constraint, not a detail: **a sweep can only
ever reap segments owned by the same OS user it runs as.** a sweep run as the
`data` zenka's user [ `protocol-7`, bare, per `cfg/zenki/data/zenka.v7`
— confirm if curious ] can never reap a `taeki`-owned orphan, and vice versa,
no matter what permission grants are inside the segment's header — those
grants are about **read access to content**, never about **who may delete the
file**, and that second thing is an OS-level fact this design cannot route
around. **do not attempt to defeat this** [ e.g. by trying `sudo`,
suid-helpers, or anything cute ] — just have the sweep **skip and count**
files it does not own, explicitly, rather than attempt-and-silently-fail or
attempt-and-log-a-scary-error for something that is expected and normal in a
multi-user deployment.

## what to build

### 1. the sweep core, standalone-loadable — `data/lib-path/pm/AMOS7/SHM.pm`

add a new exported sub, same hybrid style as the rest of the package [ no
`<[...]>` syntax in this file, plain Perl, works standalone or in-zenka
identically since it does nothing zenka-specific ]:

```perl
## scan a directory [ default /dev/shm ] for p7:M:* segments and unlink any
## that are both stale [ created more than $ttl_seconds ago ] AND owned by
## the current effective UID. never attempts to unlink a file owned by a
## different UID -- the sticky bit on /dev/shm would refuse it anyway, and
## attempting it would just be noise. returns a summary hashref, never dies.
sub sweep_stale_segments {

    my $options     = shift // {};
    my $dir         = $options->{'dir'} // '/dev/shm';
    my $ttl_seconds = $options->{'ttl_seconds'} // 3600;

    my %summary = (
        'scanned'             => 0,
        'reaped'               => 0,
        'skipped_fresh'        => 0,
        'skipped_other_owner'  => 0,
        'skipped_unreadable'   => 0,
        'errors'               => [],
    );

    opendir( my $dh, $dir ) or return \%summary;
    my @candidates = grep { /^p7:M:[^.]/ } readdir($dh);   # exclude *.notify
    closedir($dh);

    for my $name (@candidates) {
        my $path = "$dir/$name";
        $summary{'scanned'}++;

        # ownership check FIRST [ -O is "owned by effective uid" ] ; never
        # attempt to even open-for-read-then-stat a file we can't reap, to
        # keep this cheap and to keep the "skipped, not failed" count honest
        if ( not -O $path ) {
            $summary{'skipped_other_owner'}++;
            next;
        }

        my $header = _read_header_only($path);
        if ( not defined $header ) {
            $summary{'skipped_unreadable'}++;
            next;
        }

        my $age = time() - ( $header->{'created'} // 0 );
        if ( $age <= $ttl_seconds ) {
            $summary{'skipped_fresh'}++;
            next;
        }

        _standalone_unlink_segment($path);   # already removes the .notify FIFO too
        $summary{'reaped'}++;
    }

    return \%summary;
}

## lightweight header peek : open + read first 512 bytes, no mmap, no lock.
## this is a maintenance scan, not a real mount -- it should never need the
## weight of shm_open's full mmap_file_read + permission_verify machinery.
sub _read_header_only {
    my $path = shift;
    open( my $fh, '<', $path ) or return undef;
    binmode($fh);
    my $raw;
    my $got = read( $fh, $raw, SHM_HEADER_SIZE );
    close($fh);
    return undef unless defined $got and $got == SHM_HEADER_SIZE;
    return undef unless substr( $raw, 0, 4 ) eq 'P7SH';
    return unpack_shm_header($raw);
}
```

[ illustrative, not verbatim-mandatory — match whatever's cleanest given the
actual current contents of the file, but keep the structural decisions:
ownership check before any read attempt, `_standalone_unlink_segment` reused
[ it already exists from part A, do not duplicate its unlink+notify-unlink
logic ], a plain summary hashref, never dies/exits. **add `sweep_stale_segments`
to the package's export list** alongside the existing exports [ check the
`our @EXPORT_OK` or equivalent near the top of the file ]. ]

### 2. a manually-invokable zenka wrapper — NOT wired to a timer

add `src/data.mount.shm.reap` [ a thin wrapper, same relationship every
other `data.mount.shm.*` file has to its `AMOS7::SHM` core sub ]:

```perl
## [:< ##

# name  = data.mount.shm.reap
# descr = manually-invoked TTL safety-net sweep for crashed/SIGKILL'd writers
#         [ phase 4 part B ] -- NOT on a timer, call explicitly via
#         p7c data.shm-reap or similar

my $ttl = shift // <data.cfg.shm-reap-ttl-seconds> // 3600;

my $summary = AMOS7::SHM::sweep_stale_segments( { 'ttl_seconds' => $ttl } );

return $summary;

#,,...
```

[ leave off the fake signature, as always -- the `#,,...` above is a
reminder not a literal instruction, do not write that line ]

and a `.cmd.` whitelisted entry point, `src/data.cmd.shm-reap`, following
the `{mode, data}` string-reply convention [ same shape as
`data.cmd.shm-self-test` — read it for the formatting idiom ] that calls
`<[data.mount.shm.reap]>` and renders the summary hash into a short readable
string [ scanned / reaped / skipped counts ].

**do not add a timer.** this task explicitly stops at "callable on demand" —
wiring this to `event.add_timer` for automatic periodic sweeping is its own
follow-up decision [ timer pitfalls are real in this codebase : undef interval
= max-rate loop, always needs a fallback — not worth rushing under this task's
time budget ]. say so plainly in your summary as the next, NOT-done step.

## scope — do not go beyond this

- do not touch `data.mount.shm.create`, `data.mount.shm.init_code`,
  `data.mount.shm.cleanup`, `data.mount.shm.unlink`, or `data.mount.shm.remove`
  — part A is done and signed, this task is purely additive alongside it
- do not wire a timer
- do not attempt anything cross-user [ see fact #2 above — skip, don't fight it ]
- do not touch `shm_open`, `Page.pm`, or `Feedback.pm`

## verification — standalone, fully scriptable

write `bin/dev/script-scratchpad/test-shm-ttl-reap.pl` :

1. create a segment via `shm_create` [ `mlock => 0` ], confirm it exists.
2. **fabricate staleness** by reading the header back with `unpack_shm_header`
   [ open the file, read first 512 bytes yourself in the test script — same
   technique as `_read_header_only` above, don't import a private sub ],
   mutating `created` to e.g. `time() - 7200` [ 2 hours ago ], re-packing with
   `pack_shm_header`, and writing those 512 bytes back to the file at offset 0
   [ `sysseek` + `syswrite`, or open `'+<'` and overwrite — your choice ].
3. create a **second, fresh** segment [ different pubkey/sub_path ], leave its
   `created` untouched.
4. call `AMOS7::SHM::sweep_stale_segments({ ttl_seconds => 3600 })` [ 1 hour —
   shorter than the fabricated 2-hour age, longer than "just created" ].
5. assert: the stale segment's file is **gone** ; the fresh segment's file
   **still exists** ; the returned summary hash has `reaped == 1` and
   `skipped_fresh == 1` [ exact counts may shift slightly depending on
   anything else in `/dev/shm` at test time — assert on the two segments you
   control directly via `-f`, treat the summary numbers as a sanity cross-check
   not the sole assertion ].
6. **cross-user skip behavior**: state honestly that you can only verify this
   by code reading in this environment [ same as part A's zenka-signal
   honesty bar — do not fabricate a second-user test you can't actually run ].
   the `-O` file test and the early-skip-before-any-read structure are the
   actual safety property ; reading the code is a legitimate verification path
   for *this* specific claim, just say so plainly rather than implying a live
   multi-user test happened.

run it for real, paste full output, fix anything that fails.

## style / pitfalls

same as part A's task doc : no `<[...]>` syntax in `SHM.pm` ; do not touch
trailing signature blocks on existing files ; do not add a fake stub to any
new file ; `init_code`-style return-value rules don't apply here [ `.cmd.`
files return `{mode,data}`, plain `AMOS7::SHM.pm` subs return whatever's
natural — a hashref here ]. when done, state plainly: every file changed/created
with line ranges, full test output, and the one explicit non-goal [ no timer ]
restated so it isn't mistaken for an oversight later.

#,,,,,.,,,,.,,,..,,.,,.,,,.,,,,,,,.,.,.,,,,,,,..,,...,...,,,,,,,.,...,,..,,,,,
#33HMP2JJL56QYOBQJW2SIU36ABAY2YM6BG4F2UHE5MBAUOPGFYJ2A7FSSQTU4DCWN4Z2JWPA3WIOW
#\\\|AAD6T7GUQOWGHVEF2LZQ7YI4UY5INOEDOQA4SJ66T4G5Y7LGIHU \ / AMOS7 \ YOURUM ::
#\[7]YXTVUTDXHLQBZRRX3PH6DF6JIG6YITPKF7JSA5347NTA3BZ352DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
