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

## implementation [ branch `coding-lock-tokens`, 2026-09-24 ]

status : implemented, syntax-checked [ `bin/format-code -c` ], reflowed,
offline-simulated. NOT yet live-verified -- the five checks above are the
local session's job, fixes go onto this branch before signing.

### the mechanism

- `<coding.state.backend>->{$b}` = `{ lock => $task_id, lock_token => N,
  token_counter => N, queue => [..] }`. `lock_seq` is gone [ as are the
  `[stamp]` log line and the stamp block in `coding.async.request` ].
- `backend_acquire( task, backend, [token] )` returns `{ acquired, queued,
  token }`. a fresh grant AND a re-entry both rotate to a new token
  [ `++token_counter` ], so an older connection's token goes stale the moment
  the next round acquires.
- re-entry = holder task_id AND the presented token == `lock_token`. without
  the token, the holder task itself is queued like any other task
  [ log : `[queue A : holder without token#-, ..]` ].
- `backend_release( task, backend, token | 'force' )` : holder check always ;
  token must match unless `force`. undef token = skip [ logged
  `stale token` ].
- **lock context** : `<coding.async.lock_ctx> = { task_id, backend, token }`,
  set with `local` around a holder's own synchronous call chain :
  - every callback closure in `coding.async.request` [ on_header / on_chunk /
    on_complete / on_error / on_abort / check_stop ] with that request's token
  - `coding.task.enqueue_round` around its send_request, with the token it
    was just granted
  - the `backend_release` handoff around the next task's send_request, with
    the handoff token
- `coding.async.lock_token( task, backend )` [ new module ] returns the ctx
  token when the ctx is this task + backend, else undef. `backend_acquire`
  uses it implicitly when no token is passed ; releases inside a call chain
  pass it explicitly.
- timers, commands and another task's callbacks run outside any matching ctx
  -> they are fresh callers, no special casing needed.
- leak guards : `enqueue_round` and the release handoff each release their
  just-granted token if send_request returned `success => FALSE` and the
  token is unchanged [ no request took the lock over : "no state",
  queue_paused ... ].
- structured log kept : `lock <backend>: <holder>#<token> -> <holder>#<token>
  [acquire | reenter | queue .. | release | release force | handoff, ..
  | skip release by X#T : not holder | stale token | drop X finished]`.

### caller enumeration

legend : **ctx** = token taken from the lock context of the running call
chain ; **own** = token the caller got from its own acquire ; **fresh** = no
token, acquires anew and may queue ; **force** = token check skipped [ holder
check stays ].

