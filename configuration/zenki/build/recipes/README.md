# build zenka recipe registry — schema

one yaml file per recipe : `configuration/zenki/build/recipes/<name>.yaml`.
consumed by the `recipe.run` command [ `modules/build.cmd.recipe.run` ],
which dispatches on the top-level `kind` field.

recipes are **fallback-only** : they exist for software with NO packaged
alternative. always check `.deps/profiles.yaml` / apt first — a recipe
existing does not mean it should run by default. [ kimi-cli / claude are
pip/npm packages and belong to ext-pkg-zenka, not here. ]

recipes **wrap existing scripts**, they do not replace them : the backing
scripts under `bin/build-scripts/` and `bin/install-scripts/` remain the
implementation; the registry makes them named, versioned and declared
[ source / patches / checksums / install destination ] instead of ad-hoc.

## common fields [ all kinds ]

```yaml
name: <recipe-name>            # must match the file name
kind: git-build | tarball-extract | vendor-deb | pip-venv
descr: <one line>
backing_script: <repo-relative path>   # existing script being wrapped
reference: <docs this recipe encodes>
install:
  destination: <absolute path>     # where the artifact ends up
  requires_root: 1                 # install step needs root [ see notes ]
notes: <free text>
```

`install.requires_root: 1` means the install step is SKIPPED [ with a
reported manual command ] when the zenka runs unprivileged — builds and
checksum records still complete. this mirrors reality : the wrapped
scripts [ install_llama_cuda.sh, download_impressive.pl, .., ] chown to
root / write under /usr/local.

## kind: git-build

source checked out from git, own-fork patches applied, built via docker
or native backend, artifacts extracted to an install destination.

```yaml
kind: git-build
source:
  git_url: <clone url>
  branch: <branch-or-tag>        # own-fork branch requirements live here
  work_dir: <absolute path>      # checkout location [ reused across runs ]
patches:                         # applied in order, before the build
  - path: data/patches/<file>.patch   # repo-relative or absolute
    expect: clean-apply | known-conflict
build:
  backend: docker | native
  script: <repo-relative path>   # docker backend : existing build script
  command: <shell command>       # native backend : run in source.work_dir
  env:                           # exported for the build script
    KEY: value
artifacts:                       # paths [ relative to source.work_dir ]
  - <path>                       # existence verified + bmw-384 checksummed
install:
  script: <repo-relative path>   # optional extract/symlink backing script
  destination: <absolute path>
  requires_root: 1
```

patch handling in `recipe.run` [ `modules/build.cmd.recipe.run` ] :
`git apply --check` per declared
patch — clean → applied ; already applied [ reverse-check ] → skipped ;
conflict → **halt and report**, never force-applied. [ phase 2 adds
drift detection against upstream HEAD. ]

## kind: tarball-extract

fetch-verify-place : mirror list [ first success wins ], pinned checksums
for BOTH the archive and the extracted file(s), no compilation.

```yaml
kind: tarball-extract
source:
  version: <upstream version>
  mirrors:
    - <url>                      # tried in order, first success wins
checksums:
  algorithm: sha1                # keep the backing script's algorithm,
                                 # do NOT silently swap
  archive: <hex>
  files:
    <extracted-file>: <hex>
  sizes:                         # byte sizes as additional pin [ optional ]
    archive: <n>
extract:
  member: <archive-member-path>  # single file extracted from the archive
install:
  destination: <absolute path>   # final installed file path
  requires_root: 1
```

## kind: vendor-deb

prebuilt vendor .deb packages fetched from the vendor site [ version
checked against a feed ], installed via dpkg. no source, no compilation.

```yaml
kind: vendor-deb
version_check:
  feed_url: <rss/atom feed url>
  pattern: <regex with one capture group>   # as the backing script uses
source:
  base_url: <vendor download base url>
  packages: [ <pkg>, .., ]       # fetch order matters [ libs first ]
  arch_map:                      # uname -m -> vendor arch string
    x86_64: amd64
install:
  method: dpkg
  requires_root: 1
```

## kind: pip-venv

python package installed into an isolated, project-local venv [ NOT a
global pip install — that distinction separates pip-venv recipes here
from ext-pkg-zenka ]. recreate-safe : deleting/recreating the venv never
touches declared external data dirs.

```yaml
kind: pip-venv
python: '3.11'                   # version pin for venv creation
venv:
  tool: uv
  path: <absolute venv path>
package:
  name: <pypi name>
  version: <pin or null>         # null = latest [ unpinned upstream ]
env:                             # exported for anything invoking the tool
  KEY: <absolute path>           # written to data/build/env/<name>.env
data_dirs:                       # NEVER touched by venv recreation
  - <absolute path>
```

## post-install record [ all kinds ]

every run writes :

- `data/build/logs/build-<name>-<epoch>.yaml` — full build log entry
  [ kind, steps, exit codes, captured output tails, status ]
- `data/build/checksums/<name>.yaml` — checksum record : bmw-384 sums of
  installed artifacts [ via `base.chk-sum.bmw.filesum` ], install paths,
  recipe name/kind, timestamp
