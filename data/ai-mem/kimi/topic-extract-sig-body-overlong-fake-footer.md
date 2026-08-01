# source.extract_sig_body — over-long fake-footer bypass fix (2026-08-02)

Implemented `data/tasks/source-extract-sig-body-overlong-fake-footer-not-stripped.md`
in full, live-verified via the sourcecode console zenka. Uncommitted (human review).

## root cause

Every footer-recognizing regex in `modules/source.extract_sig_body` capped
comma/colon-line length (`{70,85}`, `{70,90}`, `{70,80}`, checksum `{60,100}`).
A hand-typed/hallucinated fake footer with 95+ char lines matched NO pattern —
including the generic real-signature extraction pattern, which reuses
`$footer_start_regex` as its start marker — so extract fell through to the
`extraction_failed_with_markers` branch and returned without stripping;
`sourcecode.console.strip-signature-footer` then logged
`invalid signature structure` and skipped the file.

## fix

- `modules/source.extract_sig_body`: all length ceilings replaced with
  open-ended minimums (`{70,}`, checksum `{60,}`) — left-anchored structural
  markers (`#` + long `.`/`,` run, `\\\|` / `\[7]` prefixes, AMOS7/YOURUM/
  DATA-SIGNATURE/PLACEHOLDER tokens) carry recognition confidence, not the
  character count. A larger fixed ceiling would just relocate the bypass.
  Applied consistently to: `$footer_start_regex` (used by strip + non-strip
  detection + template validation), all three PLACEHOLDER stub strips, the
  sequential-fake stub strip, all four repair-mode extraction patterns, and
  the separator-issue detection check.
- `modules/sourcecode.console.strip-signature-footer`: keeps a copy of the
  original content; when extract returns `was-present=0` but modified the
  buffer in-memory (stub-only file), the cleaned content is now written back
  instead of silently discarded. Pre-existing gap that affected ALL stub
  variants (PLACEHOLDER, AMOS7-perl, sequential-fake).

## verification (all live, via `bin/Protocol-7 sourcecode ...`)

- console zenka is standalone (`base.call.console_command`), NOT p7c-reachable;
  invoke as `bin/Protocol-7 sourcecode <cmd> <path>`. File args are resolved
  relative to the invocation cwd — absolute /tmp paths get mangled by
  `catfile`; use `../../../tmp/...` relative paths from the repo root.
- bug reproduced before fix: 95-char fake footer →
  `:E: invalid signature structure: signature footer present but could not be
  validated`, file byte-unchanged; `read-sig-footer-state` shows bmw/sig ERROR.
- before-fix on fake-in-front-of-REAL-footer file: strip removed the REAL
  footer and left the FAKE in the written file (worst-case symptom).
- after fix: sequential-only fake stripped from disk; non-sequential fake
  classified via `yourum-fake-signature` and stripped; fake+real file restored
  BYTE-IDENTICAL to the real module's pre-signature baseline.
- regression: real signed module stripped after fix byte-identical to the
  pre-fix strip baseline. 9-file batch (incl. audio.*, base.log, ncode.*):
  every diff removed only a genuine footer.
- false-positive scan: 7660 repo files have `^#[.,]{70,}` lines; 136 are not
  real footers, but only 22 sit at EOF-anchored `#`-only tails and ALL are
  len 79-84 — inside the OLD `{70,85}` ceiling, i.e. pre-existing exposure,
  zero NEW exposure from the open bound. Ordinary trailing comment blocks:
  untouched. Prose mentioning AMOS7/SIGNATURE: untouched on disk (conservative
  `extraction_failed_with_markers` error, pre-existing behavior).

## side notes

- before/after comparisons used `git stash push -- <files>` round-trips;
  the console zenka reads modules from disk fresh on every invocation, so
  stash = instant old-code toggle.
- `strip-signature-footer` writes restored content back to the given path —
  always run it against /tmp copies, never repo files.
- claude memory updated in place: `topic-fake-signature-footer-detection.md`
  and `project-2026-07-30-gap-audit.md` (both already dirty from elsewhere).
- `git stash`/`stash pop` touch only the pathspec'd files; ai-mem dirt from
  other sessions was left alone.

#,,..,,.,,,,.,,,,,.,.,,..,...,..,,,,.,.,,,,..,..,,...,...,,.,,,..,,.,,...,..,,
#OK6KF3MPET7LYCMLN3IMPW4BC27NT4EAIWJVBXNM5ROJK3CEYPPKMQ6O5GRVZBVXE7LPALI6UIWG4
#\\\|2FDNPHURBP6KPYBJNFJYVIAQWXJ4CY76O6K7XIYSRE3SYZHEHSF \ / AMOS7 \ YOURUM ::
#\[7]LLZHQVJKFNTGV5IGOGAC5VNOL35MQ32NXW622CCIUD2N3JKFIEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
