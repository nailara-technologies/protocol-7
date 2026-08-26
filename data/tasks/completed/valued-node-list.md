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

#,,,.,,,,,.,.,,..,,,.,,.,,,,.,..,,,,,,,,,,...,..,,...,...,.,.,..,,,,,,,..,,..,
#WU664V27JSML2G572M7SZSEKQTKVTHNZWTENEP3IGDE7FD3PEQUG2QOAVLURBTPDSUY3IRU2VG6PM
#\\\|RKJGVTSI54T2NFBVF6X6NQDXUVLK7LH6LLHQVTI4MWIJOEZG7UN \ / AMOS7 \ YOURUM ::
#\[7]THR2OUVI42MOXLV65CWUCDPW7DAMN5UKNCPM4T4NPL7L53UTQ2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
