# Task: "abort inference" for the coding zenka

## Goal
Add two capabilities to the coding zenka:
1. an **abort-pattern registry** — reusable regexes, each addressed by its own AMOS
   checksum, that terminate a streaming inference the moment one matches the output.
2. a **race-safe `.cmd.` command** to abort the currently-running (or a specific)
   inference call.

You are extending existing infrastructure. Do NOT build a new streaming layer, a new
task-tracking mechanism, or a new persistence format. Match the house style of the files
you read.

## Read first (do not reinvent these)
- `modules/coding.handler.http_io` — reads socket bytes, splits lines, feeds each to
  parse_line; owns `$state` (`sock`, `io_watcher`, `callbacks`, `completed`) and calls
  `<[coding.async.http_cleanup]>->($state)` to tear the connection down. **This is where
  abort teardown must hook.**
- `modules/coding.handler.http_io_parse_line` — signature `($line, $state, $callbacks)`;
  processes one streamed line and accumulates model output. **This is where per-line
  pattern matching must hook.**
- `modules/coding.async.http_client` — builds `$state` and threads `callbacks` in. **You
  must confirm here where the running task_id is available** so it can be stored on
  `$state` (e.g. `$state->{'task_id'}`) — thread it in rather than guessing.
- `modules/coding.self_test.check_constraint` and `modules/coding.self_test.evaluate` —
  the landed pattern for a task carrying auxiliary matching config alongside its prompt.
  Mirror this idiom for how a task references its abort-pattern set.
- `modules/jobsite.checksum.index` — the canonical AMOS-checksum content-addressing store:
  `utf8::encode(my $s = $str); my $c = <[chk-sum.amos]>->($s);` then persist with
  `<[file.zenka_dir.write]>->("checksum-store/.../$c", \$empty, '>', 0640)` where
  **file existence == record** (no load/persist cycle). Replicate this idiom in a new
  namespace; do NOT invent YAML/JSON stores.
- `modules/coding.cmd.stop-task` — the exact `.cmd.` shape to copy: reads
  `$call->{'args'}`, defaults to `<coding.task.active>->[0]` when no id given, looks up
  `<coding.task.queue>->{$task_id}`, checks `execution.status`, returns
  `{ mode => qw|false|, data => '...' }` on the sad path.

## Conventions (these are gotchas — get them right)
- Modules are ONE file per dotted name in `modules/`; the filename IS the callable. No
  `sub {}`. No `my $call` except in genuine `.cmd.` entry points (which DO receive
  `$call = { args => ..., session_id => ... }`).
- Invocation: `<[module.name]>` (implicit call), `<[module.name]>->($arg)` with args,
  `<data.path>` for `%data` (dot = nesting).
- Constants: `TRUE => 5`, `FALSE => 0`, `UNKNOWN => 2`. Never assume TRUE == 1.
- Logging ONLY via `<[base.logs]>->( severity, 'fmt %s', $arg )`. Never `base.log`
  (singular), never raw `warn`/`print` for operational logs.
- Comments lowercase, `[ word ]` bracket style, narrative flow (see the read-first files).
- Every file starts with a `## [:< ##` header carrying `# name = ...` and `# descr = ...`.
- **Do NOT hand-write any AMOS7 signature/footer block** (`#,,,`, `#\|`, `#[7]`…). The
  project's signing tool generates those. Leave files unsigned — do not add placeholders.

## Part 1 — abort-pattern registry (AMOS-checksum addressed)
Each pattern's **address IS its `<[chk-sum.amos]>` checksum over its own canonical content**
(regex string, or a deterministic pattern+metadata blob — your call, but the checksum must
be a pure function of content so an unchanged pattern always yields the same ID and
re-registering is a no-op, not a duplicate). `utf8::encode` before checksumming, as
jobsite.checksum.index does.

New modules (names indicative — align to your final design, keep the `coding.abort.*`
namespace):
- `coding.abort.register` — takes a regex string (+ optional metadata), derives its AMOS
  checksum, stores it via `<[file.zenka_dir.write]>` under a new store root
  (e.g. `abort-patterns/<c_sum>` — file content = the pattern text so it can be read back
  and compiled). Returns the checksum ID. Re-register of identical content = no-op.
- `coding.abort.lookup` / `coding.abort.list` — read one / enumerate the store dir.
- `coding.abort.remove` — unlink the store entry by checksum ID.
- `coding.abort.task_bind` — associate a set of pattern-checksum-IDs with a given task
  (store the *IDs* on the task record so raw regex text is never re-embedded per task;
  patterns are reusable across tasks). Model this after how self_test attaches constraint
  config to a task.
