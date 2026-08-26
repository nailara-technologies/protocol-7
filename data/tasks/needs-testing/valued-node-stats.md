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

#,,.,,,.,,,,.,.,,,,,.,...,..,,,,.,,..,.,,,.,.,..,,...,..,,,..,.,.,,..,.,.,.,,,
#SZ7SM5KEBNJV5PAUHSYQL3OJSLGX5IFH4D63UFYRZHLLY5RNZX6DTXVFCMOJNO6GJFZT6XKJ76GW6
#\\\|WSSWXTBKMFL54CDQIE7TYODMCPB2PREFZIIJZUZK2K33BZ4LUN6 \ / AMOS7 \ YOURUM ::
#\[7]JW2QKCQ7YXWXZPFXMQ5LNJOTX5S7WWVGXE2SKLCRTE3YJFK5CEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
