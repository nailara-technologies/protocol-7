# task: implement valued.cmd.stats

## objective
create `modules/valued.cmd.stats` — returns a summary of the valued
tree: total nodes, average priority, highest and lowest priority node.

## read first
- `modules/valued.resolve` — returns refs + weight for a node id
- `modules/valued.cmd.list` — reference for iteration pattern

## what to implement

no params. iterates all nodes in `<valued.index>`, computes:
  total     — count of all nodes
  avg       — average priority (sum / count)
  highest   — { id, priority } of top node
  lowest    — { id, priority } of bottom node

return format: `{ 'mode' => 'size', 'data' => $str }` where $str is:
  "nodes: N  avg: X.XX  highest: ID (X.XX)  lowest: ID (X.XX)"

empty tree returns "no nodes".

#,,,.,,,,,...,...,,,,,,,,,,.,,,,,,...,..,,.,.,..,,...,...,.,,,...,..,,,.,,,,,,
#XEC6TCAUNQ4B6KADQDHUZ2ULKEYHR7FSOT3A7XG6J2U2VKEXFI5XUWZE3E4NREFXBYEABXRMLRV4O
#\\\|PE7KFP2NSF4CZKHY74ZZLGIDZDSDOI7OOYJ5XGRPJGX2AVDEIJB \ / AMOS7 \ YOURUM ::
#\[7]3XNLYWPMJEXFOWKNQKJ5UP6JSXLRQSNUUHAVLKERHDRQAM2ZQKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
