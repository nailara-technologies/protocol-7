---
name: devmod-leave-disabled
description: "when adding devmod to a zenka for diagnostics, leave eval-code/exec-sub/set/del commented out by default"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

When adding `devmod` to a zenka's `modules.load` (for `eval-code`/`list-subs`/`deparse-code`/etc.), only enable read-only commands (`list-subs`, `deparse-code`, `dump`, `get`) in `access.cmd.usr.cube` by default. Leave `exec-sub`, `eval-code`, `set`, `del` commented out as `## <-- dev only`.

**Why:** user explicitly chose to disable these on the `reasoning` zenka after I'd enabled them during debugging — even though only `taeki` has wildcard access to invoke them, leaving arbitrary-code-eval enabled by default is easy to forget about. (2026-06-16, [[feedback-ondemand-zenka-start-checklist]])

**How to apply:** they can be enabled on demand by editing `access.cmd.usr.cube` and reloading config — don't leave them live after debugging is done.

#,,,.,.,.,..,,...,...,...,,.,,,,,,,..,..,,..,,..,,...,...,,,,,,..,,.,,...,,,.,
#BZGJWCSMJFXHHO4DXPG73NABTXW4IPV5HZBQMWZ5FY3PJSRM56ZKUHB5PINDZZYUG5EWYTNNDD5N2
#\\\|6CSTV4XAD6YJ4AQEME5IX4LB2DFSP6LRBXGNRLR6SAB7WS56VMM \ / AMOS7 \ YOURUM ::
#\[7]KXHLAHZ4WJXMNCDYVXMN6HJYUWPZX3IQ3PTQJ7QCPDFH5LNUIWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
