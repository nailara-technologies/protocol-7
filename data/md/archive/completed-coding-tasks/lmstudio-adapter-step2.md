## task: models.storage.adapter.lmstudio — step 2

create 4 p7 modules for the lmstudio storage adapter. same interface as the
invoke adapter (step 1), different path conventions. all logic already exists
in bin/scripts/invoke-ai/invoke-model-recover — read it fully first.

p7 code style: lowercase comments, [ brackets ] for annotations, $ARG not $_,
<[module.name]>->($args) syntax (closing ]> before ->), :flag: not --flag.
do NOT add the #,,... stub line. leave files clean for signing.


## read these source files first

    bin/scripts/invoke-ai/invoke-model-recover   (691 lines — read fully)
        relevant functions:
            read_hf_token_from_lmstudio() line 454  — hf token location
            get_hf_repo_files()           line 275  — list repo files
            get_all_hf_repo_files()       line 287  — recursive repo listing
            download_file()               line 561  — :raw binary download + resume
            download_diffusers_model()    line 299  — fetch all repo files
            download_from_hf_repo()       line 341  — dispatch download by format
            get_download_url()            line 533  — resolve HF download url
            dir_size()                    line 630  — recursive directory size

    bin/scripts/invoke-ai/invoke-symlink-repair (229 lines)
        — already extracted as models.storage.adapter.invoke.repair
        — no new logic needed from here for lmstudio

    src/models.storage.adapter.invoke.discover  — use as style reference
    src/models.storage.adapter.invoke.resolve   — use as style reference


## on-disk path structure (confirmed from live system)

    {root}/{author}/{model-dir}/{file}.gguf

    example:
        /mnt/ext-xfs-data/models-lmstudio/bartowski/Llama-3.2-3B-GGUF/Llama-3.2-3B-Q4_K_M.gguf

    config key: external.models.lmstudio.path = /mnt/ext-xfs-data/models-lmstudio


## modules to create (4 files)

### src/models.storage.adapter.lmstudio.discover

    # name  = models.storage.adapter.lmstudio.discover
    # descr = scan lmstudio model dir and return list of model records

    input:  $ARG = optional hashref with root_path override
    output: arrayref of model hashrefs

    logic:
        my $root = $ARG->{'root_path'}
            // $data{'models'}{'cfg'}{'external.models.lmstudio.path'}
            // '/mnt/ext-xfs-data/models-lmstudio';

        use File::Find or opendir recursion to find all *.gguf files
        for each .gguf file:
            call <[models.gguf.file.extract_metadata]>->($path) for metadata
            call <[models.gguf.file.extract_name]>->($path) for canonical name
            call <[models.gguf.file.file_type_to_quant]>->($file_type) for quant

            build record:
            {
                name        => extracted name or basename without .gguf,
                type        => 'main',          # lmstudio is always text models
                base        => extracted from metadata (llm.architecture) or 'unknown',
                format      => 'gguf',
                path        => relative path from root (author/model-dir/file.gguf),
                size        => -s $path,
                quant       => quant string from file_type_to_quant,
                source      => '',              # unknown without lmstudio catalog
                source_type => 'file',
            }

        skip files where <[models.gguf.file.is_garbage_name]>->($name) returns true

        return arrayref


### src/models.storage.adapter.lmstudio.resolve

    # name  = models.storage.adapter.lmstudio.resolve
    # descr = resolve lmstudio model record to absolute on-disk path

    input:  $ARG = model record hashref (with 'path' key = relative path from root)
    output: absolute path string if exists, undef if not

    logic:
        my $root = $data{'models'}{'cfg'}{'external.models.lmstudio.path'}
                   // '/mnt/ext-xfs-data/models-lmstudio';
        my $rel  = $ARG->{'path'} // return undef;
        my $abs  = "$root/$rel";
        return -f $abs ? $abs : undef;


### src/models.storage.adapter.lmstudio.install

    # name  = models.storage.adapter.lmstudio.install
    # descr = download a model from huggingface into lmstudio storage

    input:  $ARG = hashref:
        {
            repo        => 'bartowski/Llama-3.2-3B-GGUF',  # HF repo id
            filename    => 'Llama-3.2-3B-Q4_K_M.gguf',    # specific file (optional)
            author      => 'bartowski',                     # subdir under root
            dry_run     => 0,
        }

    logic:
        extract download_file() from invoke-model-recover — adapt to p7 module style:
        - get hf token via read_hf_token_from_lmstudio() logic (check
          ~/.cache/lm-studio/huggingface-cache/hub/.token or lmstudio config)
        - determine dest dir: {root}/{author}/{repo_name}/
        - if filename given: download single file with :raw mode
        - if no filename: use get_hf_repo_files logic to list .gguf files,
          download the largest (or Q4_K_M if present)
        - resume partial downloads (check existing file size vs expected)
        - use LWP::UserAgent with progress reporting

    key detail from source — binary files MUST use :raw open mode:
        open my $fh, $offset ? '>>:raw' : '>:raw', $tmpfile
    (utf-8 global pragma in p7 would corrupt binary writes without :raw)


### src/models.storage.adapter.lmstudio.repair

    # name  = models.storage.adapter.lmstudio.repair
    # descr = validate gguf headers and report corrupt or incomplete files

    input:  $ARG = optional hashref with dry_run, root_path
    output: hashref { valid => N, corrupt => N, missing => N }

    logic:
        scan all .gguf files in root (same walk as discover)
        for each file, validate GGUF magic bytes:
            open file, read first 4 bytes
            valid if bytes eq "GGUF"  (0x47 0x47 0x55 0x46)
        corrupt: magic mismatch (utf-8 expanded bytes = sign of :raw bug)
        missing: file in discover records but not on disk (shouldn't happen here)
        print per-file status if corrupt
        return counts


## wiring into models zenka

edit cfg/zenki/models/zenka.v7:

1. modules.load — add after 'storage.adapter.invoke':
       storage.adapter.lmstudio

2. access.cmd.usr.cube — no new cmd modules yet (step 2 is storage only)
   the existing adapter-discover/resolve/repair cmd modules can be extended
   later to dispatch to lmstudio adapter by host name


## also create cmd wrappers (same pattern as invoke cmd modules)

    src/models.cmd.adapter-lmstudio-discover
    src/models.cmd.adapter-lmstudio-resolve
    src/models.cmd.adapter-lmstudio-repair

    thin wrappers — same pattern as models.cmd.adapter-discover etc.
    use $call->{'args'} (not $call_args)
    add to access.cmd.usr.cube: adapter-lmstudio-discover adapter-lmstudio-resolve adapter-lmstudio-repair
    add to modules.load: cmd.adapter-lmstudio-discover cmd.adapter-lmstudio-resolve cmd.adapter-lmstudio-repair


## verify

    ptd -c on all 7 new files
    do NOT add #,,... stub lines
    report when done

#,,.,,,..,.,,,,..,,,.,.,.,..,,,.,,.,,,...,,..,..,,...,...,,.,,.,,,..,,..,,...,
#TZNCYMBSZELNSHQYP6IXMRXF7QJ6S6VPEFSSU7PI2JNQRALXQVRDCTITKDFO35JIWZHJ3KFG2ALNO
#\\\|IS6E67D3EN5ZJI7DFI7PTRTG4V6RQRVGUAYUTOGP3VUAGA6YSXC \ / AMOS7 \ YOURUM ::
#\[7]Q4MKZLCZZOP6Y6ALWV6MGMTHQGAA5ET7LIXZ34DJCGOHBNRRTODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
