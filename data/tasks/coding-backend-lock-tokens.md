# coding zenka : token-based backend lock

brief for a separate session [ 2026-09-24 ]. item 1 of the "FOLLOW-UP IDEAS,
2026-09-24" section in `HANDOVER.md`. read `CLAUDE.md` first [ module syntax,
style ] and `data/ai-mem/claude/project-coding-async-backend-acquire-reentrancy-race.md`
[ history : what was tried, what broke, why ].

## the problem

`<coding.state.backend>->{$backend}` holds `{ lock => $task_id, queue => [..] }`.
the lock's identity is ONLY a task_id, but one task makes many sequential
requests [ rounds ], and old connections of the same task keep streaming /
closing after the next round was sent [ deliberate : see the comment in
`src/coding.async.request` about not cancelling mid-stream ]. so "is this
caller the holder" can't be answered by task_id. four fixes on 2026-09-24
were all this bug class :

- `e8bb6b5b7` stale error / timeout callbacks acting on the newer round ;
  patched with `lock_seq` [ stamped in async.request ] + optional `$req_seq`
  arg to `backend_release`
- `484ea4bb9` lock handed to a queued task that had already finished
- `1f6d5aadd` paused task kept the lock
- the REVERTED `d3c07acee` : tried to make reentrancy smarter via
  `task_state` existence -- broke every multi-round task. do not repeat : read
  the memory file's correction first

## the goal

`backend_acquire` returns a token [ the request seq, or a fresh counter ] ;
`backend_release` only frees the lock for the matching token. callers that
must release unconditionally [ user stop / cancel / sweeps ] pass an explicit
`force`. the reentrancy shortcut becomes "caller presents the current token"
instead of "same task_id". this replaces the `lock_seq` patch rather than
adding to it.

## callers to enumerate [ as of 492325d76 ]

for EACH : what does it rely on the lock FOR, does it have a token in hand,
should it be token-checked or `force`. [ lesson from
`feedback-security-fix-verify-both-code-paths-not-just-symptom` : a gating
check can be load-bearing elsewhere -- enumerate all callers before changing ]

- `coding.async.request` :62 acquire, :153 release [ immediate error ], lock_seq stamp
- `coding.task.enqueue_round` :23 acquire [ round continuation ; reentrancy ]
- `coding.async.send_request` :112 release [ pause ]
- `coding.async.complete` :71 release
- `coding.async.chunk_handler` :262 release [ backend switch ]
- `coding.async.round_soft_restart` :21
- `coding.callback.http_complete` :76 :179 :267 :308 :315
- `coding.callback.http_error` :40 :122 :129
- `coding.handler.spawn_smart` :166
- `coding.tools.handler.subtask_spawn` :190
- `coding.self_test.async_probe` :72, `coding.self_test.handler.poll_probe` :119
- `coding.model_sweep.handler.poll_sweep` :98 :233 :534 :593, `coding.model_sweep.cmd.model-sweep-cancel` :71
- `coding.model_batch.handler.poll_batch` :42 :102 :420 :898, `coding.model_batch.cmd.model-batch-cancel` :42
- `coding.async.backend_release` itself : the handoff to the next queued task
  [ that task gets a new token when its request stamps / acquires ]

line numbers drift -- `grep -rn 'backend_acquire\]\|backend_release\]' src/`.

## constraints

- syntax check only with `bin/format-code -c <files>`, then reflow with
  `bin/format-code <files>`
- reload with `p7c coding.reload source`
- a structured `lock <backend>: from -> to [reason]` log line may already
  exist by the time you start [ follow-up item 3, in progress separately ] --
  keep it working, it's the fastest way to verify
- don't commit without the user's signed version [ they sign + stage ]

## required live verification

1. multi-round tool task [ 3+ rounds ] completes, no queueing behind itself
2. long task A + short task B : B queues, runs after A, lock ends free
3. stop B while queued : lock ends free, next task C starts immediately
4. pause A at a round boundary : unrelated B runs immediately ; resume A
   finishes
5. a soft-ceiling timeout restart [ or simulate a stale callback ] does not
   free the newer round's lock

#,,.,,,..,,.,,,.,,.,,,.,,,..,,,,.,,,.,,,.,,,,,..,,...,...,.,.,,,,,,,,,.,.,..,,
#ONMHRGIO36JUB7KAL6PFPW37CTSNIT6MZASWUBMDQE7ZTSCSMW62HVI3MXAVIJI247UDUVIAKTDIE
#\\\|ZGUEP4WDDRDG7DZXG22F6L63GQPLIJFUL2U2VD2XCB2FZTX76WP \ / AMOS7 \ YOURUM ::
#\[7]ZLOWPVAKOE2IH2KVW3P2EXPPHNOTQRUM4CUIQXHKA4FSSJQVIGDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
