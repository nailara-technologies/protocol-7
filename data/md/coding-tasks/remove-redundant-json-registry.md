# Remove Redundant JSON Registry System

## Current State
Two registry systems exist:
1. **JSON** (`models.registry.load.load_registry`, `save.save_registry`, `base.get_registry`)
2. **YAML** (`models.storage.yaml_load`, `yaml_save`)

Both now use flat format: `{ <id> => {...} }`

## Files to Remove/Consolidate
- `modules/models.registry.load.load_registry`
- `modules/models.registry.save.save_registry`
- `modules/models.registry.base.get_registry`
- `modules/models.registry.base.save_registry_internal`
- `modules/models.registry.empty.create_empty_registry`

## Callers to Update
- `modules/models.registry.get_entry.get_model_entry` - use `<models.registry>`
- `modules/models.registry.list_all.list_all_models` - use `<models.registry>`
- `modules/models.registry.update_entry.update_model_entry` - use `yaml_save`

## Migration Path
1. Ensure YAML registry has all data from JSON
2. Update callers to use `<models.registry>` directly
3. Remove JSON modules
4. Update `base.list.subroutines`

## Note
JSON path: `/var/protocol-7/models/registry.json`
YAML path: `var/zenka/models/registry/models.yaml`

#,,,.,,,,,..,,..,,,..,...,,,,,.,,,,..,.,.,.,.,..,,...,...,..,,.,.,.,.,.,,,.,.,
#PBTCW57QAP7BKW2RPDTIWO5ZJHDS3VJD6ESQJS64PSLCHFHQVOPTEEWZCWAGMFFNSVZENXWH66UMS
#\\\|F7JGDBE2OGD6DDKTQ6JJOKPMDPY7NADLQSHOYORJJ5DUX27SZAQ \ / AMOS7 \ YOURUM ::
#\[7]OWY7EDKC6ZZTHQZXX25VKVPIHJKJGLNYZFU4BWXI5EYTUDHR6SAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
