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

[[topic-ncode-access-gap]]
[[topic-ui-show-security-levels]]
[[topic-jobsite-ui-usability]]

#,,..,.,,,...,,,.,,.,,,..,.,,,,.,,.,.,,,,,..,,..,,...,...,...,...,.,,,.,,,,,.,
#FNESERA2PMC2VGZCJBXU56FQAZPNE5Y6WYCZRYHV5UXI7QZAGSJINENGZHDLL4TSRLFZFUGFWXNV4
#\\\|34D7GU54SMTOUEUNS6XOAL6FLDB2BKE6IAIOUVNCPG5X4MNTF25 \ / AMOS7 \ YOURUM ::
#\[7]GO6ZNU64XMH36E7TNAHFC2RTPLPP3AWJMSYPPIC7JN4NR6GL4WDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
