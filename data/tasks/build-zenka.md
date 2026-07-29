# build zenka — task

## context

design: [[NETWORK-BUILD-SYSTEM]] (data/md/design/NETWORK-BUILD-SYSTEM.md) —
this task implements layer 1 only ("build.zenka + docker backend");
layers 2-6 (build graph, network distribution, consensus, LLM audit
intake) are separate future tasks, not in scope here.
prompted by: fasttext CLI dependency for [[dep-graph-semantic-embeddings]]
— turned out to have a debian package (added as the `embeddings` profile
in .deps/profiles.yaml) so no build was needed, but the ad-hoc source
build done in the meantime (shallow clone + `make`, no recipe, no
cleanup, gitignored one-off) is exactly the pattern this zenka should
replace going forward.

flagship real use case: ik_llama.cpp. no debian package exists for it;
protocol-7 already has hand-run, manually-documented build recipes:

    bin/build-scripts/llama-cpp/build-cuda-docker.sh
    bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh
    bin/build-scripts/README.md               — full manual runbook
    data/yaml/build-instructions/ik_llama_dual_strategy_2025-12-05.yaml
    data/yaml/build-instructions/ik_llama_cuda_gpu_build_successful-2025-12-05.yaml
    data/yaml/build-instructions/ik_llama_cpu_build_successful-2025-12-05.yaml
    data/yaml/archive/build-logs/build-ik_llama_containerized-strategy-2025-12-05.yaml
    data/yaml/archive/build-logs/build-ik_llama_cuda-failure-2025-12-05.yaml
    data/yaml/archive/build-logs/build-ik_llama_vulkan-progress-2025-12-05.yaml
    data/patches/iqk-symbol-extern-c-fix.patch  — own-fork patch, must
                                                   survive rebuilds
    data/md/documentation/BUILD-VISION-PIPELINE.md — step-by-step guide
    bin/build-scripts/README.md branch note: build must happen on the
    `fix_cli_log` branch of the ik_llama.cpp fork (disables broken
    LOG_TEE macro) — this IS the "own-fork awareness" the design doc
    describes, already discovered by hand, not yet encoded as data.
    bin/install-scripts/install_llama_cuda.sh  — the extract/symlink
    step (source binaries in build/bin → /usr/local/bin) NETWORK-BUILD-
    SYSTEM.md already describes as part of layer 1; not a new concern,
    confirms build.recipe.run's artifact-extraction step (task 1.3).

this is a rescue-and-generalize task, not greenfield: the manual runbook
already solved the hard part (glibc/CUDA incompatibility → Docker with
Ubuntu 22.04 base). the zenka's job is to make that runbook executable
and repeatable instead of copy-pasted by a human or a dispatched agent
each time.

two more existing scripts under bin/install-scripts/ turn out to be the
SAME recipe shape with a different source kind — not git+build, but
fetch-verify-place:

    bin/install-scripts/download_impressive.pl — sourceforge/mirror
    tarball, sha1-verified (archive AND extracted file both checked
    against pinned hashes), single file extracted straight to its
    install path. no compilation: the "build" step is verify+extract.

    bin/install-scripts/install_mediainfo.pl — fetches PREBUILT vendor
    .deb packages directly from mediaarea.net (version-checked against
    an rss feed, architecture-detected), installs via dpkg. no source,
    no compilation: the "build" step is fetch+dpkg-install.

so the recipe registry needs a `kind` field, not just a `backend` field
— git-build (ik_llama.cpp), tarball-extract (impressive), and
vendor-deb (mediainfo) are three source shapes the same registry should
express, all wrapping existing working scripts rather than rewriting
them from scratch.

a fourth kind exists too — InvokeAI, per
data/md/documentation/INVOKE-MIGRATION-PLAN.md phase 2.1 option B:

    kind: pip-venv — `uv venv --python 3.11` + `uv pip install invokeai`
    into an isolated venv (INVOKEAI_ROOT env var points at model/output
    dirs, kept separate from the venv itself). no git clone, no
    compilation, no .deb — a python package install into a project-
    local environment, checksummable/reinstallable the same way as the
    other three kinds.

