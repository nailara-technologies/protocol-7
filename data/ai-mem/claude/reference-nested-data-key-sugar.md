---
name: reference-nested-data-key-sugar
description: "any %data nesting depth >= 2 has a <key0.key1[.keyN]> sugar form, not just the documented <[module.name]> subroutine-call sugar -- applies to reads, writes, delete, and partial paths"
metadata:
  node_type: memory
  type: reference
  originSessionId: fee6b203-065d-46ee-9e22-bac7aa31efd1
---

2026-09-01. CLAUDE.md documents `<[module.name]>` as sugar for
`$code{'module.name'}->()`, but there's a second, more general sugar form
that isn't written down anywhere I could find (checked
`data/yaml/code-style/CONVENTIONS.yaml` and
`data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`, neither mentions
it): **any `%data` access nested two or more levels deep can be written
as `<key0.key1[.keyN]>`** instead of the literal
`$data{'key0'}{'key1'}{...}` chain.

Pointed out by the user after reviewing
`src/base.zenki.resume_ondemand_timeout` (this session's new file), which
had `$data{'watcher'}{'io'}{'transfer'}->start` /
`->is_active` spelled out literally instead of the shorter
`<watcher.io.transfer>->start` / `->is_active`. Same for `delete` —
`delete $data{'base'}{'ondemand'}{'saved_timeout'};` could be
`delete <base.ondemand.saved_timeout>;`. The sugar also composes
partially: `<watcher.io>->{$name}->cancel` is valid too (sugar for the
fixed prefix, literal hash access for the dynamic suffix) — useful when
a trailing key segment is a variable rather than a literal.

**Not urgent, not something to hand-fix retroactively**: per the user,
this is planned to become an automated `ncode`-driven cleanup task later
("it was even planned for format-code to have some of that capability")
— i.e. a tool pass that rewrites existing literal `$data{...}{...}{...}`
chains into the sugar form across `src/`, not something to chase by hand
file-by-file. Worth using the sugar form in new code going forward,
but don't retroactively edit already-signed/staged files just for this.

#,,.,,,,,,.,,,,.,,,,.,.,,,.,,,...,,..,,.,,,..,..,,...,...,,..,,..,,.,,,,,,,.,,
#LRXLZZMIS3ZQK33QMHYORJHEUZ7MJSUOMEZLS5EDJWZHISW3GG2ZWSGOKTGTTWP6FXRRXZMJGP6SG
#\\\|FTDJ7ZUDZ5RKIZDXCIXORTNWW7KGEN3VY35P3PYBPUMDJXJHZHX \ / AMOS7 \ YOURUM ::
#\[7]YUJ5DTJ4BKZP3XDYRZK6ZRRKJANTTF6M7XX7SIHKWCT2AFHCUABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
