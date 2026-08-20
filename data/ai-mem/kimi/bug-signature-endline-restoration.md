---
name: bug-signature-endline-restoration
description: COMPLETED — two follow-up fixes to the state-7 oscillation bug (commit 26bad5e0e). update-signatures was silently skipping malformed files, and the extract_sig_body clamp warning was not integrated into error tracking.
metadata:
  node_type: memory
  type: project
  originSessionId: 59836803-64cb-4781-9e11-bdd727d581dc
---

## COMPLETED 2026-06-03

This extends the Claude memory `data/ai-mem/claude/bug-signature-endline-restoration.md`
which documents the original root cause (`harmonize_payload_line_feed` early-return for
states 0/7) and fix in commit `26bad5e0e`.

### Two additional fixes applied today

**Problem**: after the original fix, `verify-p7-signatures` still reported invalid files,
but `update-signatures` did not repair them. a warning
`endline state mismatch : encoded delta=2 but only 1 trailing newlines found` kept
appearing during signing runs.

**Cause**: two separate integration gaps allowed malformed state-7 files to survive:

1. **concatenated footer (0 newlines before footer)**
   - `extract_sig_body` sets `$seperator_endline_absent = 1`, skips restoration.
   - `signature_valid` in `update` mode does **not** fail on `needs_separator_endline`.
   - checksum matches (payload unchanged).
   - `get-code-signed` returns `$is_valid = TRUE` and `update-signatures` with
     `skip-valid => TRUE` **skips the file entirely**.
   - fix: `src/source.cmd.get-code-signed:86` — changed early-return gate from
     `if ($is_valid)` to `if ( $is_valid and not $footer_data->{'needs_separator_endline'} )`.

2. **short footer (1 newline before footer, encoded state 7)**
   - `extract_sig_body` captures the single `\n` as separator, appends one back,
     leaving payload with only 1 trailing newline.
   - `restore_payload_endline_state(state=7)` tries to remove 2, clamps to 1,
     emits warning, continues with `structure-was-valid = TRUE`.
   - verify/update both treat the file as valid because no structured error is set.
   - fix: `src/source.extract_sig_body:710-721` — after calling
     `restore_payload_endline_state`, compare the actual length change against the
     expected change (`5 - state`). if they differ (clamping occurred), set
     `$footer_data->{'encountered-error'}` and return early with
     `structure-was-valid = FALSE`.

### Key insight: verify vs. update disagree on "valid"

| condition | `verify-p7-signatures` (strict) | `update-signatures` (update mode) |
|---|---|---|
| concatenated footer | fails (`needs_separator_endline`) | **passes** (falls through) |
| short footer + clamp | fails if checksum mismatches | **passes** (checksum often matches) |

this mismatch is why verify kept reporting re-sign files while update-signatures
silently did nothing.

### Test result

running `update-version ; us ;` on a clean repo triggered the warning exactly once
for `src/source.extract_sig_body` itself (a legacy malformed file). with both
fixes applied, the file was caught by the clamp guard, forced to re-sign, and all
subsequent runs are warning-free. `cfg/protocol-7.src-ver` (no footer) does
**not** trigger the warning — confirming the warning only originates from signed files
with a structural mismatch, never from unsigned files.

### Files changed

- `src/source.cmd.get-code-signed` — `skip-valid` gate now checks `needs_separator_endline`
- `src/source.extract_sig_body` — clamp detection returns structured error

### Related

- `data/ai-mem/claude/bug-signature-endline-restoration.md` — original root cause
- commit `26bad5e0e` — removed `harmonize_payload_line_feed` state 0/7 early-return
- `bin/dev/tests/timing/test-endline-state7-oscillation` — regression net for the original bug

#,,.,,,,.,..,,,,,,,,.,.,,,,.,,,,,,,,.,,..,.,,,.,.,...,...,.,.,,,,,.,,,..,,.,,,
#OCL5OSG26YMZW5H5KJGPSQ7CBBWAF2V6CWZHU2PLFQ2GTVUFJNCEAZHYTNZQWJVPQEVXB64L4I5R4
#\\\|OG5NJHAN6IMXL35AXD3LPO6CNRFCLZO5YDFKIQG2O5FHIYFMQ4C \ / AMOS7 \ YOURUM ::
#\[7]RP2RCRFHPGTEWKEUUMIYLK6XA6P2PIAZ5LQJNBXTZ23OKDF4LCBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
