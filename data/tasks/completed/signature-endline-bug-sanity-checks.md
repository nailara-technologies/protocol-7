# task: signature endline bug — sanity checks after strict state recovery

## RESOLVED 2026-06-03 — see signature-endline-bug-FINDINGS.md

the bug was a single root cause , not the large state-space this task
hypothesised. `source.harmonize_payload_line_feed` early-returned for endline
states 0 / 7 , so re-signing a zero-trailing-newline file ( state 7 ) left the
payload without its `\n\n` separator and concatenated the footer onto the last
content line — oscillating valid / invalid on every other sign. fix : removed
the state 0/7 early-return ( canonical-form loop is idempotent ). regression
net : `bin/dev/tests/timing/test-endline-state7-oscillation`.

NOTE : the diagnostic-channel analysis below ( the `restore_payload_endline_state`
clamp → `encountered-error` propagation ) was a wrong lead — that clamp does not
reach the generic-error log ; the generic log comes from the markers
misclassification path , which is cosmetic and unrelated to the concatenation.
the `extract_sig_body:703` suspect was also a red herring ( unreachable in
strict signing ). retained below for the record.

## status

still empirically reproducible after the may-23 strict-recovery fix
( commit 4aa5536ed `fix: stale endline recovery ...` ).  symptom : after
editing a file's last content line and re-signing, the footer's `#,,...`
first line concatenates onto the last content line with no newline
separator [ producing `... last code line.#,,..` ].

example caught in transcript on 2026-06-03 — a memory file written by
this agent and then signed showed exactly the concatenation pattern.

**concrete repro captured 2026-06-03** : `data/ai-mem/claude/session-61.md`
held this exact form for an unknown duration ( pre-commit check was the
first to catch it after an unrelated edit ) :

```
... STATE_TOOL_EXEC early-return path.#,,..,,..,.,,,...,...
#LUCZRKQIALFR3PPWHICRFGJQF7LYX4REDWEWGCNKINJBZVVF6NQ6OKFM3H4LBATBCVLC4HLLINLEK
#\\\|P4DGBXYSNPIRU2TJYWQU4XFEWB5W4JRZE6IZD7QL243O76SK3M6 \ / AMOS7 \ YOURUM ::
```

last content char `.` directly adjacent to footer first char `#` with
no separator endline. pre-commit error :
`data signature footer not valid [ no separator endline ]`.
the file is under `data/ai-mem/` , not in
`<source.cfg.normalize_endline_paths>` , so strict recovery did not run.

manual fix applied : single `\n` inserted at the byte boundary , file
re-signed by user. keep this file as a fixture for the eventual
regression test — `git log --diff-filter=A data/ai-mem/claude/session-61.md`
locates the original write commit ; that commit's parent state plus the
edit that introduced the concatenation reproduces the bug end-to-end.

## context — what we already have

read these first, do not re-derive:

- `data/yaml/coding-tasks/signature-endline-state-verification.yaml`
  ( completed task — documents state encoding 5 / 6 / 7 and states 0-4,
  test files modules/test.0/1/2/empty, restore semantics )
- `data/ai-mem/claude/bug-signature-endline-restoration.md`
  ( bug memory — root cause framing : stale encoded delta from prior
  signature applied without sanity check vs current trailing newline
  count )
- `data/yaml/docs/processing/signature-endline-handling.yaml`
  ( normalize-then-encode-delta architecture spec )
- `data/yaml/code-reviews/modules/source.signature-endline-policy-system.yaml`
  ( policy review )
- `data/asc/dev/reminders/signature_oscillation_after_create-code.asc`
  ( failure modes catalogue )

git history pointers :

- `4aa5536ed` — strict recovery for `normalize_endline_paths` ( default
  `['modules']` ) ; clamps delta to actual count ; recovery moves metadata
  to state=5 when trailing newlines ≤ 1
- `2bf1b3d46` — state 7 / 6 encoding fix for 0-newline and empty bodies
- `7a80e8ad5` — original deterministic harmonization

## the complication

