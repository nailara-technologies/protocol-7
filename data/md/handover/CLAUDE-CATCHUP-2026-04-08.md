## [:< ##

# claude catchup — 2026-04-08

## session summary

invoke.ai model recovery infrastructure built, debugged, and committed.
three new design docs laying out the storage adapter and UI adapter systems.
philosophy doc for the eternal template kitten added.


## commits this session (base branch)

    30bbd31b4  philosophy: the eternal template kitten
    15730ca8d  code-style: document :keyword: colon-bracket flag convention
    ddeaf078f  design: storage path adapters + UI adapter system architecture
    e3b68640b  ai-mem: invoke model manager + image archive system design notes
    813858abb  invoke-model-recover: fix dry-run size reporting and dir_size helper
    98743c227  invoke-ai: symlink repair + model recover fixes for uuid-based storage


## what was built and fixed

### invoke-symlink-repair (new script)
    bin/scripts/invoke-ai/invoke-symlink-repair

    invoke.ai uses uuid-based storage paths internally but expects verbose
    {base}/{type}/{name}[.ext] paths on disk. this script creates the symlinks.

    features:
    - queries invokeai.db (sqlite3) for all model records
    - creates {base}/{type}/{name} → {uuid} symlinks
    - sd-1 gets both sd-1/ and sd-1.5/ aliases
    - url-encoded filenames: creates both decoded and %xx variants
    - skips spandrel/unknown/windows-path models
    - --dry-run, --type filter, --verbose options
    - p7 :flag: style used in examples

### invoke-model-recover (three fixes)
    bin/scripts/invoke-ai/invoke-model-recover

    fix 1 — get_filename: bare uuid paths (diffusers dir models) now route
    downloads to {uuid}/model.safetensors instead of the models root dir.
    all clip_vision models were landing at OUTPUT_DIR/model.safetensors and
    overwriting each other.

    fix 2 — download_from_hf_repo: diffusers models now use
    download_diffusers_model to fetch ALL repo files including config.json.
    without config.json invoke defaults to wrong architecture (e.g. ViT-B
    hidden_size=768) and fails loading ViT-H weights (hidden_size=1280) with
    a shape mismatch error.

    fix 3 — download_file: binary files opened with :raw mode. the global
    use open ':std', ':encoding(UTF-8)' was corrupting binary writes — bytes
    >= 0x80 were getting UTF-8-expanded. symptom: "header too large" from
    safetensors. files with ascii-only headers appeared valid but had
    corrupted tensor data. 5GB file becoming 7.5GB is the signature.

    fix 4 — dry_run: was summing ALL model sizes and labelling it "total to
    download". now tracks missing vs have separately. for bare-uuid models
    measures whole directory (via new dir_size()) not just model.safetensors.

### cleaned up models-invoke root
    deleted ~35GB of stale/corrupted files:
    - ip_adapter_sdxl_image_encoder.safetensors (5.4GB, utf-8 corrupted)
    - OpenPoseXL2.safetensors (7.5GB, utf-8 corrupted)
    - controlnet-sd-xl-1.0-softedge-dexined.safetensors (7.5GB, corrupted)
    - SigLIP - google/ dir (5.3GB, corrupted)
    - diffusion_pytorch_model.safetensors (duplicate, uuid copy on disk)
    - diffusion_pytorch_model.fp16.bin (duplicate)
    - sd-xl-base/ dir (duplicate)
    disk: 70GB free → 252GB free on /mnt/ext-xfs-data (801GB volume)

### uuid alias symlink
    /mnt/ext-xfs-data/models-invoke/2fd93aa6-d7a6-4224-893d-976976150447
    → 7fe3f986-dd76-4146-9d05-d98be2ffd94a  (IP Adapter SD1.5 Image Encoder)

    invoke referenced this uuid which is not in the DB (deleted entry or
    stale workflow reference). symlink resolves it to the correct model.


## design docs written

### data/md/design/MODELS-PATH-ADAPTERS.md
    storage adapter plugin system for models zenka:
    - interface: discover, resolve, install, remove, repair, export, import
    - invoke adapter: extracts proven script logic into modules
    - lmstudio adapter: uses existing gguf modules
    - native p7 adapter: checksum-addressed (future)
    - 4-step implementation order
    - unblocks: lmstudio zenka, terminal app, coding model selection,
                image archive provenance

