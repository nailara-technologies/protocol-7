## claude zenka : claude code wrapped as a zenka, an alternate terminal, events both ways

owner question 2026-11-23 : how do zenki and events reach a claude session, and what would an
alternate terminal use if claude ran inside a claude zenka.

### what exists today [ verified 2026-11-23, claude code 2.1.330 ]

- session -> outside : mcp tool calls [ mcp-server-p7 -> cube ], hooks [ UserPromptSubmit,
  PreToolUse, PostToolUse, Notification, Stop .. : the event as json on stdin, a hook may run
  p7c ; PreToolUse can allow \ deny ], the status line command [ session state on every
  update ]
- outside -> session :
  - cross-session inbox socket : one unix socket per session, path + token in the env of
    hooks and bash [ CLAUDE_CODE_MESSAGING_SOCKET, CLAUDE_CODE_MESSAGING_TOKEN ] ; first line
    {"type":"auth","token":"<token>"}, then plain text ; read between tool calls, an idle
    session starts a turn ; tagged as another session, never as the user, cannot approve
    permissions. docs : code.claude.com/docs/en/cross-session-messaging.md
  - mcp channels [ research preview ] : capabilities.experimental['claude/channel'] = {},
    notification notifications/claude/channel { content, meta } [ meta keys
    [A-Za-z0-9_] ]. a custom server registers only in an interactive session started with
    --dangerously-load-development-channels server:<name> ; not in -p ; org policy may block
    it. a server on protocol revision 2026-07-28 cannot deliver [ ours : 2025-11-25 ].
    docs : code.claude.com/docs/en/channels-reference.md
  - hooks with asyncRewake : wakes on exit code 2, only for processes a hook started
- field names above come from page summaries : check them against the pages before coding

### order [ proposed ]

1. inbox socket in mcp-server-p7 : a line into the session when a claude run ends or a
   claude_wait pattern matches, later forwarded cube events [ subscriptions ]. the socket
   path is in the server's env [ it runs inside the session ] ; a zenka gets it handed over,
   never by guessing. replaces the background watcher loops.
2. claude zenka [ the target ] :
   - one process : claude -p --input-format stream-json --output-format stream-json
     --verbose, started through IPC::Open3, stdout \ stdin watched in the event loop [ the
     pattern of the claude runs in mcp-server-p7, e79898931b ]
   - out : every stream event becomes a zenka event [ init, text, tool, result, final with
     cost ] -- the alternate terminal, p7-log and other zenki subscribe
   - in : claude.send <text>, claude.interrupt, claude.permission <id> allow|deny [ through
     --permission-prompt-tool, an mcp-server-p7 tool that forwards to the zenka ]
   - --resume <session> keeps the conversation across zenka restarts
   - mcp-server-p7 stays the mcp server inside it : tools and cube access unchanged
   - events into the session are plain user-turn lines written by the zenka : channels are
     not needed there
3. channels : optional, only for interactive sessions started with the development flag

### clients : mcp-server-p7 runs under claude code AND kimi

- anything that pushes into a session needs a path per client [ $mcp_client_name from
  initialize ] or a quiet no-op : the inbox socket env exists only under claude code
- kimi : its own push \ wake mechanism unknown -- check the kimi cli before relying on one
- claude runs : run ids carry the server pid [ no collision between the two servers ] ;
  claude_check_status reads any server's finished run from disk, claude_wait only the runs
  of its own server [ live handles ]
- deferred replies [ claude_wait ] answer out of order : one short kimi test call to see its
  mcp client accepts that

### kimi side [ kimi 2.4.1, 2026-11-23 ]

verified by a kimi research run [ session_06be7558-0ca9-4fb9-bf71-506b6e09edd4, from its
bundled source packages/acp-server, kap-server, agent-core-v2 and the docs ]

- `kimi acp` [ the kimi adapter ] : newline-delimited json-rpc 2.0 over stdio.
  initialize { protocolVersion 1, clientCapabilities } ; session/new { cwd, mcpServers } ->
  sessionId ; session/load [ replays history ] \ session/resume { sessionId, cwd,
  mcpServers } ; session/prompt { sessionId, prompt : [ {type text, text} .. ] } ->
  { stopReason end_turn|cancelled|refusal }, one active prompt per session [ else
  turn.agent_busy ] ; session/cancel is a notification.
  events : session/update { sessionId, update { sessionUpdate : agent_message_chunk \
  agent_thought_chunk \ tool_call \ tool_call_update \ plan \ usage_update { used, size } \
  session_info_update .. } }. permissions : session/request_permission { options [ optionId
  approve_once \ approve_always \ reject ], toolCall } -> { outcome { outcome selected,
  optionId } } or { outcome { outcome cancelled } }
