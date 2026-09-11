## [:< ##

# name  = task: install LoRA training stack for coding-lora-p7-idioms
# descr = install torch/transformers/peft/bitsandbytes on this host and
#         confirm they work against the actual CUDA driver, without
#         touching the live coding zenka's GPU inference server

## context

read `data/tasks/coding-lora-p7-idioms.md` first, specifically its
"hazards that waste a run" section item 1 and scope item 2 -- **this
task file covers ONLY that one scope item (environment setup).** the
dataset, base-checkpoint fetch, training, conversion, and cfg-wiring
steps are separate, later tasks -- not in scope here, do not start them.

read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md`
before starting, same as any other P7 task.

## confirmed host facts [ do not re-derive, just use these ]

- `python3 --version` -> 3.13.15
- no training stack installed at all: `torch`/`peft`/`transformers` all
  `ModuleNotFoundError` (confirmed 2026-09-10, this session)
- GPU: RTX 3060, 12288MB total, **currently only ~243MB free** -- the
  live coding zenka's own inference server
  (`/data/source/ik_llama.cpp/llama-server-cuda-fa`, pid runs as user
  `protoco+`, serving the 9B Q4_K_M model on port 8000) is running and
  actively in use. **do not stop, restart, or otherwise touch this
  process or port 8000 -- that is a separate, later, human-scheduled
  step, not part of this task.**
- driver: `nvidia-smi` reports `NVIDIA-SMI 610.57.04`, `CUDA UMD Version:
  13.1` -- so any current stable CUDA 12.x pip wheel build of torch is
  within the driver's supported range (drivers are backward-compatible
  with older CUDA runtime builds bundled in the pip wheel).
- `nvcc` is not installed / not on PATH -- that's fine, pip-installed
  torch wheels bundle their own CUDA runtime and don't need a system
  CUDA toolkit for inference/training use.
- disk: 877G free on `/` (home for pip/venv installs), 131G free on
  `/mnt/ext-xfs-data` (where model checkpoints live)

## scope

1. install a training stack: `torch` (stable CUDA 12.x wheel matching
   the driver above), `transformers`, `peft`, `bitsandbytes` (needed for
   4-bit QLoRA given the ~12GB VRAM constraint), `accelerate`. use
   whatever install mechanism is idiomatic for this host (check for an
   existing venv/pyenv convention in the repo first -- e.g. `bin/p7-deps`
   or existing python tooling under `bin/dependencies/` -- before
   defaulting to a bare global `pip install`; if none exists, a
   dedicated venv, e.g. under `/data/projects/protocol-7/.venv-lora` or
   similar, is preferable to polluting system python).
2. **verification must NOT load any real model or allocate meaningful
   GPU memory** -- the live server above is holding nearly all VRAM and
   must be left running and undisturbed. verification is limited to:
   - `python3 -c "import torch; print(torch.__version__,
     torch.version.cuda, torch.cuda.is_available())"`
   - `torch.cuda.get_device_name(0)` (a cheap driver/device query, not a
     tensor allocation)
   - `import transformers, peft, bitsandbytes; print(<their
     __version__>)`
   - if any of the above needs more than a trivial amount of VRAM to
     even report `torch.cuda.is_available()`, stop and report that
     finding rather than trying larger allocations to "test harder" --
     that would risk crashing the live server.
3. record the exact installed package versions and the exact install
   command/mechanism used (venv path if one was created) in your final
   report -- the later training task will need this to know how to
   invoke python.

## explicitly out of scope

- fetching the HF checkpoint (`fetch.file.huggingface.*`) -- separate task
- writing/expanding the training dataset -- separate task
- writing any training code, LoRA config, rank/target-module choice --
  separate task
- touching `cfg/zenki/coding/*`, `src/coding.*`, or any P7 zenka source
  file -- this task is host-environment setup only, no repo source
  changes
- stopping, restarting, or reconfiguring the live
  `llama-server-cuda-fa` process or anything under `cfg/zenki/coding/`
- running any actual model download or training run

## if you learn something non-obvious

if you hit a real gotcha (e.g. a specific bitsandbytes/CUDA version
mismatch, a wheel that doesn't have a prebuilt binary for this python/
CUDA combo, a driver quirk), add a note to
`data/ai-mem/kimi/coding-style.md` or `data/ai-mem/kimi/MEMORY.md` in
your own established format before finishing, same as any other task.

do not add any trailing signature/checksum footer to this file or any
new file you create for this task -- the real signing pipeline
(`bin/Protocol-7 sourcecode update-signatures`) adds that later, a
drafted one is never correct.

## results [ 2026-09-10 ]

- mechanism: dedicated uv venv at `.venv-lora/` (no existing python
  tooling convention in `bin/dependencies/` -- perl/debian only).
  `.gitignore` entry added so the venv is never committed.
- install commands (recreate verbatim):
  1. `uv venv .venv-lora --python /usr/bin/python3`
  2. `uv pip install --python .venv-lora/bin/python torch --index-url https://download.pytorch.org/whl/cu126`
  3. `uv pip install --python .venv-lora/bin/python transformers peft accelerate bitsandbytes`
- installed versions (pinned by uv lockfile-in-place, record from live
  env): torch 2.14.0+cu126 (CUDA runtime 12.6), transformers 5.17.0,
  peft 0.20.0, bitsandbytes 0.50.2, accelerate 1.15.0
- later training task invokes python as
  `/data/projects/protocol-7/.venv-lora/bin/python`
- verification (cheap, no tensor allocation, live server undisturbed
  throughout -- `llama-server-cuda-fa` pid 1835516 never touched):
  `torch.cuda.is_available()` -> True, device 0 -> NVIDIA GeForce
  RTX 3060; all five packages import and report the versions above.
  VRAM before/after verification unchanged (~11.4GB used by the live
  server, ~0.3GB free).
- gotcha note for the training task: transformers resolved to major
  version **5** (5.17.0), not v4 -- any QLoRA training code must be
  written/checked against the transformers-5 API surface; v4-era
  tutorials may not apply. Also recorded in
  `data/ai-mem/kimi/coding-style.md`.

#,,,,,,..,...,,,.,,,.,.,,,.,,,.,,,..,,,..,,..,..,,...,...,.,,,,,.,.,,,.,.,,..,
#M52UXHXBSSX2IOHQHEGYWMRVFYVR57FELYQHK54OOFZ3OHP2GQFALYINYE2WTG5RUDZMNFSI5MB3S
#\\\|C6UOBHAIH7HA5HJN2M64AW3O5KMS3FOKVQVG2J6GCZJ6USQTOGL \ / AMOS7 \ YOURUM ::
#\[7]QQN5GEV3PXWXJ5CUFJ7M2Z4K4Z4DKTCMFPB76RWFP5DJTETM2YBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
