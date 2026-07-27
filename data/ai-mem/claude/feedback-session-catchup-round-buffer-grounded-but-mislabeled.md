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

#,,,.,...,,,.,,,,,.,,,...,.,,,..,,,,,,,..,.,.,..,,...,...,,,,,,,.,,..,..,,,..,
#OKBYPBLMR57OL5UP2DTHTE22ADB2XMPD4A6OZDWJZ5CAMWKI2ATJPSOOI7LQCB2E7MZO5DLACGV2E
#\\\|YCIAE7PJE4TDH4JNRDFKNJQOB725H4A7HV7RMLY74UAR2PJ66WC \ / AMOS7 \ YOURUM ::
#\[7]BN4Q6H3RFPKJRBDMBNG2EFHUT4W5HJM46JJSCBJZXWDDK3CMMQDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
