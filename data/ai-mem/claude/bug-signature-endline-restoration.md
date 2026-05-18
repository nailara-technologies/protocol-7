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
- data/yaml/coding-tasks/signature-endline-state-verification.yaml (completed but verifications pending)
- data/yaml/docs/processing/signature-endline-handling.yaml
- data/yaml/code-reviews/modules/source.signature-endline-policy-system.yaml

#,,,.,,,,,..,,.,.,,.,,...,,,.,...,..,,,,,,,,.,..,,...,...,...,.,.,.,.,,..,..,,
#5XHQILL5HUXWSA6A5PFG6EK2WV63BSESSX2K7KPF4EMOWKJLTBB2M2SWHRDRM44TD3LOMDC7W2THA
#\\\|WNZKQ2QRHNNZFE3D4SF7HFXZY5TECLWGWHLT3HN2LW2C2JUZOFV \ / AMOS7 \ YOURUM ::
#\[7]3EXFPIVQOSBJK4B6KYYA53IJPUPF4OG2RKWJ6ZOXRITQTRI6KIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
