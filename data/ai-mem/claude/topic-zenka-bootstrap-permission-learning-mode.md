---
name: topic-zenka-bootstrap-permission-learning-mode
description: "design idea (2026-07-29, not yet implemented): simplify new-zenka permission bootstrapping by enabling devmod + a wildcard cube grant during initial creation, then auto-discovering the real command list from what actually got called before committing the narrow grant and removing devmod/wildcard; generalizes to a cube 'learning mode' that watches inter-zenka command attempts and offers one-shot enable+commit, gated by a destructive-command blacklist"
metadata:
  type: project
---

Motivated by today's repeated pattern across build-zenka, ext-pkg-zenka,
openvas-agent, forensics-agent, nessus-agent: each new zenka needed at
least one follow-up round-trip to add the right `access.cmd.usr.cube`
grant line(s) after boot-testing revealed a missing permission (`no
perm.` errors), sometimes more than one round-trip as more commands got
exercised. See [[feedback-new-zenka-boot-checklist]] (data/ai-mem/kimi/)
for the concrete forensics-agent instance of this.

**Proposed simplification for new-zenka creation:**
1. During initial scaffolding, enable devmod for the new zenka AND grant
   cube a wildcard (`*`) permission, rather than trying to enumerate the
   exact command list up front.
2. Boot-test normally — with the wildcard in place, every command the
   dispatch/developer actually exercises just works, no permission
   round-trips.
3. Once the zenka starts with no errors and all the desired commands
   have been exercised at least once, list the *actual* commands that
   got called (from devmod's own tracing, or cube's own dispatch log)
   and write that concrete list as the real `access.cmd.usr.cube` grant.
4. Remove the wildcard and disable devmod as the last action before
   committing — the zenka ships with a narrow, real, exercised
   permission set, not a blanket grant, and the round-trip cost is paid
   once during scaffolding instead of scattered across the whole build.

**Generalization — a cube "learning mode":** rather than being scoped
to new-zenka creation only, cube could support a learning mode toggled
per-zenka (or globally during a dev session): while active, cube logs
every inter-zenka command attempt (granted or denied) for the zenka(s)
in scope. A single command then reviews the observed attempt list and
either auto-enables and commits them all, or presents them for one-shot
approval — replacing today's one-error-at-a-time permission whack-a-mole
with a single batch grant derived from real observed usage.

**Safety requirement, explicit from the user**: learning-mode
auto-enable must be gated by a **destructive-command blacklist** —
things like `host-poweroff` or equivalent must never be silently
auto-granted just because a dispatch happened to attempt them, even in
learning mode. The blacklist needs to be maintained independently of
whatever gets observed, not derived from observation.

**Not yet implemented** — this is still just the design conversation.
Open questions before it becomes a task file:
- where does the observed-attempt log live (per-zenka buffer? a new
  cube-side structure?) and how long does it persist across restarts
- exact mechanism for "list all desirable commands" — does devmod
  already have tracing granular enough for this, or does something new
  need to be built
- how the blacklist itself is authored/maintained and whether it's
  cube-global or has per-zenka overrides
- interaction with existing `access.cmd.usr.*` conventions (`.cmd.` vs
  `.console.` file-naming, per [[feedback-cmd-call-injection-not-caught-by-perl-c]])
  — the auto-derived grant needs to respect the same rules a human
  author already has to follow

#,,.,,,..,,..,..,,,.,,,,,,...,...,..,,.,.,,..,..,,...,.,.,...,.,,,...,..,,,,.,
#OTJHED3SDWFRKTOVQQWEUG3GKV3BVRNECOPOVIFRSQ3SCVLVWBBWW5SZLV7SCA6776GNA43OW42ME
#\\\|GSOQ7AUPE7GJ4ITJN3XYSO7KQGP4BXNJ2MXR3B4FZDPXFJ7IL3I \ / AMOS7 \ YOURUM ::
#\[7]RGJGLKU33UMAV5RM74CA465RC3255EZGZFV4EUMA55RKJL67TWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