- match integration: in `coding.handler.http_io_parse_line`, after content is extracted,
  test the accumulated/new output against the compiled regexes bound to the running task.
  On match: set an abort flag on `$state`, then terminate the call **immediately** —
  invoke `<[coding.async.http_cleanup]>->($state)` (cancel `io_watcher`, close `sock`) and
  fire an abort/complete callback. Do not wait for `[DONE]`/EOF.
- **the abort event must carry, at minimum: the matched pattern's checksum ID, the matched
  text/surrounding context, and the task_id.** A future consumer branches on this
  (retry / escalate tier / switch stage) — that branching logic is OUT OF SCOPE here; just
  guarantee the information is present in the callback payload / returned structure.
- Compile regexes once per abort round (guard `eval { qr/.../ }` — a bad stored pattern
  must log via `<[base.logs]>->(0,...)` and be skipped, never crash the stream handler).

## Part 2 — abort-inference command (race-safe)
New `.cmd.` module, `coding.cmd.abort-inference` (follow `coding.cmd.stop-task` exactly for
shape, arg parsing, and `{mode,data}` returns; add to the same whitelist that stop-task is
registered in).
- **No arg**: abort whatever inference is running in the current context now.
- **Optional arg = task_id**: abort ONLY IF the currently-running task still equals that
  task_id. This guards the race where the caller targeted task A but A finished and task B
  now occupies the slot — blindly aborting "whatever runs now" would wrongly kill B.
- If a task_id is given and does NOT match the current running task: **safe no-op** — log
  it via `<[base.logs]>` and return a `mode => qw|false|` (or benign) reply; do NOT error,
  do NOT touch any state. The caller's target is simply already superseded, which is fine.
- **Kimi: confirm the exact in-flight task identity to check against before implementing.**
  Candidates observed: `<coding.task.active>` (arrayref, `->[0]` = current), the per-call
  `$state->{'task_id'}` you thread through http_client, and `<coding.task.queue>->{$id}`
  with `->{'execution'}{'status'} eq 'in_progress'`. Reuse the existing one; do NOT create
  a parallel tracker. State clearly in a code comment which source you chose.

## Expected files
- new: `coding.abort.register`, `coding.abort.lookup`, `coding.abort.list`,
  `coding.abort.remove`, `coding.abort.task_bind` (merge/rename if your design is cleaner —
  keep `coding.abort.*`), `coding.cmd.abort-inference`.
- modified: `coding.handler.http_io_parse_line` (pattern match hook),
  `coding.async.http_client` (thread task_id onto `$state`), the module-load/start file
  and command whitelist for the coding zenka (register the new modules + the new `.cmd.`).
- possibly modified: the task record shape where self_test attaches per-task config
  (to also hold bound abort-pattern IDs).

## Definition of done (self-check before returning)
- [ ] pattern checksum ID is a deterministic pure function of pattern content
      (`utf8::encode` + `<[chk-sum.amos]>`); re-registering identical content is a no-op.
- [ ] patterns stored as file-existence records under a new store root, jobsite-style;
      no YAML/JSON index invented.
- [ ] tasks reference patterns by checksum ID only — no raw regex re-embedded per task;
      patterns reusable across tasks.
- [ ] a match during streaming terminates the call immediately (cleanup + socket close,
      not waiting for EOF/`[DONE]`).
- [ ] abort event payload carries matched pattern checksum ID + matched text/context +
      task_id.
- [ ] a malformed stored regex is logged and skipped, never crashes the stream handler.
- [ ] `coding.cmd.abort-inference`: no-arg aborts current; task_id arg aborts only on
      match; mismatched task_id is a logged safe no-op (no error, no state change).
- [ ] chosen in-flight-task identity source is an EXISTING one, named in a comment; no
      parallel tracker added.
- [ ] all modules: `## [:< ##` header with name+descr; lowercase `[ word ]` comments;
      `<[base.logs]>` logging; TRUE/FALSE/UNKNOWN honored; NO hand-written signature footer.
- [ ] new modules added to the coding zenka's module-load list and `.cmd.` whitelist.

#,,,,,,..,,..,.,.,,,,,,.,,.,.,.,,,..,,,,,,.,,,..,,...,...,...,..,,..,,.,.,.,.,
#LEIJSYJFTV2C4QZ75DA6YMYC2D5VZZS4WM5D33EF4O62POVBHNAOWZNOO4XP45YWCYI2G7JLTYGXE
#\\\|5WWWWMWI2LZ4ATPG3A6BCQ2BJEVXQSHE7VBGWVYQH4HVHCOE2A2 \ / AMOS7 \ YOURUM ::
#\[7]3LZ7NKD7KKJKB4I4E4D7K43GL6NIWFTFKS2DQ6QCUB3HVA2FFOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
