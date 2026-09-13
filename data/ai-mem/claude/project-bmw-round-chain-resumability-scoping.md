---
name: project-bmw-round-chain-resumability-scoping
description: decision on how the coding-zenka round-rewind checksum chain handles BMW's lack of real cross-process state export -- accept re-feed-on-restart now, don't block on it
metadata:
  type: project
---

2026-09-14, during design of the round-rewind/redo primitive
([[project-coding-zenka-session-ui-plan]]'s phase 3) using BMW-L13 as a
git-commit-style parent-pointer checksum chain (each round's checksum =
`BMW(parent_checksum . round_content)`, not a single cumulative live
object).

**What was verified live, not assumed:**
- `Digest::BMW->clone()` genuinely deep-copies internal state -- confirmed
  by diverging two clones with different suffixes after a shared prefix
  and getting two independently-correct digests.
- Calling `->digest`/`->hexdigest` directly on a LIVE (non-cloned) BMW
  object finalizes/resets it per `Digest::base` convention -- confirmed:
  add() after a direct digest() call no longer matches correct
  accumulation. Any future code touching a live per-session BMW object
  MUST export via `->clone->digest`, never digest the live object itself.
- The actual `Digest::BMW` installed on this machine
  (`/usr/local/lib/x86_64-linux-gnu/perl/5.42.3/Digest/BMW.pm`, the one
  `base.chk-sum.bmw.*` loads) has NO `getstate`/`setstate` --
  `can('getstate')`/`can('setstate')` both return false. This directly
  contradicts `data/asc/what-AI-thinks/markdown-form/protocol7/research/
  bmw_algorithm_complete_analysis.md`'s "COMPLETE ✅ / production ready"
  claim that these were added via an XS patch -- that work, if it happened
  at all, never made it into this system's real Perl install. Flag that
  doc as unverified-against-reality if it resurfaces; same discipline as
  [[feedback-esoteric-research-verification-pipeline]].

**Decision: don't chase BMW state-export/cross-process resumability now.**
A live per-task BMW object is a pure in-process PERFORMANCE optimization
(avoids re-hashing from round 1 each time), not a correctness requirement
-- round content is already persisted in the task's `messages`, so on a
coding-zenka restart the chain can be rebuilt by re-feeding the full
buffer up to the current round through a fresh object. BMW is fast enough
that this is a non-issue at task-history scale.

**Why:** user's explicit call, drawing a direct comparison to
`AMOS7::CHKSUM::ELF::inline_elf` -- that gap eventually closed there too,
but noted as "easier" because ELF's rolling-accumulator hash has state
that IS its output (a single scalar), so resuming only ever needed a
start-checksum function parameter, never a real serialization API. BMW's
internal multi-word MD-style state is NOT exposed by its finalized
digest, which is the real reason true resumability there needs
`getstate`/`setstate` (still absent) rather than a simple start-value
param -- a structural difference, not a solvable-the-same-way gap.

**How to apply:** when building `coding.cmd.rewind-round` /
`base.chk-sum.bmw.L13-str`-based round chaining, don't add BMW
getstate/setstate plumbing as a prerequisite. Store each round's exported
(cloned-then-digested) checksum string as the persisted chain link; on
any state loss (process restart, missing live object), rebuild by
re-adding stored round content from the nearest known-good round forward.
Revisit real state export only if buffer-replay cost actually becomes a
measured problem, not preemptively.

[[project-coding-zenka-session-ui-plan]]
[[topic-addressing-trinity]]
[[project-checksum-addressing-implementation-survey]]

#,,.,,,..,.,,.,,,.,,,,.,.,,..,,,,,,,.,,,,,,,,,,..,..,,.,.,...,...,...,..,,,,.,

#,,..,,.,,,,,,...,,..,...,,.,,,,,,,,,,,.,,.,,,..,,...,...,...,..,,,,.,.,.,.,.,
#T5YAVK2JU7FWU62ZOEKBB25V4X52HDG7ZU254OF4PAQ5QV6VN7XUHI4RB3MWTJ5PLYS667KFTJABK
#\\\|BRZZWN5CFEBBGOB3T6UZ2HQ3W3KXIH4NSDMKA2XJCMQRWMT4SZ2 \ / AMOS7 \ YOURUM ::
#\[7]R3NRDZTXE6WU6EP6HYA2RZS6E6RXMLNPCTUR564XJBQW5YGJLICA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
