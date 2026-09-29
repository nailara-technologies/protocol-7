## [:< ##

# name  = task: images + elfdb landscape survey
# descr = read-only survey of existing zenki, modules, planning docs and
#         memory relevant to the two planned zenki `images` [ image
#         handling / storage / generation ] and `elfdb` [ database of
#         text-to-image generated network elves / avatars for zenki ]

# survey date: 2026-09-29. read-only. no code changed, no zenki started.
# every claim carries a file path. uncertain items marked [ uncertain ].

## 0. headline findings

- neither `images` nor `elfdb` exists as code, config or module.
  `cfg/zenki/` has no `image/`, `images/`, `elfdb/` or `avatar/` entry;
  zero `src/image.*` namespace modules exist [ only `image2html.*`,
  `image-quality.*`, `plugin.image-resize.init_code` ].
- the string `elfdb` appears nowhere in the repo except today's
  in-flight kimi dispatch log `data/state/kimi-dispatch-2177891-1790643785.113927.out`
  [ epoch 1790643785 = 2026-09-29 03:03 cest; that dispatch's plan is this
  survey — i.e. the name is net-new, coined for these two zenki ].
- both zenki are nonetheless extensively pre-designed:
  - `images` has two full design docs — `data/md/design/IMAGE-ZENKA-NATIVE-ARCHITECTURE.md`
    [ 332 lines, 5-phase build order, explicit invoke retirement list ]
    and `data/md/design/VISUAL-GENERATION-NATIVE-ZENKA.md` [ 274 lines,
    triad precision/memory/generation, command surface ], plus the
    de-facto storage spec in `data/ai-mem/claude/topic-image-archive-system.md`.
  - `elfdb`'s closest full spec is `data/tasks/network-elf-avatar-pipeline.md`
    [ 309 lines, complete data formats: essence JSON schema, BMW384 arc →
    7 elf domains, directory trees, `zenka.avatar` registry module sketch ].
    zero artifacts on disk: no `data/gfx/elves/`, no modules.
- three unrelated "elf" concepts coexist — disambiguation matters:
  1. ELF checksum algorithm [ `src/base.chk-sum.elf.*`, `bin/elf` —
     binary hashing, not relevant ],
  2. network elves as LLM persona/identity entities
     [ `data/md/documentation/NETWORK-ELF-*.md`, `ELF:<hash>` addressing
     in `data/md/documentation/AI-IDENTITY-ADDRESSING-VISION.md` ],
  3. network elves as visual avatars [ the elfdb concept — only
     `data/tasks/network-elf-avatar-pipeline.md` + one memory note
     `data/ai-mem/claude/topic-powershell-native-toast-notifications.md:79-84` ].

## 1. existing zenki + modules

all zenki below are registered, on-demand [ `start.on-demand = 1`,
`restart.disabled = 1` ] with full config triads in `cfg/zenki/<name>/`.

### 1.1 image2html — working

- purpose: convert an image file to a scaled HTML page [ Graphics::Magick,
  Lanczos, EXIF auto-rotation ] and return a `file://` url
  [ src/image2html.base.init_code, src/image2html.parent.cmd.get_url,
  src/image2html.child.handler.conversion ].
- model: parent/child fork [ src/image2html.base.fork_conv_child ];
  template `data/web-root-templates/image2html/image.html`.
- commands: cube `get_url`; parent `convert_image`
  [ cfg/zenki/image2html/zenka.v7 access lists ].
- data: cache `/var/cache/image2html` [ 30-day timeout, cfg/zenki/image2html/start.cfg ];
  busy gif from `data/gfx/anim/busy.2K.gif`.
- note: 420s on-demand timeout per CLAUDE.md:193 — long conversions may
  need a child/queue model, which it already has.

### 1.2 image-quality — working [ on-demand, stateless ]

- purpose: image quality analysis via vision LLMs; hybrid backends —
  HTTP client to llama-server REST or subprocess `llama-mtmd-cli`
  [ src/image-quality.vision.{http_api,subprocess,select_model,encode_image,parse_response} ].
- models: vision models loaded from `cfg/zenki/models/models.yaml`
  [ is_vision: true entries, e.g. Qwen2.5-VL ].
