# task: implement valued.tree.top_n

## signatures note
do NOT add the single-line `#,,.,,,...` stub. leave files clean.

## data key syntax reminder
`<valued.index>->{$id}` not `$data{'valued.index'}{$id}` — dotted
keys in %data use `<key.sub>->{}` syntax, parsed to nested form.
`<[module.name]>->($arg)` to call a module with args.

## objective
create `src/valued.tree.top_n` — return the N nodes with highest
effective priority, with optional parent-branch filter.

## read first
- `src/valued.resolve` — returns refs + weight for a node id
- `src/valued.node.create` — shows node structure:
  { id, refs, weight, parents => [], children => [] }
- `src/valued.init_code` — shows storage:
  `<valued.index>` is hashref { id => node_href }

## what to implement

params (hashref):
  n       — how many nodes to return [ default 10 ]
  parent  — optional: only include nodes whose parents list contains
             this id (direct children of a branch)
  type    — optional: filter by node type field if set on the node

logic:
1. iterate all nodes in `<valued.index>`
2. apply parent filter if given — check `$node->{'parents'}` arrayref
3. apply type filter if given — check `$node->{'type'}` field
4. sort by `<[valued.resolve]>->($id)` descending
5. return first N as arrayref of hashrefs:
   [ { id => ..., refs => ..., weight => ..., priority => ... }, ... ]

return format: `{ mode => 'size', data => $formatted_str }`
where $formatted_str is one line per node:
  "PRIORITY  ID  (refs=N weight=F)"
sorted highest first.

## style
- `$ARG` not `$_` in map/grep
- `<valued.index>->{}` for dotted data keys
- `<[base.logs]>->( N, fmt, args )` for logging
- lowercase comments, `[ word ]` bracket annotations

#,,.,,,..,.,.,..,,.,.,,.,,,,.,..,,,,,,,,.,.,.,..,,...,...,.,.,.,.,...,.,.,.,,,
#7WVAQKPWQIQ6M7PUWCAEY3XEHYLV2QK6PLBCQJV3WGEVWIR2YGVJOWD5OJ262TGENOAESEPVWON5O
#\\\|4IMIGGXG5ZGOFW2YSON3PY4JMTPQXFS5C44DLPYTYPKYNT7HVVN \ / AMOS7 \ YOURUM ::
#\[7]JI3MOZE4WOBEZSHHZQTC32X7VD7N2GIXZM3GSRQP7UFQHCONO4AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