explicitly OUT of scope:

    bin/install-scripts/install_privoxy.sh — no build/fetch-artifact
    step at all: apt-get install + sed config mutation + systemctl
    restart. system *provisioning*, a different problem shape (no
    artifact, no checksum, no consensus story) from everything above.
    may become its own "provision.zenka" task later if the need
    recurs; forcing it into this recipe schema would blur what a
    "recipe" means here.

    kimi-cli and claude — turned out NOT to be unpackaged software at
    all: kimi-cli is a normal pip package (`pip index versions kimi-cli`
    confirms it on PyPI, currently 1.49.0) and claude is a normal npm
    package (`@anthropic-ai/claude-code`, currently 2.1.220). both are
    self-updating once installed, which matters for lifecycle (install-
    if-missing, never force-reinstall/patch) but the install mechanism
    itself is just "ask a package manager for a package" — pip/npm, not
    git-build/tarball/vendor-deb/pip-venv. see [[ext-pkg-zenka]]: they
    belong there, not here. build-zenka is specifically for software
    with NO package-manager path at all.

full three-way split, so nothing falls into a categorical blind spot
between the task files:

    os-pkg zenka (configuration/zenki/os-pkg/, currently a stub —
      modules/os-pkg.init_code is just `0;`) — OS-distro packages,
      apt/dpkg only, per its own `start` file description
    [[ext-pkg-zenka]] (new task, greenfield) — external package-manager
      ecosystems: pip, npm, uv tool. kimi and claude are its first two
      real entries.
    build-zenka (this file) — genuinely unpackaged software: git-build,
      tarball-extract, vendor-deb, pip-venv (isolated envs, not global
      pip installs — that distinction is what separates InvokeAI here
      from kimi-cli in ext-pkg-zenka)

## goals

1. `build.<recipe>.run` as a zenka command: given a named recipe, run
   the build (dockerized where the recipe requires it), extract
   artifacts, report checksums — no manual script invocation required
2. recipe registry: existing scripts/procedures (git+build,
   tarball+checksum extract, vendor-.deb fetch, or pip/venv install)
   become named, versioned recipes with declared source/patches/
   checksums, not ad-hoc scripts run by hand
3. own-fork awareness: track which patches/branch requirements apply
   to which source repo; detect when upstream moves past a patch
   (clean-apply vs conflict) before blindly rebuilding
4. fallback-only positioning: recipes are for cases with NO packaged
   alternative (ik_llama.cpp) — always check .deps/profiles.yaml /
   apt first; a recipe existing does not mean it should run by default
5. everything local — no network distribution, no consensus voting;
   those are layers 2+ and explicitly out of scope for this task

## phase 1 — zenka scaffold + recipe registry

### task 1.1 — create build zenka
```
## dispatch + prompt
create configuration/zenki/build/ following the zenka-startup.v7 +
start script pattern from configuration/zenki/letsencr/ (access.zenki
pattern from configuration/zenki/cube/ or configuration/zenki/transport/
— letsencr has none, see data/tasks/openvas-agent.md task 1.1 for the
same note). bootable, stoppable, registered. no modules yet.
```

### task 1.2 — recipe registry format
```
## dispatch + prompt
design the recipe registry: one yaml file per recipe under
configuration/zenki/build/recipes/<name>.yaml. top-level `kind` field
selects the source/install shape, since four already exist in the repo
as hand-run scripts or documented procedures:

  kind: git-build     — source: git url + branch/tag; patches: paths
                         under data/patches/, each declared clean-apply
                         vs known-conflict; build backend: docker |
                         native; build script reference (existing
                         scripts in bin/build-scripts/ become the
                         backing script, not rewritten); output
                         artifact paths + install destination
                         (mirrors bin/install-scripts/install_llama_cuda.sh)

  kind: tarball-extract — source: list of mirror urls (first success
                         wins, as download_impressive.pl already does);
                         pinned checksums for BOTH the archive and the
                         extracted file(s) (sha1 in the existing
                         script — keep it, don't silently swap
                         algorithms); install destination path

  kind: vendor-deb     — version-check source (e.g. an rss/atom feed
                         url, as install_mediainfo.pl uses); per-arch
                         package url pattern; install via dpkg

  kind: pip-venv       — python version pin; venv location; package
                         name/version (uv pip install <pkg>); env vars
                         the tool needs pointed at data dirs outside the
                         venv (e.g. INVOKEAI_ROOT), so venv deletion/
                         recreation never touches user data

write the schema, then encode four recipes against it, reusing the
existing scripts/procedures as the backing implementation rather than
rewriting their logic:
  ik_llama-cuda   (kind: git-build)   ← bin/build-scripts/llama-cpp/
                                        build-cuda-docker.sh +
                                        build-instructions yaml +
                                        iqk-symbol-extern-c-fix.patch +
                                        fix_cli_log branch requirement
  impressive      (kind: tarball-extract) ← download_impressive.pl
  mediainfo       (kind: vendor-deb)  ← install_mediainfo.pl
  invokeai        (kind: pip-venv)    ← data/md/documentation/
                                        INVOKE-MIGRATION-PLAN.md
                                        phase 2.1 option B
```

