# protocol-7 coding style [ kimi-specific ]

nuances and patterns that kimi specifically needs to get right.
canonical reference: data/yaml/docs/protocol-7-coding-style.md
complementary reference: data/ai-mem/claude/coding-style.md

---

## core philosophy

**minimal changes, maximal clarity**
- every edit should be purposeful
- prefer explicit over implicit
- when in doubt, follow existing patterns exactly

---

## syntax validation [ critical ]

### do not trust `perl -c`
protocol-7 syntax extends perl in ways that confuse `perl -c`:
- `<key.path> //= 0` looks like glob assignment to perl — produces false error
- p7-specific constructs may pass silently but still be wrong

### use `bin/dev/ptd` instead
```bash
## validate and reformat
./bin/dev/ptd modules/namespace.module.name

## check only (no reformat) — requires -c or -check flag
./bin/dev/ptd -c modules/namespace.module.name
./bin/dev/ptd -check modules/namespace.module.name
```

### verbatim escape for unusual constructs
```perl
#<<V  code skipping: perltidy passes this verbatim

    <some.unusual.construct> //= {};

#>>V
```
use sparingly — rewrite into cleaner form once logic settles.

---

## invocation syntax [ critical ]

### closing token is `]>` — never `]->` or `>` alone
```perl
<[base.command]>->($arg)    ## correct
<[base.command]->($arg)     ## wrong — missing >
<[base.command>->($arg)     ## wrong — missing ]
```

### no-arg calls
```perl
<[base.exit]>               ## correct — implicit ->()
<[base.exit]>->()           ## redundant but valid
```

### variable module name [ dynamic dispatch ]
```perl
<[$handler]>->($arg)        ## correct — resolves to $code{$handler}->($arg)
<[$handler]>                ## correct — resolves to $code{$handler}->()
$code{$handler}->($arg)     ## also valid — explicit form
```
note: variable form uses NO quotes — `$code{$var}` not `$code{'$var'}`

### swapped module families — file name != runtime `%code` key [ critical ]

some module families are renamed during zenka startup by `<[base.swap_subs]>`.
after the swap, the long `base.<family>.*` keys are deleted from `%code`; only
the short form resolves at runtime. known swapped families (grep
`<[base.swap_subs]>` in `modules/*.pre_init` / `modules/*.init_code` for the
current list):

`base.event`→`event` · `base.file`→`file` · `base.base32`→`base32` ·
`base.templates`→`templates` · `base.chk-sum.*`→`chk-sum.*` ·
`base.zenka.push`→`zenka.push` · `base.dependency`→`dependency` ·
`base.locales`→`locales` · `base.protocol-7`→`protocol-7` ·
`v7.zenka`→`zenka` · `fetch.file.huggingface`→`huggingface` ·
`event.anyevent`→`event`

```perl
## file on disk: modules/base.event.add_timer
## runtime call after init: use the short name
<[event.add_timer]>->(...)

## <[base.event.add_timer]> is undefined after the family's pre_init runs
```

rule: `ls modules/` is not evidence of the runtime `%code` key. if a family is
in the swapped list, use the short form. when unsure, check
`p7c <zenka>.list-subs <pattern>` on a live zenka.

---

## data access patterns [ critical ]

### three distinct notations — never mix them

```perl
<[module.name]>->($arg)          ## function call — exact key match in %code
<key.path>                       ## data read — dots become nested hash access
$data{'key'}{'path'}             ## explicit data read — always valid
```

### data path vs module path
```perl
<data.fuse.mounts>{$mp}               ## data: $data{'data'}{'fuse'}{'mounts'}{$mp}
<[data.fuse.init_code]>               ## call: $code{'data.fuse.init_code'}->()
<web.metrics>->{commands_executed}    ## data hash deref
```

### `<module.name>->(...)` without brackets is a fatal data access [ gotcha ]

writing a subroutine call in data-access syntax compiles fine but dies at
runtime with `undefined value as subroutine reference` — the data store has
no coderef at that key :

```perl
<kimi.handler.approval_request>->( $id, $payload )    ## WRONG : data access,
                                                      ## undef->() : fatal
<[kimi.handler.approval_request]>->( $id, $payload )  ## correct : sub call
```

