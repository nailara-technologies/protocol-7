## [:< ##

# models zenka — path structure adapter system

## motivation

the models zenka already has a rich storage layer (17 modules: discover,
tier_management, create_symlink, resolve_model, etc.) built around a
generic "tier" abstraction. however, different model hosts use incompatible
on-disk path conventions:

- invoke.ai  : uuid-based dirs, verbose symlinks at {base}/{type}/{name}
- lm-studio  : flat GGUF files at {category}/{name}.gguf
- native p7  : content-addressed, checksum-rooted, AMOS7-signed

rather than hardcoding any of these into the storage core, the solution is
a path adapter plugin system — thin modules that translate between the
generic models registry and each host's conventions.

this also unblocks: lmstudio zenka (placeholder → working), the planned
invoke model manager (Term::Clui), image archive system (model provenance),
and any future host (comfyui, a1111, etc.) without touching core storage.


## existing foundation

    models.storage.create_symlink   — creates symlinks between tiers
    models.storage.discover         — scans tiers for model files
    models.storage.discover_directory
    models.storage.resolve_model    — finds model across tiers
    models.storage.tier_management  — tier lifecycle
    models.storage.get_tier_path    — resolves tier root paths

    configuration/external-inference-models:
        external.models.invokeai.path  = /mnt/ext-xfs-data/models-invoke
        external.models.lmstudio.path  = /mnt/ext-xfs-data/models-lmstudio

    bin/scripts/invoke-ai/invoke-symlink-repair   — proven path repair logic
    bin/scripts/invoke-ai/invoke-model-recover    — proven download + recover


## adapter interface

each adapter is a namespace of modules under models.storage.adapter.{name}.*
implementing a standard interface:

    models.storage.adapter.{name}.discover
        → scan adapter's root dir, return list of model records
        → each record: { name, type, base, format, path, size, checksum? }

    models.storage.adapter.{name}.resolve  (path, model_record)
        → given a registry record, return the canonical on-disk path
        → for invoke: resolves uuid dir; for lmstudio: resolves .gguf file

    models.storage.adapter.{name}.install  (model_record, source)
        → download/copy model to correct location for this host
        → wraps existing download logic where available

    models.storage.adapter.{name}.remove   (model_record)
        → safe delete: files + db entry + any adapter-specific cleanup
        → for invoke: also cleans dangling verbose symlinks

    models.storage.adapter.{name}.repair
        → idempotent: fix structural inconsistencies for this host
        → invoke: invoke-symlink-repair logic, promoted to module
        → lmstudio: validate .gguf headers, rebuild catalog if needed

    models.storage.adapter.{name}.export   (model_records)
        → serialize model collection to portable yaml snapshot
        → includes checksums for integrity verification on restore

    models.storage.adapter.{name}.import   (yaml_snapshot)
        → restore from snapshot: re-download or re-link models
        → foundation for "bootstrap fresh install from collection profile"


## invoke adapter — models.storage.adapter.invoke.*

migrates proven script logic into reusable modules:

    models.storage.adapter.invoke.discover
        → queries invokeai.db (sqlite3), returns registry records
        → already implemented in invoke-model-recover::query_database

    models.storage.adapter.invoke.resolve
        → uuid dir for diffusers; {uuid}/{file} for single-file types
        → handles url-encoded filenames (literal %xx on disk)

    models.storage.adapter.invoke.repair
        → invoke-symlink-repair logic: {base}/{type}/{name} → uuid
        → creates sd-1 + sd-1.5 dual aliases
        → both decoded and %xx-encoded filename variants

    models.storage.adapter.invoke.install
        → invoke-model-recover download logic
        → diffusers: all repo files (config.json required, not just weights)
        → binary: :raw file open (prevents utf-8 corruption)
        → resumes partial downloads

    models.storage.adapter.invoke.remove
        → removes uuid dir, db entry, dangling symlinks, uuid alias symlinks

    models.storage.adapter.invoke.export / import
        → yaml snapshot of full model collection + workflow configs
        → wraps invoke-export-config + invoke-model-backup


## lmstudio adapter — models.storage.adapter.lmstudio.*

    models.storage.adapter.lmstudio.discover
        → scan /mnt/ext-xfs-data/models-lmstudio for .gguf files
        → use models.gguf.file.extract_metadata for model info
        → models.gguf.file.extract_name, file_type_to_quant already exist

    models.storage.adapter.lmstudio.resolve
        → flat path: {root}/{category}/{name}.gguf

    models.storage.adapter.lmstudio.repair
        → validate GGUF headers (magic bytes check)
        → rebuild lm-studio catalog.json if needed

    models.storage.adapter.lmstudio.install
        → HuggingFace download to correct category subdir
        → reuse invoke-model-recover download_file (with :raw fix)


## native p7 adapter — models.storage.adapter.native.*

    future: content-addressed storage rooted at AMOS7 checksum
    models stored at {checksum-prefix}/{model-hash}/
    consistent with the checksum-as-address architectural vision
    (see data/md/documentation/CHECKSUM-CLUSTER-MAP.md)


## zenki that benefit from this

    models zenka     — unified discover/resolve across all hosts
    lmstudio zenka   — unblocks implementation (placeholder → working)
    terminal zenka   — model manager UI queries adapter layer
    coding zenka     — model selection can span invoke + lmstudio
    lm-vision zenka  — vision model discovery across hosts
    image archive    — model provenance tracking via registry


## implementation order (step by step)

step 1 — invoke adapter
    - extract invoke-symlink-repair logic → models.storage.adapter.invoke.repair
    - extract invoke-model-recover logic → invoke.discover + invoke.install
    - wire into models zenka: models.cmd.adapter.{repair,discover,install}
    - test: p7c models.adapter.repair, models.adapter.discover invoke

step 2 — lmstudio adapter
    - implement discover using existing gguf modules
    - implement resolve (flat path)
    - wire lmstudio zenka start file (currently placeholder)
    - test: p7c models.adapter.discover lmstudio

step 3 — unified discover
    - models.registry.populate_from_discovery already exists
    - extend to call each active adapter and merge results
    - dedup by checksum where models exist in multiple hosts

step 4 — export/import (collection profiles)
    - invoke.export wrapping existing backup scripts
    - yaml snapshot format definition
    - invoke.import for fresh-install bootstrap

#,,,,,,..,,..,..,,...,.,,,...,,,,,...,..,,..,,..,,...,...,,,,,...,,..,...,.,.,
#65NPZLUN2C4RQDKJHYRUTBO5RRAYXTC5FDLS24ME2LABGJ2WSMZNBLF6KRXKDRY3SCKXHOK36TMDW
#\\\|G5TVYYVQ2YOFJS45UDMXIWT6S3XCNC7AEC5IJGUQI57K77ZCVRB \ / AMOS7 \ YOURUM ::
#\[7]6SRRUNAFFSVMJYHXQX5K6HYWEZCHT6FMTYKAMQSVQMH24QR4O4BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
