---
name: base-log-vs-logs-sprintf
description: "base.log and base.logs look identical at call sites but only base.logs sprintfs the message -- passing a %s/%d template plus trailing args to base.log silently misassigns them to log_buffer/time_stamp instead of substituting, found live at 113 call sites across 63 files this session"
metadata:
  node_type: memory
  type: feedback
  modified: 2026-07-20
---

`src/base.log` — "generate a log entry", signature `(log_level, log_msg, [log_buffer],
[time-stamp])`, exactly those 4 positional args, shifted in that fixed order. **It never
sprintfs the message.** `src/base.logs` — "'base.log' sprintf wrapper", does
`sprintf(shift @ARG, @ARG)` on the template + remaining args, then calls `base.log` with the
already-formatted result. The two look identical at call sites
(`<[base.log]>->(...)` vs `<[base.logs]>->(...)`, one letter apart) but have incompatible
contracts.

**Failure mode**: `<[base.log]>->( $level, "template %s", $value )` — `$value` doesn't fill the
`%s`, it gets silently shifted into `$log_buffer` (3rd positional param) instead. If that
misassigned value then flows into something that validates buffer names
(`base.buffer.add_line`'s `^[\w\-_]{1,24}$` check), it can cascade into a real, visible failure
even though the original call *looks* harmless — a log statement that should be inert. Confirmed
live this session: `base.code.call_expected`'s missing-sub warning passed the sub name as this
3rd arg, producing a `base.s_warn`/"invalid buffer name" spam loop in `p7-log` on every reload
(traced via `v7.show-buffer undef-subs` → `base.code.call_expected` → `base.log`/`base.logs`
confusion, see [[project-sys-deps-wiring-completion]] session trail).

**Scale, when actually swept**: a first narrow grep found 5 instances; a proper multi-line-aware
detection pass (checking for `%s`/`%d` in the message string with un-sprintf'd trailing args,
excluding calls already wrapped in their own `sprintf(...)`) found **113 across 63 files** — not
concentrated in one subsystem, spread through `coding.handler.models_*`, `models.*`, `httpd`/
`httpsd`, `plugin.web.space.*`, `decoder.*`, `source.signature_valid`, and more. Fixed via
`kimi_dispatch model=k2.7` (task file `data/tasks/base-log-sprintf-misuse-sweep.md`, checklist
`data/tasks/base-log-sweep-baseline.txt`), landed `9eba08e3d`.

**Detection gotcha**: a naive single-line grep for the bug pattern misses most instances because
call sites wrap args across multiple lines, and a naive character-class regex (`[^'"]*` between
quotes) breaks on messages containing an embedded apostrophe (e.g. `"starting 'nvidia-smi' ..."`)
— it silently stops matching at the first `'` inside a double-quoted string. Use a proper
multi-line-aware script (see the task file's detection approach) or `ncode search` with a regex
like `\[base\.log\].+%s`, not a quick single-line grep, when re-auditing this in the future.

**How to apply**: when writing or reviewing any `<[base.log]>->(...)` call, check whether the
message contains `%`-placeholders. If it does and there are trailing args meant to fill them, it
must be `<[base.logs]>->(...)` instead — otherwise those args land in the wrong parameter slots
and the message never gets substituted.

## related

[[project-sys-deps-wiring-completion]] · [[project-ondemand-zenki-registry-wipe]]

#,,..,.,.,.,,,,.,,.,.,,,,,,.,,,.,,,..,...,,,,,..,,...,...,,..,.,.,..,,.,,,,,.,
#P4O77XMT4AABPAECOPVYMUIZ6PWGAR4G27SR6IKB4QIAOPHPZSETZXAYNKRGNFW4ADJ2SFK3QUQCY
#\\\|WZC7UHKJZZZRM4365BRBTJU2KOMS66SX2KKV6SQOA4QRO67BA4S \ / AMOS7 \ YOURUM ::
#\[7]KKCFKR7OFJBWDMYVJYJIG7JML7YTF3JOT34IRS6NIJXOCPXH3YAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
