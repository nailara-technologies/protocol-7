## task: valued.cmd.query

Create module `modules/valued.cmd.query` — network command wrapper around `valued.tree.top_n`.

### context

`valued.tree.top_n` is an internal sub (called as `<[valued.tree.top_n]>->($params)`).
It accepts a hashref: `{ n => int, parent => str, type => str }` and returns a formatted
string of top-N nodes sorted by priority.

`valued.cmd.query` exposes this as a p7c-callable command with param parsing.

### reference modules

- `modules/valued.tree.top_n` — the sub being wrapped; see its params and output format
- `modules/valued.cmd.list` — pattern for cmd wrapper returning `{ mode => 'size', data => $output }`
- `modules/task.cmd.next` — param parsing with multiple optional fields

### spec

**params** (HASH path preferred, fallback to positional args):
- `n`      — max results, default 10
- `parent` — filter by parent node id, default '' (no filter)
- `type`   — filter by node type, default '' (no filter)

**positional args fallback**: first token = n (if numeric), ignore parent/type

**logic**:
1. parse params (hash path first, then args fallback)
2. validate n is a positive integer, clamp to range 1..100
3. call `<[valued.tree.top_n]>->({ n => $n, parent => $parent, type => $type })`
4. the sub returns a formatted string already — use it directly
5. if result is empty/undef, return 'no nodes'
6. return `{ mode => 'size', data => $output }`

### style notes

- lowercase comments
- follow valued.cmd.list style exactly
- do NOT add the `#,,.,,,...` stub

### signatures note

Do NOT copy or invent AMOS7 signatures. Leave the file clean — real footer added by
`bin/Protocol-7 sourcecode update-signatures`. Never add the fake `#,,.,,,...` stub.

#,,.,,..,,,..,.,,,,.,,,,.,,,,,...,.,.,...,,,,,..,,...,..,,...,,,,,...,.,.,..,,
#RQMGZZBGAGG7WBYXMKTAHK7XULBQBD7DGAQK5D5WNDR3YBTV6JLXWNWXOXNPYJT627JLNJUXKUTYA
#\\\|AEGCMEVCEE3YR4KLUEY6KBAZHMX7TCDEI5KFBWKSGF2JXCZJJDK \ / AMOS7 \ YOURUM ::
#\[7]KVA7WPSYZZNXGJLY3UPCPAWTDBLODMHQ2A5GXSXXIRPLYNNEZGBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
