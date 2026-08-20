# task: implement valued.tree.persist and valued.tree.restore

## objective
create two modules:
- `src/valued.tree.persist` — save live valued tree to YAML on disk
- `src/valued.tree.restore` — load persisted tree back into memory

## read first
- `src/valued.init_code` — shows <valued.index> structure
- `src/task.persist.save` — reference for YAML persistence pattern
- `src/task.persist.load` — reference for YAML restore pattern

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

#,,..,,..,..,,,.,,,,.,,,,,.,,,.,.,,.,,...,,,,,..,,...,...,.,,,,,.,..,,,..,,..,
#JGMWN474QRJTONOICV4KER5LAF6E4CO2Z63IVE7K5YP3MJTNQJHSN7FEWZTYO6GY772M5QH2M7IYS
#\\\|TT2KIFVLO64F5JZZG666OE35HZCMCRQA57WDKWS4I65RCYPQX23 \ / AMOS7 \ YOURUM ::
#\[7]EDJQDOHTLYKY2FVLGNAA2B63P6NSC2EFBS63TTCN6YT7RTM6NCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
