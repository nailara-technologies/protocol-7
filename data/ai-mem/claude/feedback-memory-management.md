---
name: feedback-memory-management
description: "strategic memory update timing, tree-structured knowledge modules, context startup efficiency"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 56461443-76ee-4bbf-9976-ee5713dd7c8d
---

Update memory frequently — don't wait until forced by context pressure.

**Why:** The prompt cache has a 5-minute TTL. At high token counts, useful insights,
activity logs, and future plans can be lost before they're written. A memory update
at ~150K tokens costs little but preserves a lot. At ~200K+ the cost of loss grows
faster than the cost of writing.

**When to write memory proactively:**
- After any cluster of 3+ related completions (batch them into one update)
- After any non-obvious design decision that informs future work
- When a new pattern or constraint is discovered that would save time later
- When open items accumulate (keep topic-next-steps.md current)
- Before a long dispatch (claude_dispatch / kimi_dispatch) that might push context

**Memory as tree-structured knowledge modules:**
The goal is loadable knowledge modules — load only what's relevant to the current
task rather than the full MEMORY.md on every startup. Structure memory files so
each can stand alone: self-contained name, description, and body with enough context
to be useful without the others. Cross-link with [[name]] to related memories.

**Startup efficiency:** Keep MEMORY.md index lean (< 200 lines). Each entry's
one-line hook should be specific enough that the AI can decide whether to load
the full file. Generic descriptions waste startup context.

**Strategic maintenance:**
- Merge related feedback memories when they converge on the same rule
- Remove memories that are now obvious from the code (e.g., a pattern now visible
  in every module doesn't need a memory)
- Update stale project memories — they decay faster than user/feedback memories
- The session memory files (session-N.md) are breadcrumbs, not load-on-startup;
  keep them for forensics but don't over-index them

**How to apply:** At ~42K context remaining (per feedback-memory-sync-timing.md),
do a memory sync. But also do partial syncs mid-session when insights accumulate,
without waiting for the threshold.

**Why:** a context zenka will eventually do this automatically — until then, proactive
manual maintenance is the substitute.

#,,,.,...,,,,,.,.,,..,..,,..,,,,,,,..,,,,,.,,,..,,...,...,.,,,..,,,..,.,,,..,,
#FRTRYSE5UMR7YQXYOP664RMUHMIPPH7JBA3EGPZBOLK4HYLHRJEB2RPUI7IMDNMSR52TOFS35AK5C
#\\\|VTO7T6DJCDTWURTSZYQOFDIEQA6J7VFZADXMCNXEL7NRKK7OSS5 \ / AMOS7 \ YOURUM ::
#\[7]PFIWBIXEIJK3FXLKOALVBGEHCYWDZSBH7YWT7Q5F7RYGP24A56BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
