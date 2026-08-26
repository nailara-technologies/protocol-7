---
name: invoke-ai model management lessons
description: hard-won lessons from automating invoke.ai model recovery and path repair
type: project
---

## invoke.ai uuid-based storage vs verbose path expectations

invoke stores model metadata in `~/.invokeai/db/invokeai.db` with uuid-based
`path` fields, but at runtime looks for models at verbose paths:
`{models_dir}/{base}/{type}/{name}[.ext]`

**fix**: `invoke-symlink-repair` creates these verbose symlinks from the db.

## sd-1 base maps to both sd-1/ and sd-1.5/ on disk

invoke may check either prefix depending on version — create symlinks under both.

## url-encoded filenames are literal on disk

invoke stores names like `great%20lighting` with literal `%20` in the filesystem.
create symlinks for both decoded (`great lighting.safetensors`) and raw
(`great%20lighting.safetensors`) variants.

## diffusers models need config.json — not just model.safetensors

without `config.json`, invoke defaults to a small architecture (e.g. ViT-B,
hidden_size=768) and then fails loading weights from a larger model (ViT-H,
hidden_size=1280) with a shape mismatch error.

**fix**: for bare-uuid (diffusers format) models, use `download_diffusers_model`
to fetch ALL repo files, not just the weights file.

## binary files must be opened with :raw in perl

`use open ':std', ':encoding(UTF-8)'` corrupts binary writes — bytes >= 0x80
get mangled into multi-byte utf-8 sequences. symptom: "header too large" from
safetensors. files with only ascii-range bytes in their header may appear valid
but have corrupted tensor data.

**fix**: `open my $fh, '>:raw', $tmpfile` for all binary downloads.

## partial downloads can masquerade as complete

if a `.tmp` file exists from a prior interrupted download, the resume logic
may think it's already complete if size >= 99% of the db-recorded expected size.
db size metadata can be stale (smaller than actual). always verify actual file
integrity (check header bytes, not just size) for critical models.

## stale uuid references after invoke cleanup

invoke may delete empty/incomplete model directories on startup but retain
the uuid reference in a queued job or workflow node. the uuid may no longer
appear in the db. fix: create a uuid-to-uuid symlink from the stale uuid
to the correct downloaded uuid directory.

## duplicate db entries for same model

invoke sometimes has 2+ db entries for the same model (same source, different
uuids). the recover script downloads to both — if one download is interrupted
the other may still be complete and usable.

#,,,,,,,,,.,,,,..,...,.,,,..,,,,.,,..,,,.,,..,..,,...,...,...,.,,,..,,..,,,.,,
#PL7K5LUOBLRYW2O3Q3LRHPNC4Y3K5IQU4WPCAG7YWHIMH7TJQWOHIUJZS4IZZSHHCKCK6PCXYMUU2
#\\\|TGLKDK2BYMAJRCXZXOCK4HNM3YCHXGIDLL74ZNQHAZ4V6VDBCPB \ / AMOS7 \ YOURUM ::
#\[7]ZWBDC6PXBQRKYS5MP22IVHGGORRO2OCRVPVBH4FJ3HP372B4SUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