found live in `kimi.flush_on_acquisition` [ 2026-08-04 ] : the extracted
module had this bug plus a fabricated blank payload and an arrayref reset of
the hashref `<kimi.approval.pending>` — all invisible because nothing called
the module. lesson : after extracting an inline sub to its own module, grep
for a real call site AND invoke it once live [ `kimi.eval-code` ] to prove
the wiring.

### assignment patterns
```perl
<key.path> = $value;                 ## simple assignment
<key.path> //= $default;             ## defined-or assignment
push <key.path>->@*, $item;          ## array push via postfix dereference
```

---

## reply handling [ critical ]

### return format — always use hashref with 'mode'
```perl
## success with data
return { 'mode' => qw| true |, 'data' => $result };

## success with size (multi-line)
return { 'mode' => qw| size |, 'data' => $multi_line_content };

## failure
return { 'mode' => qw| false |, 'data' => $error_message };
```

### never embed newlines in 'true' mode
```perl
return { 'mode' => qw| true |, 'data' => "line1\nline2" };   ## wrong
return { 'mode' => qw| size |, 'data' => "line1\nline2" };   ## correct
```

### error messages
- lowercase
- descriptive but concise
- no interpolation — use sprintf-style

---

## async handler chains [ critical ]

### protocol-7.route-send returns send count, NOT reply data
```perl
## wrong — interpreting return as data
my $result = <[protocol-7.route-send]>->({ ... });
if ( $result->{'mode'} eq qw| true | ) { ... }   ## crash — $result is 0 or 1

## correct — check send count
my $sent = <[protocol-7.route-send]>->({ ... });
if ( $sent <= 0 ) { ## failed to send
    ## handle send failure
}
## reply comes async via handler
```

### handler chain pattern
For multi-step async workflows, use handler chain:
```
caller → route-send with handler_a
    ↓ async
handler_a → validate → route-send with handler_b OR fallback
    ↓ async
handler_b → validate → complete OR fallback
```

### handler signature
```perl
## [:< ##
# name  = models.handler.my-reply
# descr = handle reply from some async command

my $reply = shift;

my $data   = $reply->{'data'}   // '';
my $mode   = $reply->{'mode'}   // qw| unknown |;
my $params = $reply->{'params'} // {};  ## original params from route-send

## $mode is: true | false | size | deferred | unknown
if ( $mode eq qw| false | ) {
    ## handle failure, fallback
} else {
    ## continue workflow
}
```

### preserving state across async boundaries
Pass all needed context in `reply.params`:
```perl
<[protocol-7.route-send]>->(
    {   'command'   => 'v7.notify_online',
        'call_args' => { 'args' => ":start: $zenka_name" },
        'reply'     => {
            'handler' => qw| models.handler.my-reply |,
            'params'  => {           ## [ all context needed by handler ]
                'task_id'    => $task_id,
                'model'      => $model,
                'job_id'     => $job_id,
                'target_cmd' => $target_cmd,
                'encoded'    => $encoded
            }
        }
    }
);
```

### reset active state before fallback
When handler needs to fall back to alternative flow:
```perl
## handler detected failure, falling back ##
<models.task.active_id>  = $task_id;   ## restore guard
<models.task.active_job> = $job_id;

<[models.task.fallback-direct]>->($params);  ## alternative flow
```

---

## logging [ critical ]

### format strings — never interpolate
```perl
<[base.log]>->(2, "loading module '%s'", $name);        ## correct
<[base.log]>->(2, "loading module '$name'");            ## wrong — interpolation
```

### log levels
log levels correspond to -v[v[v[v[v]]]] flags when starting the zenka.

colors per level (from base.log.format_entry):
- 0: error — always visible, color highlighted
- 1: default — normal operation
- 2: info — info/debug combined, development use
- 3+: debug — extended debug, compiles routines with additional logging
- 4: dumps parsed sourcecode after syntax parsing on startup
- 5: with devmod enabled, dumps entire %data hash on shutdown

### common usage
```perl
<[base.log]>->(0, "error: %s", $msg);        ## always visible, highlighted
<[base.log]>->(1, "normal: %s", $msg);        ## normal operation logging
<[base.log]>->(2, "info: %s", $msg);          ## info/debug (development)
```

### rarely used in regular code
levels 3+ are primarily for development/debugging:
- 3: extended debug, routine call tracing
- 4: sourcecode dump on startup
- 5: data hash dump on shutdown

