---
name: feedback-upgrade-substrate-not-revert-on-tool-limits
description: when an automated tool (format-code, a parser, a codegen pass) hits a case it can't handle correctly, the right response is to upgrade the underlying system (parser/syntax/tool) to handle it correctly, not revert the change or patch around the edge case -- confirmed as the correct default approach for protocol-7
metadata:
  type: feedback
---

When an automated tool — `bin/format-code`, a parser, a codegen/rewrite pass — goes "one step too
far" and hits a case it mishandles, the correct response is to fix/upgrade the underlying system
(the parser, the syntax rule, the tool itself) so it handles that case correctly, not to revert
the tool's change or quietly patch around the specific edge case. Treat the failure as a signal to
improve the substrate, not as a reason to retreat from it.

**Why**: confirmed directly by the user (2026-09-02) as "the exact correct approach for
protocol-7 to fulfil its true potential as a substrate representing error-free computing
effectively" — referencing a prior instance where `format-code` surfaced a real parser gap, and
the response was to upgrade the parser/syntax handling rather than revert. The user was explicit
that they're glad this is already the default approach here without needing reminders — a
confirmation of an already-validated pattern, not a new instruction. Consistent with this
session's own bug-hunting arc in the `sys-deps`/`debian` install queue: every bug found (the
`kill(0,$pid)` EPERM/ESRCH ambiguity, the wrong reply-hashref fields, the orphaned apt_child) was
fixed at its actual root cause and matched against a proven-working sibling pattern, never patched
around symptomatically. See [[reference-debug-via-proven-sibling-pattern]] for the concrete
debugging technique this pairs with.

**How to apply**: when a tool, parser, or automated pass reveals a case it gets wrong, default to
fixing that underlying system so the case is handled correctly going forward — even if a quick
revert or narrow workaround would resolve the immediate symptom faster. This applies to
`format-code`/`ncode` and similar repo-wide tooling especially, since a narrow workaround there
just relocates the same gap to the next file that hits it.

#,,.,,.,.,,.,,,.,,,.,,,..,,,.,..,,,,.,,,.,,,.,..,,...,...,..,,.,,,,.,,.,,,.,.,
#HV5CKSWPQMM6NQ7NVV4NNAHRX7FYUBG42UO3TPYH5XR5YW54QWXBY2TU3RZIZFAWGRSGWKQV5Z2V2
#\\\|VPDO57676UKONQNMGXKKIVZO6D5L7NII4FK2WRA3YUPUVOQFJZG \ / AMOS7 \ YOURUM ::
#\[7]G7IHL3Y467OY6Z7XFIVYGSCA5KYZEJV7KY65FDJCPOF7TZ57ZMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