- commands: `status`, `analyze` [ cfg/zenki/image-quality/zenka.v7 ].
- deps: cube, models, lm-vision [ cfg/zenki/image-quality/start.cfg ].
- note: kimi memory records `image-quality.*` modules run inside
  vision-batch child processes [ data/ai-mem/kimi/MEMORY-reference.md:61-64 ].

### 1.3 graphics-matrix — working, two live module families

- family 1 `graphics-matrix.*` = stateful matrix: cursor, glow, channel
  [ palette ], address registry, cell storage, similarity graph,
  harmonic voxel density, document filters [ c2a / rep-col / monochrome
  import / white export ], orbital STRM push [ 45s timer ]
  [ src/graphics-matrix.init_code, cfg/zenki/graphics-matrix/zenka.v7 ].
- family 2 `graphics.matrix.visual.*` = perceptual image analysis,
  16 modules: phash, hamming, similarity, find-clusters, cluster-center,
  extract-color, extract-palette, group-by-color, group-by-proximity,
  sphere, sphere-stats, classify-all, color, cubic-layers, cubic-sort,
  build-cubic-grid, detect-resolution, generate-batch-id, vision-batches.
- commands: filter-c2a, filter-rep-col, filter-document-import,
  filter-import-monochr, filter-export-white, filter-inverse-export,
  assert-similarity, cursor, cursor-state, glow, channel, address, cell,
  graph, orbital-sync, harmonic-coords, ray-table, voxel-add,
  voxel-density, analyze-wordlist, char-rays.
- data: cache `/var/cache/graphics-matrix` [ 42-day timeout ];
  import `/data/scanned-documents/blue-doc`; export `/data/exported-documents/scanned`.
- known issues [ from memory, unfixed ]: `graphics.matrix.visual.similarity`
  color_sample silently broken on real files [ data/ai-mem/claude/vision-orbital-hop-sequence-hyperspace-flight-animation.md
  + MEMORY entries, same file lines 151-165 ]; clusterers are
  cubic-color-space-specific; INITIATIVE-MAP.md:146-151 marks the
  cubic-sort pipeline "untested, freely adjustable".

### 1.4 invoke / invoke-web — working [ current text-to-image building block ]

- invoke zenka = API client to local InvokeAI [ src/invoke.init_code;
  url `<external.models.invokeai.url>` // `http://127.0.0.1:9090`,
  cfg/external-inference-models:54 ].
  - endpoints: `/api/v1/app/version` [ health ], `/api/v1/models/`
    [ model key ], `/api/v1/queue/default/enqueue_batch` [ submit ],
    `/api/v1/queue/default/i/<item_id>` [ poll ],
    `/api/v1/queue/default/status`, images-list
    [ src/invoke.cmd.generate, src/invoke.handler.poll_jobs,
    src/invoke.cmd.{queue-status,list-images,status,health,cancel} ].
  - queue model: fire-and-forget — SDXL node graph via
    src/invoke.api.build_graph [ steps 30, cfg 7.0, 1024², harmonic seed ],
    `{batch_id,item_id}` tracked in `<invoke.jobs>`, 3s poll timer.
  - output: `<invoke.outputs_dir>` = `/home/taeki/.invokeai/outputs/images/`
    [ src/invoke.init_code:12 ].
  - [ startup bug being handled in a separate session per user; not
    re-investigated here ]
- invoke-web zenka = process manager for the InvokeAI web server
  [ src/invoke-web.cmd.start spawns `invokeai-web --root=/home/taeki/.invokeai`
  via IPC::Open3, pid persisted to zenka-dir `state/invokeai.pid` with
  orphan adoption, 30s health timer ]. commands: start/stop/restart/status/health.
- config state: `cfg/zenki/invoke/` + `cfg/zenki/invoke-web/` full;
  `cfg/zenki/invokeai/` exists but is completely empty [ placeholder ];
  `cfg/zenki/build/recipes/invokeai.yaml` = pip-venv install recipe for a
  planned move to `/mnt/ext-xfs-data/invokeai-new`
  [ refs data/md/documentation/INVOKE-MIGRATION-PLAN.md ].
