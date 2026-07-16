## task: mcp-server-p7 — config-driven external command tools

### context

`bin/mcp-server-p7` is a stdio MCP server exposing P7 network commands as
tools. currently all tools are hardcoded in `@tools` and dispatched via an
`elsif` chain.

the goal is to add a **config-driven external command table** — a YAML or
inline config that maps tool names to shell commands with descriptions. each
entry becomes a callable MCP tool. the primary use case is exposing `kimi`
dispatches (and similar CLI tools) directly from the MCP interface, so Claude
Code and other MCP clients can call them without a zenka integration.

### what to read first

```bash
head -80 bin/mcp-server-p7              ## configuration block + @tools start
sed -n '390,440p' bin/mcp-server-p7     ## tool dispatch elsif chain
grep -n 'sub tool_' bin/mcp-server-p7   ## existing tool implementations
```

---

### phase 1: external command config table

add a config section near the top of `bin/mcp-server-p7` (after the existing
`##[ configuration ]##` block):

```perl
##[ external command tools ]##

my @external_tools = (
    {   name        => 'kimi_dispatch',
        description => 'dispatch a task to the local kimi AI agent. '
            . 'runs kimi with auto-approval (-y) and returns combined output. '
            . 'use for code implementation, analysis, or research tasks.',
        command     => 'kimi -y -p %s',   ## %s = shell-quoted prompt arg
        param_name  => 'prompt',
        param_desc  => 'the task or question for kimi to work on',
        timeout     => 300,               ## seconds
    },
    ## additional external tools can be added here
    ## format: name, description, command (%s = shell-quoted first arg),
    ##         param_name, param_desc, timeout
);
```

this table is the single place to add new external command tools. each entry
automatically gets registered as an MCP tool and handled by the generic
dispatch.

---

### phase 2: register external tools in @tools

after the existing `@tools` array definition, append entries from
`@external_tools`:

```perl
for my $ext ( @external_tools ) {
    push @tools, {
        'name'        => $ext->{'name'},
        'description' => $ext->{'description'},
        'inputSchema' => {
            'type'       => 'object',
            'properties' => {
                $ext->{'param_name'} => {
                    'type'        => 'string',
                    'description' => $ext->{'param_desc'},
                }
            },
            'required'             => [ $ext->{'param_name'} ],
            'additionalProperties' => \0,
        },
    };
}
```

---

### phase 3: dispatch handler

in the tool dispatch elsif chain, add a catch for external tools:

```perl
} elsif ( my ($ext) = grep { $_->{'name'} eq $name } @external_tools ) {
    tool_external_command( $id, $args, $ext );
```

implement `sub tool_external_command`:

```perl
sub tool_external_command {
    my ( $id, $args, $ext ) = @ARG;
    my $param  = $args->{ $ext->{'param_name'} } // '';
    my $cmd    = sprintf( $ext->{'command'}, quotemeta($param) );
    my $output = '';
    my $error  = '';

    ## run with timeout, capture stdout+stderr
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm( $ext->{'timeout'} // 120 );
        $output = qx($cmd 2>&1);
        alarm(0);
    };
    if ( $@ ) {
        $error = $@ eq "timeout\n"
            ? "command timed out after $ext->{'timeout'}s"
            : "error: $@";
    }

    my $result = length($error) ? $error : $output;
    reply_tool_result( $id, $result );
}
```

use `String::ShellQuote::shell_quote` if available, otherwise `quotemeta` is
acceptable for the prompt string.

---

### notes

- the `kimi_dispatch` tool is the primary motivation but the table should be
  generic enough to add other CLI tools (e.g. `p7c`, `bin/chat`) later
- timeout default 120s, kimi tasks use 300s since they can be long-running
- stdout and stderr are merged (2>&1) — kimi writes progress to stdout
- the tool name in MCP must be unique — check against existing `@tools` names
  before adding
- the `p7_list_tools` tool should include external tools in its output
  automatically (it iterates `@tools` which now includes them)
- no signature stubs, this is a standalone Perl script not a P7 module

### success criteria

- [ ] `kimi_dispatch` appears in MCP tool list
- [ ] calling `kimi_dispatch` with a prompt runs `kimi -y -p <prompt>`
- [ ] output is returned as tool result
- [ ] timeout fires cleanly without hanging the MCP server
- [ ] adding a new entry to `@external_tools` is the only change needed
      to expose a new CLI tool

### dispatch

model: kimi
reasoning: low

prompt: |
  Implement the task at data/tasks/mcp-server-p7-external-commands.md

  Read the configuration block, @tools array, and tool dispatch section of
  bin/mcp-server-p7 before writing anything. Follow the existing code style
  exactly. Add the @external_tools config table, register entries into @tools,
  and implement tool_external_command. No signature stubs (this is a script,
  not a P7 module).

#,,,.,,,.,...,.,,,,.,,,,,,.,.,,,,,,,.,..,,...,..,,...,...,..,,.,.,,..,...,,.,,
#23S2WCSUGUTZLYDRP2DYRDUPPVXYTA3N2D4NCVMZAQPQYDID6WWYS5XPXO74JLSXVQL72Z6Q2QC62
#\\\|EG76GC5YXEGU2G4XCPXIKYM475ASVPB5TKFDC2A3IY2S6GVPM5E \ / AMOS7 \ YOURUM ::
#\[7]LUCJEDTYBGXNPCVLWINFLCO2U5YYTTTG4XHQRNHBQKNBGUGP5CBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