strict state recovery added in `4aa5536ed` only triggers for paths
listed in `<source.cfg.normalize_endline_paths>` ( default `['modules']` ).
files outside that set — `data/`, `data/ai-mem/`, `data/tasks/`,
`bin/dev/`, memory dir under `~/.claude/projects/...` if signed — fall
back to the un-recovered path, where the delta-clamp in
`source.restore_payload_endline_state` is the only defense.

the delta-clamp prevents underflow but does *not* fix the
`stale-state -> wrong-restore` direction in every case.

### existing guard located 2026-06-03

`source.restore_payload_endline_state` lines 40-47 already does the
exact sanity check we hypothesized :

```perl
my ($actual_trailing) = $payload_sref->$* =~ /(\n+)$/;
my $actual_count = defined $actual_trailing ? length($actual_trailing) : 0;
if ( $actual_count < $delta ) {
    <[base.s_warn]>->(
        ': endline state mismatch : encoded delta=%d but only'
            . ' %d trailing newlines found <{C1}>',
        $delta, $actual_count
    );
    $delta = $actual_count;    ## clamp to actual ##
}
```

observed live on 2026-06-03 during `bin/Protocol-7 sourcecode
update-signatures` on this very task file ( encoded delta=2 , only 1
trailing newline after edit ) — clamp fired , file then logged
`:E: unspecified error in footer structure` at
`source.cmd.get-code-signed:74` ( falls through to `not
$found_footer_valid` branch ) , then re-signed successfully from a
fresh payload.

### diagnostic-channel disconnect

the warn fires into stderr via `<[base.s_warn]>` , but the structured
error field that the rest of the pipeline reads —
`$footer_data->{'encountered-error'}` — is never set by
`restore_payload_endline_state`. so the downstream log at
`source.cmd.get-code-signed:74` :

```perl
$footer_error // 'unspecified error in footer structure'
```

