## task: add claude_dispatch + claude_continue to bin/mcp-server-p7

### motivation

`kimi_dispatch` / `kimi_continue` run tasks on the local 9B model — free but
limited in reasoning quality. a `claude_dispatch` / `claude_continue` pair adds
an async high-quality dispatch path using the Claude Code CLI, callable from
anywhere in the P7 network (nshell, p7c, coding zenka self-improvement, etc.).

key difference from the built-in Agent tool: async + non-blocking. dispatch a
task and continue working; collect the result later via claude_continue.

---

### cli invocation pattern

dispatch (new session):
```bash
claude -p "$prompt" \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --model "$model" \
    --max-budget-usd "$max_budget"
```

continue (resume session):
```bash
claude -r "$session_id" \
    -p "$additional_prompt" \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --model "$model" \
    --max-budget-usd "$max_budget"
```

the stream-json output contains a `session_id` field in the final message.
extract it with a regex: `"session_id"\s*:\s*"([^"]+)"`.

---

### new MCP tools to add in bin/mcp-server-p7

follow the same pattern as `kimi_dispatch` / `kimi_continue` (lines ~48-75).
add immediately after the kimi tools.

#### claude_dispatch

```perl
{   'name'        => 'claude_dispatch',
    'description' =>
          'dispatch a task to Claude Code CLI in non-interactive mode. '
        . 'runs claude -p with --dangerously-skip-permissions and returns '
        . 'combined output. the result contains a session ID line: '
        . '"session_id: <uuid>" — pass that to claude_continue to resume.',
    'command'     => undef,    ## custom handler — see below
    'params'      => [
        [ 'prompt',      'the task or question for claude to work on', 1 ],
        [ 'model',       'model: haiku|sonnet|opus (default: sonnet)',  0 ],
        [ 'max_budget',  'max USD to spend (default: 1.00)',            0 ],
    ],
    'timeout'     => 2400,     ## 40 minutes
},
```

#### claude_continue

```perl
{   'name'        => 'claude_continue',
    'description' =>
          'resume a claude_dispatch session by session ID. '
        . 'pass the session_id from the previous dispatch result. '
        . 'sends a new prompt and returns the additional output.',
    'command'     => undef,    ## custom handler — see below
    'params'      => [
        [ 'session_id',  'the session UUID from the prior dispatch result', 1 ],
        [ 'prompt',      'the next instruction for the resumed session',     1 ],
        [ 'model',       'model: haiku|sonnet|opus (default: sonnet)',       0 ],
        [ 'max_budget',  'max USD to spend (default: 1.00)',                 0 ],
    ],
    'timeout'     => 2400,     ## 40 minutes
},
```

---

### custom handler implementation

the `kimi_dispatch` tool uses `'command' => 'kimi -y -p %s'` which is
shell-substituted and run via the generic `_run_ext_tool` sub. `claude_dispatch`
needs a similar but slightly richer command builder. two options:

**option A (preferred): command template string**

add to the dispatch entry:
```perl
'command' => 'claude -p %s --dangerously-skip-permissions '
           . '--output-format stream-json --model %s --max-budget-usd %s',
```

with arg ordering: prompt, model, max_budget.

in the MCP dispatch handler, before calling `_run_ext_tool`, resolve defaults:
```perl
$args->{'model'}      //= 'sonnet';
$args->{'max_budget'} //= '1.00';
```

then pass three shell-quoted args to the `%s` substitutions.

**option B: inline handler**

handle `claude_dispatch` as a special case in the dispatch loop (like how
`kimi-web.dispatch` is handled separately around line ~1060). build the command:
```perl
my $model      = $args->{'model'}      // 'sonnet';
my $budget     = $args->{'max_budget'} // '1.00';
my $safe_prompt = quotemeta( $args->{'prompt'} // '' );
my $cmd = "claude -p $safe_prompt "
        . "--dangerously-skip-permissions "
        . "--output-format stream-json "
        . "--model $model "
        . "--max-budget-usd $budget";
```

prefer option A if the `_run_ext_tool` sub can handle 3 `%s` substitutions.

---

### session ID extraction

after the command completes, extract the session ID from the combined output
and append a clean line for the caller to parse (same as kimi's resume line):

```perl
my $session_id = '';
if ( $output =~ m{"session_id"\s*:\s*"([a-f0-9\-]{36})"} ) {
    $session_id = $1;
    $output .= "\nTo resume this session: claude -r $session_id\n";
}
```

---

### model aliases

accept shorthand aliases in the model parameter:

```perl
my %model_map = (
    'haiku'  => 'claude-haiku-4-5-20251001',
    'sonnet' => 'claude-sonnet-4-6',
    'opus'   => 'claude-opus-4-7',
);
$model = $model_map{$model} // $model;    ## pass-through if already a full ID
```

---

### claude_continue command

```perl
'command' => 'claude -r %s -p %s --dangerously-skip-permissions '
           . '--output-format stream-json --model %s --max-budget-usd %s',
```

arg order: session_id, prompt, model, max_budget.

---

### tool descriptions for MCP (shown to calling LLMs)

`claude_dispatch`:
> dispatch a task to Claude Code CLI in non-interactive mode. high-quality
> async dispatch for complex multi-file code tasks, architecture decisions, or
> tasks requiring deep reasoning. specify model=haiku for cheap mechanical work,
> model=sonnet (default) for general tasks, model=opus for maximum quality.
> the result ends with "To resume this session: claude -r <uuid>" — pass that
> uuid to claude_continue to resume a long-running task.

`claude_continue`:
> resume a claude session by session ID and send a new prompt. use when
> claude_dispatch output ends with a resume line. claude resumes with full prior
> context and acts on the new prompt.

---

### cost awareness

- haiku: ~0.25 USD/MTok input, ~1.25 USD/MTok output — cheap for mechanical tasks
- sonnet: ~3 USD/MTok input, ~15 USD/MTok output — good default
- opus: ~15 USD/MTok input, ~75 USD/MTok output — only for highest-quality work

`max_budget_usd` defaults to 1.00 — sufficient for most tasks. caller can
raise for long sessions. the CLI will abort if budget is exceeded.

---

### in bin/mcp-server-p7: where to add

1. add the two tool entries to the `@ext_tools` array after the `kimi_continue`
   entry (around line 72)
2. if using option A (command template), verify `_run_ext_tool` supports 3+
   positional `%s` args — if not, extend it
3. add session ID extraction after the command completes in the tool handler
4. add model alias resolution before command construction

read the current `_run_ext_tool` implementation and the kimi tool entries
carefully before making changes. the kimi tools use `String::ShellQuote` or
similar for shell quoting — use the same approach.

---

## signatures note

do NOT manually write or edit signature lines. do not add stubs to new files.

## dispatch

#,,,,,,..,,.,,,..,.,,,..,,,,,,,,.,..,,...,,,.,..,,...,...,..,,.,,,..,,,..,..,,
#KV66SMOX3RACHET7NSUWVXW3TICCUN42SIILOI3KVV4PVQ5G63AN6L6VLVXI5QS3PISEGMF4UHH7E
#\\\|4XRXED56AMY7QMPBZBIMHLZYDDABZSLFMFA7KN5I3QOJ6SRTW7Q \ / AMOS7 \ YOURUM ::
#\[7]64IHLEL4Q6MQUREJUT3H7Q24XJBT7566RQC4KCGDLGAM4YHIN2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
