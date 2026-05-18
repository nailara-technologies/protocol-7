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

**Fix direction**: restoration should verify actual trailing newlines match
what the encoded state expects before applying. If they don't match → treat
as state 5 (no-op) or re-derive from current content, ignore stored delta.

**Not the fix**: adding normalization rules per-path (e.g. modules/) would
mask the bug rather than fix it.

**After fix**: add normalization config to the existing path set-up for
signing so modules/ always converges cleanly as a belt-and-suspenders layer.

**Reproduction**: edit a module file inserting a line before the last code
line → run update-signatures → inspect result for missing newline before `#,,`

**Related task files**:
- data/yaml/coding-tasks/signature-endline-state-verification.yaml (completed but verifications pending)
- data/yaml/docs/processing/signature-endline-handling.yaml
- data/yaml/code-reviews/modules/source.signature-endline-policy-system.yaml

#,,..,,,,,.,,,...,,.,,,,,,,,.,..,,,,,,.,,,,.,,..,,...,..,,,.,,,.,,,.,,,.,,.,,,
#IS23KNTBUGOM4VQ2BTTX4SCR3HQOGX4NXORNGMCVJRD6AVDTRRUSJ5VTNGA4OOKSXKBRGVQVQDG2Y
#\\\|HV5PX2SO6K3BXHOY2VYZ4LVSYGWYCTIJAFZX3ILM7NODWYNP7JZ \ / AMOS7 \ YOURUM ::
#\[7]EE5R6FHCJ5DTR5POU6LC2ITMZ2SBDVGGDKEFXLXAZCCD2LO2JMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