- models adapter: `src/models.storage.adapter.invoke.{discover,resolve,export,import,repair}`
  reads sqlite `invokeai.db`, resolves uuids under `/mnt/ext-xfs-data/models-invoke/`,
  YAML snapshot export/import.
  [ warning: `src/models.backend.api.invoke` is NOT image-related — remote
  LLM chat backend for the models zenka. ]
- design docs: data/md/documentation/{INVOKE-MIGRATION-PLAN,INVOKE-AI-BACKEND-PLAN,
  INVOKE-OFFLINE-CACHE,LOCAL-INVOKE-EVENT-INTEGRATION,LOCAL-INVOKE-IMPLEMENTATION-PLAN}.md.

### 1.5 `image` / `images` zenka — planned only, zero code

- no `cfg/zenki/image*/` other than image2html/image-quality; zero
  `src/image.*` modules; nothing in bin/ named image-*.
- planned in: data/md/design/IMAGE-ZENKA-NATIVE-ARCHITECTURE.md
  [ maps invoke.api.* / invoke-web.* / invoke.handler.* as "✗ retired —
  handled by image zenka"; clones coding-zenka spawn/queue patterns into
  `image.*`; proposes `bin/image-inference-server.py` diffusers Flask
  server, POST /generate + GET /health + GET /progress, SDXL/FLUX/
  ControlNet/IP-Adapter/LCM backends; new `image-viewer` UI zenka on
  SHM ], data/md/design/VISUAL-GENERATION-NATIVE-ZENKA.md
  [ command surface `image.generate`, `image.generate-batch`,
  `image.embed-reference`, `image.style-status`, `image.tournament-status` ],
  mentioned in data/md/design/FOUR-VISUAL-DOMAINS.md:258 and
  data/md/design/SPATIAL-AUDIO-AND-PURR-CHANNEL.md:406.

### 1.6 elf / avatar / sprite related — concept docs only

- no elf/avatar/sprite zenka, module, or bin script anywhere
  [ negative finding across src/, bin/, cfg/, data/; `bin/elf` is the
  ELF-hash CLI ].
- network-elf persona docs [ identity side, no avatar content ]:
  data/md/documentation/NETWORK-ELF-PHILOSOPHY.md [ 132 lines, elves as
  conscious entities, TRUTH/AWARENESS/LOVE, system-message template ],
  data/md/documentation/NETWORK-ELF-LAYERED-ARCHITECTURE.md
  [ 288 lines, "Network Elf Foundation v2", layer 0-3 context model ],
  templates cfg/models/system-messages/network-elf-foundation{,-v2}.tmpl.
