---
name: bug-signature-endline-restoration
description: signing restoration uses stale encoded endline state after edit changes last content line — produces concatenated footer
metadata: 
  node_type: memory
  type: project
  originSessionId: 59836803-64cb-4781-9e11-bdd727d581dc
---

## Bug

When a file is edited such that the last content line changes (e.g. inserting a
line before `return TRUE;`), the re-signing restoration logic reads the endline
state encoded in the OLD signature and applies it as if the content still ends
the same way. The strip+restore cycle then adds or removes the wrong number of
newlines — producing `return TRUE;#,,...` with no separator.

**Why**: `source.restore_payload_endline_state` trusts the encoded delta from
the previous signature without checking whether the actual trailing newline
count matches what that delta implies. Valid assumption for a clean sign/verify
cycle, but breaks when an edit changes the endline state between sign cycles.

**Root cause**: no sanity check on the encoded state vs. actual current state
before applying the delta.

**Fix direction**: in `restore_payload_endline_state`, before removing N
trailing newlines (states 0-4, negative delta), count actual trailing newlines
in the content. If `actual < N` → encoded state is stale/corrupt → log warning
with discrepancy, clamp removal to actual count (don't underflow).

Zero trailing newlines after restore is valid for many file types (JSON, YAML,
generated files, binaries) — cannot assume it's wrong without file-type context.
File-path heuristics (e.g. modules/) would couple signing to content conventions
and avoid the real fix. The only safe invariant: cannot remove more newlines than
exist.

**After fix**: add normalization config to the existing path set-up for
signing so modules/ always converges cleanly as a belt-and-suspenders layer.

**Reproduction**: edit a module file inserting a line before the last code
line → run update-signatures → inspect result for missing newline before `#,,`

**Related task files**:
- data/tasks/signature-endline-bug-sanity-checks.md  ← active consolidating task (2026-06-03)
- data/yaml/coding-tasks/signature-endline-state-verification.yaml (completed but verifications pending)
- data/yaml/docs/processing/signature-endline-handling.yaml
- data/yaml/code-reviews/modules/source.signature-endline-policy-system.yaml

**Update 2026-06-03**: Strict state recovery WAS implemented in commit 4aa5536ed
(`fix: stale endline recovery + vc-changed-files -sig-only staged diff`) but only
applies to paths in `<source.cfg.normalize_endline_paths>` (default `['modules']`).
Files outside that set (data/, data/ai-mem/, data/tasks/) still hit the bug —
empirically reproduced on a memory file write 2026-06-03. See the active task
file above for the 16-cell state×actual-nl matrix to work through, and the
sanity-check options (universal recovery vs hard assertion). Opus-suitable.

#,,..,..,,,..,,.,,..,,,..,..,,,,.,,,.,,,.,.,.,..,,...,...,,,,,.,.,,.,,,,.,..,,
#3JHI53AXQUPW3AXXYCFGMAYTFSVRRCORXNPC3ZFE5FKBA4B4YA7X4W4CBZVTSS2QMAGUTESHL5C3G
#\\\|A6PH2CRDF4I7GNLOQGDVVA2C357XSBEU4WNMTVHFXSS7CNUEOZ7 \ / AMOS7 \ YOURUM ::
#\[7]A2TIUFEFVFO5YXELPN5EGUYZF5U4TZESBJXRGBPLE2NM3FIWJYAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
