# p7_memory_update MCP tool improvements

`bin/mcp-server-p7` tool `p7_memory_update` was updated to keep the main
`MEMORY.md` index readable and to stop inlining topic updates.

## Length guard

The main `MEMORY.md` index now has a soft limit of **180 lines** and a hard
limit of **200 lines**:

- appends that would push `MEMORY.md` past 200 lines are refused.
- appends that push it past 180 lines still succeed but prepend a warning.

This applies to both `data/ai-mem/claude/MEMORY.md` and
`data/ai-mem/kimi/MEMORY.md`.

## External topic files

A new `target` parameter lets the caller write directly to a file under
`data/ai-mem/<agent>/` instead of appending to `MEMORY.md`:

```json
{
  "mode": "apply",
  "agent": "kimi",
  "target": "topic-foo.md",
  "content": "..."
}
```

If `target` points to a file that does not exist, it is created with
`write_new_file`; otherwise the content is appended with `write_append`.

## UPDATE FILE directive

Apply-mode content starting with `UPDATE FILE: <filename>` is automatically
routed to that file. The directive line and common boilerplate
(`Replace the entire file content with the following ...`) are stripped
before writing.

This prevents the leak where a coding agent intending to update
`topic-credential-fabric-proxy-transport.md` instead appends the whole body
to `MEMORY.md`.

## Review mode

Review mode now honors `target`, so summarizing a topic file works the same
way as summarizing `MEMORY.md`.

## Agent scope

`agent` resolves to `claude` or `kimi` (or auto-detects from the MCP client
identity). All `target` paths are kept inside the selected agent's
`data/ai-mem/<agent>/` directory; paths containing `../` are rejected.

#,,.,,...,..,,...,.,,,,,.,,..,,,.,.,,,,,,,...,..,,...,...,.,.,...,..,,.,.,..,,
#DIYLRNLYUM2BX2QPQHVWDCYZJYN4ELMEQU2F42TUCUDE343JJRIVHJZ5ZMRAOL4426FU3NKY3RKDO
#\\\|WO2JGBDIHVLHH4LLQUJKZ5BXGPFLA274QWYJNDQ7CNEN2O54P3T \ / AMOS7 \ YOURUM ::
#\[7]GHXH2UW2XZDYALGCZTOL6R2AO7WN2ATLOKPAJHU7F4MH7NR6YEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
