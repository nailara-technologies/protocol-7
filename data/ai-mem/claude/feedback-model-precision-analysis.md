---
name: model precision on analysis tasks
description: Qwopus 9B v3 significantly more precise than sushi coder on code analysis; sushi coder hallucinates "async" for blocking calls
type: feedback
originSessionId: 66f44304-8c27-4c9c-927c-f41b97361621
---
Qwopus 9B v3 (ZDMAPAY:AR3OCKQ) correctly identified LWP::UserAgent in a while loop as CRITICAL
in round 1. Sushi coder (UU4JSVQ:MEHBONI) on the same module with the same template said
"no blocking occurs because the HTTP call is async at the OS level" — a false belief.

**Why:** LWP::UserAgent is synchronous blocking — it blocks the entire OS thread for the full
request duration. event.once() before the call does not help.

**How to apply:** For analysis tasks (event-loop audits, security reviews, architectural
investigations), prefer Qwopus until the evaluation system establishes a better-ranked model.
Sushi coder remains good for methodical coding tasks (file edits, module extraction) where
precise technical analysis is less critical.

Default model switched to Qwopus on 2026-05-09 based on this evidence.

## summarization comparison (2026-05-09, same file tested on all three)

- **Qwopus 9B v3**: clean 4-paragraph prose, no artifacts, preserves all specifics
- **Kimi VL A3B Thinking**: think-block leaked into output, AMOS signatures
  confused for cryptographic hashes, otherwise comparable quality — faster at 3B
- **Deepseek Opus distilled 9B** (EMQFUAA:VWI5WKQ): best on structured technical docs —
  adds headers, catches implementation status + research connection sections Qwopus
  misses, clean output with no artifacts

**How to apply:** For summarization tasks on structured technical documents, prefer
Deepseek Opus distilled. Kimi VL A3B needs think-block stripping before output is
usable. Qwopus remains the reliable all-rounder.

#,,,,,,,.,.,,,..,,.,,,.,.,...,..,,,,.,.,.,...,..,,...,...,.,.,.,.,.,,,,.,,,.,,
#L4PTXUFD2HX666BZJZHPG5M6UXLPHYEJ7IS7DYTZAMIWOLNVHWAUY7735X44MLJ6WWONQ6UXJ3Z4M
#\\\|5HTHFJOWUQI2CMKYQHMIHY6BTUKDDTYKUWSZZTAPTVRSXRSGIDU \ / AMOS7 \ YOURUM ::
#\[7]DI7YFVKDPUNL3CBAINTVRNJDMFWGSOPEQ5JOSIG5KHRPQXYVP4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
