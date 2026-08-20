# invokeai + 9p lazy model storage — design & plan

## situation

invoke-model-recover only queries `WHERE type='main'` from the invokeai sqlite db.
starting invoke-web reveals many more missing model files (vae, lora, controlnet,
t5_encoder, clip_vision, ip_adapter, embedding). these are not discovered or downloaded.

goal: working invoke installation + automation/reproducibility advances in parallel.

---

## model type taxonomy

invokeai sqlite db `models` table has a `type` column:

```
main          ## diffusion model — 2..30 GB each — download on demand
vae           ## variational autoencoder — usually 1 file, ~300 MB
lora          ## lora adapter — 10 MB..2 GB each
controlnet    ## controlnet — ~1.5 GB each
t5_encoder    ## t5 text encoder (sd3, flux) — ~9 GB
clip_vision   ## clip vision encoder — ~600 MB
ip_adapter    ## ip-adapter — ~1 GB
embedding     ## textual inversion — tiny, KBs
```

non-main types: download all together at install time.
main types: large, download on demand — either manually or via 9p lazy hook.

---

## phase 1 — script fix [ invoke-model-recover ]

file: `bin/scripts/invoke-ai/invoke-model-recover`

changes:
- remove `WHERE type='main'` filter from query_database() sql
- add `type` field to output, group listing by type
- add `--batch` flag: download all non-main types
- add `--main` flag / AMOS id positional args: download specific main models
- keep `--type vae,lora,...` for targeted group downloads

result: running `invoke-model-recover --batch` downloads all the files invoke-web
needs at startup. running invoke-web should produce a clean startup after that.

---

## phase 2 — invokeai-web wrapper zenka

stub dir: `cfg/zenki/invokeai/` (exists, empty)
companion: `cfg/zenki/invokeai-web/` (to create)

pattern: same as `coding.handler.monitor_inference_startup` — start child process
via IPC::Open3, read stdout/stderr via non-blocking io handlers.

### what the zenka does

- starts `invoke-web` (or `invokeai-web --host 0.0.0.0 --port 9090`) as managed child
- reads stderr line by line via AnyEvent fd watcher
- parses for missing model file messages — extract path, classify type
- non-main missing → queue immediate download via invoke-model-recover
- main missing → flag as on-demand, do not block startup
- restarts invoke-web after dependency downloads complete
- exposes commands: `invokeai.status`, `invokeai.restart`, `invokeai.missing`

### why stderr is better than db query alone

invoke-web's startup output reflects the actual runtime state — paths may have
changed, models may have been manually added/removed, db metadata may be stale.
parsing stderr is the ground truth source for what is actually missing.

### key modules to write

```
src/coding.init_code → use coding zenka pattern as template
cfg/zenki/invokeai-web/start
cfg/zenki/invokeai-web/zenka-startup.v7
src/invokeai.handler.monitor_startup
src/invokeai.handler.parse_missing_model
src/invokeai.cmd.status
src/invokeai.cmd.restart
```

---

## phase 3 — 9p filesystem backend for lazy model download

### current server scope

`plan-9.server.*` is fully implemented for amos-term buffer serving.
type system: `root` → `buffer` → `layer` / `metadata`.
protocol, codec, client sessions, fid management — all done.

### what needs adding — 4 modules + 2 small extensions

**`plan-9.server.export_path`** [ new ]
registers a real filesystem directory as a 9p-accessible mount point:

```perl
$data{'plan-9'}{'server'}{'paths'}{$name} = {
    'root'     => $real_path,   ## e.g. /mnt/ext-xfs-data/models-invoke
    'on_miss'  => $coderef,     ## download hook [ optional ]
    'readonly' => TRUE,
    'qid_path' => $data{'plan-9'}{'server'}{'next_qid'}++,
};
```

**`plan-9.server.fs.read`** [ new ]
reads real file bytes at offset/count, with download-on-demand hook:

```perl
if ( !-f $path || -z $path ) {
    ## zeroed or missing — trigger download, then re-read ##
    $on_miss->({ path => $path }) if defined $on_miss;
}
open my $fh, '<:raw', $path or return '';
seek $fh, $offset, 0;
read $fh, my $buf, $count;
return $buf;
```

**`plan-9.server.handle_walk` extension** [ modify existing ]
add `elsif $walk_result->{type} eq 'dir'` branch — resolves real dir entries,
produces fids typed `dir` or `file` instead of `buffer`/`layer`.

**`plan-9.server.handle-io-read` extension** [ modify existing ]
add `elsif $f->{type} eq 'file'` branch calling `plan-9.server.fs.read`.

**`plan-9.server.fs.stat`** [ new ]
stat wrapper that returns 0-size for zeroed/missing files so invoke can
enumerate the directory without errors, but reads trigger download.

### mount on invokeai side

```bash
## invokeai zenka startup — or manual for testing
mount -t 9p -o trans=tcp,port=15640,version=9p2000 \
    127.0.0.1 /mnt/invokeai-models

## invokeai.yaml
models_dir: /mnt/invokeai-models
```

kernel 9p client — no fuse dependency.

### download hook wiring

```perl
## registered when exporting the models path ##
'on_miss' => sub {
    my ($args) = @ARG;
    ## look up model in db by path, get source url, download via lwp ##
    <[invokeai.model.fetch]>->({ path => $args->{'path'} });
}
```

---

## implementation sequence

```
[x] design doc (this file)
[ ] phase 1: invoke-model-recover — remove type filter, add --batch flag
[ ] phase 2: invokeai-web wrapper zenka — startup monitor + missing model parser
[ ] phase 3a: plan-9.server.export_path + plan-9.server.fs.read + fs.stat
[ ] phase 3b: handle_walk + handle-io-read extensions for 'dir'/'file' types
[ ] phase 3c: wire invokeai download hook, test mount -t 9p
```

---

## related files

```
bin/scripts/invoke-ai/invoke-model-recover        ## phase 1 target
data/md/design/9P-IMPLEMENTATION.md              ## 9p server architecture
data/md/design/9P-STORAGE-VISION.md              ## broader 9p storage mesh
data/md/documentation/INVOKE-MIGRATION-PLAN.md   ## migration context
data/md/coding-tasks/invoke-ai-model-storage-management.md  ## phase 2+3 task
cfg/zenki/invokeai/                     ## stub dir, empty
```

---

## notes

- invoke db: `~/.invokeai/db/invokeai.db` (sqlite)
- models path: `/mnt/ext-xfs-data/models-invoke`
- hf token: read from invoke config or lm-studio config (already in script)
- zeroed vs missing behaviour in invoke.ai: test before implementing zero state
  (if invoke crashes on zero → use `.z` suffix rename approach instead)
- phase 3 9p server extension does not break existing amos-term buffer serving —
  `root` walk still checks `buffers` first, new `paths` registry is separate

#,,.,,,,,,,,,,,,.,,..,.,.,.,,,,.,,.,,,.,.,...,..,,...,...,.,.,..,,.,,,.,.,,.,,
#IX6WRIXNLNPFL2ICUWW42BVZAQGTCGUXUZY7ZTJ2DFVGGMOOO6H6LISUAMCQZAWHSZISS7BIIUQJY
#\\\|PNW2YWVYIRQX7E6MOSRUB4WT4H5F5UF6Z4EZVMILMSKQOY6PDCS \ / AMOS7 \ YOURUM ::
#\[7]TTZEM46JE4SXWDU4X43WZIFI2YJGTHOLMMXXBFQ66XVA2AXIPWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
