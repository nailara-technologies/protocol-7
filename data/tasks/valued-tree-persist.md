# task: implement valued.tree.persist and valued.tree.restore

## objective
create two modules:
- `modules/valued.tree.persist` — save live valued tree to YAML on disk
- `modules/valued.tree.restore` — load persisted tree back into memory

## read first
- `modules/valued.init_code` — shows <valued.index> structure
- `modules/task.persist.save` — reference for YAML persistence pattern
- `modules/task.persist.load` — reference for YAML restore pattern

## valued.tree.persist

no params. serializes <valued.index> to disk:
  1. build a plain hashref from <valued.index> — strip any code refs
  2. serialize with <[format.yaml.dump_str]>->($data)
  3. write to zenka dir file 'valued-tree.yaml' via
     <[file.zenka_dir.write]>->( 'valued-tree.yaml', \$yaml_str )
  4. log count of nodes saved at level 1
  5. return TRUE on success, FALSE on failure

## valued.tree.restore

no params. loads persisted tree into live index:
  1. read file via <[file.zenka_dir.read]>->( 'valued-tree.yaml' )
  2. return FALSE [ no warn ] if file does not exist yet
  3. parse with <[format.yaml.load_str]>->($content)
  4. for each node entry: call <[valued.tree.register_node]>->($node_def)
  5. log count of nodes restored at level 1
  6. return count of nodes restored

## style
- $ARG not $_ in map/grep/foreach
- <[base.logs]>->( N, fmt, args ) for logging
- lowercase comments, [ word ] bracket annotations
- no use statements, no pragmas

#,,..,.,.,,.,,.,,,,,.,,,.,,.,,..,,.,,,.,,,..,,..,,...,...,...,,,,,,,.,,,.,,,.,
#47FXXSJSINN5NXUYAU7CQD463P6HZAEZ3SPQVNMLCATFIHE4S4G4666T2R4QXGFFXRVTWAZXCUV6U
#\\\|3UN4SG6EWNO74OWXASMQLBZMGNH77ZJ2SKF4I4ZYTULTZ2TCDVW \ / AMOS7 \ YOURUM ::
#\[7]CALZI5XO3DNN6K7ZIUHZJRKNS4A25FZ2VYLXRZAI6K4SUNSXJSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