levels 7,8,9 are technically possible but unused.

### separate verbosity control
logged verbosities can be controlled separately for different targets:
- `<system.zenka.verbosity.console>` — console output
- `<system.zenka.verbosity.buffer>` — uim-memory buffer
- `<system.zenka.verbosity.logfile>` — log files (via network to p7-log zenka)

the effective verbosity is the max of all three (see modules/base.get_max_verbosity).

---

## module structure

### header template
```perl
## [:< ##

# name  = namespace.category.action
# descr = brief lowercase description
# param = $params [ { expected_keys } ]

my $params = shift // {};
```

### signature footer [ critical ]
**never add signature footer manually** — `bin/Protocol-7 sourcecode update-signatures` adds the real footer.

**placeholder footers**: do not include placeholder signature lines with trailing spaces — they block the signing system.
```
#,,,.,,,.,,..,.,.,..,,,..,..,,,..  ## wrong — trailing space
#,,,.,,,.,,..,.,.,..,,,..,..,,,..  ## correct — no space
```

leave files clean for proper signing.

### never add signature footer manually
`bin/Protocol-7 sourcecode update-signatures` adds the real footer.
leave files clean for proper signing.

---

## hash and array operations

### postfix dereference (preferred)
```perl
<array.path>->@*;                    ## full array
<array.path>[0];                     ## single element
<hash.path>->%*;                     ## full hash
<hash.path>{key};                    ## single value
```

### checking existence
```perl
exists <hash.path>{key};             ## key exists
defined <hash.path>{key};            ## value defined
<hash.path>{key} // 'default';       ## defined-or default
```

---

## string handling

### qw| | for word lists and scalar strings
```perl
qw| success error pending |          ## correct — spaces separate
qw|success error pending|            ## also correct
```

### qw| | for scalar string values [ preferred ]
```perl
## ref comparisons — qw| | preferred over quotes
ref $result eq qw| HASH |            ## correct — project style
ref $buffer eq qw| ARRAY |           ## correct
ref $entry  eq qw| HASH |            ## correct

## return mode values
return { 'mode' => qw| true | }      ## correct — always qw| |
return { 'mode' => qw| false | }     ## correct

## general scalar assignments
my $name = qw| zenka |;              ## correct — qw| | for keywords

## do NOT flag qw| | on scalars as wrong — it IS the style
```

### qq| | for interpolation needs
```perl
qq|error: $err at line $line|;       ## when you need interpolation
```

### single quotes for literals
```perl
'fixed string'                       ## no interpolation needed
```

---

## column width

### 78 character limit
code and comments must fit within 78 columns. ptd enforces this.

### breaking long strings
ptd **cannot** automatically break up long strings. you must manually split them:

```perl
## wrong — exceeds 78 columns
"[module] failed to render system message: $result->{message}"

## correct — split with concatenation
"[module] render failed: "
    . $result->{message}
```

### check for violations
```bash
./bin/vc-changed-files -exc-len | grep modules/
```

---

## control flow

### early returns for guard clauses
```perl
return { 'mode' => qw| false |, 'data' => 'missing param' }
    unless defined $required_param;
```

### foreach with meaningful names
```perl
foreach my $task_file (@task_files) { ... }
```

### map/grep for transformations
```perl
my @names = map { $_->{name} } @tasks;
my @pending = grep { $_->{status} eq 'pending' } @tasks;
```

---

## error handling

### defensive coding
```perl
## check before use
unless ( -f $path and -r $path ) {
    return { 'mode' => qw| false |, 'data' => "not readable: $path" };
}

## eval for risky operations
my $result = eval { risky_operation() };
if ($@) {
    return { 'mode' => qw| false |, 'data' => "failed: $@" };
}
```

### file operations
```perl
open my $fh, '<', $path
    or return { 'mode' => qw| false |, 'data' => "cannot open: $!" };
```

---

## protocol-7 idioms

### route-send for cross-zenka calls
```perl
my $sent = <[protocol-7.route-send]>->(
    {   command   => qw| cube.web.render-template |,
        call_args => { template_path => $path, budget => 2000 },
        reply     => { handler => qw| my.handler |, params => {} }
    }
);
```

