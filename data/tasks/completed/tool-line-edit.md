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
- `modules/coding.tools.definitions` lines 465-503 — `replace_in_file`
  definition: exact format to follow for the three new tool definitions
- `modules/coding.tools.dispatch` lines 340-360 — `edit_file` dispatch
  handler: exact pattern to follow for the three new dispatch handlers

## where to add

coding.tools.definitions:
  append the three new `push @tools, { ... }` blocks after the
  existing `replace_in_file` block [ after line ~503 ]

coding.tools.dispatch:
  add three new entries to the dispatch hashref, alongside `edit_file`
  [ after the edit_file handler block ]

## path sanitization [ required — copy from edit_file pattern ]
  my $root     = <system.root_path>;
  my $abs_path = "$root/$path";
  my $real_path = Cwd::abs_path($abs_path) // '';
  my $real_root = Cwd::abs_path($root)     // '';
  return 'error: path escapes project root'
      if !length $real_path or index( $real_path, "$real_root/" ) != 0;
  return 'error: file not found' unless -f $real_path;

## file read/write using P7 base modules
  ## read into arrayref of lines [ each line retains its newline ] ##
  my $lines_ref = <[base.file.slurp]>->( $real_path, undef, ':encoding(UTF-8)' );
  return "cannot read: $path" unless defined $lines_ref;
  my @lines = ref $lines_ref eq 'ARRAY' ? @{$lines_ref} : split /\n/, ${$lines_ref};

  ## ... modify @lines ...

  ## write back with encoding ##
  <[base.file.write_encoded]>->( ':encoding(UTF-8)', $real_path, @lines );

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

#,,,.,,.,,,.,,,,.,,,,,,.,,,,,,,,,,,.,,.,,,,..,..,,...,...,.,.,,,.,...,,.,,,.,,
#AYO77UBG53GOQQ573QD5TPBQPEAWNXFV7NIS25ODB6A6OORFIAJX2Q55LLD2LQ5E7BGSJ625IPZYO
#\\\|SCNYNQC63WKKRXDCTRZAAXSJBUXPHPKSXMOH3JCXANEYWKYNBNY \ / AMOS7 \ YOURUM ::
#\[7]BZVKHKEUEEB6O3U4M2FUXKQ67LV4LTSMJALQ4UJP2OGBD67XZWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
