---
name: critical-patterns
description: CRITICAL P7 coding patterns — load this when writing or reviewing any P7 module code
metadata: 
  node_type: memory
  type: reference
  originSessionId: 491a0f4e-591b-444d-84b2-705a21429284
---

## protocol-7.route-send
- Wraps `send.local`, auto-prepends `<protocol-7.network.parent_route>`
- **Returns count of sent commands (0 or 1), NOT the reply data**
- Replies arrive asynchronously via `reply.handler` callback
- Use `call_args => { args => $string }` — NOT `param => { hashref }` (never transmitted)
- For async chains: pass state via `reply.params`, dispatch in handler
- Use for cube-routed commands (`v7.*`, `httpd.*`, `p7-log.*`, etc.)
- Do NOT use for `child.*` commands (local socketpair aliases)
- Multiline args corrupt protocol framing — base32r encode or collapse newlines

## Event Timers
- Repeating: BOTH `'interval' => N` AND `'repeat' => TRUE`
- One-shot: `'after' => N` with no interval key
- ❌ `'repeat' => 62` (no interval → error)

## Module Loading
- `base.perlmod.autoload`: one module per call, NOT a list
- ❌ `<[base.perlmod.autoload]>->(qw| IPC::Open3 YAML::XS |)`
- ✅ `map { <[base.perlmod.autoload]>->($_) } qw| IPC::Open3 YAML::XS |`

## Module Invocation Syntax
- ALWAYS `<[module.name]>->($args)` — closing `]>` BEFORE `->`
- `<[mod]>` is implicit no-arg call — never add `->()` for zero args

## IPC send.local pattern
```perl
my $cmd_count = <[base.protocol-7.command.send.local]>->({
    'command'   => 'target.name',
    'call_args' => { 'args' => $data },
    'reply'     => { 'handler' => 'caller.handler.reply',
                     'params'  => { 'context' => $value } }
});
```

## Cross-zenka deferred replies
- Need local reply_id store + callback_id + route-send back
- `call_args.data` not transmitted; multiline = `:B32:`
- Deferred P7 reply from httpd handler crashes (flush_shutdown vs flush, session lifetime)
- Use web zenka push/cache instead for httpd→jobsite type flows

## Config Variable Path Conflicts
- `<a.b.c>` and `<a.b.c.d>` CONFLICT — scalar vs hash deref
- ✅ Use flat sibling name: `<kimi.connect.retry_cur>` not `<kimi.connect.retry_delay.current>`

## Swap-Boundary Module Dispatch
- `<[chk-sum.amos]>` fails P7 pre-validation during base init (swap not yet applied)
- `<[base.chk-sum.amos]>` fails after re-init (swap already applied)
- Fix: `my $fn = $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}; $fn->($input);`

## Style: TRUE ≠ 1
- `TRUE=5`, `FALSE=0`, `UNKNOWN=2`
- `> 1` checks trigger on `TRUE` (5) — use literal `1` for "more to read" return codes

## file.slurp Returns Scalar Ref
- `<[file.slurp]>->($path)` returns `\$content`, NOT `$content`
- Pattern: `my $content = <[file.slurp]>->($path)->$*;`

## File stat shadowing
- `bin/Protocol-7` `use File::stat` shadows builtin; always use `File::stat::stat($p)->size/mtime`

## Logging
- `base.logs` handles sprintf; `base.log` has default log_level [1]
- Log levels: 0=error 1=default 2=info 3=debug
- No variable interpolation in logs — use sprintf format codes

## Code Style
- Lowercase comments; `[ word ]` annotations not `( word )`
- `$ARG` instead of `$_`; `$data_ref->%*` dereferencing
- Inline extracted subs → `namespace.name` (no underscore prefix)
- `# descr =` lines enforced to 55 chars max by pre-commit hook

## File Ownership
- Files: 0664, dirs: 0775; `getpwnam` uid at index 2, gid at index 3
- Namespace swapping: `base.file.*` → `file.*` via swap_subs in base.file.init_code

## plugin.web.* loading
- `plugin.web.*` in httpd needs `[base.white-list.register]` in start file
- `file.zenka_dir.data_path` returns caller's zenka dir not owner's

## Config keys
- `coding.cfg.*` / `httpd.cfg.*` keys go in `configuration/zenki/<name>/start`
- Never create `modules/<zenka>.cfg` — loader treats it as a Perl sub
- Never set config key to empty string

## fork-child module loading
- Parent branch of fork must explicitly `load_runtime_modules` for all subs it calls
- Child loads don't reach parent `%code`

## cube.cmd.* call_args
- Receive `$call_args` with keys `'session_id'` and `'args'`
- Using `'sid'`/`'args_list'` silently FALSEs out

## list backends return format
- `{ mode => 'size', data => $formatted_string }` — not arrayref

## WebSocket / JSON
- `Frame->new( buffer => $text, type => 'text', masked => 1 )`
- Set `max_payload_size => 16 * 1024 * 1024` for large messages; `->next` DIES on oversized — wrap in eval
- `decode_json` expects raw UTF-8 bytes; `from_json` accepts decoded strings
- Use `from_json` for websocket text frames

## Watcher state machines
- IO::Async variable watchers are the proven reliable pattern
- Never use polling timers/sleep loops for state; coding zenka is the reference
- See [[feedback-watcher-state-machines]]

## AMOS Checksums
- 7 characters, `^[A-Z0-9]{7}$`
- Harmonized ref: `TYPE:CHKSUM7:ADDR_B32` where ADDR_B32 is `[2-9A-Z]{1,16}`
- Regex delimiter must not conflict with `{1,16}` — use `m''` not `m,,`

## Warning Capture in Sort Blocks
- `<=>` on non-numeric emits warning, not exception — `$EVAL_ERROR` stays empty
- Pre-check with `looks_like_number()` (Scalar::Util)
- If wrapping `$SIG{__WARN__}`, capture prev and call through

## system.zenka.initialized
- FALSE during startup, TRUE after zenka goes online; stays TRUE during reload
- Use to distinguish real restart from reload in post_init

## Deferred Zenka Online
- Remove `[get_session_id]` from start file; call from within event loop when ready
- Guard with `<zenka.session.acquired>` flag against reconnect duplicates

## p7c vs p7
- Always use `p7c` not `p7` — binary was renamed
- `p7c v7.restart cube` restarts all zenki at once; use after editing cube/access.zenki

## chmod child restore readline
- Every restore cmd to chmod child needs `readline` after; missing one desyncs the pipe

## PERSISTENT_AMEND env var
- Not normally set; prefix: `PERSISTENT_AMEND=0 git commit -m "..."`

## Config String → Arrayref Pattern
- P7 start file values are scalars — split in init_code: `if defined and not ref → split m|\s+|`

## ptd usage
- Use `ptd` (not `ptd -c`) after writing modules — formats + checks syntax in one pass

#,,,,,,..,.,,,.,.,.,,,,,.,.,,,,,,,.,.,,..,.,,,..,,...,...,.,.,...,,,,,,..,,.,,
#PIRIOWJQAHG33DMTRFZHGMJSTFP25I5AXLBVRCRBTZ7LJLZUKWYRPFKIGQA23ZWRBUD53R6D27TM2
#\\\|5GLO6MZBLRYU425CBGNLJCLTGBGOSXTJIYCA6GLPQQW7J66BRSY \ / AMOS7 \ YOURUM ::
#\[7]4CFNRUTZ6YZ46FGP6HVXR4MZ6D654IWKR2ERBLFZJWZMMIJB4ABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