### callback pattern
```perl
<[base.callback.cmd_reply]>->(
    $reply_id,
    { 'mode' => qw| size |, 'data' => $output }
);
```

### time handling
```perl
my $start = <[base.time]>->(4);      ## high precision
my $elapsed_ms = (<[base.time]>->(4) - $start) * 1000;
```

---

## common pitfalls

### confusing data and code paths
```perl
<data.key>              ## data access
<[code.key]>            ## code call
```

### missing -> in hash/array access
```perl
<data.key>{sub}         ## wrong — missing ->
<data.key>->{sub}       ## correct
```

### wrong return format
```perl
return $value;                       ## wrong
return { mode => 'true', data => $value };  ## correct
```

### forgetting // for undefined safety
```perl
my $val = <data.key>;                ## may be undef
my $val = <data.key> // '';          ## safe default
```

---

## cli flag conventions

### single `-` prefix always — multi-character flags are fine, `--` prefix is not used:
```
-c          ## ok — single char
-check      ## ok — multi-char with single dash
--check     ## wrong — double dash not used in this project
```

## signature and versioning

### never modify signatures manually
use the signing system:
```bash
./bin/Protocol-7 sourcecode update-signatures
./bin/Protocol-7 sourcecode update-version
```

### pre-commit checklist
1. `bin/dev/ptd -c` passes on all modified modules (syntax check without reformat)
2. no manual signature lines added
3. all returns use proper mode/data hashref
4. no variable interpolation in log messages
5. column width ≤ 78 characters

---

## kimi-specific reminders

**when analyzing code:**
- look for existing patterns first
- follow the same indentation and spacing
- preserve comment style (lowercase, concise)

**when modifying modules:**
- make minimal changes
- keep diffs clean and focused
- prefer adding new modules over modifying core ones

**when creating modules:**
- one subroutine per file (protocol-7 convention)
- clear, descriptive names
- comprehensive but concise description header

---

## quick reference card

```perl
## call module
<[namespace.module.name]>->($arg)

## read data
<data.path.here>

## assign data
<data.path> = $value;
<data.path> //= $default;

## return success
return { 'mode' => qw| true |, 'data' => $result };

## return multi-line
return { 'mode' => qw| size |, 'data' => $content };

## return error
return { 'mode' => qw| false |, 'data' => $error };

## log message
<[base.log]>->(2, "format string %s", $var);

## check file
-f $path and -r $path

## safe eval
my $r = eval { operation() } // {};
```

---

## regular expressions [ critical ]

### delimiter hierarchy

**never use `//` or `s///` forms** — they obscure delimiter intent and complicate escaping.

preferred order based on pattern content:

```perl
## 1. pipes preferred (no pipes in pattern)
$path    =~ m|/var/log/.*\.txt$|;      ## correct — pipes
$filename =~ s|\.gguf$||i;               ## correct — pipes

## 2. braces when pipes exist in pattern
$html    =~ m{[|]};                      ## braces — pipe in pattern
$cmd     =~ s{\|}{ }g;                  ## braces — pipe in replacement

## 3. other delimiters as needed (parens, etc.)
$expr    =~ s(\(([^)]+)\))[$1]g;        ## parens for paren-heavy patterns
```

### matching

```perl
## correct — m||
if ( $path =~ m|/var/log/.*| ) { ... }
if ( $name =~ m{vl|vision}i ) { ... }   ## braces — pipe in pattern

## wrong — // form
if ( $path =~ /\/var\/log\/.*\/ ) { ... }
```

### substitution

```perl
## correct — s|||
$filename =~ s|\.gguf$||i;
$path     =~ s|^/tmp/|/var/|;

## correct — s{}{} when pipes present
$html =~ s{\|}{<pipe>}g;
$html =~ s{<([^>]+)>}{[$1]}gsx;          ## complex patterns — braces read better

## wrong — s/// form
$filename =~ s/\.gguf$//i;
```

### modifiers always explicit

```perl
m|pattern|i      ## case-insensitive
m|pattern|g      ## global match
s|old|new|gsx    ## global + single-line + extended
```

---

## style principles

1. **readability first** — code is read more than written
2. **consistency** — match surrounding code exactly
3. **explicitness** — no clever shortcuts, be clear
4. **defensiveness** — check inputs, handle errors
5. **minimalism** — smallest change that works

