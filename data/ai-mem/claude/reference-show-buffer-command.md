---
name: reference-show-buffer-command
description: correct command for viewing zenka buffer/log content — no p7-log.tail command exists
metadata:
  type: reference
---

There is no `p7-log.tail` (or any `*.tail`) command in Protocol-7. For inspecting a named
buffer's tail content or filtering it, use `show-buffer`:

```
<zenka>.show-buffer <name> [lines] [pattern]
```

- `list buffers` (routed to the target zenka) enumerates available buffer names first.
- `[lines]`: numeric token of up to 5 digits, taken as a tail count (last N lines). A
  numeric token with more than 5 digits is assumed to be a pattern instead (e.g. a PID
  or hash), not a line count — no real buffer runs past ~99999 lines.
- `[pattern]`: everything after `[lines]` (or after `<name>` if `[lines]` is absent) is a
  Perl regex, compiled via `<[base.eval.comp_regex]>` and matched against each line.
  Tail is applied first, then the pattern filters within that window.
- Implemented in `modules/base.cmd.show-buffer`; added 2026-08-07 (`bin/todo` item 7).

**Why:** in an earlier session I tried calling a nonexistent `p7-log.tail` command,
guessing at a name instead of checking what actually exists (`list buffers` /
`show-buffer`). The user filed the todo item from that mistake, deferred it for months,
then had me implement `[lines]`/`[pattern]` support on `show-buffer` directly.

**How to apply:** when asked to check zenka log/buffer output, use `show-buffer` (with
`list buffers` first if the buffer name is unknown) — never invent a `.tail`/`.log`-style
command name without verifying it exists in `modules/`.

See also [[topic-buffer-access-control]] (future per-buffer ACL), and the
`base.eval.comp_regex` delimiter-escaping bug fixed alongside this (raw `'` in a pattern
used to crash the regex compile — fixed by escaping only the `'` delimiter, not backslash,
since `qr'...'` hands `\`-escapes straight to the regex engine).

**Correction 2026-08-07**: the `zenka` buffer (and named buffers generally) is a passive
review sink only — it has no functional role in the zenka's actual runtime logic. Its
retention is governed purely by `system.zenka.verbosity.buffer` (default 1) vs. how
chatty the code logging into it happens to be at each level; nothing downstream reads it.
I initially over-interpreted a rotated-out buffer (`coding`'s zenka buffer, 130777-byte
cap, blown through within a single self-test prompt because `coding.handler.http_io` /
`http_io_parse_line` log every SSE chunk at level 2 — ~5 log lines per streamed token)
as evidence that the underlying timeout/retry *behavior* itself was somehow unverifiable
or unreliable. The user corrected this directly: the buffer's rotation only affects what
a human can review after the fact through `show-buffer` — it says nothing about whether
the code path itself is correct. Don't conflate "I can't see it in the buffer" with "the
system can't see it either" — the buffer is strictly downstream of behavior, never load-
bearing for it. (The user separately lowered the coding zenka's `verbosity.buffer` to
match console level 1, which stopped the chunk-spam eviction problem for future review —
but that was a review-quality fix, not a correctness one.)

#,,..,.,.,.,,,,,,,.,,,..,,.,,,,,.,.,.,.,,,,..,..,,...,...,,..,,..,.,,,...,.,.,
#MQG3LBRBEEQHMEEIO2OFFSZLU3OW4E756IUEMMLZVKCQPMGPIUTBP2T7YAF5A7TLL5BGLZIU6IRNI
#\\\|TE6AFSUCOSXQ57FU6CNFCPHY4GTWWPDT3H6WCXLFMJ3MATLJZK3 \ / AMOS7 \ YOURUM ::
#\[7]QPY4FMBK4KJHQOLSLBERLHC6XXOOEL5GNQ6MIQCCOQUIAO4SDUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
