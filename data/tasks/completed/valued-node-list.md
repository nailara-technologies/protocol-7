# task: implement valued.cmd.list

## objective
create `src/valued.cmd.list` — a network command that returns all
valued tree nodes as a formatted list, sorted by effective priority.

## read first
- `src/valued.resolve` — returns refs + weight for a node id
- `src/valued.init_code` — shows <valued.index> structure
- `src/task.cmd.show` — reference for cmd module return format

## what to implement

no params required. iterates all nodes in `<valued.index>`,
sorts by `<[valued.resolve]>->($id)` descending, returns formatted list.

one line per node:
  "%.2f  %-28s  refs=%-3d weight=%.3f"

return: `{ 'mode' => 'size', 'data' => $formatted_str }`

## acceptance
- `p7c valued.list` returns all nodes sorted highest priority first
- empty tree returns 'no nodes' message
- correct return format: mode=size, data=string

#,,,,,.,,,,,.,,,,,,,.,,,.,,,.,.,.,...,...,,.,,..,,...,..,,.,.,.,.,.,.,,.,,...,
#F6OPFIOA7MHJD45CHUFIXGY2OXUEFX3OKD32CGZ4GFYTQ6P73ATIF6CNYDPPQLTFB7L5KOSDKMLJG
#\\\|MYIJJA34HBWLWAA74JHU5EXL4QMPCJXHCZIPLRPPP75HZJKM5VO \ / AMOS7 \ YOURUM ::
#\[7]FRUG3EYOD6NWUWFIAXTJW5ES46ISVHDOJ7UQEC2NMGQ4CZTJHABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