---

## composing injected javascript from template modules

when a perl module returns a `js_source` heredoc that is later embedded into a
larger js payload, do **not** pass that template string through `sprintf`.
template js commonly contains the `%` modulo operator, which `sprintf` will
try to interpret as a format specifier. instead, build the payload with
concatenation:

```perl
my $payload = $js_header . $template_js . $js_footer;
```

use `sprintf` only for the fixed skeleton pieces that have no literal `%`.

---

## web-browser userscript capture/replay quirks [ webkit ]

- `console_capture.install` runs at `init_view` [ pre-load ], so its
  DOCUMENT_START userscript is enough. `replay_capture.install` runs
  on-demand from `replay-record start` on an already-loaded page — the
  userscript alone would miss the current page, so install also does a
  fire-and-forget `run_javascript` of the same source. the in-page
  `__p7ReplayHooked` guard keeps the double injection idempotent.
- pages assign `window.__p7ReplayTarget` only after document-start, so
  capture listeners attach to `document` in capture phase [ events aimed
  at the target pass through ] and resolve the target at event time for
  x/y normalization.
- capture drops `e.isTrusted === false` events — synthetic replay events
  must never re-record themselves [ replay during active recording ].
- `register_script_message_handler` is per user-content-manager and NOT
  idempotent — re-registering the same channel errors. guard perl-side:
  `<web-browser.replay_capture.installed>->{$view_id}`.
- `web-browser.js_call` logs the entire js string at verbosity 2 — never
  pass KB-sized payloads or 10Hz polls through it. one-shot tiny checks:
  js_call [ graph-params pattern ]. large payloads / poll loops: call
  `$view->evaluate_javascript` directly [ run_js pattern ].
- neither `base.time` nor Time::HiRes is guaranteed loaded in the
  web-browser zenka — count `event.add_timer` ticks against the fixed
  poll interval for timeouts instead of wall-clock.
- after adding modules: `./bin/dev/gen-sub-whitelist web-browser`
  regenerates the whitelist [ scans modules/ via dep-graph, strips the
  signature — user re-signs ]. `base.list.subroutines` updates
  separately via the sourcecode console.

---

## %code presence checks and cross-namespace calls [ july 2026, critical ]

new primitives in `modules/base.code.*` and `modules/base.mod.exists` — use
these instead of raw `exists $code{'...'}` checks or identity proxies like
`<system.zenka.name> eq 'v7'`.

### why: the referenced-subroutine scanner

`base.referenced_subroutines.clear_from_disk` runs on every `reload`/`init`.
it regex-scans compiled source for **literal-quoted** `$code{'name'}`
patterns and reports ones with no matching `%code` entry into the
`undef-subs` buffer [ query live via `show-buffer undef-subs` ]. it clears
by actual `%code` definition [ `defined $code{$ARG}` — true for both a real
compile and a deferred stub ], not by file-existence on disk [ the old
check, which masked real bugs ].

consequence: writing `exists $code{'literal.name'}` directly in a module
**gets flagged by the scanner** even though the check itself is safe.

### the primitives

- `<[base.code.exists]>->('name')` — `%code` presence check via a dynamic
  key [ `$code{$sub_name}` with a runtime variable ]. invisible to the
  scanner by construction. use this for all presence checks.
- `<[base.code.call_expected]>->($condition, 'name', @args)` — call only if
  `$condition` true; if true but the sub is missing, logs a level-0 error
  [ the "should definitely be there" case ]. returns undef when condition
  false.
- `<[base.code.call_optional]>->('name', @args)` — call if present, silent
  skip if not. for genuinely best-effort integrations, no expectation
  either way.
- `<[base.mod.exists]>->('ns')` — checks `<base.p7_mod.loaded>->{$name}`,
  the ground-truth registry of which namespaces *this* zenka loaded. use
  this instead of `<system.zenka.name> eq 'v7'` when the real question is
  "is namespace X compiled into %code here".

### canonical usage patterns

```perl
## expected : guard by module registry, loud error if sub missing
<[base.code.call_expected]>->(
    <[base.mod.exists]>->(qw| v7 |),
    qw| v7.teardown |
);

## hard requirement : condition TRUE, errors if absent
my $pubkey_response = <[base.code.call_expected]>->(
    TRUE, qw| crypt.C25519.cmd.get-public-key |
);    ## see modules/auth.auth_select

## optional integration : silent either way
<[base.code.call_optional]>->(
    qw| channels.cmd.update |, { 'args' => "..." }
);

## presence check only
if ( <[base.code.exists]>->(qw| auth.auth_select |) ) { ... }
```

