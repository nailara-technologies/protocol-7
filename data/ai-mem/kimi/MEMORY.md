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
- **session-end ritual** — user signs + stages; I commit (running `./bin/dev/update-version` first if
  the hook flags a version mismatch); the user then rebuilds the bundle (`gbc` alias) and pushes
  `hub base`. pushing to the `ext-bundle` remote fails by design — it is the bundle FILE, read-only.
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

- **[topic-model-batch-harness-and-self-test-findings.md](topic-model-batch-harness-and-self-test-findings.md)**
  — 2026-09-21: Event.pm silent watcher suspension, `event.add_timer` `data` vs `params`,
  ambient `$call` hazard, self-test seed-restart gate coverage (prompts 2+3), prompt 3
  `mismatch_hint`, honest context-exhausted reporting, batch harness env blockers (open).

- **[MEMORY-completed.md](MEMORY-completed.md)** — explicitly-completed / resolved work.
- **[MEMORY-archive.md](MEMORY-archive.md)** — stale chronological session log.

#,,.,,,,.,,,.,..,,..,,..,,...,,,.,,.,,..,,,,.,.,.,...,...,.,.,..,,.,.,...,.,.,
#LFLNEUV7TVXRMBPVFZWFBL6W3KIER7G2J3DLY2V3GISQMPM4VEUHTLGTZHE57FD44OVR4OALIZHEK
#\\\|KXS66XE7QGIFOY2FAO6F7DKLE6U65RVH7MGE7XJ4VWZLLI2HP6D \ / AMOS7 \ YOURUM ::
#\[7]PBWN6NBOXLHWVTVRJM33UVXXAU25PUCR4Q7KU4Q426BMG3R4S6BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
