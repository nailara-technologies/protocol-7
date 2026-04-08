## [:< ##

# task: models.storage.adapter.invoke — step 1

extract proven invoke path logic from bin/scripts/invoke-ai/ into
reusable p7 modules under models.storage.adapter.invoke.*

this is the first concrete step toward the path adapter system defined
in MODELS-PATH-ADAPTERS.md. all logic already exists and is tested —
this is reorganization + module wrapping, not new code.


## scope

create 3 modules (minimum viable adapter):

    models.storage.adapter.invoke.discover
    models.storage.adapter.invoke.resolve
    models.storage.adapter.invoke.repair


## module: models.storage.adapter.invoke.discover

source: invoke-model-recover::query_database()

    input:  optional db path (defaults to external.models.invokeai.db
            config key, falls back to ~/.invokeai/db/invokeai.db)

    output: arrayref of model records, each a hashref:
        {
            name        => 'perfection-realistic-ilxl-v32-sdxl',
            type        => 'main',
            base        => 'sdxl',
            format      => 'diffusers',
            path        => '23cf4e5b-...',    # as stored in db
            size        => 4294967296,
            source      => 'https://...',
            source_type => 'hf_repo_id',
        }

    skip: type IN (spandrel_image_to_image, unknown)
    skip: path matches ^[A-Za-z]:[\\/] or ^/ (windows/absolute paths)

    implementation:
        use sqlite3 cli (already used in script)
        parse JSON output with JSON::PP
        return arrayref


## module: models.storage.adapter.invoke.resolve

    input:  model record (hashref as above)
    output: absolute path to model on disk (file or directory), or undef

    logic:
        my $root = config 'external.models.invokeai.path'
                   // '/mnt/ext-xfs-data/models-invoke';

        if path =~ /^[0-9a-f-]{36}$/   # bare uuid → diffusers dir
            return "$root/$path"  if -d "$root/$path";
            return undef;

        if path =~ /^([0-9a-f-]{36})\/(.+)$/  # uuid/filename
            try decoded and raw (uri-encoded) variants:
            "$root/$uuid/$filename_decoded"
            "$root/$uuid/$filename_raw"
            return first that exists, undef if neither;

        return undef;  # unrecognized format


## module: models.storage.adapter.invoke.repair

source: bin/scripts/invoke-ai/invoke-symlink-repair (in full)

    input:  optional list of model records (defaults to discover output)
            optional :dry-run: flag

    output: count of symlinks created, skipped, missing, failed

    logic: (already fully implemented — copy and adapt)
        for each model record:
            determine verbose link path: {base}/{type}/{name}[.ext]
            handle base aliases: sd-1 → [sd-1, sd-1.5]
            handle uri-encoded names: create both decoded + %xx variants
            check target exists (resolve call above)
            create symlink if link path doesn't exist
            make_path for parent dirs

    the module wraps the full logic from invoke-symlink-repair,
    making it callable as:  p7c models.adapter.repair invoke


## wiring into models zenka

add commands to configuration/zenki/models/start:

    models.cmd.adapter.discover     # list models from a host adapter
    models.cmd.adapter.resolve      # resolve a model to its disk path
    models.cmd.adapter.repair       # repair path structure for a host

and to subroutine.white-list.


## test plan

    # discover invoke models
    p7c models.adapter.discover invoke

    # resolve a specific model (pass name, get path back)
    p7c models.adapter.resolve invoke 'perfection-realistic-ilxl-v32-sdxl'

    # repair symlinks (dry-run)
    p7c models.adapter.repair invoke :dry-run:

    # repair symlinks (live)
    p7c models.adapter.repair invoke


## files to create

    modules/models.storage.adapter.invoke.discover
    modules/models.storage.adapter.invoke.resolve
    modules/models.storage.adapter.invoke.repair
    modules/models.cmd.adapter.discover    (thin cmd wrapper)
    modules/models.cmd.adapter.resolve     (thin cmd wrapper)
    modules/models.cmd.adapter.repair      (thin cmd wrapper)


## dependencies

    JSON::PP          — already used in script
    URI::Escape       — already used in invoke-symlink-repair
    File::Path        — already loaded in most modules
    File::Basename    — already loaded
    sqlite3           — system binary, already used


## what this enables next

    - lmstudio adapter step 1 (same interface, different path logic)
    - models zenka unified discover (merge results from all adapters)
    - terminal.app.models (list view data source → this discover)
    - safe model remove (add invoke.remove module next)

#,,.,,.,.,.,,,...,,..,...,...,,,,,..,,.,.,..,,..,,...,...,...,.,,,...,,,.,,,.,
#LI2GH3XFED6ZIKGYXVPOD3LCZ573A6OPLXFMZACTQRXLBAHYHZLNNTKCEGNHHEI4FOZ2ZBOQZKES4
#\\\|LJXFBX3ALVKJPQIVZJVIDTJO7F5P4EAD3GKQA5GFWGU6QGSQ2Q2 \ / AMOS7 \ YOURUM ::
#\[7]BYLH7CAMEFX3QHRNRXZT67ODH3TL3JFZRKGPHQVUTLN5BNLUJOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
