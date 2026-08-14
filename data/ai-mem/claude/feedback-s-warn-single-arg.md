---
name: s-warn-single-arg
description: "fixing base.s_warn 'sprintf parameter expected' errors - use plain warn for non-sprintf messages, not <{C1}>, '' padding"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1fae67f1-7fe7-41e7-9119-372afacccc2b
---

`<[base.s_warn]>->(...)` requires >=2 args (sprintf template + at least one
param), else it warns "sprintf parameter expected". When fixing a single-arg
`<[base.s_warn]>->('fixed message <{C1}>')` call that has no real sprintf
params, do NOT pad it to `<[base.s_warn]>->('msg <{C1}>', '')`.

Instead replace it with plain `warn 'msg <{C1}>';` — `warn` is overloaded
with a SIGWARN handler that already expands `<{C1}>`/`<{NC}>` caller-info
placeholders, same as `base.s_warn` does for sprintf-style messages.

**Why:** user explicitly corrected the `<{C1}>, ''` workaround
(2026-06-15, cred-mesh.key_holder.parent fixes) — said `<{C1}>, ''` is "a
workaround" and plain `warn '... <{C1}>'` is the correct/regular form.

**How to apply:** for messages WITH real sprintf params, keep/add them as
extra args to `base.s_warn`. For fixed messages with no params, use plain
`warn`.

**Alternative seen 2026-08-14** (`sessions.holder.*`, see
[[vision-sessions-zenka-key-holding-children]]): `<[base.logs]>->(0,
'fixed message')` also satisfies the same `@ARG < 2` shape (the level
counts as the first of the two required args), so it works too and reads
more consistently when a file already mixes `base.logs` calls at other
levels for informational messages. Not a correction to the guidance
above — plain `warn '... <{C1}>'` is still the documented/preferred form
for a pure warning with no level distinction — just noting the
`base.logs(0, ...)` shape is a real, working alternative if a file is
already logs-heavy.

#,,.,,...,...,.,.,..,,,,.,..,,.,,,,..,.,.,,,,,..,,...,...,,,.,.,,,...,,..,.,,,
#465337TFGH23LE5FZLW3PKKUXYZ7OCLVH2UZF4CHFGMWTKGNJR6TMLIOQ3CSPNDEOVR57N2PGK7OE
#\\\|ZIMUQQHEMC3CYR53MKURYC5BSPRJ4S244K3Q4ZZYRDWQBMUTBBT \ / AMOS7 \ YOURUM ::
#\[7]LNSS7EOEUMTT5YXQZ2HD75BTM6G4CN44DB2MYKHFTKI77TD62ACQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
