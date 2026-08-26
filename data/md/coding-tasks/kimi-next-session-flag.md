# Task: kimi ask-reply :next: flag — fresh session before prompt

status: pending

## before you start

read your memory files:
- `data/ai-mem/kimi/MEMORY.md` — index to your saved memories
- `data/ai-mem/kimi/coding-style.md` — coding conventions for this project
- `data/yaml/code-style/CONVENTIONS.yaml` — quick reference

## problem

`kimi.cmd.ask-reply` always appends to the current kimi-web session.
when models auto-dispatches tasks sequentially [ task A completes, task B
is claimed and dispatched ], task B's prompt is appended to task A's
session. the response then contains both conversations concatenated, and
the wrong result gets stored against the task id.

## solution: `:next:` prefix flag

add support for a `:next:` prefix in the prompt string passed to
`kimi.cmd.ask-reply`. when present:

1. strip `:next:` from the prompt
2. store prompt + reply_id in a deferred slot
3. tear down current websocket, create fresh session via REST API,
   reconnect websocket
4. when status reaches `ready` after fresh connect, dispatch the
   stored prompt via `kimi.wire.prompt`
5. return `{ mode => 'deferred' }` immediately [ same as normal prompt ]

if `:next:` is not present, behavior is unchanged [ append to session ].

## modules to create / modify

### new: `kimi.session.create`

extract the REST API session creation from `kimi.connect` [ lines 19-68 ]
into a reusable module. returns session_id on success, undef on error.

both `kimi.connect` and the `:next:` reset flow should call this module
instead of inlining the REST call.

reference: `kimi.connect` lines 19-68 [ the REST POST to /api/sessions/ ]

### modify: `kimi.cmd.ask-reply`

after prompt decoding [ after line 23 ], check for `:next:` prefix:

```
if ( $prompt =~ s{^:next:\s*}{} ) {
    ## store deferred prompt for post-reconnect dispatch
    <kimi.next.deferred> = {
        'prompt'   => $prompt,
        'reply_id' => $$call{'reply_id'}
    };
    ## trigger session reset + reconnect
    <[kimi.session.reset_and_reconnect]>->();
    return { 'mode' => 'deferred' };
}
```

### new: `kimi.session.reset_and_reconnect`

lightweight session reset without full `kimi.cmd.new-session` overhead.
tears down websocket, clears session state, creates fresh session via
`kimi.session.create`, reconnects websocket. reuses connection setup
logic from `kimi.connect` [ lines 70-105 ].

state to clear: `kimi.session_id`, `kimi.wire.accumulator`,
`kimi.wire.pending`, `kimi.ws.status` → `connecting`

### modify: `kimi.handler.ws_message`

at the ready transition after initialize response [ around line 260 ],
check for deferred prompt:

```
if ( defined <kimi.next.deferred> ) {
    my $def = delete <kimi.next.deferred>;
    <[kimi.wire.prompt]>->( $def->{'prompt'}, $def->{'reply_id'} );
}
```

### modify: `models.task.execute`

prepend `:next:` to prompt before base32r encoding [ line 27 ]:

```
$prompt = ':next: ' . $prompt;
```

this ensures every task dispatch starts a fresh kimi session.

## reference implementations [ read these for style and patterns ]

- `kimi.connect` — full connect flow, session creation, websocket setup,
  preserved prompt handling across reconnects [ lines 111-123 ]
- `kimi.cmd.new-session` — existing full teardown [ too heavy but shows
  what state needs clearing ]
- `kimi.handler.ws_message` — TurnEnd handler [ line 162-203 ] and
  initialize response handler [ line 258-269 ] show the ready transition
- `models.handler.task-poll-step` — async callback chain pattern with
  steps [ claimed → show → enqueue ]
- `models.task.execute` — where prompt is built and dispatched

## constraints

- no fake signatures — leave new files without the 4-line footer
- no timers or polling — fully async chain
- lowercase comments, `[ annotation ]` not `( annotation )`
- `$ARG` not `$_`, `->%*` dereferencing style
- log levels: 0=error, 1=default, 2=info
- test by creating a task via `task.create :kimi: :next: test prompt`
  and verifying fresh session is created before dispatch

## acceptance criteria

- [x] `:next:` prefix in ask-reply triggers fresh session
- [x] prompt without `:next:` appends to existing session [ unchanged ]
- [x] `kimi.session.create` extracted and used by both connect and reset
- [x] `models.task.execute` prepends `:next:` to all task prompts
- [x] sequential task dispatch produces independent sessions
- [x] no timers, no polling — pure async chain

#,,..,...,.,,,,..,,..,,.,,,..,,,,,,..,,..,,,.,..,,...,...,..,,,.,,,.,,,,.,..,,
#5MZCP6EOI4YQYFPSFVCEQAYXQRRLGL6D3AFQKDVCWWOCZ3TM4XGHNSPYDNZMLVW4FN62A7JBM2WMG
#\\\|RQMA3XWXZIJN7DYLCDO6SGDUMTQ6RSIG3XQ4Z4IYUSWCIVERUUN \ / AMOS7 \ YOURUM ::
#\[7]PJ5KRQVX24D5SVAC5CPLYVIXKPIQK657LUQ3EHMVBLEFWBLIVAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
