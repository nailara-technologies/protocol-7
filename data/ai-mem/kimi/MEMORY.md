# Kimi Development Memory — top-level index

this file is auto-loaded every session. it keeps only the CRITICAL items inline; everything else
lives in the category files below. when a topic surfaces in conversation that matches a category
summary, OPEN that file — it is not auto-loaded, so it is only consulted when you go read it.

## CRITICAL

- **commit policy** — never commit without a valid version number (`./bin/dev/update-version`) and
  proper signatures (`bin/Protocol-7 sourcecode update-signatures`). use `--no-verify` only in
  emergencies.
- **commit message form** — short `area : topic` title [ <= 72 chars ], ONE empty line, then `- `
  bullets wrapped at ~75 [ two-space continuation ]. a one-line message is fine only when there
  is nothing more to say — never fold the whole body into the title with `;` `--` `[ ]`. the
  multi-line messages in the history are the CORRECT form, the long one-liners are the offenders
  [ 2026-09-30 a reword task inverted this, collapsed the correct messages and was force-pushed ;
  before any history reword, show the older-history baseline and state which form is produced ].
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
  open for: fork-child gotchas, iteration-counter quality rejection, `v7-zenki.terminate` deadlock,
  `v7-zenki.reload init` live-network teardown.

- **[topic-model-batch-harness-and-self-test-findings.md](topic-model-batch-harness-and-self-test-findings.md)**
  — 2026-09-21: Event.pm silent watcher suspension, `event.add_timer` `data` vs `params`,
  ambient `$call` hazard, self-test seed-restart gate coverage (prompts 2+3), prompt 3
  `mismatch_hint`, honest context-exhausted reporting, batch harness env blockers (open).

- **[MEMORY-completed.md](MEMORY-completed.md)** — explicitly-completed / resolved work.
- **[MEMORY-archive.md](MEMORY-archive.md)** — stale chronological session log.

#,,,.,,.,,..,,.,.,,..,,,.,.,.,.,.,.,,,,,.,.,,,.,.,...,..,,...,,.,,.,.,,,,,,.,,
#6JRRS3EKFMS3MIVRREWVERVOWDRWE7JD2H2LMC5VWWI2SL7HGAM2LDY6ZK3TZYP6TQMA56BT4EXDA
#\\\|2TRC36FG453VPA54IMQ6PIDGCEALUT75I62LUZFC37D2KY2U2LQ \ / AMOS7 \ YOURUM ::
#\[7]P6DDCX3KELVHRTWVGLCCYHYK4U22KCY5BUREKJQVYZSBD63WTODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