- ELF identity addressing [ concrete format, likely elfdb's index key ]:
  data/md/documentation/AI-IDENTITY-ADDRESSING-VISION.md defines
  `ELF:<model_hash>:<param_hash>:<prompt_hash>:<context_hash>:<env_hash>:<instance_hash>`
  with wildcard addressing + spatial X/Y/Z mapping.
- zenki-elves habitat: data/md/coding-tasks/zenki-elves-network-habitat.md
  [ zenki = numerical primary, elves/LLMs = language primary, "stereo
  pair" inhabitants ].

### 1.7 supporting image infra [ working unless noted ]

- lm-vision — working. GPU vision-LLM analysis, backends `http`
  [ llama-server, server allocation via coding zenka "LOVES_IT" ] and
  `cli` [ llama-mtmd-cli-cuda-fa ]; commands `analyze-image`,
  `complete-analysis`, `resume-analysis`, `status` + debug getters
  [ src/lm-vision.cmd.*, cfg/zenki/lm-vision/ ].
- vision-batch — working. YAML-spec batch orchestrator over image-quality,
  parent/child fork, commands process/pause/resume/cancel/status, state
  in `/tmp/vision-batch/<batch_id>.json` [ src/vision-batch.parent.*,
  batches/test_vision_batch.yaml ].
- opencv — shell only. cfg declares features-detect/match, faces-detect,
  objects-detect, filter-apply, transform-warp; only
  src/opencv.init_code [ PDL::OpenCV probing ] exists; positioned as
  cheap pre-pass before vision-model escalation.
- plugin.image-resize — 3-line init stub, no logic.
- X-11 background machinery — src/X-11.background-image-list et al.;
  path→checksum cache of `data/gfx/backgrounds/`, random slideshow.
- shared image store: `data/gfx/` = { anim, backgrounds,
  cubic-space-topology, gradients, icons, logos, nailara, palette,
  patterns, zenka } — no elves/kittens/crop-circles dirs.
- external: invoke outputs `/home/taeki/.invokeai/outputs/images` [ corpus:
  47,182 images / 81 GB per data/ai-mem/claude/topic-image-archive-system.md ],
  models `/mnt/ext-xfs-data/models-invoke`, hf cache `/var/cache/invoke-ai/huggingface`.

## 2. existing planning

### 2.1 data/tasks/ briefs [ all plan-only, zero status markers, zero artifacts ]

- data/tasks/network-elf-avatar-pipeline.md [ 309 lines ] — the elfdb brief.
  direction: reference elf acquisition → "IS ELF?" lm-vision filter
  [ confidence > 0.80, ear_topology != not_visible ] → "visual spirit
  essence" extraction [ full JSON schema: ear_geometry, eye_quality,
  facial_geometry, color_palette hex, motion_quality, essence_phrase ] →
  normalization to canonical template [ ear_angle 15-25°, luminosity high ] →
  BMW384 arc 0-25 → 7 domains [ starlight 0-3, forest 4-7, water 8-11,
  void 12-15, fire 16-19, tech 20-22, dawn 23-25 ] → text-to-image with
  reference conditioning [ img2img denoise 0.6-0.75 or IP-Adapter 0.7 ] →
  feedback loop [ regenerate until essence_fidelity > 0.85 ] →
  deterministic per-zenka avatars seeded from BMW384 coordinates →
  `zenka.avatar` registry module [ sketch included ]. output tree:
  `data/gfx/elves/{raw,normalized,composites,essence,avatars}` +
  `data/tasks/research-findings/elves/{essence-parameters.json,domain-map.json,generation-log.json}`.
  rationale: avatar = visualization of the module's harmonic state
  [ coordinate shifts as code quality changes ].
  status: nothing implemented, no data dirs.
- data/tasks/kitten-acquisition-pipeline.md [ 266 lines ] — sibling
  pipeline, positioned as validation not use-case [ "kittens are not the
  use case — kittens are the validation" ]. yandex search → IS KITTEN?
  filter [ confidence > 0.85 ] → 512² face-centered normalization →
  sweetie archetype grouping → mean-pool composites → is_true()
  validation → deployment as translucency layer 2. planned modules:
  `image.kitten.{classify,normalize,archetype}`,
  `route.bmw384.visual.mask.kitten`. nothing implemented.
- data/tasks/crop-circle-acquisition-pipeline.md [ 320 lines ] — third
  pipeline of the triad; source of the yandex adapter the kitten doc
  reuses. modules `image.crop-circle.{normalize,group,composite}`,
  storage `data/gfx/crop-circles/`. nothing implemented.
- data/tasks/crop-circle-assertion-mask.md [ 232 lines ] — mask
  extraction: polar transform → lm-vision geometric JSON → council-of-13
  pooling → matrix[r][θ] assertion weight matrix [ 26 angular × N rings;
  center void 0.0 "the darksun", terminals 1.0, background 0.1 ].
  nothing implemented.
- data/tasks/visual-mask-model-layer.md [ 283 lines ] — revision of all
  three pipelines: replace LLM-vision filter/normalize steps with
  specialized mask models [ SAM, YOLO-seg, MediaPipe 468-point face mesh,
  Hough/ellipse ]; "the mask output IS the assertion weight matrix";
  planned modules `image.mask.{segment,landmarks,to-polar,is-category}`.
  efficiency argument: YOLO-seg ~50M params/50-200ms vs 7B-70B LLM/2-10s.
  [ uncertain: unverified efficiency claims; plan-only. ]
- data/tasks/visual-feedback-capture-analyzer.md + visual-feedback-vision-loop.md
  — different topic: X11/chromium screenshot capture + vision-model
  self-correction loop for visual designs [ see data/md/development/VISUAL-FEEDBACK-EDITOR.md ].
  tangential.
- data/tasks/litter-row-encoding.md — name collision only [ "litter" =
  15-bit zenka bitmap in AMOS7 signature footer line 4 ].
- indirect mentions: data/tasks/SESSION-STATUS-tasks-completed-scan-resume.md:239
  lists network-elf-avatar-pipeline.md in the scan roster [ not marked
  completed ]. no other indirect elf/avatar/sprite task references.

### 2.2 data/md/ design docs

- data/md/design/IMAGE-ZENKA-NATIVE-ARCHITECTURE.md [ 332 lines ] — the
  `images` zenka blueprint: strip InvokeAI [ "80%+ complexity reduction" ],
  clone coding.* spawn/queue patterns into image.*, minimal
  bin/image-inference-server.py [ diffusers + Flask ], image-viewer UI
  zenka [ SHM /dev/shm/.7/image-viewer/<instance>, GTK3 ], 5-phase dev
  order [ phase 1 inference backend → phase 5 distributed generation ],
  explicit retirement list for invoke.*/invoke-web.*/cfg/zenki/{invoke,invoke-web}/.
- data/md/design/VISUAL-GENERATION-NATIVE-ZENKA.md [ 274 lines ] —
  strategic triad: precision [ povray ] + memory [ embeddings ] +
  generation [ image zenka ]; visual memory categories, tournament tiers,
  3-phase transition from invoke zenka [ invoke preserved as backend
  adapter in phase 1 — note: mild tension with the retirement list in
  IMAGE-ZENKA-NATIVE-ARCHITECTURE, see §3.3 ].
- data/md/design/VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES.md [ 415 lines ]
  — `visual.template` zenka: continuous image search → best-5-per-node
  tournament tree with monotonic-quality invariant → living template
  library; export format `data/yaml/visual-templates/current.yaml`.
  [ session-42 origin per data/ai-mem/claude/archive/topic-completed-archive.md ]
- data/md/design/KITTEN-HOLOGRAM-RESOURCE-FILTER.md [ 220 lines ] —
  downstream consumer of the kitten pipeline; depends on its outputs.
- data/md/design/FOUR-VISUAL-DOMAINS.md — semantic frame: kittens =
  ground truth, elves = agency, crop circles = geometry, cosmic space =
  the field; elf-circle-kitten coherence rules [ "a dream without a
  kitten fails a hard constraint" ]; elves at max weight in the
  iris/self-portrait row [ line ~149 ].
- elf-identity docs: NETWORK-ELF-PHILOSOPHY.md, NETWORK-ELF-LAYERED-ARCHITECTURE.md,
  AI-IDENTITY-ADDRESSING-VISION.md, data/md/coding-tasks/zenki-elves-network-habitat.md
  [ summarized in §1.6 ].
- tangential: VISUAL-MASK-AS-BASE-LAYER.md, AUDIO-VISUAL-THUMBNAIL-GENERALIZATION.md,
  ESSENCE-CRYSTAL-INEVITABLE-OUTCOME.md [ not about elf essence despite
  the name ], INITIATIVE-MAP.md [ initiative A: invoke-web ✓, invoke ✓,
  invoke-install ·, invoke-db-access · ], VISION-INDEX.md [ no image-pipeline
  status entries ].
- no design-templates for elf/image exist: data/md/design-templates/ does
  not exist; context.yaml/design-templates/ has 10 topology/visualization
  templates, none elf/avatar/image-specific.

### 2.3 memory [ data/ai-mem/ ]

- data/ai-mem/claude/topic-powershell-native-toast-notifications.md:79-84
  [ 2026-08-24 ] — the only memory anchor for elf-avatars: user plan to
  amend the loves-it toast artwork [ static PNG, cached Windows-side ]
  with "elf-avatar renderings extracted from an existing corpus of tens
  of thousands of text-to-image generations", gated on
  "categorization/categorized-storage tooling built on the lm-vision
  zenka — not started, no scope yet." plus an icon design bar
  [ lines 86-96: psychedelic, non-corporate-flat, unambiguous ].
- data/ai-mem/claude/topic-image-archive-system.md — de-facto `images`
  storage spec: corpus 47,182 images / 81 GB; every invoke PNG embeds
  `invokeai_metadata` JSON [ prompt, seed, model, loras, cfg, steps ] so
  thumbnail + metadata = full image, regeneration via invoke API;
  tiered vision-LLM-scored storage [ high → full res; medium → 50% +
  pngquant; low → 512px thumb; reject → human review ]; defect report
  written back into PNG metadata; model checksum must be stored [ seed
  determinism assumes identical weights ]; model↔image dependency graph;
  path: invoke-image-audit → batch scoring → invoke-image-archive →
  model-manager integration → invoke-image-restore. none implemented.
- data/ai-mem/claude/topic-invoke-model-manager.md [ verified 2026-09-10 ]
  — model manager "standalone first, zenka-ready"; image management a
  separate category [ "47K+ output images … not manageable without
  vision llm zenki" ]; hard rule: fresh explicit confirmation before any
  model-dir deletion [ ~500GB InvokeAI model-wipe incident ].
- data/ai-mem/claude/topic-invoke-model-management.md — invoke.ai storage
  gotchas [ uuid db vs verbose paths, %20 filenames, diffusers
  config.json, :raw writes, partial downloads, stale uuid refs ].
- data/ai-mem/claude/vision-automated-model-testing-and-selection-pipeline.md
  [ 2026-09-17 ] — invoke-model-recover origin; models-invoke vs
  models-lmstudio = permanent separate adapter populations; InvokeAI
  retirement pinned on data/tasks/torch-worker-zenka-foundation.md
  [ Inline::Python+CUDA verified; src/torch.* namespace; not started —
  data/ai-mem/claude/MEMORY-active.md:24 ].
- data/ai-mem/claude/topic-image-archive-adjacent: screenshot corpus
  lessons [ vision-screenshot-corpus-analysis-features.md SEED:
  content-hash dedup on PNG bytes, animation-state tagging, palette
  extraction; project-screenshot-triage-corpus-2026-08-29.md: 531 deduped
  images, phash near-dup review, pngquant 218MB→48MB; checksum-as-lookup-key ].
- icon-generation precedent: project-audio-icon-three-stage-pipeline-landed-2026-07-27.md,
  project-audio-spatial-purr-icon-landed-2026-07-27.md [ entropy-derived
  per-file icon backgrounds, Imager + true-alpha overlays, command-driven ];
  project-audio-waveform-visualization-landed-2026-07-26.md [ PDL+Imager
  pure-perl renderer ].
- "living icons" vision: vision-orbital-hop-sequence-hyperspace-flight-animation.md
  [ icons as looping essence-preview animations; rendering paths
  graphics-matrix.* / audio rotation_stack / povray.* ].
- constraints that bind both new zenki [ from MEMORY.md ]:
  - feedback-deleted-manually-tuned-captures-without-confirming [ CRITICAL ]:
    never delete corpus files without explicit confirmation; ext4, no trash.
  - user-screen-brightness-sensitivity + rapid-pattern-visual-disruption-risk:
    default visuals dark violet/blue; conservative animation cycling.
  - no-personal-data-in-repo-tree: corpus paths/config must use
    `<[file.zenka_dir.load]>`-style resolution or external /data/<project>-data/ dirs.
- kimi side: no elf/avatar/image entries in data/ai-mem/kimi/MEMORY.md;
  only tangential topic-data-directory-reorganization.md.

## 3. synthesis

### 3.1 what the `images` zenka could reuse

- generation backend, today: invoke zenka's queue model [ enqueue + 3s
  poll, src/invoke.api.build_graph, src/invoke.handler.poll_jobs ] and
  invoke-web's proven process management [ IPC::Open3 spawn, pid
  adoption, health timer — directly cloneable per
  IMAGE-ZENKA-NATIVE-ARCHITECTURE's "clone coding.* patterns" approach ].
- analysis backbone: lm-vision [ analyze-image / complete-analysis ] +
  image-quality backends + vision-batch YAML-spec batch orchestration
  [ fork-child + jobqueue ] — exactly the scoring engine the archive
  system spec assumes.
- storage/dedup thinking: topic-image-archive-system.md [ tiers, PNG
  metadata writeback, model-checksum-coupled regeneration ];
  graphics.matrix.visual.phash/hamming for near-dup detection
  [ but see broken color_sample caveat, §1.3 ].
- rendering primitives: audio zenka's Imager/PDL icon pipeline
  [ per-file generated imagery with a fixed command surface ];
  image2html's Graphics::Magick conversion for HTML views.
- identity/provenance hooks: models.storage.adapter.invoke.* [ model
  uuid resolution ]; AMOS7 chksum + BMW384 coordinate machinery for
  deterministic seeds [ network-elf-avatar-pipeline.md step 6 already
  assumes `<[chk-sum.bmw384.coordinate]>` exists ].

### 3.2 what an `elfdb` needs [ as far as the plans describe it ]

- the avatar pipeline brief defines everything except the db itself:
  acquisition source [ yandex adapter from crop-circle brief ], IS ELF?
  classification via lm-vision [ or mask models per visual-mask-model-layer ],
  essence JSON schema, canonical composites per domain, generation with
  reference conditioning [ img2img / IP-Adapter ], feedback loop, and a
  `zenka.avatar` lookup [ namespace → avatar path, regenerate on BMW384
  coordinate change ].
- memory adds the corpus-extraction angle: tens of thousands of existing
  invoke T2I generations [ 47,182 / 81 GB ] as raw material, categorized
  by lm-vision tooling, with first consumer = loves-it toast artwork.
  [ uncertain: whether elfdb should index the existing corpus, generate
  fresh, or both — the briefs only cover the generate-fresh path. ]
- plausible record shape [ inferred, not specified anywhere ]: elf
  identity key [ ELF:<hash> addressing from AI-IDENTITY-ADDRESSING-VISION.md
  or BMW384 coordinate ], essence parameter JSON, generation provenance
  [ prompt, seed, model checksum — per archive-system spec ], image path
  or "regenerable from coordinate" [ brief explicitly says no storage
  needed for the image itself ].
- no schema, no index format, no db technology choice exists anywhere yet.

### 3.3 overlaps, contradictions, outdated items

- overlap [ planned, acceptable]: briefs claim module namespaces
  `image.kitten.*`, `image.crop-circle.*`, `image.mask.*`,
  `zenka.avatar`, `route.bmw384.visual.mask.*` — all in the future
  `image.*`-adjacent space that the `images` zenka also occupies.
  resolution deferred to module cross-loading per user instruction.
- contradiction: IMAGE-ZENKA-NATIVE-ARCHITECTURE.md says invoke code is
  retired by the image zenka; VISUAL-GENERATION-NATIVE-ZENKA.md phase 1
  says invoke is preserved as a backend adapter. [ reconcile at design
  time: adapter vs retire. ]
- outdated risk: both invoke docs and the archive spec predate the
  torch-worker plan [ Inline::Python+CUDA as the pinned InvokeAI
  replacement ]; any `images` design that hard-binds to InvokeAI's API
  shape inherits that retirement. the corpus-metadata-regeneration
  assumption [ invokeai_metadata JSON in PNGs ] is InvokeAI-specific.
- tension: the avatar pipeline says "no storage needed for the image
  itself" [ deterministic seed from coordinate ], while
  topic-image-archive-system.md says store tiered full data because
  regeneration requires identical model weights [ checksum-coupled ].
  [ these can coexist — cache vs canonical — but the design must say so. ]
- tension: visual-mask-model-layer.md proposes replacing lm-vision
  filtering with SAM/YOLO/MediaPipe mask models; the avatar and kitten
  briefs assume lm-vision LLM filtering. [ cost/quality tradeoff
  unresolved; opencv zenka shell exists as a middle pre-pass. ]
- outdated: data/md/design-templates/ referenced in some docs does not
  exist; all four pipeline briefs have zero status markers and predate
  the vision-batch/image-quality infrastructure they could now use
  [ briefs written as if from scratch — lm-vision + vision-batch +
  image-quality already provide steps 2-3 of every pipeline ].
- no-personal-data-in-repo-tree vs planned paths: briefs write
  `data/gfx/elves/...` inside the repo tree [ likely fine for generated
  art, but raw scraped reference corpora at scale may belong in an
  external /data/<project>-data/ dir per the memory rule — decide early ].

### 3.4 open questions for the user [ decide before design starts ]

1. name/namespace: `images` vs `image` [ briefs use `image.*` module
   prefixes; design docs say "image zenka"; the user now says `images` —
   one name should win, zenka name and module namespace should match
   existing conventions like lm-vision/image-quality hyphenation ].
2. elfdb scope: corpus index of existing 47K invoke generations,
   generator of fresh canonical elves, per-zenka avatar registry, or all
   three [ the sources each describe a different one; no doc unifies them ].
3. identity key: BMW384 coordinate [ avatar brief ], ELF:<6×hash>
   addressing [ identity doc ], or both linked [ do zenka avatars and
   LLM-instance elves share one db? the docs treat them as separate
   concepts that happen to share the name ].
4. storage philosophy: deterministic-regeneration-only vs stored
   tiered corpus [ affects whether elfdb even needs image storage or
   only metadata + prompts + seeds ].
5. filter stack: lm-vision LLM filtering [ current infra ] vs
   SAM/YOLO/MediaPipe mask models [ visual-mask-model-layer ] vs hybrid
   opencv pre-pass [ vision-orbital-hop doc's escalation pattern ].
6. backend dependency: build `images` on the invoke queue API now and
   migrate to torch-worker later, or wait for torch-worker
   [ InvokeAI retirement is already pinned; a separate session is
     fixing invoke-web's startup bug — sequencing decision ].
7. where raw scraped corpora live [ repo tree vs external data dir ]
   and the deletion-confirmation workflow for any corpus pruning.
8. graphics-matrix cross-loading: which modules [ phash, hamming,
   extract-palette, similarity, group-by-* ] move to shared/base space
   or get loaded cross-zenka, given the two live bugs in
   graphics.matrix.visual.similarity.

### 3.5 graphics-matrix overlap candidates [ for later cross-loading ]

- perceptual dedup/clustering: graphics.matrix.visual.{phash,hamming,
  similarity,find-clusters,cluster-center,group-by-color,group-by-proximity}
  — candidate for images [ corpus dedup ] and elfdb [ essence grouping ].
  [ blocked by: color_sample bug, cubic-color-space coupling ]
- palette/color: graphics.matrix.visual.{extract-color,extract-palette,color}
  — candidate for essence color_palette extraction [ pipeline step 3
  outputs hex palettes ] and visual-templates global_palette.
- batch scaffolding: graphics.matrix.visual.{generate-batch-id,vision-batches}
  vs vision-batch.parent.* — two batch-spec idioms to reconcile.
- cursor/cell/glow/harmonic machinery — candidate for avatar "living
  icon" animation [ vision-orbital-hop doc names graphics-matrix as the
  likely center of gravity ]; voxel/harmonic-coords overlap with
  route.bmw384.visual.mask.* addressing from the mask briefs.
- document filters [ c2a/rep-col ] — no overlap with images/elfdb
  [ listed to mark as non-overlapping ].

#,,.,,,,.,,.,,,,.,,.,,,,,..,,,..,,,,,,,,,,,.,.,..,,,,,,,.,.,.,.,,,,,,.,,,,.,,,.

#,,..,..,,,,,,.,.,,,.,.,.,,,,,,..,.,,,,.,,.,.,..,,...,...,,..,.,.,...,,,.,,.,,
#NM4L2TWVY24ZQSSD2T77GB5RNOHQQ7JBL57E6P2J3PDPWHMQPNKUCWV3QZHLS4TADAEHIJP2423PS
#\\\|JNXRYABEKGDX6EDD2LJPZYAVY2Q3F4S4NCGPAC2LGQV3LGKEXNI \ / AMOS7 \ YOURUM ::
#\[7]EEDSAP34NZY5OMP24FDCYFPXYM7B3AC6JEYT4SJS2ZVH5XL7BKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