### data/md/design/TERMINAL-ZENKA-ARCHITECTURE.md
    UI adapter system — application logic runs independently of render backend:
    - adapters: curses, web, gtk3 (protocol-7-menu plugins), sdl (future)
    - shared: abstract action protocol (:action:scroll_down:), UI templates,
              global P7 style, pager as data layer for all adapters
    - web adapter: localhost browser + project website views
    - apps: ui.app.models (model manager), ui.app.image (archive browser),
            ui.app.source (code browser), ui.app.config, ui.app.network
    - standalone-first → zenka-second implementation strategy

### data/md/design/TASK-invoke-adapter-step1.md
    concrete first task: extract invoke scripts → models.storage.adapter.invoke.*
    modules (discover, resolve, repair). zero new logic — reorganization only.
    includes exact input/output specs, test commands, file list.


## current invoke model status

    206/299 models downloaded (93 missing, ~249GB to go per db metadata)
    252GB free on external volume — plenty of room
    
    to continue downloading:
        invoke-model-recover --download           # main models
        invoke-model-recover --batch              # all non-main types
        invoke-model-recover --type TYPE --download  # specific type
    
    after each download run:
        invoke-symlink-repair                     # wire up verbose paths
    
    models still missing include:
        - controlnet models (sdxl, sd-1, flux)
        - most main models (only perfection-realistic downloaded)
        - some clip_vision, ip_adapter, embedding models
        - upscalers (C:\ windows paths — need manual repair, separate task)

    invoke UI deletion: avoid — leaves dangling symlinks, uuid alias risk.
    use scripts for model management until invoke-model-manager is built.


## active design priorities

    1. models.storage.adapter.invoke.* (step 1 task defined, ready to implement)
       → extract script logic → p7 modules → wire models zenka commands

    2. models.storage.adapter.lmstudio.* (lmstudio zenka placeholder → working)
       → uses existing gguf modules (extract_metadata, extract_name, etc.)

    3. terminal.curses_ui expansion (widget.list, widget.detail, keybindings)
       → foundation for ui.app.models standalone

    4. invoke model manager (Term::Clui standalone)
       → wires invoke adapter → curses ui → safe delete/archive/repair


## ai-mem files updated this session

    topic-invoke-model-management.md  — hard-won lessons (binary corruption,
        config.json requirement, utf-8 :raw fix, partial download traps,
        uuid alias symlinks, duplicate db entries)

    topic-invoke-model-manager.md     — planned Term::Clui manager design,
        invoke UI deletion risk, zenka evolution path

    topic-image-archive-system.md     — vision-scored tiered storage,
        thumbnail+metadata=full image, pngquant tiers, model↔image dep graph


## code style update

    CONVENTIONS.yaml: :keyword: colon-bracket flag convention documented.
    llm correction rule: --flag style must become :flag: in p7 contexts.
    any zenka in routing chain can recognize :flag: tokens without
    separate parsing logic.


## philosophy

    data/md/philosophy/ETERNAL-TEMPLATE-KITTEN.md

    "the universe is a kitten, looking at itself from within a kitten."

    the knowledge base the zenki consult to reason about the system
    IS the system describing itself. when the deduplication tree is live,
    insights fold back into the corpus future instances draw from.
    the tree does not merely accumulate — it crystallizes.

#,,,.,...,,,,,,,,,,,,,..,,,,,,.,,,.,.,,.,,,,.,..,,...,...,.,,,,..,,,.,..,,,,,,
#3EZ2YHI324BCJAXEMY5V3HSRJEQCVEHDKIVQX2SNRBV36JB3E7V645NKQGBFY7FVUINAX627DBJ2M
#\\\|WIKDH5G7EFCBNUDU6PW3RHPTBKYVBT672GWUQLRTYIJV367MGU5 \ / AMOS7 \ YOURUM ::
#\[7]IWPITHOIANVXWZ6GIU53FM3GPANTWQPPNT54KDDK5QDO2EVLR2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
