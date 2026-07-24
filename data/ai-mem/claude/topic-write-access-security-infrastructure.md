---
name: topic-write-access-security-infrastructure
description: "cross-zenka signature/approval infrastructure for write/sign commands — directory profiles, PIN auth, protocol-7-menu approval UI, jobsite-style code-review UI"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**2026-07-17, design-only, not started.** Surfaced while trying to grant
`ncode` network command access (it locked itself down with
`system.access.wildcards.allow = false` but never got an
`access.cmd.usr.<caller>` grant for the actual human/mcp caller — see
[[topic-ncode-access-gap]]). User's response: don't just bolt on a broad
write grant — this needs real security infrastructure, and it's not
ncode-specific, it's needed for every zenka that can mutate state or the
filesystem.

## the vision, as described

**Directory/capability profiles.** `ncode` (and similar tools) need
whitelisted directory profiles distinguishing read-only zones from
write/sign zones. Concrete first step: the protocol-7 code repository
itself can be **read-only enabled immediately** — it's public, browsing/
searching/diffing it is zero-risk. Write/sign commands are the part that
needs the new infrastructure, so read and write should be split into
separate grants/profiles rather than gated by the same switch.

**Signature-gated write/sign commands.** Any write commit (code-signing
via `ncode.cmd.sign`, and analogous mutating commands in other zenki)
should require a cryptographic signature over the relevant parameters —
not just a bare command-name whitelist check. This generalizes past
ncode: the user wants this for "all other zenki too," which is why it's
being treated as a shared dependency/infrastructure project rather than
solved per-zenka.

**Approval/signature system, at least two flavors:**
- **zenka-inherited approval** — a zenka's signature authority can
  inherit from a task approval or "node authority" already granted
  upstream (intent propagation down a chain), so not every mutating
  action needs a fresh human touch if it's already covered by an
  approved task/intent.
- **interactive human approval** — needs actual UI, not just a config
  whitelist.

**protocol-7-menu expansion** is the proposed home for interactive
approval: it already has `protocol-7-menu.cmd.input-password` (a styled
GTK3 modal, character-masked, Escape-to-cancel — see the file for the
existing pattern) — a real precedent to extend, not a green-field UI.
Wanted additions:
- display pending approval requests
- sign/authorize from the menu
- hold an **authorized security level** per session/user, checked before
  allowing higher-risk actions — this also has a real precedent already:
  `ui.caller.security-level` + `cred-mesh.cmd.ui-show` /
  `cred-mesh.ui.interactive.refresh` already gate slot-list/slot-detail
  views behind caller security level 1/2. The write-approval system
  should reuse/extend this existing mechanism, not invent a parallel one.
  Related: [[topic-ui-show-security-levels]] ("border glyphs nest
  desktops; step 6 open") — check whether that work is the right base
  to build on before starting fresh.
- **PIN auth** as a fast alternative to password entry, specifically for
  cases where there will be *many* small approval requests (e.g. a batch
  of code-signing requests) and mouse-only/full-password input is too
  slow or too insecure for the volume.

**Diff visualization for what's being signed** — a later-phase want:
before approving a code-sign request, the user wants to actually see the
diff, styled. Proposed simplification: instead of full syntax
highlighting rendered in the approval UI itself, have **another zenka
generate an image** of the styled diff and display *that* — offloads the
rendering complexity from the approval-UI zenka entirely.

**Longer-term: a jobsite-style web UI for code-change review.** Modeled
directly on the existing jobsite UI ([[topic-jobsite-ui-usability]],
[[project-plugin-web-jobs]]) — same column/card layout, but cards are
code-change suggestions (from any zenka or any model) instead of job
postings. Approve/apply from the same UI. Explicitly wants the **same
security model** as everything above: a cryptographic signature for
approval, with security *inherited downstream* from that one signature
rather than re-checked at every step — the design goal stated directly:
"simplifying security to just signature validation without weakening it."

## how to apply

This is a multi-session infrastructure project, not a single task. Before
starting implementation on any piece:
1. Check whether [[topic-ui-show-security-levels]]'s existing
   `ui.caller.security-level` mechanism already covers what's needed for
   session-level authorization, or whether it needs extending.
2. Treat directory/capability profiles (read vs. write/sign) as the
   first buildable increment — it unblocks read-only ncode access
   immediately without touching the harder signature-approval problem.
2. Do NOT grant broad write/sign command access to any zenka as a
   stopgap "for now" — the user explicitly rejected that shortcut for
   ncode specifically because the real fix (signature-gated approval)
   generalizes across zenki and a per-zenka whitelist hack would need
   redoing later anyway.
3. When scoping actual implementation work, split into separate task
   files per dependency layer (profiles / signature-over-params /
   inheritance-from-task-approval / protocol-7-menu UI / PIN auth /
   diff-image generation / jobsite-style review UI) rather than one
   monolithic task — the user's own framing already separates these as
   "several types of command approval/signature systems."

## update 2026-07-24: first concrete piece landed, but not the approval system

[[project-ncode-write-path-2026-07-24]] landed a working transient-permission
mechanism (chmod-child `restore`/`create` grants, group-write-precedence bug
fixed) that lets `ncode.cmd.apply` actually write files — this is
*infrastructure* the eventual approval system will need, but it is **not**
the approval/signature layer itself. `suggest`/`apply` were opened on
`ncode`'s cube whitelist during that session with the user's live, explicit,
in-session authorization ("you can expand ncode as needed";
"signed and staged" on every change) — narrowly for testing this specific
mechanism, gated only by the `ptd -c` syntax check and checksum-addressed fix
IDs, not by anything resembling signature-gated approval.

## update 2026-07-24, same day: the approval-gate loop (phase 1, see
[[topic-ncode-pattern-learning-loop]]) exposed a *second* access gap, one
layer up from the ncode-internal one above