| caller | relies on the lock for | token in hand | now |
|---|---|---|---|
| `coding.async.request` acquire | serializing the actual HTTP request per backend | ctx when called in a continuation / handoff / enqueue_round chain, else none | ctx -> re-enter + rotate ; none -> fresh [ queues, returns `deferred` ] |
| `coding.async.request` immediate-error release | freeing the lock when http_client fails at once | own [ `$lock_token` ] | token-checked |
| `coding.async.request` stamp [ `lock_seq` ] | stale-callback protection | -- | **removed**, replaced by rotation on acquire |
| `coding.task.enqueue_round` acquire | gating the next round | ctx inside callbacks [ tools_done, loop-assertion, http_complete's finish_tool_calls ] ; none for task-append, `enqueue_round_timer`, `round_chain.resume_from_node`, complete's recovery / parent-resume, http_complete after its own release | ctx -> re-enter ; none -> **fresh, may queue** [ per decision, never force ] |
| `coding.async.send_request` pause release | not blocking unrelated tasks while paused | ctx [ enqueue_round / callback / handoff chain ] | token-checked via `lock_token` |
| `coding.async.send_request` queue_paused branch | -- [ NEW release ] : the 5s timer comes back as a fresh enqueue_round and would queue behind the task's own lock forever | ctx | token-checked via `lock_token` [ no-op if the caller holds nothing ] |
| `coding.async.complete` | freeing the lock when the task ends [ any reason : done, failed, stopped, aborted ] | none reliable [ callers range over callbacks, stop, abort-inference, fail_task ] | **force** |
| `coding.async.chunk_handler` backend-switch release | freeing the OLD backend when model selection moves the task | ctx [ runs in on_chunk ] | token-checked via `lock_token( task, old_backend )` ; the new backend is a fresh acquire [ ctx backend differs ] |
| `coding.async.chunk_handler` model-selection / tool-call-reminder send_request | next round on the same connection chain | ctx | re-enter via async.request |
| `coding.async.round_soft_restart` | freeing the lock before the retry timer re-dispatches | new 3rd param | token-checked with `$callbacks->{lock_token}` from `coding.handler.http_timeout` [ already stale-seq filtered ] ; **force** from `coding.cmd.restart-round` [ user command ] |
| `coding.callback.http_complete` [ 5 releases ] | freeing after the round ended / before its own re-enqueue | ctx [ on_complete closure ] | token-checked via `lock_token`. the trailing / early-return releases after a continuation are now no-ops by rotation [ this was the e8bb6b5b7 class ] |
| `coding.callback.http_error` [ 3 releases ] | freeing before retry timer / before failing | ctx [ on_error closure ; also reached from http_complete's no-data forward, same ctx ] | token-checked via `lock_token` |
| `coding.callback.retry_request` [ timer ] | -- no release ; its send_request acquires | none | fresh [ lock was released by http_error / soft restart before the timer was armed ] |
| `coding.tools.handler.subtask_spawn` | parent gives the backend to its child while waiting | ctx [ tool runs inside the parent's on_chunk / on_complete chain ] | token-checked via `lock_token( parent, backend )`. **risk** : a direct `coding.call-tool subtask_spawn` from a command has no ctx -> release skipped, child would queue behind the parent ; watch in live checks |
| `coding.handler.spawn_smart` | cancelling a self-test probe on switch-model | the probe's token is in its state, but this is a cancel | **force** |
| `coding.self_test.handler.poll_probe` acquire | probe mutual exclusion [ skipped under a sweep lock ] | own | keeps the token, passes it as `lock_token` to async_probe |
| `coding.self_test.async_probe` `$finish` release | freeing the probe lock on every terminal path | own [ param `lock_token` ] | token-checked ; undef under a sweep lock -> guarded no-op [ same as before ] |
| `coding.model_sweep.handler.poll_sweep` acquire + 3 releases | holding the backend for a whole candidate cycle | lock ids are unique per switch [ `sweep:<switch_id>` ] | acquire : own [ unused ] ; releases : **force** |
| `coding.model_sweep.cmd.model-sweep-cancel` | freeing a cancelled sweep's candidate lock | -- | **force** |
| `coding.model_batch.handler.poll_batch` acquire + 3 releases | same as sweep [ `batch:<switch_id>` ] | own [ unused ] | releases : **force** |
| `coding.model_batch.cmd.model-batch-cancel` | same | -- | **force** |
| `coding.async.backend_release` handoff | giving the lock to the next queued task | mints a fresh handoff token | sets ctx for the next task's send_request -> its async.request re-enters + rotates ; releases the handoff token itself if send_request bailed |
| state_machine `resume` [ from `coding.cmd.resume-task` ] | -- | none | fresh [ lock was released at pause ] |
| state_machine `user_responded` | -- | none | fresh. note : no emitter of `needs_user` exists in `src/`, the path looks dead |
| `coding.task.execute_round` | -- | -- | no callers in `src/`, dead |

### deliberately unchanged

- compaction : `send_request` returning `compacting` still holds the lock
  until http_complete's `subtask` branch releases it [ ctx token, same
  connection, so it matches ]. if compaction ever starts from a token-less
  enqueue_round [ nothing in flight ], nothing releases and the compaction
  subtask queues behind its parent -- the same as before this change, noted
  for the live checks.
- stale-seq filtering in http_complete / http_error / http_timeout stays : it
  guards state [ retries, failing the task ], the token only guards the lock.

### offline simulation [ not a substitute for the live checks ]

acquire / release / lock_token / enqueue_round loaded as closures with a
mocked send_request + in-flight connections. all pass : 3+ round task never
queues and stale trailing releases are skipped ; A + B queue and hand off,
lock ends free ; stopped queued B skipped, C starts ; paused A frees, B runs,
resume works ; old connection's late release does not free the newer
request's lock ; token-less same-task trigger queues and runs via handoff.
it found one real bug [ `qw| release force |` in scalar context ], fixed.

### what to watch in the live checks

- any `[queue X : holder without token#-]` line for a task that then never
  runs : a continuation path that lost its ctx [ -> self-deadlock ]. fix
  there, not by loosening acquire
- `skip release by X#T : stale token` directly followed by a stuck lock : a
  release site that should have been force or needs a token
- `lock ... [handoff, ..]` followed by `handoff to X not taken` : expected
  only for tasks finished / paused while queued

#,,,,,,..,.,,,..,,.,.,,,.,,,.,,.,,...,,.,,,.,,..,,...,...,...,.,,,,,.,.,.,.,.,
#WT5IWZ2JX54RLUWVE7HXQFVBHU2B2ZMDMWN2C3M372PK5OEQJPXDJXNPFWVJK4ZCTPR26VPZAJ4E4
#\\\|JKR5AZMPQGZV6JSLLC643N7NZYYVLI23GTVI2N33S7TD244EVH2 \ / AMOS7 \ YOURUM ::
#\[7]ZELSOMZJT5TOOWIUQIYVPCTCN2RWG5DZJ3WOPWQNU5M4IWCKWEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