real examples: `base.sig_term` / `base.sig_int` [ v7.teardown ],
`base.buffer.add_line` [ p7-log ], `base.zenki.resolve_primary_sid`,
`auth.auth_select` [ crypt.C25519.cmd.get-public-key, expected=TRUE ],
`base.handler.auth` [ code.exists + call_optional ],
`base.ensure_zenka_dependencies` [ exists + call_optional ].

### caveat: renames must grep for sprintf-resolved names [ critical ]

before renaming or moving any module, grep the whole tree for
`sprintf.*<name-fragment>` constructions, not just literal `<[...]>` calls
and literal `$code{'...'}` references. dynamic resolution like
`sprintf('prefix.%s.suffix', $var)` is invisible to both grep-for-literal
and the referenced-sub scanner. this bit twice in one session:
`base.net.connect` and `base.handler.auth`'s cap-neg dispatcher — a rename
silently broke nshell's cube connect until caught by testing.

```bash
grep -rn 'sprintf' modules/ | grep -i '<name-fragment>'
```

---

## live-verifying send failure paths [ 2026-08-04, kimi zenka ]

`websocket.send` returns the written byte count on success, undef on
syswrite error — the correct send-confirmation check is
`defined $sent and $sent > 0` [ kimi.wire.approval_respond uses this after
the toctou fix : `kimi.approval.responded` is marked + persisted only
after a confirmed send, never before, or a reconnect silently swallows
the legitimate kimi-web re-send of the same approval request ].

the kimi zenka runs with `$SIG{PIPE}` at DEFAULT : an in-process write
test against a peer-closed socket kills the zenka. safe failure injection
for send paths via devmod eval-code : temporarily swap the socket data key
for a read-only filehandle — syswrite fails with EBADF, returns undef, no
signal, no die :

```perl
open my $rfh, '<', '/dev/null';
my $saved = <kimi.ws.socket>;
<kimi.ws.socket> = $rfh;
my $r = eval { <[kimi.wire.approval_respond]>->( 'test-id', 'approve' ) };
<kimi.ws.socket> = $saved;    ## restore even when the eval dies
close $rfh;
```

devmod.cmd.eval-code wraps source in `use warnings 'FATAL'` : any warning
becomes a die — wrap risky calls in an inner `eval {}` and restore swapped
state after it, never skip the restore on the failure path.

pipe() handles in the kimi zenka carry a `:utf8` layer : syswrite dies with
"syswrite() isn't allowed on :utf8 handles" — binmode BOTH ends right after
pipe() when using a pipe as a swapped capture socket. outbound frames decode
with `Protocol::WebSocket::Frame->new` + `->append($bytes)` + `->next`.

---

## kimi QuestionRequest decline pattern [ 2026-08-04 ]

`QuestionRequest` [ kimi-web AskUserQuestion ] is NOT approval-shaped : reply
is a json-rpc success response with result `{request_id, answers:{}}` — empty
answers resolve as "user dismissed", the tool returns a non-error result and
the model proceeds. never force-fit `kimi.wire.approval_respond` [ its result
fails QuestionResponse validation ]. use `kimi.wire.question_respond`.
kimi-web re-sends unanswered questions on every reconnect — answer each one,
no responded-set tracking needed. protocol details + live-verify notes :
[topic-kimi-question-request-decline.md](topic-kimi-question-request-decline.md)

---

## kimi api-child mini-protocol + reload gotchas [ 2026-08-04 ]

`kimi.session.start_api_child`'s persistent child speaks single-line verbs
[ verify / create / get / patch — get and patch reply `json <compact-json>`
on one line, errors prefixed `error ` ]. adding a verb = one more
`^cmd ...` regex branch in the child heredoc [ HTTP::Request for PATCH,
LWP::UserAgent has no ->patch convenience on this install ].

gotchas hit while wiring kimi.cmd.list-models / set-model :

