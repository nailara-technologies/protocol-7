---
name: feedback-init-phase-idempotency-is-a-hard-invariant
description: protocol-7's per-zenka init_code is a firm, general-coverage guarantee to be safely re-runnable at ANY time, not best-effort — a reinit that breaks something is a bug in that init_code to fix at the root, never a reason to avoid reinit or paper over it
metadata:
  type: feedback
---

Stated directly by the user 2026-09-18: `init_code` receiving `$reinit` as its first parameter
(the real signal `base.init_modules` passes, not an inferred flag — see
[[feedback-init-code-runs-before-drop-privs]]) exists specifically so init code can install guards
that behave cleanly whether this is a fresh boot or a live re-init. This makes "the init phase is
trustable at any time" a **design invariant of this codebase**, not a hope — and it's meant to be
achievable with full coverage, not just for the common cases.

**Why this matters:** the practical consequence is about how to react when a reinit surfaces a
problem. If re-running an init_code path ever throws an exception, corrupts state, double-registers
something, or otherwise misbehaves, **that is a bug in that specific init_code to fix**, not a
signal to tell the user/agent "don't reinit this zenka" or to add a cautionary workaround instead of
a real `$reinit`-aware guard. The generic trust assumption is supposed to hold everywhere; a
counterexample is a gap in coverage to close, not an exception to document and route around.

**Direct precedent — a real reinit crash, fixed at the root, not avoided:**
[[feedback-v7-reload-init-live-swap-subs-crash]] — a bare `v7.reload init` crashed the whole v7
process via `base.swap_subs`'s destructive wipe firing on a stale/partial snapshot (an
un-whitelisted nested lifecycle hook resolving on a different pass than its whitelisted sibling).
The fix was in the shared loader/`swap_subs` code (stub-awareness + per-namespace generation
gating) — not a recommendation to avoid `reload init`. That memory's own "related" section
explicitly retracts an earlier note that had suggested avoiding bare `reload init` as unsafe.

**Confirmed working example, same day:** `coding.reload init` after a fix to
`coding.handler.inference_server_sigchld` (a `$code{...}`-bound SIGCHLD handler, not `sub{}`-
wrapped — see [[feedback-event-watcher-callback-reload-needs-restart]]) re-ran `coding`'s init
cleanly. Live inference-server state (`ready`/`ready` on both backends) and sweep state (`idle`)
survived intact across the reinit. The `[vision-parser] reinit : keeping existing state machine`
log line during that same reinit is a concrete, already-shipped example of a guard built for exactly
this: distinguishing first-init from a live reinit and preserving state deliberately rather than
starting cold.

**Why this is generally achievable, per the user, 2026-09-18** — the root architectural reason
init-phase idempotency is a realistic invariant here rather than an aspiration: this codebase's
design deliberately carries zenka state IN the shared `%data` hash, not distributed across
encapsulated objects. A re-init that merely re-runs code against `%data` can check what's already
there and skip/preserve it (exactly what the `[vision-parser] reinit : keeping existing state
machine` guard does). Contrast this with unsafe-by-design frameworks where state lives inside
object instances — reinitializing or reinstantiating those necessarily loses whatever state that
object held, because there is nowhere else for it to have been checked or preserved from. The
`%data`-centralized design is *why* the invariant can be pursued with full coverage instead of
being fundamentally impossible for some subsystems.

**How to apply:**
- When writing or touching an `init_code` module, always look at what it does with its first
  parameter. Anything that shouldn't be duplicated or reset on a live re-run — timers, signal/event
  watcher bindings, one-time resource allocation — needs an explicit `if ($reinit)` (or equivalent)
  branch, per [[feedback-init-code-runs-before-drop-privs]]'s existing guidance.
- Never assume a piece of init_code "only runs once at boot" as a reason to skip that guard — the
  system is designed for it to run again live, so treat that as a real code path to handle, not a
  hypothetical.
- If a reinit surfaces a real problem, root-cause and fix the specific init_code's idempotency gap
  first, the same way the swap_subs crash was handled. Only fall back to recommending a full zenka
  restart (per [[feedback-event-watcher-callback-reload-needs-restart]]) for the narrower, distinct
  case of a callback bound once before any init_code runs at all (outside the reinit-reachable
  path) — not as a substitute for fixing a genuinely broken reinit.

#,,,.,...,...,,,,,.,.,..,,,..,,..,.,,,.,.,,.,,.,.,...,...,.,,,..,,,.,,.,,,.,,,
#42VVFPPVFK6J6E43UTF46XP3TOTS4YUUM5FY2FTNTLR4B5AGYP5L3KRCBZQ2GY42OZIJMARUPEBZC
#\\\|PUU6TDEKN5SJNWE7JCRNE6GM7XYJE7U7E5OWEBBS3CKJJ3CGOUL \ / AMOS7 \ YOURUM ::
#\[7]AJGCWIQII674X6XEB353ED6RHNAL54JJOHKZGF75E2CIFDMCQYBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
