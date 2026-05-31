## task: add `template` parameter to kimi_dispatch and claude_dispatch

### goal

add an optional `template` parameter to `kimi_dispatch` and `claude_dispatch`
(and their `_continue` variants) that resolves a named context template and
prepends it to the prompt before dispatch. mirrors the `template=` support
already present in `p7_agent_spawn`.

---

### background

`data/yaml/context-templates/` holds named YAML templates (e.g.
`kimi-dispatch-workflow.yaml`, `code-review.yaml`). these are resolved by
the `kimi-web` zenka via `kimi-web.resolve_template template=<name>`. the
resolved content is a multi-section text block suitable for injecting into
the start of an AI prompt as context.

`p7_agent_spawn` (line ~1181 in `bin/mcp-server-p7`) already accepts
`template=` and passes it through to the cube command. for `kimi_dispatch`
and `claude_dispatch` the template must be resolved in-process and prepended
to the prompt string before the CLI is invoked.

---

### where to implement

**file**: `bin/mcp-server-p7`

**section**: `tool_external_command` (~line 1689), specifically the block
that builds the command from params.

**also**: the `@external_tools` definitions for `kimi_dispatch`,
`claude_dispatch`, `kimi_continue`, `claude_continue` — each needs a new
optional `template` param entry.

---

### implementation spec

**step 1 — add `template` param to tool definitions** (~line 50–119)

for `kimi_dispatch`, `claude_dispatch`, `kimi_continue`, `claude_continue`,
add an optional param (required=0) after the existing params:

```perl
[   'template',
    'name of a context template from data/yaml/context-templates/ '
        . 'to prepend to the prompt (e.g. "kimi-dispatch-workflow")',
    0
],
```

**step 2 — skip `template` in shell command building** (~line 1709)

add `template` to `%skip_in_cmd`:

```perl
my %skip_in_cmd = map { $_ => 1 } qw( auto_summarize template );
```

**step 3 — resolve and prepend** (~line 1711, after `%skip_in_cmd` and
before the params loop)

```perl
## template: resolve and prepend to prompt before dispatch ##
if ( length( $args->{'template'} // '' ) ) {
    my $tname = $args->{'template'};
    my ( $tok, $tresult )
        = cube_command("kimi-web.resolve_template template=$tname budget=4000");
    if ( $tok and length $tresult ) {
        $args->{'prompt'} = "$tresult\n\n---\n\n" . ( $args->{'prompt'} // '' );
    } else {
        ## non-fatal: log and continue without template ##
        log_msg("template resolve failed for '$tname' — dispatching without");
    }
}
```

**notes**:
- `cube_command` is already used throughout the file — no new imports
- `kimi_continue` and `claude_continue` use the `legacy format` (param_name
  / param2_name) not the `params` array — their `template` param will need
  to be handled separately if they switch to the params array, or can be
  injected the same way by reading `$args->{'template'}` directly before
  the legacy param block
- `budget=4000` matches what `tool_template_resolve` uses (line 1241)
- use `$ARG` not `@_` throughout; lowercase comments; bracket annotations

---

### verify

```bash
grep -n "skip_in_cmd\|resolve_template\|param_name\|param2_name" bin/mcp-server-p7 | head -20
```

confirm: `kimi_continue` / `claude_continue` use the legacy format — handle
their `template` param in the same pre-command block, not in the params loop.

---

### test plan

```bash
## resolve a template manually to confirm cube command works
p7c kimi-web.resolve_template template=code-review budget=2000

## dispatch with template — confirm template preamble appears in kimi output
## (auto_summarize=false keeps raw output visible for inspection)
## [ dispatch a tiny task so output is short ]
kimi_dispatch prompt="what files are in data/tasks/?" template=kimi-dispatch-workflow auto_summarize=false
```

expected: the resolved template text appears at the start of what kimi receives,
followed by `---` separator and then the actual prompt.

---

## signatures_note

do not add or modify the 4-line `#,,,` signature block at the end of module
files. `bin/mcp-server-p7` is a standalone script with no signature block.
leave module signing to `bin/Protocol-7 sourcecode update-signatures`.

---

### dispatch

model: kimi
reasoning: low

prompt: |
  implement the task at data/tasks/dispatch-template-param.md

  read bin/mcp-server-p7 lines 50-145 (external_tools definitions) and
  lines 1689-1735 (tool_external_command) carefully before writing anything.

  pay special attention to: kimi_continue and claude_continue use the
  legacy param_name/param2_name format (not the params array) — handle
  their template param by reading $args->{'template'} directly in the
  pre-command block rather than through the params loop.

  follow existing code style: $ARG not @_, lowercase comments, bracket
  annotations [ like this ].

#,,,.,.,,,,,,,.,,,...,,,.,,..,..,,.,,,,..,,,.,..,,...,..,,..,,.,,,.,.,,,,,,,.,
#GBDWTDQNA2OZ3FWMOKCTSX6N2535VBBN5ZXZLYO77G7MT6OKAPVI7MSWXNWBXAQACCU2XCGCRUUTY
#\\\|T2RSX3UWXN7GECNZO2KTZTO5JNSMCS6YNCMJFUWPEN7FGB2N2L5 \ / AMOS7 \ YOURUM ::
#\[7]TJJJDCFJAEXDSBHEP6YDB5HEU2DCGH45ZQMRA2IKWSPGNSSILEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
