---
name: cross-zenka deferred reply pattern
description: how to correctly implement deferred replies across zenki via route-send
type: feedback
originSessionId: 34ca9c97-628c-46af-82f3-d04a171ae8f0
---
Cross-zenka deferred replies via `reply => { handler => ... }` in route-send FAIL
because the session closes after the handler returns `{ mode => 'deferred' }`.
`base.callback.cmd_reply` silently drops the reply (session gone path, level 2 log).

**Why:** The session that received the routed command is only valid for the duration
of that call. Once `deferred` is returned, the session closes. Any later `cmd_reply`
with that reply_id finds the session gone and drops silently.

**How to apply:** For any cross-zenka deferred operation:
1. Store `reply_id` locally in originating zenka (e.g. `<task.summarize.pending>`)
2. Pass `callback_id=<key>` in args to the receiving zenka
3. Receiving zenka, when done, calls `route-send` to a dedicated cmd in the
   originating zenka (e.g. `task.summarize-done`) with the result
4. That cmd fires `base.callback.cmd_reply` locally with the stored reply_id
5. Add the callback cmd to cube access.zenki for the calling zenka

Pattern implemented in: task.cmd.summarize + task.cmd.summarize-done +
coding.cmd.summarize-context + coding.handler.deferred_reply (callback_id branch)

Also: `call_args.data` is NOT transmitted over routes — only `call_args.args` (string).
Multiline content must be base32-encoded: `encode_b32r(Encode::encode('UTF-8', $text))`
and passed as `:B32:<b32>` in args. Receiver strips `:B32:` prefix and decodes.

#,,,.,,.,,,.,,,,.,,,.,,,,,.,,,,..,.,,,,,.,,..,..,,...,.,.,.,,,,,.,.,.,.,.,.,.,
#OOTNKG5JHICSSUVLKNA64K3IXWOLDEKA3IOWNBSOXIYA6IXF7PQELEVDSFT5FMTTUR325NC6SFEWE
#\\\|ZDM7OIVNWHKF55CKLW3CAQUK4ARMC2NZ5JSLNO2ZA7DFDCRCBL2 \ / AMOS7 \ YOURUM ::
#\[7]A23E2HFCCUTSVFJYH4TVXHRZRTKSUSMQEKCFQGPVHJETBVXXIKAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