Landed `ncode.cmd.review`/`.graduate`/`.expand` and added them to `ncode`'s
own `access.cmd.usr.cube` start-file whitelist (same pattern as
`suggest`/`apply`/`assess`). But that whitelist only controls what `ncode`
itself will *accept* — reaching it at all still requires an entry in
`configuration/zenki/cube/access.zenki` for the calling zenka's
`access.cmd.usr.<caller>` block, and **no such entry exists for `ncode` as a
target, for any caller.** Confirmed directly: `access.zenki` has no
`access.cmd.usr.ncode`-style grant anywhere, and no other zenka's block
(`access.cmd.usr.coding`, `.kimi`, `.task`, etc.) lists any `ncode.*` target
either. The only thing that can reach `ncode.*` today is the wildcard in
`configuration/zenki/cube/access.users`:

```
access.cmd.usr.<admin-user>  =  ** ..*.**
access.cmd.usr.<unix-admin>  =  ** ..*.**
```

This is *why* the live smoke tests of `ncode.cmd.review`/`.graduate` worked
during phase-1 verification — they went out via `p7c`, which resolves to
`<unix-admin>` (see below), not because any real zenka-to-zenka grant exists.

**Two separate principal identities, not one "admin" bucket** — confirmed in
`configuration/system-user-map` (`system.admin-user = taeki`) and
`configuration/zenki/cube/auth.users`
(`auth.setup.usr.<admin-user> = :unix:<unix-admin>,:unix:<admin-user>,:auth-keypair:`
vs. `auth.setup.usr.<unix-admin> = :unix:<unix-admin>,:unix:<admin-user>`):
- **`taeki`** — nshell path, keypair/session auth (`nshell: whoami` → `taeki`)
- **`unix-taeki`** — p7c path, unix-socket peer-credential auth (`p7c whoami`
  → `unix-taeki`)

Both currently sit under the same blanket wildcard in `access.users`, but
they're structurally independent principals in the access-control model and
**can be given separate restrictions** — user confirmed this explicitly,
correcting an implicit "it's all just taeki" assumption. Relevant if/when
the write-access-security design above ever wants to scope nshell-driven
(interactive human) actions differently from p7c-driven (scriptable/agent,
including how Claude/Kimi CLI sessions actually authenticate today) actions.

