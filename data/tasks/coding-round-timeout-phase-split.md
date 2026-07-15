## task: split round-elapsed tracking into HTTP-wait vs tool-execution phases

### context

session 2026-07-15/16 built `coding.cmd.round-time` / `coding.cmd.round-progress`
to show, per active coding-zenka task, how long the current round has been
running against `coding.http-timeouts.request-completed` (777s). the goal
was an early-warning signal for stuck inference before the next 777s
timeout log line, and it worked well enough to catch several genuinely
wedged tasks (stale `single-llm` backend lock left held by an aborted
task — see `coding.async.backend_release` call sites, fixed separately).

### the actual bug: what `round_started` currently measures

`round_started` is stamped once, in `coding.async.request`, right before
the HTTP request for the current round is dispatched (see the comment
there: "fires on every actual dispatch attempt, first try and every
timeout retry alike"). it is only cleared in `coding.async.state_machine`'s
`tools_done` transition (`delete $state->{'round_started'}`), which fires
*after* the model's response is fully received **and** all of that
round's tool calls have finished executing.

so the elapsed time shown is:

```
http-wait time (governed by the 777s ceiling)
  + tool-execution time (search_code, read_file, ncode_search, ... —
    completely unbounded, no timeout at all)
```

...compared directly against 777s, which is *only* the HTTP layer's own
timeout (`coding.async.http_client`'s `$default_http_timeout`). a round
that made 6 tool calls each doing a few seconds of disk I/O can easily
push "elapsed" past 777s with the HTTP request itself having completed in
under a minute — the display then flags it `!!` as if stuck, when it's
just doing legitimate work. as the user put it: **it might never stop
counting**, because there's currently no ceiling at all on the
tool-execution phase, and the display doesn't distinguish which phase
it's actually in.

### what to build

split into two measurements instead of one:

1. **http-wait phase**: start the clock at the same dispatch point as now
   (`coding.async.request`, right after `backend_acquire` succeeds).
   **stop/clear it as soon as the response is fully received** — i.e.
   whatever handler currently marks `http_state.completed = TRUE` on a
   successful full response (not on error — check both paths, since
   `http_state.completed` was observed set to TRUE even on the 0-bytes
   orphaned-connection wedge case, so "completed" alone isn't a clean
   success signal; may need a distinct flag). *this* phase is the one
   that's fairly compared against the 777s ceiling.

2. **tool-execution phase**: separately track time since the http-wait
   phase ended (response complete) until `tools_done` fires. no timeout
   applies here by design, but it's worth surfacing anyway — a round
   spending 10 minutes in tool calls might indicate something looping
   (e.g. `search_code` retrying a bad regex) even though it's not an
   HTTP-layer problem.

`coding.cmd.round-time` / `coding.cmd.round-progress` should show both,
distinctly labeled, e.g.:

```
task-XXXXX | R:03 | http: 45s/777s [6%] | tools: 812s (no ceiling) [!! long]
```

rather than the current single misleading combined number.

### what already exists [ don't rebuild ]

- `coding.async.request` — dispatch-time stamp, correct insertion point
  for phase 1's start
- `coding.async.state_machine`'s `tools_done` transition — correct point
  to end phase 2 (and phase 1 should already be long over by then)
- `coding.cmd.round-time`, `coding.cmd.round-progress` — display logic,
  needs the two-phase rework but the nailara-bar rendering pattern is
  fine to reuse
- `coding.state.backend.<name>.lock` — correct source for "who's actually
  generating right now" (round-progress was fixed this session to read
  this instead of `<coding.task.active>[0]`, which is unrelated array
  position, not the lock holder)

### status [ 2026-07-15 ]

design-only, nothing implemented for the phase split. the single-number
version is live and useful for catching hard-stuck tasks (backend lock
held by nothing), but produces false `!!` alarms for rounds doing
legitimate long tool-call sequences. treat any `!!` from the current
version as "investigate," not "definitely stuck" — check
`coding.tree-read "coding.async.task_state.<task_id>.http_state"` for
`completed`/`bytes_received` to tell a real HTTP-layer hang from normal
tool execution before aborting.

#,,..,,,,,,,,,,..,,.,,..,,...,,,,,...,.,.,,,.,..,,...,...,..,,,,.,,,,,...,.,,,
#RIWFLJLG73NV3AYZLN4DJRKDWUURZRZ4QN7EDWE5ZYTK7KQ6UCTD2MRPVT637RDMLCAN3G4FPYAUC
#\\\|P7ESDZLOKG3QIJVVNQEGLD6VRFAAAAD3QSWXVFAACAPHH5SU7RR \ / AMOS7 \ YOURUM ::
#\[7]LF5UAE7OCQV6NYLACGME2XNSGDQ4FZOGRQT7NXZT6UIRGSZEJ2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
