# task: content zenka — undef $type_str race crashes web-browser (segfault)

## context

Part of the same 2026-08-28 session as `data/tasks/x11-xvfb-start-async-refactor.md`
and `data/tasks/web-browser-capture-slideshow-var-watcher.md` (style-triage screenshot
pipeline). The web-browser capture-slideshow feature (built and verified working
earlier tonight) was being smoke-tested with a fresh batch of files fed through
`content.cmd.clear-entries` + `content.cmd.add-entry` (8 `file://` entries) +
`web-browser.cmd.fetch_url_list`, called back-to-back with no delay. This triggered a
REAL crash — a segmentation fault in the `web-browser` zenka, more severe than any of
tonight's earlier heartbeat-timeout crashes. This is a PRE-EXISTING bug, unrelated to
anything built tonight by either a human or Kimi — just newly exposed by this specific
usage pattern (rapid add-entry then immediate fetch).

## observed crash, verbatim from the live log

```
:. content : [5710542] content list cleared.,
:. content : no files in playlist.
:. content : [5710542] adding list entry.,        [ x8, one per file added ]
:. content : : warn : undef value $type_str in index
:. content : :.    .: [content.cmd.get_list_types:68]     [ x8, one per entry ]
:. we.,.er : not a HASH reference
:. we.,.er : :. [web-browser.handler.url_list_reply:14]
:. we.,.er : starting of 'web-browser' zenka not successful
:. we.,.er : .. exit [ 0110 ] called .,
: < web-browser > [PID:1103008] shut down [ with exit code 0000, signal 11 :: segmentation fault :: ]
: instance 2357500 ['web-browser']   online --> error
: : preparing instance 2357500 ['web-browser'] :: restart ::
```

`web-browser` auto-restarted cleanly afterward (single instance, same instance id,
confirmed — this write-up is not itself evidence of ongoing instability, just of this
one crash path).

## root cause, confirmed via code reading — a genuine async race, not a typo

`src/content.cmd.get_list_types` line 66-70:

```perl
my $type_str = $type_list->{$file};
foreach my $req_type ( keys %file_types ) {
    $reply_string .= "$type_str $file$url_flags_str\n"
        if !length($req_type)
        or index( $type_str, $req_type ) != -1;
}
```

`$type_list` is `<content.file_types>`, a hash keyed by file/url. It is ONLY populated
by `src/content.handler.mimetype_reply` (line 80: `<content.file_types>->{$url} = $type;`),
which is an ASYNC reply handler — confirmed via `src/content.process_playlist_entries`
line ~167, which dispatches the mimetype check through
`<[protocol-7.command.send.local]>` with `'handler' => 'content.callback.check_mimetype'`,
the standard async command+reply pattern used throughout this codebase (same shape as
`coding.handler.spawn_smart_path_reply` etc.) — not a synchronous call.

So: `content.add-entry` returns immediately (it just pushes to `<content.file_list>`
and queues `content.process_playlist_entries` on a 0.07s timer — see
`src/content.cmd.add-entry`), and the actual per-entry mimetype resolution that
populates `<content.file_types>` happens even later, asynchronously, one HTTP-ish
round trip per entry. If `content.cmd.get_list_types` (or `get_list`, used internally
by whatever `web-browser.cmd.fetch_url_list` calls) runs before ALL of a freshly-added
batch's mimetype checks have completed, `$type_list->{$file}` is genuinely `undef` for
the not-yet-resolved entries — exactly matching the observed
`undef value $type_str in index` warnings, one per still-unresolved entry.

`content.cmd.get_list_types` itself only WARNS on this (Perl's `index()`/string
interpolation on undef is a warning, not fatal) but produces a MALFORMED reply line for
each undef-type entry — likely something like `" /path/to/file.html\n"` (leading space,
no type token) instead of `"html /path/to/file.html\n"`.

