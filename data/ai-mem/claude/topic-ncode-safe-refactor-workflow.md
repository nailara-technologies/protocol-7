---
name: topic-ncode-safe-refactor-workflow
description: "ncode's existing preview/backup/undo/grace-period CLI strengths need a network+web-UI equivalent, aimed at making autonomous zenka/model refactors as safe as human-approved ones"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**2026-07-17, design-only.** Surfaced right after scoping `ncode`'s
read-only network access (see [[topic-ncode-access-gap]],
[[topic-write-access-security-infrastructure]] for the write/sign
approval side). This note is the ncode-specific expansion the user wants
on top of that — distinct from the general signature-approval
infrastructure, though it will plug into it once that exists.

## what already exists in bin/ncode (confirmed by reading the code, not assumed)

- `preview()` (`-preview-only` flag) — styled diff shown before applying.
- `create_backup` / `cmd_restore_backup` — tar.gz/tar.xz archives under
  `backups/`, restorable via `bin/ncode restore-backup [-latest]`.
- `undo` / `undo-move` commands.
- **`warn_apply()` (line ~1271) already IS the grace-period-abort
  feature** the user described, verified live via `ncode search
  "A P P L Y I N G"`: blinks "A P P L Y I N G   C H A N G E S" for ~3s
  (7 iterations × 0.42s `IO::Select->can_read` poll on STDIN), any
  keypress during that window calls `&aborted` which `exit`s *before*
  `create_backup`/`overwrite_source_files` run at all three call sites
  (lines 726→746→750, 974→994→998, 1219→1233→1236) — a genuine
  pre-write abort, not a post-write undo. **Important constraint**: it's
  called `warn_apply() unless $AI_FRIENDLY` — disabled in non-interactive/
  AI-friendly output mode, because it fundamentally depends on raw TTY
  keystroke polling (`&raw_mode_on`, `IO::Select` on `\*STDIN`). No
  network command or web UI has an equivalent raw-TTY channel to poll —
  **this is the actual gap**, not the absence of the safety concept.

So the ask is not "build a grace-period abort" — it's "give this exact
UX a real equivalent when the caller isn't a human at an interactive
terminal."

## the vision, as described

1. **network/web equivalent of `warn_apply`**: user's own answer —
   assign a **timeout to the change approval** itself, replacing raw
   STDIN keystroke polling with a pending-apply state that has an
   explicit cancel action (command/button) available during the
   timeout window. Mirrors `warn_apply`'s blink-then-commit shape
   (visible countdown, any cancel action aborts before write) without
   assuming a TTY — a network command or a web UI can both expose
   "cancel within N seconds" the same way jobqueue's dependency/timeout
   primitives already model waiting-with-a-deadline elsewhere in this
   codebase ([[topic-coding-round-timeout-adaptive]] is a structurally
   similar precedent: soft ceiling + explicit escalation, not silent
   blocking).
2. **change-queue / column-based web UI**: modeled directly on the
   existing jobsite UI ([[topic-jobsite-ui-usability]]) — same
   column/card layout, but cards are code-change suggestions instead of
   job postings. Natural extension of the same preview/backup strengths,
   but as a *queue* of pending changes rather than one at a time. Same
   security model as [[topic-write-access-security-infrastructure]]:
   one signature approves, downstream trust inherits from it.
3. **the actual goal — safe autonomous refactor workloads**: once
   preview/backup/grace-period/undo have a network/web equivalent and
   are batchable through the queue UI, **zenki and models themselves**
   should be able to propose fast code refactors with the same safety
   guarantee a human gets today at the CLI, enabling things currently
   too expensive to sustain continuously:
   - nightly style-compliance-only passes
   - comment coherence/quality upgrades (rewriting comments toward
     "meaningful coherence" without touching logic)
   - dynamic style-convention upgrades over time — approved cheaply in
     batches/groups rather than reviewed individually, without weakening
     the safety guarantee ("just signature validation, not weaker").

User's own framing of why this matters: these continuous style/coherence
passes are a real, measurable component of project quality (coherence in
whatever style a project has chosen), but are currently expensive to
sustain — cheap batch approval over a safe preview/backup/grace-period
pipeline is what makes them sustainable.

## how to apply

- Don't reinvent preview/backup/undo — they exist and work
  (`bin/ncode`). The actual build surface is: (a) a non-TTY equivalent
  of `warn_apply`'s abort window, (b) exposing that + preview/backup
  over the network command layer once write access is granted, (c) the
  jobsite-style queue UI on top.
- The change-queue web UI should reuse jobsite's existing column/card
  patterns ([[topic-jobsite-ui-usability]]) rather than building fresh.
- Sequencing: this plugs into
  [[topic-write-access-security-infrastructure]]'s signature-approval
  system once that exists — don't build ncode write/apply network
  commands ungated in the meantime.

[[topic-ncode-access-gap]]
[[topic-write-access-security-infrastructure]]
[[topic-jobsite-ui-usability]]

#,,,,,...,...,...,.,.,,,.,,.,,,,.,,,.,,,,,.,,,..,,...,...,...,.,,,...,,..,,.,,
#YFKAIGQVWJFLYSDW6IFQHP4CTX4AGDBYKE4NGJQM3ASHMNYZYEWSFZ3KZS6KSRKR5BU63P2HV7UTC
#\\\|RMN75OTFTLANYCTSK2IVOHNYJJBKGVX3Y257DGXSJBLMUKFGN62 \ / AMOS7 \ YOURUM ::
#\[7]576SFKFDGICCRJQOOWZIY3E7UUYVCBDILPDBEPFSQE3KTWGICSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
