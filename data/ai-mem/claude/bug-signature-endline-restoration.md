---
name: bug-signature-endline-restoration
description: RESOLVED — signature footer concatenation was harmonize state-0/7 early-return, not the restore clamp; state-7 (0-trailing-newline) files oscillated on every other sign
metadata:
  node_type: memory
  type: project
  originSessionId: 59836803-64cb-4781-9e11-bdd727d581dc
---

## RESOLVED 2026-06-03

The footer-concatenation bug (`last content line.#,,..` with no separator) was a
single root cause, **not** the large state×nl-count matrix earlier hypothesised.

**Symptom**: a file whose on-disk body has **zero trailing newlines** (encoded
endline state 7) oscillates — sign 1 valid (state 7), sign 2 INVALID (footer
concatenated, state 5), sign 3 valid, … A *single* sign looks correct, which is
why it was first mis-diagnosed as "not reproducible". **Always test re-signing
across ≥2 passes** to see signature oscillation.

**Root cause**: `source.harmonize_payload_line_feed` early-returned for endline
states 0 and 7 ("already at modification limit"), skipping its idempotent
canonical-form loop. On a state-7 re-sign, `extract_sig_body` strips the footer
and `restore_payload_endline_state` correctly returns the payload to 0 trailing
newlines — then `harmonize(7)` no-ops, so the `\n\n` separator is never re-added,
and `get-code-signed:181` appends the footer onto the last content byte.

**Fix**: removed the `== 0 or == 7` early-return (and dead `$mod_offset`) in
`harmonize_payload_line_feed`. Signing only ever emits states 5/6/7, so the
change is effectively state-7-only; repo had 0 state-7 files, so no existing
file changed behaviour.

**Wrong leads (do not re-chase)**:
- the `restore_payload_endline_state` clamp (lines 40-47) was already present and
  working; it does NOT reach the generic-error log.
- the `:E: unspecified error in footer structure` log comes from the
  markers-misclassification path in `extract_sig_body` (content literally
  containing SIGNATURE/AMOS7/YOURUM) — cosmetic, unrelated to concatenation.
- `extract_sig_body:703` `$seperator_endline_absent` skip-branch is unreachable
  in strict signing (early return at :652).

**Regression net**: `bin/dev/tests/timing/test-endline-state7-oscillation`
(self-contained; 0-trailing fixtures both path roots; proven to exit 1 when the
fix is reverted). Needed because `verify-p7-signatures` over the repo can't catch
a revert — no state-7 files exist to trip it.

**Tools**: `sourcecode report-endline-state <pattern> -v` lists encoded states
(find at-risk state-7 files). `update-signatures` needs the passphrase; the
`test-*` family (`test-sign-and-verify` etc.) signs with a temp key — correct for
unattended reproduction.

**Record**: `data/tasks/completed/signature-endline-bug-FINDINGS.md` (full
writeup) + `signature-endline-bug-sanity-checks.md` (original task, banner-marked).

#,,,.,.,.,..,,.,,,.,.,.,.,,,,,..,,..,,,..,,..,..,,...,...,.,.,,,,,,,,,...,.,,,
#BZJFUJC6DDVEHXED3IYHULHS6DPXOWSJG6HXMJSZXFAVR7I3FD5PHJPP7YLFNW64SCKL6LCMWJ2LY
#\\\|UEZWVCJPMZXT7YV52CEVKF5LF5GXQG5X2ZSXSOCKS3XL6MMJMEK \ / AMOS7 \ YOURUM ::
#\[7]VUSTQ27I5CEXU44I44Y37MLRJQL3N6KNA4EYN7QC2LAFLPCNRWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