- `kimi web` [ KAP ] : REST POST /api/v1/sessions/{id}/prompts { content [..] }, GET
  /api/v1/sessions, :abort, :takeover ; websocket /api/v1/ws, client_hello { token,
  subscriptions [ session ids ], cursors } -> assistant.delta, tool.call.*, tool.result,
  turn.started \ ended, prompt.* ; token in ~/.kimi-code/server.token ; specs at
  /openapi.json \ /asyncapi.json
- a RUNNING tui session cannot be reached : no socket, no injection ; its lock refuses
  prompts [ session.occupied ], :takeover evicts the tui. a relay kimi session is run by the
  adapter, not by an open tui
- hooks : ~/.kimi-code/config.toml [[hooks]] event \ matcher \ command \ timeout ; events
  UserPromptSubmit, PreToolUse, PostToolUse, Stop, SessionStart \ End, Notification .. ;
  exit 2 blocks ; they cannot originate a message in an idle session
- its mcp client : notifications/message and progress are dropped [ never in the
  conversation ] ; out-of-order responses are matched by id -- claude_wait is safe under
  kimi
- `kimi -p --output-format stream-json` : output only, aggregated lines [ role assistant \
  tool \ meta ], no stdin input mode -- one-shot runs only [ kimi_dispatch ]

### session relay [ claude <-> kimi, owner idea 2026-11-23 ]

- one zenka, two adapters : claude [ stream-json or the inbox socket ], kimi [ acp or the
  kimi web api ] ; a message from one session becomes a prompt in the other, its answer
  comes back as an event
- through the zenka : one log [ p7-log ], access through cube, the alternate terminal can
  follow both ; the p7_chat channels of mcp-server-p7 as the visible surface

### coding zenka as the persistent layer [ owner direction 2026-11-23 ]

sessions are short, the coding zenka lasts : claude and kimi both organize work there, and
it carries that work out over long token timespans, including calling them again.

- shared plan : tasks, notes, dependencies and results live in the coding zenka, not in a
  session ; either agent adds, splits or re-plans them, the other sees the same state
- it calls the agents : a planned task starts a claude or kimi run [ the adapters above ],
  resumes a session [ --resume \ kimi_continue ] or a fresh one with the task context
- budget aware : token usage curves per agent and window [ the usage zenka : 5h \ 7d
  percent and reset times ], thresholds, rate limits ; work is placed where the budget
  allows and spread over the windows instead of burning one early
  [ see token-budget-pacing-early-week ]
- dynamic planning : the plan reorders by budget, results and owner input ; a task that
  waits for a window reset is a planned state, not a failure
- the owner decides, the zenka records : approvals \ signs stay with the owner, the zenka
  queues them [ one pending sign at a time ]
- reawakening a continuation : the task zenka holds the task state [ task.create \ claim \
  continue \ handover \ result ], the events zenka the time [ event-setup.<name>, `at` times
  and triggers -- events.trigger_event ]. a task parked on a budget window, a run end, a
  sign or a zenka event gets an event ; when it fires, the coding zenka continues the task
  [ task.continue with the follow-up, the agent session resumed or a fresh one from
  task.handover ]. a wake-up is the next step of a plan, never a blind retry
- triggers worth having : window reset [ usage zenka ], run finished \ pattern [ claude runs,
  kimi ], sign approved \ committed, a zenka event [ net, n7fs place done .. ], an owner
  message, a time from the plan

### event buckets [ owner direction 2026-11-23 ]

today the events zenka reads static event-setup.<name> files [ .: events :. actions
send-command \ zenka-present, .: timetable :. `at` times ] -- nothing added at runtime, no
dependencies. buckets add that :

- a bucket per owner zenka [ coding, task, later others ] : its own timetable, added to,
  changed and cleared at runtime by that zenka [ access : a zenka writes only its own bucket ]
- an entry : id, action [ send-command .. as today ], when [ `at` a time, after a span from
  base.interval.next, on an event : another entry fired, a zenka event, a window reset ],
  depends [ entry ids that must have fired \ succeeded first ], a reason [ shown in listings ]
- dependencies resolved by the events zenka : an entry becomes due when its time has come
  AND its dependencies are met ; a failed dependency marks the dependants blocked with the
  reason, never fires them
- persisted [ p7 config style per bucket, add-only journal for fired \ failed ] : a restart
  keeps the timetable, missed entries fire once on start or are marked missed by their rule
- listing : events.bucket.show <bucket> -- entries, state [ waiting \ due \ fired \ blocked
  \ missed ], what each one waits for
- the static event-setup files stay as they are ; a bucket is the runtime layer beside them

