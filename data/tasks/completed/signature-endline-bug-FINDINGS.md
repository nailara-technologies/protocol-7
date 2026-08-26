# findings: signature endline concatenation bug — REPRODUCED + root cause 2026-06-03

## headline ( corrected )

the bug **is real and reproducible** as an **oscillation across successive
signings** of any file whose on-disk body has **zero trailing newlines**
( encoded endline state 7 ). it was missed on the first pass of this
investigation because a *single* sign looks correct — the corruption appears
on the *next* sign.

an earlier draft of this file wrongly concluded "not reproducible / self-heals".
that was based on single-sign tests. corrected below.

## reproduction ( `sourcecode test-sign-and-verify` , temp key , repeated )

fixture : `printf 'content with no trailing newline' > data/test-scratch/osc.md`
( outside `<source.normalize_endline_paths>` so it reaches state 7 ).

| pass | encoded state | verify | content→footer boundary |
| ---- | ------------- | ------ | ----------------------- |
| 1 | 7 | valid   | `...newline.\n\n#,,...`  ( separator present ) |
| 2 | 5 | INVALID | `...newline.#,,...`      ( **concatenated , no separator** ) |
| 3 | 7 | valid   | separator present again |

odd passes valid , even passes corrupt — classic oscillation.

control : a file ending in exactly **one** newline ( state 6 ) is stable and
valid across all three passes. only the zero-trailing-newline / state-7 case
oscillates.

## root cause

`source.harmonize_payload_line_feed` lines 24-26 :

```perl
## already at modification limit ? ##
if ( $cur_endline_state == 0 or $cur_endline_state == 7 ) {
    return $cur_endline_state;    ##  no change, keep previous state  ##
}
```

this early-return is a leftover that contradicts the module's own "Fix #3"
canonical-form logic ( lines 39-69 ) , which always normalizes the trailing
newlines to exactly `\n\n` and returns state 5. for states 0 and 7 the
early-return skips that normalization entirely.

the oscillation , step by step , for a state-7 file on re-sign :

1. `extract_sig_body` strips the footer ; restoration via
   `restore_payload_endline_state(state=7)` removes 2 trailing newlines ,
   leaving the payload with **0** trailing newlines ( its canonical pre-sign
   form , correct for checksumming ).
2. `create_harmonic_footer` reads `endline-state-encoded = 7` and calls
   `harmonize_payload_line_feed( $src_ref, 7 )`.
3. harmonize **early-returns** ( state 7 ) → payload keeps **0** trailing
   newlines. the canonical `\n\n` separator is never re-added.
4. `get-code-signed:181` does `$src_str .= signature-footer-str` → footer is
   appended directly onto the last content byte → **concatenation**.

on the *first* sign this does not happen because the first-sign path goes
through the `needs_separator_endline` state-6 branch
( `create_harmonic_footer:182` ) which appends `\n` and then harmonize(6)
( which is NOT early-returned ) completes the `\n\n`. only the *re-sign* of an
already-state-7 file feeds 7 into harmonize and hits the no-op.

## the user diagnosed this directly

" during or after stripping the encoded amount of endlines that leaves it
without final endline or in an undefined because untracked state " — exactly
right : the strip+restore returns the payload to 0 trailing newlines , and the
state-7 harmonize no-op fails to re-establish the separator before append.

## why earlier triggers A/B "passed"

- trigger A single sign = pass 1 = valid. the bug is pass 2+.
- the markers-misclassification path and the `extract_sig_body:703`
  skip-branch are still red herrings for the concatenation ( 703 is
  unreachable in strict signing — early return at 652 ). they are unrelated to
  this oscillation.

## fix applied + verified ( 2026-06-03 )

`source.harmonize_payload_line_feed` : removed the
`if ( $cur_endline_state == 0 or == 7 ) { return }` early-return ( and the
dead `$mod_offset` it computed ) so the canonical-form loop always runs.

verification ( all via `test-sign-and-verify` , temp key ) :

- `osc.md` ( 0-trailing , state 7 ) : was 7/5/7/5 oscillating → now
  7/7/7/7 , valid every pass , no concatenation.
- real-shape 0-trailing file with literal `#,,` / `#:::` blocks in body :
  stable state 7 , valid , no concatenation across 3 passes.
