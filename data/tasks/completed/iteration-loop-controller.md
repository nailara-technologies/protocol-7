# task: implement iteration.loop — loop controller for self-improving tasks

## signatures note
do NOT add `#,,.,,,...` stub. leave files clean.

## data key syntax reminder
`<iteration.state>->{$id}` not `$data{'iteration.state'}{$id}`.
`<[module.name]>->($arg)` to call a module with args.
write the module to disk — do not return code in the response.

## objective
create `modules/iteration.loop` — the controller that runs a task
through multiple attempts, scores each result, applies template deltas,
and advances the best result when done.

## read first (understand these before writing)
- `modules/iteration.score_result` — takes {result, criteria, attempt_n},
  returns {score, passed, total, verdict, issues, attempt_n}
- `modules/valued.tree.record_outcome` — takes {node_id, outcome}
- `modules/task.cmd.complete` — shows how task completion works
- `data/yaml/context-templates/iteration-loop.yaml` — the template this
  controller drives; shows config fields and on_complete hooks

## storage
use `<iteration.state>` as the live state hashref, keyed by task_id:
  <iteration.state>->{$task_id} = {
    attempt_n    => N,
    max_attempts => N,
    best_score   => 0.0,
    best_result  => '',
    attempts     => [],   ## [ {attempt_n, result, score, verdict, issues} ]
    deltas       => [],   ## accumulated template deltas
  }

initialize `<iteration.state> //= {}` in iteration.init_code (create
that module too — 3 lines, just initializes the hashref).

## what iteration.loop does

params (hashref via shift):
  task_id      — identifies which iteration state to update
  result       — the output from this attempt
  criteria     — arrayref of acceptance criteria strings
  node_id      — valued tree node id for outcome recording
  max_attempts — max retries [ default 5 ]

logic:
1. load or initialize state for task_id
2. call iteration.score_result with {result, criteria, attempt_n}
3. store attempt record in state.attempts
4. update best_score / best_result if this attempt scored higher
5. record outcome in valued tree:
   verdict=advance → 'completed', verdict=retry → no call yet,
   verdict=escalate → 'blocked'
6. decide action:
   - verdict=advance OR attempt_n >= max_attempts → call iteration.finish
   - verdict=retry → return { mode=>'retry', data=>$score_record }
     [ caller re-runs with template delta applied ]
   - verdict=escalate → return { mode=>'escalate', data=>$score_record }

create `modules/iteration.finish` too — takes task_id, returns
formatted summary of all attempts with best result highlighted:
  "iteration complete: N attempts, best score=X.XX (attempt M)\n
   unfixed issues: ..."

## style
- `$ARG` not `$_` in map/grep/foreach
- `<iteration.state>->{}` for dotted data keys
- `<[base.logs]>->( N, fmt, args )` for logging
- lowercase comments, `[ word ]` bracket annotations
- no use statements, no pragmas

## acceptance
- first call initializes state, scores, returns retry or advance
- second call updates state, compares score to best, decides again
- on max_attempts: iteration.finish called, best result surfaced
- valued tree updated on advance or escalate
- iteration.init_code exists and initializes <iteration.state>

#,,,,,.,,,,,,,.,.,...,,,,,,.,,..,,...,.,.,...,..,,...,...,,,,,...,,..,,,,,,,,,
#APEXDVNECZ5LGQOTJSQDWOREHBZARR6Y5XBFMFCO2TC7GVL4N7I7M5WFCU7QFPOAGMXFSFCLC25AY
#\\\|FHHJGGATK54BCARZF6X2I4THXAOVX3RTFKG6B3XKXSZI3PB7OLO \ / AMOS7 \ YOURUM ::
#\[7]DAEL5PCKPSCTMQGM544AIVZMCSHJSIWKLMVE23CDK36A4UC2TMAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