### task 1.3 — build.recipe.run
```
## dispatch + prompt
new module build.recipe.run: args recipe name, optional force-rebuild
flag. loads the recipe yaml and dispatches on `kind`:

  git-build: checks out source at the declared branch/tag, applies
  declared patches (report clean-apply vs conflict — do NOT force-apply
  a conflicting patch, halt and report instead), runs the build (docker
  backend: invoke the existing bin/build-scripts/llama-cpp/
  build-cuda-docker.sh style script inside the zenka rather than
  duplicating its logic; native backend: shell out to the declared
  build command), extracts artifacts to the declared install
  destination (same move bin/install-scripts/install_llama_cuda.sh does
  by hand today).

  tarball-extract: downloads from the mirror list (first success wins),
  verifies archive checksum, extracts, verifies extracted-file
  checksum, places at install destination — same sequence
  download_impressive.pl already implements; wrap it, don't rewrite it.

  vendor-deb: checks declared version source, fetches the arch-matched
  package url, installs via dpkg — same sequence
  install_mediainfo.pl already implements.

  pip-venv: creates the venv at the declared location (recreate-safe —
  never touches the declared external data dirs), installs the pinned
  package, exports the declared env vars for anything that invokes the
  tool afterward — same sequence as INVOKE-MIGRATION-PLAN.md phase 2.1
  option B.

all four kinds: compute and store a checksum record after install
(reuse an existing AMOS7/base checksum module — see
modules/base.chk-sum.*) and write a build log entry per run.
```

## phase 2 — patch drift detection (optional, do if phase 1 lands clean)

### task 2.1 — own-fork patch tracking
```
## dispatch + prompt
new module build.recipe.check-patch-drift: for a recipe with declared
patches, fetch upstream's current HEAD for the declared branch, dry-run
apply each patch (git apply --check), report clean/conflict per patch
without mutating the working tree. this is the concrete mechanism
behind NETWORK-BUILD-SYSTEM.md's "own-fork awareness" — flags when
ik_llama.cpp's fix_cli_log branch or the iqk-symbol patch needs
attention after an upstream pull, instead of discovering it mid-build.
```

## notes

- do NOT build anything as part of scaffolding — task 1.1/1.2/1.3 are
  registry + orchestration only; running the actual ik_llama.cpp build
  is a manual verification step once build.recipe.run exists, not part
  of the implementation task.
- fasttext is explicitly NOT a recipe candidate — it has a debian
  package now (`embeddings` profile). recipes are for genuinely
  unpackaged software; always check .deps/profiles.yaml first, and if
  a package exists, use it instead of writing a recipe.
- the existing bin/build-scripts/ shell scripts should be referenced
  and invoked, not rewritten in perl — the zenka wraps orchestration
  (patch application, checkout, artifact extraction, checksums), it
  does not need to reimplement docker build logic that already works.
- layers 2 (build graph / dependency ordering between recipes) and
  beyond (network distribution, 5/7 consensus, LLM audit intake) are
  explicitly out of scope — see [[NETWORK-BUILD-SYSTEM]] for the full
  vision; this task is layer 1 only.

#,,,.,...,,,.,.,.,..,,..,,.,.,,..,.,,,.,.,,,.,..,,...,...,.,.,,,.,..,,...,.,,,
#NL6JW4MBH4TKJL7W7HLHRFPEZRQJODDRW4NC4DF7VFRRGTZTRKX2VRXIP5MM2BFW7QKKM2JGZWXAC
#\\\|XBMLTUUVMPKG6XKRQ2EEEY7S44XSGA4QQEQZ3WYANWULFW64E7D \ / AMOS7 \ YOURUM ::
#\[7]NMDQSM4456FB4LCGIT2C6VJSRPGEM2DYYUOX37KCEWG6HICY24AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
