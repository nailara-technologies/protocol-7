---
name: feedback-session-catchup-round-buffer-grounded-but-mislabeled
description: "the local 9B coding-zenka summarizer's live \"round N\" buffer output, shown while session_catchup/auto_summarize digests a claude_dispatch transcript, tends to be grounded in real content from that transcript rather than pure hallucination -- but can misattribute/mislabel what it saw (e.g. narrating real tool-call timing numbers as if they were \"povray render duration\"), so treat it as evidence to verify, not as an authoritative causal report"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d91a6199-7a60-4156-b83f-19dde0889634
  modified: 2026-07-27T16:10:41.792Z
---

Observed twice now: the local 9B model's live round-buffer output
during `session_catchup`/`auto_summarize` post-processing of a
`claude_dispatch` transcript surfaces real details that genuinely
appear somewhere in that transcript — previously it accurately
described Kimi's actual rendered console UI elements (ASCII
frames/banners Kimi's terminal output really produces), and again on
2026-07-27 it reported specific numbers ("204s vs 114ms" render
duration) during a dispatch that only researched and wrote a markdown
file, no rendering involved at all. Direct verification (git status,
file timestamps, grep for the cited figures across the repo) confirmed
nothing was actually rendered or changed — but the numbers likely
weren't invented from nothing either; more likely a real tool-call
timing figure from elsewhere in the dispatch session's own transcript
(e.g. Claude Code's internal telemetry for a slow `grep` across ~97
files) got faithfully extracted but re-narrated under the wrong label,
since "render" was contextually dominant in that dispatch's actual
subject matter.

**Why:** the summarizer is compressing/digesting a long transcript in
chunks (see [[topic-dynamic-context-prep-vs-model-size]] and prior
`coding.context-size` tuning notes) — it has real content to draw on,
but chunk boundaries and its own limited capacity make it prone to
correct-content/wrong-label errors rather than either pure fabrication
or pure fidelity.

**How to apply:**
- don't dismiss round-buffer content as fabricated just because a
  specific claim doesn't match reality — the underlying numbers/details
  are often real, just attached to the wrong narrative
- don't trust a specific causal claim from the buffer either, without
  checking — verify against ground truth (`git status`, file
  timestamps, grep for cited identifiers/figures, or resuming the
  actual dispatch session via the `claude -r <uuid>` line in its
  result) before acting on anything the round-buffer states as fact
- the real work product of the dispatch (files written) is independent
  of this summarization tail and can be verified/used immediately —
  no need to wait for or trust the round-buffer's narrative either way

## sharper case, 2026-07-27 : possible stuck self-referential reprocessing

separately, on the same date, caught the pipeline actively generating
fresh rounds (`/var/protocol-7/coding/results/<task-id>`, growing input
byte count round to round) describing content that matched the exact
wording of a `kimi_dispatch` prompt (`crop_wide.v1`'s test-harness
instructions — "black 512x512 with rectangle outlines," "row lit
fraction," "boundary verification," "synthetic image") from a dispatch
that had already completed successfully **over two hours earlier** —
confirmed via `~/.kimi/sessions/` (no session newer than the completed
one) and the real deliverable already existing, tested, and committed.
no live kimi process, no session activity, yet the coding zenka's log
(`/var/log/protocol-7/<host>.coding.zenka.log`) showed fresh inference
rounds still dispatching against it, ~30s apart, each with a *larger*
input than the last (172105 → 178034 bytes in one step). user's
hypothesis (plausible, not fully proven — the actual per-round prompt
tmp file, logged as `tmp-file-path` in that log, gets deleted
immediately after use, so the exact mechanism couldn't be directly
inspected): each round's prompt may include the *previous round's own
generated summary* concatenated back in as if it were fresh transcript
content, letting the model latch onto and elaborate on its own prior
claims (e.g. "this is a repetitive loop") rather than tracking real new
material — which would explain both the growing byte count with no
live source and the narrative escalating in confidence/specificity
each round without any new grounding evidence.

**how to apply, additionally:**
- if a round-buffer's subject matter doesn't match anything currently
  active (compare wording/vocabulary against your actual recent
  dispatch prompts, not just current session state), and the
  underlying dispatch already completed and was independently
  verified, the round-buffer may be stuck reprocessing stale content —
  don't let it cast doubt on an already-verified deliverable
- `/var/protocol-7/coding/results/<task-id>` (recent files, by mtime)
  and `/var/log/protocol-7/<host>.coding.zenka.log` (grep for
  `inference complete for <task-id>` to see input byte-count trend)
  are the way to check whether input size is genuinely growing from
  live activity or just churning

#,,..,,.,,..,,,..,.,.,...,...,,,.,..,,.,.,.,.,..,,...,...,,..,,,,,,,,,.,.,,..,
#YNHII4CJB47H7PYTDXHOALSR4UKPU36WADBKGPDDXCP62FI2BVTXTWEJFGT3JLOT63RZVPCY4NDSC
#\\\|GWHBQOPF5W4U4ZEVAWOCDUQA5HQP2CNNSHY24RXMCEBZ4S6F4NA \ / AMOS7 \ YOURUM ::
#\[7]BXCL57FXGCBPVPPAZQ4A5ZOGV3S65OVSSJ5CFYJK65CLVDVTTYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
