
 .:[  invoke.ai : model storage management and lazy retrieval  ]:.

## Context

An invoke.ai path/UUID bug caused deletion of ~500GB of models from external disk.
Recovery script `bin/scripts/invoke-ai/invoke-model-recover` was created by kimi to
re-download from HuggingFace using metadata from the invoke SQLite database.

As the model collection expands, selective download and space management are needed.
This task documents the planned upgrade path from manual scripts toward automated
zenka-managed lazy model storage.

## Phase 1 : invoke-model-recover Enhancements [ script ]

### Default Behaviour Change

Without flags: list downloadable models with sizes and AMOS7 checksum IDs.
Currently requires explicit `-list` flag.

### AMOS7 Checksum IDs

Load AMOS7 via `BEGIN { }` lib path setup (same pattern as `bin/amos-chksum`).
Generate a stable AMOS7 ID per model from source URL or canonical name —
gives a consistent selector that survives database rebuilds.

```
 : amos-id :.    : name :.                          : size :.
--------------------------------------------------------------
  AB3XY7Q     qwen_openthoughts_science_claude       6.3 GB
  MK29RLP     claudette-7b                           4.1 GB
  ...
```

### Selective Download

Accept AMOS ID(s) or `:all:` as positional args instead of / alongside names:

```bash
invoke-model-recover                      # list only [ default ]
invoke-model-recover :all:                # download all
invoke-model-recover AB3XY7Q MK29RLP     # download selected by id
invoke-model-recover -download modelname # existing name-based still works
```

### Progress Bar Style

Adopt `bin/dev/ptd` visual style for download progress ( `-bar -sot -ce -l=78` ).
`ptd` is already Perl + LWP-compatible — reuse its bar rendering approach.

## Phase 2 : Zeroing / Space Reclamation [ script ]

### Zeroed State

Truncate unused model files to 0 bytes to reclaim space while preserving the
filesystem entry. Test invoke.ai behaviour with 0-byte file first:

- if invoke handles missing better than zero → rename with `.z` suffix to mark
  as zeroed, original path becomes missing
- if zero is fine → truncate in place, no rename needed

Three explicit states:
```
present   → file exists, size > 0     [ normal ]
zeroed    → file exists, size = 0     [ reclaimed, re-downloadable ]
           or .z suffix variant
missing   → file does not exist       [ unknown to local catalog ]
```

### Zeroing Policy [ manual for now, automated later ]

```bash
invoke-model-recover --zero AB3XY7Q    # zero specific model
invoke-model-recover --zero-unused     # zero all not flagged :keep:
```

Keep flag: a small sidecar file `.keep` alongside the model, or a local
registry entry — to be decided when implemented.

## Phase 3 : Downloader Zenka [ future ]

Replace script with a zenka that manages the full model lifecycle:

- Search and download from HuggingFace API
- LAN-first fetch: check other local hosts before going to HuggingFace
  [ same model on gigabit LAN >> WAN download ]
- Track last-used timestamps per model
- Auto-zero LRU models when disk pressure exceeds threshold
- Honour permanent `:keep:` flags [ never auto-zero ]
- Expose commands: `search`, `fetch`, `zero`, `restore`, `status`

## Phase 4 : FUSE Lazy Storage [ future — requires data zenka ]

With the data zenka FUSE mount feature, model paths become transparent:

- Consumer opens `/models/path/to/model.gguf`
- FUSE intercepts: if zeroed → trigger download zenka → stream or block
- If present on LAN host → fetch from there first
- If only on HuggingFace → download, cache locally
- Consumer never knows the difference

This enables the full lazy model storage abstraction:
- Models flagged `:keep:` are always local
- Others are local while recently used, remote otherwise
- LAN acts as L1 cache, HuggingFace as L2

## Files

```
bin/scripts/invoke-ai/invoke-model-recover    ## phase 1+2 target
bin/scripts/invoke-ai/invoke-model-prefetch   ## related, review for overlap
data/lib-path/pm/AMOS7/                       ## for checksum ID generation
```

## Notes

- invoke.ai database lives at `~/.invokeai/db/invokeai.db` [ SQLite ]
- models on `/mnt/ext-xfs-data/models-invoke`
- HF token read from invoke config or lm-studio config [ already implemented ]
- zeroed vs missing behaviour in invoke.ai: **test before implementing zero**
- `.z` suffix approach preserves original path as missing if zero is problematic

#,,..,...,,,,,.,.,,,,,,,.,...,,.,,...,.,.,...,.,.,...,...,.,.,.,.,...,,,.,,.,,
#MWXKTVN6LXXP3DHG7J54SSGMDJVE7JIAT34OPIMBSPZLULO4PYRQT2YSTHK4QJ7NJUW3LNARRUF2I
#\\\|RUPRHG4NLAODDL6XLG2HWWOKLXKCZFUFRWNT3MAMM2CFVYNFHJK \ / AMOS7 \ YOURUM ::
#\[7]E3HIKVYOUQVD2OEFWIXA7ZHBNINBX34FM6V3MN7ZQUY76JSTDCCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