**Open implication for the pattern-learning loop specifically:** phase 1's
`review`/`graduate` calls are only reachable today by whatever is running as
`taeki`/`unix-taeki` (a human, or an agent shelling out through `p7c` as
that user — which is how this session's own verification worked). If the
intent is ever for a zenka like `coding` to drive its own review loop
natively (in-process cube routing, not shelling out), it needs an explicit
`access.cmd.usr.coding = ... ncode.review ncode.expand ncode.graduate ...`
grant added to `access.zenki` — same shape as the existing
`access.cmd.usr.coding` grants for `task.claim`/`task.complete`. Not done;
folds into the same "don't bolt on a broad grant as a stopgap" caution
already recorded above — this needs the real access-control decision, not
a quick add.

**Direction of the grant matters, confirmed by user:** `access.cmd.usr.<X>`
governs what `<X>` may call *outward* as source, not what may call *into*
`<X>`. So "let `coding` call into `ncode`" means adding `ncode.*` targets to
`access.cmd.usr.coding` (as above) — but the reverse also exists as a real
option: an `access.cmd.usr.ncode` block would grant **`ncode` itself**
outbound permission to contact other zenki, e.g. push a notification to
`coding`/`task` when a pattern graduates, mirroring existing outbound
patterns like `v7.notify_online`/`cred-mesh.rotate` elsewhere in the same
file. Not built, but a real option for phase 2+ if the loop should ever
notify proactively instead of only being polled/driven externally.

This does **not** supersede the "do NOT grant broad write/sign access as a
stopgap" guidance above — that was a standing policy rejection of an
unattended shortcut, this was a supervised, narrow, explicitly re-authorized
opening for a specific piece of work. Whether it stays open going forward is
an open decision the user hasn't made yet; don't treat it as settled either
way without asking.

## update 2026-07-24, same day: `SIGNED-COMMAND-INTERFACE.md` is the concrete
mechanism for the "has-seen-preview" / "has-self-approved" approval type

Surfaced while discussing the ncode pattern-learning-loop's
`ncode.cmd.review` contract (see [[topic-ncode-pattern-learning-loop]]):
the user asked whether an important approval type would be
"has-seen-preview + has-[self-]approved-preview" — i.e. does the review
schema actually *prove* the approver looked at the real content, and does
it distinguish self-review (same actor proposed and approved) from
independent review. Answer: yes, and `data/md/design/
SIGNED-COMMAND-INTERFACE.md` (pre-existing design doc, already referenced
from this file's "signature-gated write/sign commands" section above but
not previously connected to a concrete use case) already specifies exactly
the mechanism needed:

- **Signed payload proves seen-preview.** That doc's signature footer
  covers `command-string + ntime + nonce` today; extending the signed
  payload to also include a **checksum of the actual preview content**
  (the fix's diff/line, or the candidate's pattern+replace) means a valid
  signature can only be produced by someone who actually had that content
  in hand — the signature itself is the proof, not a separate trusted
  claim.
- **`signed_by` + existing `source_task` gives self-vs-independent review
  for free.** `base.cmd.verify_signature` already resolves `signed_by`
  (key fingerprint → identity) for the handler. Phase 1 of the
  pattern-learning loop already stamps `source_task` on every candidate at
  creation (`ncode.regex.assess`). Self-approval detection is just
  comparing `signed_by` against the identity that owns `source_task` — no
  new field needed once review calls are signed.
- **Fits the existing security-tier model directly.** `ncode.cmd.review`/
  `.graduate`/`.widen-scope` (phase 2, not yet built) are exactly the
  "expands what auto-applies without further per-instance checking" class
  that doc's `security.cmd.require-signed` tier already targets (same
  bucket as `teardown`/key-operations), and
  `security.cmd.authorized_keys.<cmd>` gives the "which identities may
  approve this pattern family" access layer for free.
- **Different, complementary axis from the `access.zenki` gap above.**
  That gap is "can this zenka reach `ncode` at all" (zenka-routing).
  Signed-command authorization is "does this specific cryptographic
  identity's signature authorize this specific approval" — orthogonal, not
  overlapping; both would be needed together for a real deployment.

Not built. Natural next step if picked up: fold this into the phase-2 task
file (`data/tasks/ncode-pattern-scope-stack-phase2.md`) as an additional
part, since it changes `ncode.cmd.review`'s contract directly — currently
deferred there pending this decision.

[[topic-ncode-access-gap]]
[[topic-ui-show-security-levels]]
[[topic-jobsite-ui-usability]]
[[topic-ncode-pattern-learning-loop]]

#,,..,...,.,,,,,,,..,,..,,,,.,.,,,...,.,.,.,.,..,,...,...,..,,,,.,..,,.,,,,,,,
#WTCW7VWQFISJOQ65XSAOCZBLJQP3N4IYQ26DDKHQKILEJ53QVD2LUYLHCBAAFH2Y34CHCVYRAQFNE
#\\\|GBLG62OJRTODQH3BO5U2UNXVWC474L6W2CILWAIR6TUVW5LF4DS \ / AMOS7 \ YOURUM ::
#\[7]ZSBMUGVK2ONZOY3PUNI3BZ4G65AKIZIBOTVYQE4B3QOJMTDFW4AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
