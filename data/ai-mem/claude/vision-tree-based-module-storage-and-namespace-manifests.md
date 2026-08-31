---
name: vision-tree-based-module-storage-and-namespace-manifests
description: "stalled design thread: per-namespace-prefix module manifests (e.g. a src/base.file manifest for src/base.file.*) as a step toward optionally supporting tree-based module storage (src/base/file/init_code) alongside today's flat dot-notation (src/base.file.init_code), with a sourcecode-zenka command to flatten/expand between layouts and the flat form always taking load priority for simple override; base.list.subroutines retirement was postponed on this, not because it's dead code"
metadata:
  node_type: memory
  type: project
  originSessionId: fee6b203-065d-46ee-9e22-bac7aa31efd1
---

2026-08-31, surfaced correcting my own mischaracterization of
`src/base.list.subroutines` as dead/unmaintained code (see
[[project-deps-tracking-var-relocation]] for the correction — it's
actively updated by `src/sourcecode.console.update-sub-list`, meant as a
security integrity safeguard against a correctly-signed-but-removed-from-
src subroutine silently still loading, though nothing currently consumes
the manifest to actually perform that check).

## why retiring it was postponed

User was mid-thought on a bigger redesign when this got shelved, still
unresolved:

**The immediate idea**: a manifest file per namespace prefix — e.g.
`src/base.file` (as a manifest) alongside `src/base.file.*` (the actual
subroutine files in that namespace), or `src/coding` for `src/coding.*`.

**Open problems that stalled it**, per user directly:
- would need its own automatic maintenance — same staleness-risk class
  as everything else in this session's dependency-tracking cleanup
  ([[project-deps-tracking-var-relocation]])
- unsure whether it "introduces an obsolete dependency" — i.e. whether
  this just becomes another thing that goes stale and unused, same as
  the current file's fate
- would need to serve more than one genuinely useful function to be
  worth the maintenance cost, not just the one narrow security-check use
  case `base.list.subroutines` was originally meant for
- **collides with a bigger, related idea**: tree-based module storage.

## the bigger idea underneath

User originally wanted to support **multiple physical storage layouts**
for the same logical module namespace, not just today's flat dot-notation:

- flat (current): `src/base.file.init_code`
- nested tree: `src/base/file/init_code`
- partial: `src/base/file.init_code`

A per-namespace manifest file literally named `src/base/file` would
collide with wanting `src/base/file/` to also be a real directory under
the tree-layout variant — the manifest-file idea and the tree-storage
idea fight over the same path.

**Planned mechanism**: a `sourcecode` zenka command that can flatten or
expand between these layouts on demand. The fully-qualified flat form
(`src/base.file.init_code`) would always work and take **loading
priority** regardless of which layout is in use — this is deliberately
the override mechanism: drop a flat-named file to override whatever a
tree-organized version resolves to, without needing to touch the tree
itself.

## existing precedent, but for a different concern

`src/sourcecode.console.regen-checksum-symlinks` /
`src/sourcecode.console.undo-checksum-symlinks` already implement a
similarly-shaped structural transformation (registers source checksums
into a version-addressed path, `<sourcecode.path>.version_root`,
symlink-based) — same "generate an alternate structural view, with an
undo path" shape the tree-storage flatten/expand command would need.
**Not directly reusable as-is** though — per user, the checksum-symlink
mechanism itself is separately planned to be "integrated more natively
with the checksum base [generic] file storage" (a different, larger
thread than this one — the BMW-for-all-files checksum system mentioned
in [[project-deps-tracking-var-relocation]]). Read that mechanism for
the transformation *shape*, not as something to extend directly for
tree-storage.

**What specifically broke, per user's own explanation**: the mechanism
stored full per-version snapshots, not diffs — "it was not diff based
storage yet either" — so every version update produced a large,
redundant diff in git ("obsolete redundancy" that "would have needed
severe refinement" to eliminate). That's *why* it only ever had
"temporary [experimental] usefulness," not a fundamental flaw in the
underlying idea. The actual goal behind it: let parallel versions of
source exist simultaneously, with the ability to select specific
routines from a given version and reverse/undo the operation
(explaining the regen/undo command pairing) — a checksum-keyed way to
reach historical/alternate versions without full git-history traversal.

**Even though it didn't work as implemented, it usefully defines the
real requirement** for the eventual checksum-based file storage system:
keep the clean current state as the primary stored form, and represent
historical versions as **diffs backward from that current state**
(reverse-delta storage) rather than full redundant snapshots per
version — this is what avoids the large-diff/git-redundancy problem.
The tradeoff, also per user: this adds real parsing complexity, but only
for the history-access path specifically — the common case (just using
the current clean version) stays simple, and the complexity cost is
isolated to the feature that actually needs it, not paid unconditionally.

**Follow-up refinement, same session, real advantage over git's model**:
because each backward step is its own independently addressable diff
(not an interdependent forward-chained DAG the way git commits are),
retention depth becomes a **choice**, not all-or-nothing — keep the
last N steps and simply delete older ones, no history-rewriting surgery
needed the way truncating git history requires (filter-branch, shallow
clone, squashing). And at the limit, **when the current state is already
the clean canonical one, the entire diff-history mechanism can be safely
deleted outright** — direct parallel to deleting `.git/`: the working
files stay completely intact, only the ability to look backward is
lost. This configurability (choose how much history, or none) is a real
design win over git specifically, not just a workaround for the
git-diff-bloat problem the symlink experiment hit.

**How this applies to tree-storage flatten/expand**: don't copy the
full-snapshot-per-version shape directly — if the eventual tree-storage
mechanism needs to preserve history/reversibility the way regen/undo
did, it should follow the diff-backward-from-clean-current-state
requirement this experiment surfaced, not repeat the git-diff-bloat
mistake.

## status

Pure stalled/postponed design, nothing decided. `base.list.subroutines`
should NOT be retired or "fixed" in isolation — its fate is tied up in
this unresolved manifest-vs-tree-storage question, not a simple cleanup.
Don't start designing the flatten/expand mechanism or the tree-storage
layout unprompted; this was explicitly still being thought through, not
handed over as a task.

#,,..,.,,,.,.,,,,,.,,,,,,,,.,,,,.,,..,,..,,.,,..,,...,..,,..,,.,.,..,,.,,,.,,,
#M533VOWA3JLWRRIKF4Q6XBNCQHKDPTKB7J66YZDEW3QYWD4UV2X7WSFHC3XJAMZUOKWSUYSXI2ZXY
#\\\|AV5AGZEXKPLPN7KH3J7RDFDNGIFFR7GUPTQDZJP664UPYFDNK4E \ / AMOS7 \ YOURUM ::
#\[7]RY4ZUUGJRKQYGZZM6BMGDNR3MW5GLDB6LENBAEZNBVQMSFKV36AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
