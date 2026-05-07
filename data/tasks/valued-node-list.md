# task: implement valued.cmd.list

## objective
create `modules/valued.cmd.list` — a network command that returns all
valued tree nodes as a formatted list, sorted by effective priority.

## read first
- `modules/valued.resolve` — returns refs + weight for a node id
- `modules/valued.init_code` — shows <valued.index> structure
- `modules/task.cmd.show` — reference for cmd module return format

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

#,,,,,,,.,,.,,.,.,..,,...,,..,,.,,,,,,.,,,,.,,..,,...,...,.,.,...,..,,,,.,,.,,
#I22CZZ32AI2BI6DFYXASNDF3ABORRMISK6ECR47XJHFPFDB7NJ24OLJ5LGTIROIMXO3YTZO2TIIFW
#\\\|AMKTOYN7AGKEIQY5SW56ERB4BMVAQGHIMC3FJQMYDWQU3JYXHZB \ / AMOS7 \ YOURUM ::
#\[7]YPBRDOWQGX6Z6GK7UQB2UCFV7YDUN3Q7YWOQIR2H4Y32Z2O4IKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