- the child is a singleton : after editing the heredoc, `reload source` is
  NOT enough — the old child process still runs the old verbs. kill
  `<kimi.api_child.pid>` and undef the `r_fh` / `w_fh` / `pid` data keys to
  force a respawn on next call.
- cmd module bodies compile into a scope that already declares `$call` and
  `$reply` — a fresh `my $reply = ...` masks it and fires a "masks earlier
  declaration" compile warning on reload [ visible in `show-buffer zenka` ].
  use distinct names [ e.g. `$child_reply` ].
- `length $x and $y ? a : b` parses as `(length $x) and (...) ?: ...` :
  `and` binds looser than `?:`, leaving the ternary arms as void constants
  [ "useless use of a constant" compile warnings ]. use an if statement.
- access.cmd.usr.cube changes need `kimi.reload config` — `reload source`
  recompiles modules only, the access list comes from config.

---

## local inference from shell + scoring-harness gotchas [ 2026-08-04 ]

- shell env carries `http_proxy=http://10.0.110.7:4040` : curl to
  `127.0.0.1:8000` [ local llama-server ] gets proxied and returns empty
  502. always `curl --noproxy '*'` for localhost inference.
- the qwen3.5 server burns the whole `max_tokens` budget on reasoning
  unless you pass `"chat_template_kwargs": {"enable_thinking": false}`
  [ `reasoning_effort: low/none` does NOT stop it ]. with thinking off,
  a strict 4-line score card returns in ~14s.
- `coding_summarize` / `coding.cmd.summarize-context` hardwire a
  compaction-style system prompt [ `summarize_enqueue` ] — custom
  instructions in the prompt get ignored for file input. unusable as a
  generic scoring/judging endpoint; call the server directly instead.
- `consensus_query` routes by `<inference.backend.cpu.enabled>` [ set in
  configuration/zenki/coding/start ] — points at the cpu backend :8001
  which is usually down; `tree_write` can't flip it [ restricted to
  coding/context/observations/task namespaces ].
- `bin/Protocol-7 sourcecode test-sign-and-verify <paths>` signs scratch
  copies with a temp key [ no passphrase needed ] BUT regenerates
  `test-proto7-sourcecode` fresh per console invocation — footer values
  [ incl. amos-iterations-remaining ] are only comparable within ONE
  invocation. pass all variant paths space-separated in a single call.

---

## user-edit key-actions excursion — live pty test findings (2026-08-15)

Findings from the `script -qec` acceptance runs for the `key actions`
create-a-new-key excursion [ captures in /tmp/ue-keyact/ , task
data/tasks/user-edit-key-actions-create.md ]:

* STDIN watcher during blocking excursion — HOLDS. Check 1 typed an
  ordinary char into a form field first (watcher definitely exercised),
  then triggered the excursion: the blocking `base.term.ask` name prompt
  read its line cleanly — no double-read, no lost keystroke, no hang —
  and form typing worked identically after re-loop. The reasoning that
  the watcher can stay registered (Event not pumping between unloop and
  re-loop, term_restore/term_init toggling O_NONBLOCK+termios, the
  blocking read being the sole fd-0 consumer) is now live-verified, not
  just argued.
* Resume sites: the console.start site (first) was exercised with a
  real excursion, twice (duplicate-name failure AND genuine key
  creation). The offer_create site (second) was only exercised in its
  no-op fall-through: key_actions is gated on
  `<user-edit.unix_user> eq $record->{'name'}` [ self-record-only ], and
  the bootstrap path only fires for NONEXISTENT records, so a
  throwaway-record bootstrap can never show the row for invoker taeki —
  the combination is UI-unreachable except in the genuine fresh-install
  case where the admin's OWN record is missing. Untestable here without
  deleting taeki's live record (refused). The second site's code is
  call-symmetric with the verified first site.
* `keys.console.create` password-too-short/empty guard CANNOT be
  pre-empted: the passphrase is read INSIDE create via
  AMOS7::TERM::read_password_repeated, so on a short/empty passphrase
  create still hits `<[base.exit]>` (= CORE::exit) and kills the zenka.
  Accepted per task; documented in user-edit.excursion.key_create's
  header. The other four guards (empty name, validate_keyname,
  key_exists, Crypt::Mode::CBC presence) are pre-validated by the
  excursion before calling create.
