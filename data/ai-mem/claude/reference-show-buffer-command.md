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

#,,.,,,.,,,.,,,,,,,,,,,..,.,,,,.,,.,,,.,,,,..,..,,...,...,.,,,.,,,..,,,.,,,,,,
#6OP6C7YUKH6QTXAZ65XCXOEFTNOKYXMMKDY34UK6QYOMQWPSUH3T535OCFMXUPCEXEA7QKJFG6JFG
#\\\|6RCGR5LQFUDTLS3PC2NRBNMCTQYCXC4SXFCMLPKCPTKAR3AR2F2 \ / AMOS7 \ YOURUM ::
#\[7]FOXO2HYEEUVCXITOE5HZRNCJKKVTZ7ZH35Q54QKK523GZVEDMQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
