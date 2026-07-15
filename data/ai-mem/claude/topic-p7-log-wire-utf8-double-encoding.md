---
name: topic-p7-log-wire-utf8-double-encoding
description: p7-log double-encoded non-ASCII log chars (→ etc); root cause + fix landed 2973129e6
metadata: 
  node_type: memory
  type: project
  originSessionId: 0d46a874-6932-4079-b5bd-8c9a472dd336
---

`p7-log.add_line` was double-encoding non-ASCII characters (e.g. `→`) written
to zenka log files — same mojibake pattern as [[reference-unicode-encoding-repair]]
but a live bug, not stale file corruption.

**Root cause:** `base.s_write` correctly encodes outgoing wire strings to raw
UTF-8 bytes before `syswrite`, but nothing on the receive side (`base.s_read`
→ `base.handler.command`) decodes back — `$call->{'args'}` stays a raw byte
string with no Perl UTF8 flag. `p7-log.add_line` then printed those bytes
through a `>>:encoding(UTF-8)` filehandle, which re-encoded each byte as its
own Latin-1 codepoint.

**Fix:** one line in `modules/p7-log.add_line` right before the `print`:
`utf8::decode($$log_msg_ref) if not utf8::is_utf8($$log_msg_ref);`
Landed 2973129e6 on `base`.

**Why:** any wire-transported string (via `route-send`/`protocol-7.command.send.local`)
that reaches an `:encoding(UTF-8)` filehandle without an explicit decode step
downstream will hit this same bug — only `p7-log.add_line` was audited/fixed
so far; other consumers of `$call->{'args'}` weren't checked.

**How to apply:** if similar mojibake shows up in other zenka logs, trace the
wire path backward from the write site (search for `:encoding(UTF-8)` +
missing `utf8::decode`) rather than forward from the string's origin — that's
how this one was found quickly despite several unrelated utf8 fixes already
landed elsewhere in the codebase.

**Live test tool:** `modules/devmod.cmd.echo`, loadable into any zenka's start
file (`<zenka>.commands echo` — jobsite already had devmod loaded, just needed
the command enabled), round-trips a string through `p7c <zenka>.echo "str"`
and logs it — lets you inject a wire-transported test string and inspect the
resulting log file bytes directly (`hexdump -C`) to confirm/bisect encoding
fixes without waiting for real traffic. Remove the command from the start
file again once done testing.

#,,.,,.,.,,..,.,.,...,,,,,,,,,,.,,,,.,,.,,,,.,..,,...,.,.,..,,.,.,.,.,.,.,,,.,
#5VECZ3VKNKQL6ZWRYCNWGX2OMMNJDU5REFXTFDU4YZOF2GTFTXC6KZ7DPIJXTSKPQPAO3OEOSGOPW
#\\\|U55BG7UIQV7HFFSBAYWOPKMZOFJDGVH5AJUWR4NQSSAKR2VWPRJ \ / AMOS7 \ YOURUM ::
#\[7]DFXUV4UAFV3RR5ZQ5TIHJXNMIZXUCZNR4NB26UOVWO4ZFFGV6WDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