falls back to the generic string because `$footer_error` is undef.
the specific message ( "endline state mismatch : encoded delta=N but
only M trailing newlines found" ) was emitted to stderr earlier in the
session , then thrown away from the structured channel — making the
log line near useless for triage and impossible to grep / aggregate
across signing runs.

**fix , small but real** :

- `source.restore_payload_endline_state` currently returns only the
  length delta. extend it to either :
  ( i ) take a `$footer_data` hashref by reference and set
  `$footer_data->{'encountered-error'}` directly on mismatch , or
  ( ii ) return a two-element list `( $length_delta, $error_string )`
  and let the caller in `source.extract_sig_body` set the field.

  prefer ( i ) — keeps callers simple , matches the "footer_data
  carries all diagnostic state" convention already used by
  `extract_sig_body` ( see the `amos7_header_error` and
  `invalid_characters` flags it sets nearby ).

- once the field is populated , the existing `:E: %s` log at
  `get-code-signed:74` will surface the specific message
  automatically — no caller-side change needed.

acceptance for this sub-fix : re-run the same scenario , expect log
line `:E: endline state mismatch : encoded delta=2 but only 1 trailing
newlines found` instead of the generic fallback.

**implication** : trigger B's clamp is working for files that already
have a valid prior footer. session-61.md must have hit trigger A
( no valid footer , or footer that did not even parse ) , or some
third path that bypasses extraction entirely. the task narrows
substantially :

- trigger B with intact prior footer : clamp works , confirmed live.
- remaining gaps : ( i ) trigger A — first-ever sign with no trailing
  `\n` ; ( ii ) paths that skip `extract_sig_body` entirely ; ( iii )
  the `$seperator_endline_absent` branch at `extract_sig_body:703`
  which deliberately *skips* restoration — is that branch the actual
  bypass that produced session-61's state ?

## two distinct trigger paths

the same end-symptom ( footer concatenated to last content line with no
separator ) has at least two independent root causes. they need to be
analyzed and guarded separately :

### trigger A — first sign of unterminated content

1. file is created / written with content that does **not** end in `\n`
   ( agent forgets the trailing newline ; YAML / JSON serializer omits
   it ; binary tail ; etc. )
2. file has no existing footer at all
3. signer runs : reads payload , computes hash , appends footer string
4. the path that constructs `signature-footer-str` should detect
   `original_trailing == 0` and emit state=7 with two leading `\n` , but
   in practice the footer is appended directly to the unterminated last
   line.

questions to answer :
- does `create_harmonic_footer` actually prepend the right number of
  leading newlines for state 7 , or does it assume payload already ends
  in `\n` and only emit the footer body ?
- is there a code path where `create_harmonic_footer`'s output is
  appended to payload bytes *without* the normalize-to-1-then-encode-
  delta step from `get-code-signed` lines 161-195 ?  ( smtpd / chksum-
  on-write tools / standalone sign helpers / `bin/Protocol-7 sourcecode
  update-signatures` — does every entry point go through the same
  normalize block , or do some bypass it ? )

### trigger B — re-sign drops the re-add step

1. file was previously signed correctly , ending in
   `content\n#footer-line-1\n...`
2. signing pipeline strips footer using the encoded delta : removes the
   `\n` that the previous sign added ( so payload tail returns to the
   pre-sign state — e.g. `content` with 0 trailing newlines for state=6 ,
   or `content\n` for state=5 )
3. signer recomputes hash on the bare payload — correct so far
4. when constructing the new footer string , the normalization step that
   should re-add the `\n` separator is skipped / overwritten by a
   downstream concat — the new footer is appended directly to the
   stripped tail , producing the concatenation.

questions to answer :
- where exactly does the re-add happen in `get-code-signed` ? is it the
  `$src_str =~ s/\n*$/\n/s;` line ( line ~169 ) , or is that only the
  pre-encode normalize ?
- is there a state where `restore_payload_endline_state` strips , then
  hash is computed , then footer is built , but the s///n*$/\n/ never
  fires a second time before concat ?
- does `create_harmonic_footer` always emit a leading `\n` regardless of
  the encoded delta , or does it rely on the caller to have already
  normalized ?

## logical question that spans both

at restoration time , is the recorded state ever trusted for *anything*
normative , or only as a hint that must be verified against the actual
payload tail before any byte is added or removed ?

## what to investigate

0. **separate the two trigger paths above** before debugging — build a
   minimal reproducer for *each* :
   - trigger A : empty new file + write content without trailing `\n` +
     sign — observe whether the footer concatenates or sits on its own
     line
   - trigger B : take a correctly-signed file , edit ( e.g. via the
     same write flow that produced session-61.md's corruption ) ,
     re-sign — observe whether the strip+re-add sequence preserves the
     separator

1. trace the exact path that produced the concatenation in the captured
   example. determine which trigger ( A or B ) it matches by inspecting
   the originating commit of session-61.md's content + signature.

2. read `source.restore_payload_endline_state` end-to-end against the
   four real states ( 5 / 6 / 7 / 0-4 ) crossed with the four possible
   actual-trailing-nl counts ( 0 / 1 / 2 / 3+ ) — 16 cells. mark which
   cells the current code handles correctly, which it clamps but
   produces wrong output, and which it would still corrupt.

3. inspect `source.cmd.get-code-signed` around the `normalize` /
   `recovery` branches ( commit 4aa5536ed lines ) — is recovery the
   *only* normalizer , or does some path skip both normalize and
   recovery ?  ( hypothesis : non-`normalize_endline_paths` files
   take a third branch that trusts the stale delta . )

4. propose : either
   ( a ) make recovery universal — drop the path-list restriction and
   always re-derive state from actual payload bytes before signing , or
   ( b ) add a hard sanity check before footer append : compute the
   trailing-nl count of `$src_str` , compute expected count from the
   target state , error out / log if they disagree , or
   ( c ) treat the stored state as advisory only and always re-derive
   delta from the *current* payload at restore + sign time .

5. write a test that exercises the captured failure mode under multiple
   path roots ( `modules/` , `data/tasks/` , `data/ai-mem/` ) so any
   future regression is caught regardless of normalize-paths config.

## sanity checks to add ( minimum )

- before footer append : assert trailing-nl count matches what the
  encoded state says it should be ; on mismatch , log full state +
  payload tail bytes and refuse to sign instead of producing corrupt
  output.
- before restore : if encoded state implies removing N newlines but
  fewer than N exist , do *not* silently clamp — log the discrepancy
  loud enough that the next agent ( or you ) sees it.
- on any signing of a file outside `normalize_endline_paths` : log at
  level 2 which branch was taken , so transcripts make the divergence
  visible.

## why this is opus-suitable

the bug is small in surface area but the state space ( encoded state ×
actual nl count × path-policy branch × edit-history ) is large and the
existing code already has several layers of defense that *almost* work.
opus-level reasoning is needed to map the full 16-cell matrix , identify
which guard is missing , and choose between universal recovery vs hard
assertion without re-introducing the original oscillation bug.

## test harnesses ( use these to verify both triggers + fixes )

these already exist , use them as the verification loop — do not write
new ad-hoc shell scripts unless a real gap appears :

- `bin/dev/tests/timing/test-oscillation-simple <file-pattern>`
  two consecutive sign+verify cycles , captures logs to
  `.test-oscillation-simple-output/` — catches trigger B ( re-sign
  diverging from first sign ) directly.
- `bin/dev/tests/timing/test-oscillation-sequence <file-pattern>`
  full sign-with-temp-key -> verify -> re-sign -> verify -> idempotency
  check , captures logs to `.test-oscillation-output/` — covers
  triggers A and B end-to-end.
- `bin/dev/tests/timing/test-stale-endline-recovery` ( from `4aa5536ed` )
  five-step matrix : baseline -> inject extra newlines -> stale delta ->
  recovery -> idempotency ; the regression net for the existing recovery
  path.

reproducer recipe per trigger :

- **trigger A** : `printf 'content without trailing newline' > modules/test.0` ,
  then `bin/dev/tests/timing/test-oscillation-simple modules/test.0` — expect
  pass after fix , currently fails with concatenation in step 1.
- **trigger B** : start from `modules/test.1` ( one trailing `\n` ) , sign
  once via `test-oscillation-simple modules/test.1` to confirm baseline ,
  then edit to drop the trailing newline ( `truncate -s -1 modules/test.1` )
  and re-run the script — second sign should *not* concatenate.

fixtures :

- `data/asc/test-fixtures/signature-oscillation-2026-03-15/` — before /
  after-first-sign captures of three real files , reusable as inputs.
- `data/ai-mem/claude/session-61.md` ( pre-fix copy in git history ,
  see commit before the manual `\n` insertion on 2026-06-03 ).

## acceptance

- both triggers A and B reproduced cleanly via the existing
  `test-oscillation-simple` / `test-oscillation-sequence` scripts on
  fresh fixtures , logs captured
- 16-cell matrix documented with concrete pass / fail per cell against
  current code ( two passes : one inside `normalize_endline_paths` , one
  outside )
- failing cells either fixed or guarded by an explicit refuse-to-sign
  with diagnostic log line
- both reproducer recipes pass after fix , twice in a row ( idempotent )
- `test-stale-endline-recovery` still green ( no regression of the
  recovery path that already works )
- a clean re-sign of all currently corrupted files in the repo ( one
  pass , no further oscillation )

#,,..,,..,,,,,.,.,,,,,,.,,.,.,.,,,.,.,..,,,,,,..,,...,...,.,.,..,,,..,..,,,.,,
#STCVBOTGLOBCQLCEFKODMVXRU2756BSKCX27PP766CTJRA2KNQQEUCQ4O3QJSISPAIIVPUCUHYLJG
#\\\|E5OUBUHC7KVRBLKLSYJCCTDSVJ2ZUHXZ4B3BQZ33AQN2VS45JPH \ / AMOS7 \ YOURUM ::
#\[7]6RHMRZPE5BNYLWGKL3RJP476QRAZBPH43SUPT7MR77B77RMV2UCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