event sources [ owner 2026-11-23 ] : events.trigger_event today takes only a numeric timer
id and fires that configured `at` timer now -- no other source exists. needed :

- a named signal any zenka may raise : events.signal <name> [ key = value .. ], e.g.
  claude.run.done, kimi.run.done, sign.approved, commit.done, usage.window.reset,
  n7fs.place.done, net.network.changed
- the source recorded with every signal [ the raising zenka from the cube session, never
  self-declared ] ; access per signal name in access.zenki [ who may raise what ]
- bucket entries wait `on` a signal [ optionally matching its values ] the way they wait
  on a time ; one signal may wake several entries, in dependency order
- signals journaled add-only next to the fired entries : a listing shows which source woke
  which entry

event types as plugins [ owner 2026-11-23 ] : the pattern of the usage zenka
[ plugins.load = plugin.usage.claude plugin.usage.kimi, [load_plugins:<plugins.load>] ].
today the action types are an if-chain in events.handler.event_triggered [ zenka-present,
send-command, tile-* ] and the only `when` is a timetable `at`.

- plugin.events.source.<type> : where a wake-up comes from -- timetable [ today's `at`,
  moved behind the interface ], signal, bucket-dependency, usage-window [ reset times from
  the usage zenka ], later file \ net \ n7fs sources ; each registers how it arms, what it
  matches, how it is listed
- plugin.events.action.<type> : what a fired entry does -- send-command, zenka-present,
  tile-* [ moved out of the if-chain unchanged ], task-continue [ task zenka ],
  coding-run [ coding zenka starts \ resumes an agent run ]
- one registration shape for both [ name, arm \ disarm or run, describe for listings ] ;
  events.plugins lists what is loaded ; a setup naming an unknown type is refused with the
  list of known ones
- moving the built-in types behind the same interface keeps one path, no special cases

### coding zenka [ owner idea 2026-11-23 : several roles ]

- stream summarizer : coding.summarize-context [ already behind auto_summarize ] turns long
  claude \ kimi event streams into short status lines for the terminal or a session
- dispatcher : coding.submit task states hand work to the claude \ kimi adapters, not only
  to local models ; the choice by cost from the usage zenka [ cheap work to kimi \ local,
  protocol work to claude ]
- consensus \ review : llm.service.consensus_vote asks claude, kimi and local models the
  same question and merges the answers [ e.g. a review before a sign ]
- shared tools : read_file, ncode_search, notes, tree through p7_call_tool -- both sessions
  see the same notes and task state
- resume chain : coding.handler.check-completion-chain with --resume \ kimi_continue picks
  up a run cut off at its timeout

### inbox socket wire format [ 2026-11-23 ]

- the docs define only the auth line ; no reply is sent after it. probes with
  {"type":"message","text":..} and a plain text line were dropped silently
- RECORDED [ strace of a real SendMessage, claude code 2.1.330 ] and CONFIRMED by a script
  post : after the auth line, one json line [ external format, the claude code protocol ] :
    {"msgV":1,"msg_id":"<uuid>","type":"user","priority":"next",
     "from":"uds:<sender socket>",
     "message":{"role":"user","content":"<cross-session-message from=\"uds:<sender
       socket>\" from-name=\"<name>\" from-mode=\"prompting\">\n<text>\n</cross-session-message>"}}
  the sender writes the tag itself ; from-name is shown as the sender. the receiving
  session's own token [ CLAUDE_CODE_MESSAGING_TOKEN ] authenticates a local script.
  no reply line. an undocumented protocol : keep the writer in one place, check it after
  claude code upgrades [ msgV ]

### to verify before building

- the stream-json input line shape, --input-format and --permission-prompt-tool against
  `claude --help` and the headless docs [ written from memory, not from a page read ]
- whether an idle interactive session is woken by a channel event [ implied in the docs,
  not stated ]
- inbox socket inbound policy : crossSessionInbound accept | hold | refuse, defaults by
  permission mode -- a bypass session holds messages from a prompting sender

#,,..,...,,,,,,.,,,..,..,,,,.,,,.,,,,,,,.,,,,,..,,...,..,,..,,.,.,,..,,,,,.,,,
#GX5SBUEVN6EURYYPJLONADDXOMZ7BRV4TA6WGEXG5AFVJFAMDRN3MNHYU2GIPDT3NL33RAVVVNIWW
#\\\|SHAGMIEKJWZ2LMFSGZK24ABOT2R736M2BBRV6W3X3XWZH36HFSJ \ / AMOS7 \ YOURUM ::
#\[7]ECAPA6UPVVPRJTIBMOOQHTWZXGO27X34RLCWQI43WZ5LV4WNYMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