That malformed reply is very likely what breaks `src/web-browser.handler.url_list_reply`
downstream (`not a HASH reference` at its line 14) — **not independently confirmed
which exact line/expression throws that specific error; the line-14 content read during
this session (`if ( defined <web-browser.url_list.bmw> and ... )`) does not obviously
match "not a HASH reference" at face value, so either the live line numbering differs
from what's in the tree right now, or the error is being mis-attributed to line 14 by
whatever wraps it — needs a closer read of the ACTUAL current file plus
`src/web-browser.handler.2html_reply` and the rest of `url_list_reply`'s parsing loop
(`content.cmd.get_list_types` reply format assumes well-formed `"type url\n"` lines; a
line with a leading space instead of a type token won't match
`url_list_reply`'s own `/^([^\s]+) +(.+)$/` parse regex at all, so it should just be
silently skipped, not crash — the actual segfault mechanism through to a hard
signal 11 is NOT fully traced, this task file gives you the confirmed upstream cause
and the immediate symptom, not a confirmed line-by-line chain all the way to the crash**.

## how to fix

Two independent, complementary angles — do both if reasonable:

1. **`content.cmd.get_list_types` should never emit a malformed line.** Guard against
   `$type_str` being undef — either skip the entry entirely (don't emit a line at all
   for a not-yet-typed file, consistent with "not ready yet") or default it to a safe
   placeholder type. Also check the near-identical `$type_list->{$file}` usage in
   `src/content.cmd.get_list` (line 10) for the same undef-vulnerability, since it
   reads from the same hash.
2. **`web-browser.handler.url_list_reply` (or whatever it calls into) should not crash
   hard on a malformed/partial reply.** A segfault (signal 11) from a Perl-level "not a
   HASH reference" error is itself surprising — Perl throwing that as a runtime error
   should normally just die/warn inside an eval or propagate as a normal exception, not
   segfault the whole process. Worth checking whether this is happening inside a C-level
   binding (WebKitGTK/Glib callback) where a Perl exception unwinding across a C call
   boundary can genuinely segfault rather than being caught — if so, the real fix is
   wrapping whatever calls into `url_list_reply` (or the code path between it and the
   native GTK ->callback boundary) in an `eval` that can't let a Perl die() cross that
   boundary uncaught.

## live-testing hazard

This crash is a genuine segfault, not just a heartbeat-timeout kill — treat it as more
severe than the bugs in the sibling task files tonight. `web-browser` auto-restarted
cleanly on its own this time (single instance after, no manual cleanup needed), but
don't assume that's guaranteed. Prefer fixing via code reading + the log excerpt above
over reproducing it live; if you do reproduce it, expect to need the same
`v7.instance_pids <id>` / `v7.stop <id>` duplicate-instance cleanup documented in the
sibling X-11 task file if it doesn't recover cleanly.

## dispatch notes [ for whoever picks this up, human or AI ]

Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` first if
you're kimi. P7 pitfalls: `base.logs` not `base.log` for multi-arg sprintf-style calls,
never redeclare `my $call`, never add fake `PLACEHOLDER_FOR_AMOS7_SIGNATURE_LINE`
footers to new files, `TRUE`/`FALSE` are `5`/`0` not `1`/`0`, use `bin/dev/ptd -c` to
check syntax (NOT raw `perl -c` — it doesn't run this codebase's macro preprocessor and
will report false syntax errors on every `<var>`/`<[code]>` macro). If you learn
something non-obvious while working on this, add a note to your own memory files, same
as any other task.

## status

Fixed 2026-08-28:
- `src/content.cmd.get_list_types` and `src/content.cmd.get_list` skip entries whose
  type is not yet resolved (`next if not defined $type_str`), preventing malformed
  reply lines.
- `src/base.handler.command.process_reply` now wraps every reply-handler invocation in
  an `eval` guard, logging the error and continuing instead of letting a Perl exception
  unwind across the event-loop / native callback boundary and segfault the process.

Memory note: `data/ai-mem/kimi/MEMORY-active.md` (content / web-browser undef-type
race + segfault hardening).

#,,,,,,,.,...,,,.,.,,,,.,,.,.,..,,,,,,...,,,.,..,,...,...,...,.,,,,..,,..,...,
#VHXV3NNZE4TBD7JAYIBQUTWJW6XAOZXAPTK66FT5U7HCVIWLBKKIRZUE3MZULBNT4XM3FBSX23OAI
#\\\|IOAOHM6QPXA52RWHUL3U2WTM7GEGUS5LWSQZBHFJ76NYLTVHIT3 \ / AMOS7 \ YOURUM ::
#\[7]XLVH57L4JYMFZ3QVTJMD7GOK2UO26WTGGNB77LC7UHAVZ2PLCYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
