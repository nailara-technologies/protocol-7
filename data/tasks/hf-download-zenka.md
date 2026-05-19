# task: file.fetch.huggingface — model download zenka

## context

local model availability is a recurring friction point: GPU crashes on wrong
quantization, models missing after disk events, switching between sizes manually.
this task implements `file.fetch.huggingface.*` — a p7 command interface for
downloading GGUF models from HuggingFace into the correct local storage paths.

design is distributed across:
  data/md/documentation/SELF-CONTAINED-ZENKA-VISION.md  → file.fetch.huggingface namespace
  data/md/design/MODELS-PATH-ADAPTERS.md                → category subdir routing
  data/md/coding-tasks/invoke-ai-model-storage-management.md → LAN-first, HF-second pattern
  data/md/documentation/MODELS-PATH-CONFIGURATION.md    → storage paths and config keys
  data/md/documentation/EXTERNAL-INFERENCE-MODELS-CONFIG.md → HF cache config

## signatures note

do not add signature stubs. run `bin/Protocol-7 sourcecode update-signatures` when done.

---

## what to implement

### file.fetch.huggingface

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

### file.fetch.huggingface.list

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

uses clients.http.get (non-blocking) — see modules/clients.http.*
HF API does not require auth for public models
```

### file.fetch.huggingface.search

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

### file.fetch.huggingface.lan-check

check if a model file is available on LAN hosts before downloading from HF:

```
## LAN hosts are configured in network topology or discovered via p7 network
## check each known host for the file at their models path
## if found: rsync/scp instead of HF download (much faster on LAN)

args: { filename => 'gemma-3-4b-it-Q4_K_S.gguf' }
returns: { found => 1, host => '192.168.1.X', path => '/mnt/models/...' }
         OR { found => 0 }
```

### file.fetch.huggingface.status

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
file.fetch.lan_hosts = 192.168.1.X 192.168.1.Y  ## space-separated LAN hosts to check
file.fetch.hf_token  = <token>                   ## same as external.hf.token alias
```

---

## zenka config

```
## configuration/zenki/file-fetch/start
[load_modules:file.fetch.huggingface file.fetch.huggingface.list
              file.fetch.huggingface.search file.fetch.huggingface.lan-check
              file.fetch.huggingface.status]
[init_modules]
[zenka.loop]
```

```
## configuration/zenki/file-fetch/zenka-startup.v7
start.on-demand = 1
restart.disabled = 1
heartbeat.disabled = 1
```

---

## p7 command interface

```bash
## list quantizations available for a model
p7 file.fetch.huggingface.list '{"repo":"bartowski/gemma-3-4b-it-GGUF"}'

## search for models
p7 file.fetch.huggingface.search '{"query":"gemma 4b uncensored GGUF"}'

## download specific file
p7 file.fetch.huggingface '{"repo":"bartowski/gemma-3-4b-it-GGUF","file":"gemma-3-4b-it-Q4_K_S.gguf"}'

## check LAN first
p7 file.fetch.huggingface.lan-check '{"filename":"gemma-3-4b-it-Q4_K_S.gguf"}'

## check download progress
p7 file.fetch.huggingface.status
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

- [ ] `file.fetch.huggingface.list` returns gguf files for a given repo
- [ ] `file.fetch.huggingface.search` returns repos matching query
- [ ] `file.fetch.huggingface` downloads a file to correct destination path
- [ ] progress visible via `file.fetch.huggingface.status` during download
- [ ] LAN check runs before HF download (lan-check returns found/not-found)
- [ ] HF token read from config if present (works without token for public models)
- [ ] zenka starts on-demand cleanly
- [ ] downloaded file appears in `p7c coding.list-models` output after completion

#,,..,.,.,.,.,.,,,.,,,,..,...,,,,,...,,,.,..,,..,,...,..,,.,.,.,.,,,,,...,,,,,
#YDS2FVCZALCP6HIZE73ZEBQ4WCYQ7EXK75ZN3XDNUACSCZQYXAWPA7F7A4RBIGIFRSHSV7OSSK3KS
#\\\|BG4EFGHXUVNVD34GYFM5IO22CAJ7XYVMMSDQELNI3YTBCWKSRRZ \ / AMOS7 \ YOURUM ::
#\[7]BOXWDNVVILGBAQG3V6CHG4TF36KJFWWH5JLPTMMLK5EFEDAUWEBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