* Draft side-effect: field_changed checkpoints persist the synthetic
  `key_actions` field as `key_actions: ''` — same shape as the
  pre-existing `identity_key: ''` precedent, harmless (submit deletes
  it, draft.load just reloads ''), but a before/after draft diff shows
  the added line. Left as-is for minimal change; restore the draft from
  backup after tests if a byte-identical draft matters.
* gen-sub-whitelist regen drops signature footers AND internally-called
  cmd/console subs (keys.console.create, crypt.C25519.cmd.get-public-key
  had to be re-inserted manually into subroutines.load-early).

---

## editor.control.prompt.* in-frame prompt — build + live findings (2026-08-16)

The blocking-excursion key-create flow was replaced by an event-loop-safe
in-frame prompt primitive [ task data/tasks/editor-inframe-prompt-primitive.md
].  what future work [ the deferred masked-field task ] needs to know:

* RENDER ANCHOR mechanism that shipped : prompt state lives in
  `$editor_state->{'prompt'}` [ per-state, never a %data keyword ].  the
  anchoring field's display_override [ plugin.user-edit.key-actions.render ]
  delegates to editor.control.prompt.render, which builds the display by
  calling editor.control.get_display_value / .get_display_cursor on a
  MINIMAL PSEUDO-STATE `{ fields => { prompt => $buf }, schema => { fields
  => [] } }` -- the one call shape that reuses the existing masked-stars
  machinery with zero new masking code [ empty schema => display_override /
  list branches skip themselves ].  render_form's generic cursor overlay
  EXCLUDES plugin-typed fields, so prompt.render draws its own '|' with the
  same overlay-on-reserved-trailing-cell convention.
* gen_keys / write_keys base.exit audit [ design anchor 3 ] : NEITHER calls
  base.exit -- failure modes are warn / return undef / return FALSE only.
  keys.console.create is no longer called by user-edit at all, closing the
  last base.exit-reachable path in key-create.
* NEW constraint found live : AMOS7::13::key_32 [ write_keys' enc-key
  derivation ] warns 'expected password length is at least 13 characters'
  and returns undef below 13 -- keys.console.create's own guard only
  checked `length <= 1`, so the OLD flow could run gen_keys and then fail
  mid-write [ write_keys leaves its `$name.$PID.<ntime>` tmp files behind
  on that path ].  user-edit.key_actions.submit_passphrase now validates
  >= 13 BEFORE gen_keys.
* REENTRANCY guard shape : `$editor_state->{'prompt'}{'busy'}`, set by
  prompt.handler.key around EVERY submit callback [ gen_keys's
  harmonic-truth loop re-pumps Event via event.once = a real Event::loop
  ], swallowing reentrant keys.  Replaced the global
  <user-edit.key_actions.busy>, retired with the excursion shape.
* Ctrl-C in plugin mode never reaches stdin_key's signal branch [ plugin
  routing claims every key ] ; the prompt additionally claims "\x03"
  explicitly as prompt-cancel.  NOTE for scripted pty tests : a trailing
  Ctrl-C sent while STILL in plugin mode is a swallowed no-op -- exit via
  insert-mode Ctrl-C or the harness kill.
* WHITELIST REGRESSION, third occurrence : crypt.C25519.cmd.get-public-key
  was missing from subroutines.load-early again [ gen-sub-whitelist regen
  drops it ].  symptom at startup : a flood of '[base.load_modules] no
  routines were loaded' then 'FATAL ERROR : deep recursion on anonymous
  subroutine [crypt.C25519.cmd.get-public-key:1]' [ on-demand compile
  failing + re-entering itself ].  fix = manual re-insert, again.

---

#,,,.,.,.,...,,.,,,,,,..,,.,.,..,,,,.,,,,,,..,.,.,...,..,,.,.,,..,,,.,,,,,,,.,
#NWQLM7XLTN2NIKOD3LND7OTL35ZXDZJV6WWBTGKK3G5UR7V5TICBFPCAUP2VBI2RQEED5553WQ3IU
#\\\|VLZDWUAEG3NDITWSNA25FSX2XW2ULF2GMMBAOW6JUHR5R4MXC7E \ / AMOS7 \ YOURUM ::
#\[7]3PDJ254PIFN7AWPKBVWNH6AGQJQ77VQHH7OA7XQHCN4JEA6ZE4CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
