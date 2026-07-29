---
name: topic-afk-dispatch-signing-key-system
description: "design ideation (2026-07-29, not yet implemented): a session-key or staging-repo system to let AFK model dispatches commit signed/versioned work without --no-verify bypasses, with review cycles built in"
metadata:
  type: project
---

Source problem: [[feedback-afk-dispatch-signing-bypass]] — an AFK
`kimi_dispatch`/`claude_dispatch` session has no way to provide the
interactive AMOS7 signing passphrase, so when its task says "commit when
done," it uses `git commit --no-verify` to bypass the pre-commit hook's
signing + version gates entirely (confirmed 2026-07-29, commit
`27b5421ab`). Test key signing is already implemented in this repo — the
gap is a workflow that lets dispatched models commit serially without a
human resigning after every single one.

Two options discussed 2026-07-29, not yet decided between:

1. **session key + session branches** — user announces a temporary
   session key the commit hook accepts; the dispatch commits against it
   on a session branch, never touching `base` directly with a
   temp-keyed commit; a human later re-signs with the main key before
   merge into `base`. Resigning itself can be fairly automated, so that
   part isn't the blocker — the real problem is that **one branch per
   session doesn't compose with running several dispatches on different
   topics in parallel** (exactly the pattern this session used: three
   concurrent kimi dispatches on unrelated task files sharing one
   working tree). Session branches would force either one branch per
   concurrent dispatch (fine in isolation, but then merging/resigning N
   parallel branches back into `base` is its own coordination problem)
   or serializing dispatches that could otherwise run independently —
   either way it shrinks the practical range of "how many things can be
   in flight at once," which is the opposite of what made today's
   three-parallel-dispatch session work.

2. **staging-type repository** (favored) — dispatches push to a staging
   repo/remote; resigning with the main key happens there before
   integration into `base`. The staging repo can also be where review
   cycles attach (diff review, test runs, fix-up passes) BEFORE anything
   reaches `base` with real signatures — this decouples "model commits"
   from "human resigns" without the parallelism penalty above: multiple
   dispatched models on unrelated topics can each commit to staging
   independently, with `base` only ever receiving reviewed + properly
   signed history. This is the option to build toward.

Implementation angle floated for the staging repo itself: a **gitolite
zenka**, or a native protocol-7 equivalent, so staging-repo access
control doesn't depend on SSH-key-based management (gitolite's own
interface). A native zenka fits this project's existing pattern better
— access control as zenka `access.zenki`/cube-routing grants (same
mechanism already governing everything else) rather than a bolted-on
SSH-keys-in-a-file system foreign to how the rest of protocol-7 manages
identity/trust. Would need its own scoping pass (push/pull grants per
zenka or per dispatch, how it maps to the C25519 identity work in
[[project-zenka-cryptographic-identity-survey]]) before becoming a task
file — not scoped yet.

Bigger framing this points toward: the git zenka shouldn't be staging-
repo-only or single-host — it needs to run on remote servers too, so
GitHub stops being the primary remote and becomes just one mirror the
system syncs to itself. That would make self-hosted git serving (clone/
push/pull against protocol-7's own project domains) real again, not
just the staging step of the signing pipeline — same self-hosted-
everything direction as `letsencr` (TLS) and the vhost/transport zenki
already push toward, just extended to source hosting. Ties into
[[topic-network-as-computer]] more than it ties into the narrower
signing-bypass problem this doc started from — worth its own design doc
once scoped, rather than staying a subsection here, since "git hosting
zenka" is a bigger surface than "staging repo for AFK dispatch commits."

Open questions, not yet resolved:
- how staging-repo commits carry provenance (which dispatch/model/
  session produced them) through to the resigned `base` commit —
  squash? preserve authorship? some AMOS7-native marker?
- whether the review-cycle gate is human-only, or whether an Opus/K3
  review pass (see [[feedback-kimi-task-file-drafting-from-scan]]'s
  K3-drafts/Opus-reviews pattern) could sit in the staging pipeline
  itself before human resign, catching things like the unsigned-file
  debt or scope drift automatically.
- what happens to a staging commit that fails review — does it get
  amended in place on staging (mutable history there) or does the fix
  land as a new staging commit that then squashes on promotion to
  `base`?

Related: [[project-zenka-cryptographic-identity-survey]] (broader C25519/
identity architecture context), [[topic-write-access-security-
infrastructure]] (the other open write-access security design track —
check whether these should eventually merge into one doc or stay
separate concerns).

#,,.,,,,,,,..,.,,,,.,,,..,,..,,,,,.,,,.,.,.,,,..,,...,...,.,.,.,.,.,.,.,,,.,,,

#,,,,,,,.,.,.,...,.,,,,,,,,..,,..,,..,..,,,..,..,,...,...,.,,,,,,,,,.,,..,.,.,
#TXXILIDQKTEAY5O3WKCMA5DQSRQE3E3LLQGQB24RAMSWBTICGVKBEPBAFH6B7B3SKNLK4CVDSKARG
#\\\|5G22OV2SKPAUJ4FPEYM73UIKJCEDTEHARQLHF3TXY6RMF45F4RU \ / AMOS7 \ YOURUM ::
#\[7]VGTSIYXVX3IRED53EBMBELULGBHIBIV4JTQU6XWSLGR32RJXPGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
