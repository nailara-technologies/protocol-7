---
name: feedback-standalone-zenka-init-done-hybrid
description: non-v7-managed zenki need [init-done:TRUE] or system.zenka.initialized never becomes true — init reports stall forever
metadata:
  type: feedback
---

`<system.zenka.initialized>` was historically only ever set `TRUE` for the `cube`
zenka in `base.init-done` — every other zenka was assumed to get it set later via the
v7 online-notify flow. A standalone/unmanaged zenka (nshell) that never goes through
v7 management stayed permanently "not initialized," so `base.session.send_init_reports`
looped forever logging `delaying sending init reports [ zenka is not initialized yet ]`
— almost certainly the cause of a CPU-pinned nshell hang seen when cube was killed
out from under it mid-restart.

**Why:** `base.init-done` now takes an opt-in `# param = [hybrid-init:TRUE|FALSE]`
(via `<[base.cfg_bool]>`). A zenka's start file calls `[init-done:TRUE]` right before
`[zenka.loop]` to mark itself initialized without touching any v7-managed zenka's
behavior. Fixed for nshell in commit `fc49ca693`.

**How to apply:** any new standalone/unmanaged zenka (connects to cube but isn't
v7-managed — see CLAUDE.md's "Unmanaged" deployment option) needs `[init-done:TRUE]`
in its start file, or its own init reports (and anything else gated on
`system.zenka.initialized`) will silently stall forever with no error, just a repeating
log-level-2 message.

Note: local file logging keeps working regardless of this bug — `p7-log`'s own
`local_logfile_write` gates on *p7-log's* `initialized` state, not the sending zenka's;
only the `notify_online`/init-report handshake to cube/v7 stalls.

Related: the retry timer in `base.session.send_init_reports` used to fire that log
message at a flat 0.777s forever with no backoff. Now grows `*1.2` per retry capped at
5s — same envelope shape as `v7.handler.zenka_status`'s `restart_delay` (multiplicative
growth + min/max envelope), the canonical backoff pattern to reach for in this codebase
rather than inventing a linear/additive scheme. Fixed in commit `3b3cc5ab7`.

#,,..,.,,,.,,,.,.,,,.,..,,.,,,.,.,,..,..,,,,.,..,,...,...,...,..,,,.,,,,.,,,.,
#SN2CBL2LJBJPPO3PWWFOGQYA7CCWVUBR63WF7X52JA6FUQKHHEVUXR6WGS2XIJQQW6RERMUS2VL7M
#\\\|GTHRSAH745PU6JEG2Y4EFWE3XYCWZYEMTYYOS3ZX4HM3S7VD4UF \ / AMOS7 \ YOURUM ::
#\[7]MD7UN6QLB3DCSCN2UKVWBSOZ46GS7ZH3VZICWRFJA2GXGAQFLUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
