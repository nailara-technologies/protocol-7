# task: fetch.file.huggingface — model download zenka

## context

local model availability is a recurring friction point: GPU crashes on wrong
quantization, models missing after disk events, switching between sizes manually.
this task implements `fetch.file.huggingface.*` — a p7 command interface for
downloading GGUF models from HuggingFace into the correct local storage paths.

design is distributed across:
  data/md/documentation/SELF-CONTAINED-ZENKA-VISION.md  → fetch.file.huggingface namespace
  data/md/design/MODELS-PATH-ADAPTERS.md                → category subdir routing
  data/md/coding-tasks/invoke-ai-model-storage-management.md → LAN-first, HF-second pattern
  data/md/documentation/MODELS-PATH-CONFIGURATION.md    → storage paths and config keys
  data/md/documentation/EXTERNAL-INFERENCE-MODELS-CONFIG.md → HF cache config

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## what to implement

### fetch.file.huggingface

primary download command:

```
args: {
  repo    => 'bartowski/gemma-3-4b-it-GGUF',   ## HuggingFace repo id
  file    => 'gemma-3-4b-it-Q4_K_S.gguf',      ## specific file to download
  dest    => undef,                              ## auto-detect from model type
}

auto-detect destination:
  GGUF files → <external.models.path> (the lmstudio models directory)
  default:    /mnt/ext-xfs-data/models-lmst/

download command (uses huggingface-cli if available, wget fallback):
  huggingface-cli download <repo> <file> --local-dir <dest>
  OR:
  wget "https://huggingface.co/<repo>/resolve/main/<file>" -O <dest>/<file>

returns: {
  ok       => 1,
  path     => '/mnt/ext-xfs-data/models-lmst/gemma-3-4b-it-Q4_K_S.gguf',
  size_gb  => 2.41,
  duration => 143,   ## seconds
}
```

### fetch.file.huggingface.list

list available quantizations for a model repo:

```
args: { repo => 'bartowski/gemma-3-4b-it-GGUF' }

uses HuggingFace API: https://huggingface.co/api/models/<repo>
  → parse siblings[] for .gguf files
  → show filename, size, download count

returns formatted table:
  file                           size      downloads
  gemma-3-4b-it-Q4_K_S.gguf    2.41 GB   12,450
  gemma-3-4b-it-Q4_K_M.gguf    2.49 GB   8,234
  gemma-3-4b-it-Q8_0.gguf      4.67 GB   3,891

uses clients.http.get (non-blocking) — see src/clients.http.*
HF API does not require auth for public models
```

### fetch.file.huggingface.search

search HuggingFace for GGUF models by name:

```
args: { query => 'gemma 4b GGUF', limit => 10 }

uses: https://huggingface.co/api/models?search=<query>&filter=gguf&limit=10
returns: list of { repo_id, model_name, downloads, last_modified }

formatted output:
  repo id                          downloads   updated
  bartowski/gemma-3-4b-it-GGUF    45,231      2025-03-12
  lmstudio-community/gemma-2-9b   28,103      2025-02-28
```

### fetch.file.huggingface.lan-check

check if a model file is available on LAN hosts before downloading from HF:

```
## LAN hosts are configured in network topology or discovered via p7 network
## check each known host for the file at their models path
## if found: rsync/scp instead of HF download (much faster on LAN)

args: { filename => 'gemma-3-4b-it-Q4_K_S.gguf' }
returns: { found => 1, host => '192.168.1.X', path => '/mnt/models/...' }
         OR { found => 0 }
```

### fetch.file.huggingface.status

show download progress for active downloads:

```
reads from a progress state hash keyed by filename
shows: filename, downloaded MB, total MB, speed MB/s, ETA
updated by the download handler in real-time
```

---

## configuration

```
## existing config keys to read:
<external.models.path>              ## destination for GGUF files
<external.models.huggingface.cache> ## HF configs cache (not GGUF)
<external.hf.token>                 ## HuggingFace API token (optional for public)

## new config keys to add:
fetch.file.lan_hosts = 192.168.1.X 192.168.1.Y  ## space-separated LAN hosts to check
fetch.file.hf_token  = <token>                   ## same as external.hf.token alias
```

---

## zenka config

```
## cfg/zenki/fetch-file/zenka.v7
[load_modules:fetch.file.huggingface fetch.file.huggingface.list
              fetch.file.huggingface.search fetch.file.huggingface.lan-check
              fetch.file.huggingface.status]
[init_modules]
[zenka.loop]
```

```
## cfg/zenki/fetch-file/start.cfg
start.on-demand = 1
restart.disabled = 1
heartbeat.disabled = 1
```

---

## p7 command interface

```bash
## list quantizations available for a model
p7 fetch.file.huggingface.list '{"repo":"bartowski/gemma-3-4b-it-GGUF"}'

## search for models
p7 fetch.file.huggingface.search '{"query":"gemma 4b uncensored GGUF"}'

## download specific file
p7 fetch.file.huggingface '{"repo":"bartowski/gemma-3-4b-it-GGUF","file":"gemma-3-4b-it-Q4_K_S.gguf"}'

## check LAN first
p7 fetch.file.huggingface.lan-check '{"filename":"gemma-3-4b-it-Q4_K_S.gguf"}'

## check download progress
p7 fetch.file.huggingface.status
```

---

## implementation notes

- use `clients.http.*` for all HTTP requests (non-blocking, already implemented)
- the download itself: spawn a child process (`IPC::Open3` or `open3`) running
  `huggingface-cli download` or `wget`, capture progress output, update state hash
- progress parsing: wget outputs `X% [=====>    ] X MB  X MB/s  eta Xs`
  parse with regex, store in `%data{fetch}{$filename}{progress}`
- LAN check: use `Net::Ping` or simple TCP connect to test host availability
  before attempting rsync
- HF API calls: use clients.http.get with `https://huggingface.co/api/models/<repo>`
  no auth needed for public models

## success criteria

- [ ] `fetch.file.huggingface.list` returns gguf files for a given repo
- [ ] `fetch.file.huggingface.search` returns repos matching query
- [ ] `fetch.file.huggingface` downloads a file to correct destination path
- [ ] progress visible via `fetch.file.huggingface.status` during download
- [ ] LAN check runs before HF download (lan-check returns found/not-found)
- [ ] HF token read from config if present (works without token for public models)
- [ ] zenka starts on-demand cleanly
- [ ] downloaded file appears in `p7c coding.list-models` output after completion

#,,.,,,,.,,,,,..,,,.,,...,,,.,.,.,..,,.,.,..,,..,,...,...,..,,.,,,.,.,.,.,,.,,
#DE7FWUQXTXCCSW7DP27RE5B7VMKTB2CSESVLMOJ43UEJFMVJ7ZR5W4OEQ4P36UM2LBUXCDG53O7SY
#\\\|UDH7H3UDBD6MYOQVTANH5WZUIQWDBBDIRWGEWPMST2SF4LT4S7P \ / AMOS7 \ YOURUM ::
#\[7]KXYAFRHUJC6YFUWQ4PW55METJLBNXEVDLDERCGZJLBSU3NG5GGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
