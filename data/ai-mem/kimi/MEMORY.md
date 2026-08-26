# Kimi Development Memory — top-level index

this file is auto-loaded every session. it keeps only the CRITICAL items inline; everything else
lives in the category files below. when a topic surfaces in conversation that matches a category
summary, OPEN that file — it is not auto-loaded, so it is only consulted when you go read it.

## CRITICAL

- **commit policy** — never commit without a valid version number (`./bin/dev/update-version`) and
  proper signatures (`bin/Protocol-7 sourcecode update-signatures`). use `--no-verify` only in
  emergencies.
- **structural work conventions** — before structural work, read
  `data/md/development/STYLE-PHILOSOPHY.md` alongside `data/yaml/code-style/CONVENTIONS.yaml` and
  `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`; update the philosophy doc if you refine
  its perspectives.
- **signature updates require user passphrase** — ask the user to run the signing command; never
  skip hooks.
- **memory tool limits** — `p7_memory_update` enforces per-agent line limits on `MEMORY.md`
  (claude ~180/200, kimi ~300/400); use `target` for external topic files and `UPDATE FILE:`
  directives for category files.

## Category files — open the one that matches the topic in play

- **[MEMORY-active.md](MEMORY-active.md)** — in-flight / recently-landed work.  
  open for: `routing_mode`, `strm.subscribe`, `session_catchup`, `bin/chat`, jobsite pipeline,
  duck.ai security task tree, coding self-test async transport, kimi `QuestionRequest` decline,
  amos-term interaction prototype, `source.extract_sig_body` fake-footer fix, audio spatial-purr,
  ncode scope-stack phase 2, ascii.frame cursor marker.

- **[MEMORY-reference.md](MEMORY-reference.md)** — durable how-to + settled rules.  
  open for: memory update tool details, `%code` presence / cross-namespace calls, module name
  swaps, command return style / deferred replies, perlmod load/autoload lessons, user-edit outbox
  unlink choice.

- **[MEMORY-feedback.md](MEMORY-feedback.md)** — gotchas, failure modes, and incidents.  
  open for: fork-child gotchas, iteration-counter quality rejection, `v7.stop` deadlock,
  `v7.reload init` live-network teardown.

- **[MEMORY-completed.md](MEMORY-completed.md)** — explicitly-completed / resolved work.
- **[MEMORY-archive.md](MEMORY-archive.md)** — stale chronological session log.

#,,,.,,,.,.,.,,,,,,,.,.,,,,,,,.,.,,,,,,.,,.,.,.,.,...,.,.,.,,,,,,,,..,,,,,.,.,
#3EAUE7VJLUZJHNA43RO6VROHEFBIGMO4K4VNU3IDALP5G46PETLZVHAB4RXDORIIZIHNOIT2GRZOM
#\\\|J45AB6NG3Y246ZUSIRDRWX7T4ASFI44VPZIVGF7JFGHAI3ZKQYU \ / AMOS7 \ YOURUM ::
#\[7]OPWLVUWM7EXSA43BF2QC4L5GR5WDQB2LCKHT5JEBTGPLFBARHACQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