- control ( 1-trailing , state 6 ) : unchanged , stable valid.
- inside `src/` ( 0-trailing ) : stable state 6 via recovery.
- `bin/dev/tests/timing/test-stale-endline-recovery src/note.tag` :
  all steps OK , `endline state stable : state=6 → state=6` — recovery path
  not regressed. ( step 2 exercises the over-newline reduction relevant to
  the state-0 path ; passed. )

scope : repo currently has only state 5 / 6 files ( report-endline-state :
0 files at state 7 ) ; the fix changes only state 0 / 7 handling , so no
existing committed file changes behaviour. the fix removes the *latent*
oscillation for any future 0-trailing-newline file signed outside
`<source.normalize_endline_paths>`.

note : the encoder at `create_harmonic_footer:211-223` only ever emits states
5 / 6 / 7 from signing ; states 0-4 are never produced. so removing the `== 0`
half of the guard is a dead path — the change is effectively state-7-only.
the state-0 reduction logic ( over-newlined payload → `\n\n` ) is still
exercised by `test-stale-endline-recovery` step 2 and passes.

permanent regression test : `bin/dev/tests/timing/test-endline-state7-oscillation`
( self-contained ; creates 0-trailing fixtures under `src/` and
`data/test-scratch/` , signs each 3× , asserts valid + no concatenation , and
guards against vacuous pass if a fixture is not collected ). verified : exits 0
with the fix , exits 1 ( catches the outside-path concatenation on pass 2 ) when
the early-return is reverted. needed because the repo holds no state-7 files ,
so `verify-p7-signatures` alone cannot catch a revert of this fix.

acceptance reconciliation : the task asked for a formal 16-cell matrix and
"both triggers reproduced + fixed". the real defect was a single state-7
re-sign oscillation , not the 16-cell state×nl-count space the task
hypothesised ; the matrix is therefore moot as a formal artifact — the
mechanism section above documents the relevant cells ( states 5/6 stable ,
state 7 was the break ). the markers-path generic-error log is left as a
documented cosmetic item , not fixed.

NOTE : editing this module invalidated its own signature — re-sign with
`bin/Protocol-7 sourcecode update-signatures src/source.harmonize_payload_line_feed`
( needs passphrase ) before committing.

## candidate fix ( original analysis , superseded by "fix applied" above )

primary : remove ( or correct ) the `== 0 or == 7` early-return in
`harmonize_payload_line_feed` so the canonical-form logic always runs.
expected effect : state-7 re-sign → harmonize adds `\n\n` → footer separated →
stable. must re-verify against `bin/dev/tests/timing/test-stale-endline-recovery`
( the existing recovery regression net ) to ensure no re-introduction of the
original oscillation , and against the state-0 ( 4-removed ) case.

defensive ( belt-and-suspenders , independent of the above ) : assert in
`get-code-signed` immediately before the footer append that `$src_str` ends in
the separator the encoded state implies ; refuse to sign with a loud
diagnostic otherwise.

## tooling note

- `sourcecode report-endline-state <pattern>` reports the encoded endline
  state of existing footers — use to find at-risk ( state 7 ) committed files.
- `update-signatures` needs the signing passphrase ; the `test-*` command
  family ( `test-sign-and-verify` , `test-cycle` , `test-diagnose` ) signs with
  a temp key and is the correct unattended harness.

## scratch fixtures ( untracked , delete when done )

`data/test-scratch/osc.md` ( oscillating ) , `ctrl6.md` ( stable control ) ,
`realshape.md` , `test.markers` , `test.trigA` ; `src/test.trigA`.

#,,,.,,,.,,,,,,..,.,,,,,.,..,,,..,,,,,.,.,..,,..,,...,...,,.,,,,,,,.,,,..,,..,
#CSQUKMXAKGXL3XGF4HBYRFECWG4DMLMLTDF32XPIVGP3F2KKSCKNYF3RKA5DENEZC5BPHLIF5ROSI
#\\\|RJS5VZNB7G5VZ3MTTZDBQPB7FNJXGRIGFELBNX2ZKKLDU276RGC \ / AMOS7 \ YOURUM ::
#\[7]VK4VRZXMMYJ2O2SJYXO5YZMDJAPEHFFADB3CATXR2TM77PBHUYAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
