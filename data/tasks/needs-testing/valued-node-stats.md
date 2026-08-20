# task: implement valued.cmd.stats

## objective
create `src/valued.cmd.stats` — returns a summary of the valued
tree: total nodes, average priority, highest and lowest priority node.

## read first
- `src/valued.resolve` — returns refs + weight for a node id
- `src/valued.cmd.list` — reference for iteration pattern

## what to implement

no params. iterates all nodes in `<valued.index>`, computes:
  total     — count of all nodes
  avg       — average priority (sum / count)
  highest   — { id, priority } of top node
  lowest    — { id, priority } of bottom node

return format: `{ 'mode' => 'size', 'data' => $str }` where $str is:
  "nodes: N  avg: X.XX  highest: ID (X.XX)  lowest: ID (X.XX)"

empty tree returns "no nodes".

#,,,.,,.,,,..,,..,.,.,...,...,.,,,,,,,,.,,,,.,..,,...,...,...,,..,,.,,.,.,,.,,
#UA5DXPXOKCMHADP6RBCH4W2M4N67HS6XYPBPGPPZBU2MY7R7ZZ4MA4URRC5KJFXBQ7S4NK3JBYQ7Q
#\\\|GRIO77LAYAZKYGKOYLSMYMMVBZJYFRCBKOC2AO3ESLJEJP7R3DP \ / AMOS7 \ YOURUM ::
#\[7]PXG3JR65J22IJHW5VJTVIAD3IGHZDFFOSF3D6QK2IOENYP6KBWAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
