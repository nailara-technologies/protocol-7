# task: implement line-addressed edit tools

## objective
add three new tools to the coding zenka tool set:
- `replace_line` — replace exactly one line by line number
- `delete_lines` — delete a line range
- `insert_line` — insert a line before a given line number

these tools exist because `edit_file` fails on content mismatch when
the model's expected string doesn't exactly match the file — causing
multi-round correction loops. line-addressed tools bypass that entirely.

## read first
- `modules/coding.tools.definitions` — tool definition format
- `modules/coding.tool_executor` — how tools are dispatched
- `modules/coding.tools.file_ops` or similar — existing file tools
  [ use list_modules to find the right file tool module ]

## tool definitions to add [ in coding.tools.definitions ]

```
replace_line:
  description: replace a single line in a file by line number
  params:
    path: file path
    line: line number (1-based)
    content: replacement line content (without trailing newline)

delete_lines:
  description: delete a range of lines from a file
  params:
    path: file path
    from: first line to delete (1-based)
    to: last line to delete (1-based, inclusive) [ optional, defaults to from ]

insert_line:
  description: insert a line before a given line number
  params:
    path: file path
    line: insert before this line number (1-based)
    content: line content to insert (without trailing newline)
```

## implementation

each tool reads the file, modifies the line array, writes back.
use the same file read/write pattern as existing file tools.

for replace_line:
  - read file into @lines
  - validate line number in range
  - $lines[$line - 1] = "$content\n"
  - write back

for delete_lines:
  - read file into @lines
  - splice @lines, $from-1, ($to - $from + 1)
  - write back

for insert_line:
  - read file into @lines
  - splice @lines, $line-1, 0, "$content\n"
  - write back

all three: return "ok: <operation> on <path> line <n>" on success,
error string on failure.

## style
- $ARG not $_ in map/grep/foreach
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements, no pragmas

#,,.,,,,,,,.,,...,.,.,..,,,,,,.,,,,,.,,..,.,,,..,,...,...,.,,,.,,,,,.,...,,,,,
#DIDQ7GOXSAMKQWP3PLAKX3FGNMZEIAB4SUKOJMXJOAKDCGDP4VG4JE74YSNGDBPAER5YXHT4IUA3I
#\\\|QZJZIUU42XSQVVWJRHHQAXNUYG2O42IHGSWGANKOBSDKYFSPTX6 \ / AMOS7 \ YOURUM ::
#\[7]5D2Z6N6R6BY777YSPRGGMBJV3WQKTAGKURKJKO64FJDMQEV5VCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
