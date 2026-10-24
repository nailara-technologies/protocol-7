# task : coding zenka on a CPU-only host — setup checklist

host role : **CPU-only inference host** [ 8 vCPU amd epyc, avx2, 23 GB RAM,
NO SWAP, live name server — nothing may starve the other zenki ].
binary : `/data/source/ik_llama.cpp/build-cpu/bin/llama-server`
[ ik_llama.cpp build 4876, fe215a8cc — the freshly linked cpu binary that
fixes the 2026-09-17 ABI-skew segfault :
`data/ai-mem/claude/bug-coding-cpu-binary-abi-skew-root-cause-2026-09-17.md` ].
model : `/data/models/tvall43/Qwen3.6-14B-A3B-FableVibes-GGUF/Qwen3.6-14B-A3B-FableVibes-Q4_K_M.gguf`
[ 8.1 GB, moe 3B active ; its amos id comes from the models zenka after
registering the dir -- `p7c models.list models` ; the 72T4WFI:TK55OIY this
checklist first named did NOT resolve on the host, 2026-10-18 ].

repo-side support landed with this checklist :
`coding.cfg.cpu_context_max` [ fixed context cap ],
`inference.backend.<backend>.mem_max` [ systemd-run MemoryMax scope ],
`[load_host_config]` in the coding and system zenka start files [ per-host
overlay ]. nothing below edits the repo on the host — host state lives in
`/etc/protocol-7/<zenka>/host.cfg` [ see base.load_host_config ].

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## the three memory layers [ and why three ]

| layer | mechanism | setting | what it does |
|---|---|---|---|
| 1. context cap | `coding.cfg.cpu_context_max` | 32768 | the `-c` value the auto-expansion can never exceed — the 2026-09-17 OOM was an auto-expanded 144993-token context; the RAM math is a heuristic and CANNOT override this cap [ enforced in both calculate_safe_context's cpu branch and at the spawn site ] |
| 2. cgroup hard limit | `systemd-run --scope -p MemoryMax=14G` via `inference.backend.cpu.mem_max` | 14G | even a wrong RAM estimate cannot grow llama-server past 14 GB rss — the cgroup oom-kills ONLY the server, not the name server |
| 3. zenka watchdog | system zenka `process.limits.llama-server.max_mem` | 65 [% of total ram] | last-resort kill if the scope is off/unavailable [ e.g. systemd-run missing ] ; set just above the 14G/23GB ≈ 61 % cgroup so the two layers do not fight |

## 1. host config overlay — /etc/protocol-7/coding/host.cfg

plain `key = value` lines, applied on top of the repo config on THIS host
only [ re-applied on 'reload config' ]. create the file with exactly:

```
## cpu-only inference host [ by role : no gpu, 23 GB ram, no swap ]
inference.backend.gpu.enabled = no
inference.backend.cpu.enabled = yes
inference.backend.cpu.binary = /data/source/ik_llama.cpp/build-cpu/bin/llama-server
inference.backend.cpu.threads = 8
inference.backend.cpu.mem_max = 14G
inference.backend.cpu.model_id = 72T4WFI:TK55OIY
inference.backend.cpu.path = /data/models/tvall43/Qwen3.6-14B-A3B-FableVibes-GGUF/Qwen3.6-14B-A3B-FableVibes-Q4_K_M.gguf
coding.cfg.cpu_context_max = 32768
coding.cfg.context_max = 32768
inference.model.context_length = 32768
```

notes :

- `inference.backend.cpu.path` [ explicit file path ] satisfies the spawn
  dependency WITHOUT a models-zenka registry entry
  [ `coding.callback.object.model_path` checks that slot directly ].
  still register the model [ step 2 ] so amos-id resolution / metadata work.
- `inference.model.context_length` doubles as the cpu context floor — on cpu
  the RAM-safety ceiling always wins over the floor
  [ `coding.spawn_inference_server` ], and the cap wins over both.
- do NOT set `coding.cfg.start_model` here expecting it to propagate :
  `<...>` macros in the repo config were expanded at parse time; the
  concrete keys [ model_id, amos_id, path ] must be set directly.

## 2. model registration [ models zenka ]

the registry resolves amos ids → file paths by scanning configured dirs.
on the host :

```
p7c models.scan-path-add /data/models        ## or the dir actually holding it
p7c models.get_path_by_amos 72T4WFI:TK55OIY  ## must print the file path
```

if the models zenka is not reachable on this host, the explicit
`inference.backend.cpu.path` above keeps the coding zenka fully functional —
metadata-dependent extras [ model list display, template arch gating ] just
fall back to defaults.

## 3. systemd user scope pre-flight [ layer 2 ]

`systemd-run --scope` as the unprivileged zenka user talks to the USER
service manager : it must exist and linger. as the zenka user [ the user
from `cfg/shared-params` `system.amos-zenka-user`, usually `protocol-7` ] :

```
loginctl enable-linger <zenka-user>     ## as admin, once
systemd-run --user --scope --quiet --collect -p MemoryMax=1G \
    /bin/true && echo SCOPE-OK
```

- `SCOPE-OK` → layer 2 armed. the spawn log will show
  `cpu mem scope : MemoryMax=14G MemorySwapMax=0 via /usr/bin/systemd-run`.
- the zenka's own XDG_RUNTIME_DIR is its home [ base.root.drop_privs ] :
  the spawn hands the child `/run/user/<uid>` and spawns unscoped with a
  level-0 log when neither `bus` nor `systemd/private` is there. the pre-flight above must run
  with `XDG_RUNTIME_DIR=/run/user/$(id -u)` set.
- `MemorySwapMax=0` : on a host with swap the server is killed at the
  limit instead of being pushed into swap [ swap stays for the other
  zenki ].
- failure [ "Failed to connect to bus" ] → fix the user bus
  [ `XDG_RUNTIME_DIR` set for the zenka service session ] BEFORE starting
  the coding zenka; without it every spawn burns the 5-attempt crash-restart
  ladder. if the host has no systemd at all, leave `mem_max` out and rely on
  layers 1 + 3 [ spawn proceeds unscoped with a loud level-0 log ].

## 4. system zenka watchdog — /etc/protocol-7/system/host.cfg

```
## bound a runaway cpu inference server : percent of TOTAL ram
process.limits.llama-server.max_mem = 65
process.limits.llama-server.seconds = 13
process.limits.llama-server.action  = kill
```

the name matches the process fname `llama-server`
[ 12 chars, fits /proc comm's 15 ] or the first cmndline token. the system
zenka polls `process.poll.interval` [ 5 s, accelerates under pressure ] and
kills after `seconds` of condition. the `system` zenka must be in the host's
always-on set [ it is, in every shipped start-set-up ].

## 5. start

the coding zenka is on-demand [ `cfg/zenki/coding/start.cfg` ] : any
`p7c coding.*` command starts it. first start with the overlay in place :

```
p7c v7-zenki.start coding      ## or simply : p7c coding.status
```

## 6. watch the first load [ the moment of truth ]

in one terminal, tail the system log / zenka console for the spawn lines :

```
[spawn_inference_server] backend=cpu port=8001
[calculate_safe_context] RAM=... : calc : N | clamped : 32768 [ cpu_maximum ]
[spawn_inference_server] cpu mem scope : MemoryMax=14G via /usr/bin/systemd-run
[spawn_inference_server] spawned: backend=cpu pid=...
```

expected footprint at `-c 32768` : model 8.1 GB + f16 KV
[ moe, kv on the small side ] + compute buffers ≈ **10-12 GB rss, stable** —
well inside the 14 G scope. while it loads, watch memory from another shell :

```
watch -n2 'grep -E "MemAvailable|MemFree" /proc/meminfo'
systemd-cgtop -b -n 1 | head            ## the run-*.scope MemoryMax column
ps -o pid,rss,cmd -C llama-server
```

- **MemAvailable must stay above ~6-7 GB** the whole time [ the name server
  and the other zenki keep breathing ].
- if rss climbs past 14 GB, the cgroup kills llama-server ONLY — the zenka
  crash-restarts it at a smaller context [ timeout-recovery path ]; that is
  the layers working, but report it [ the soft RAM model under-predicts for
  this model — same class as the 2026-09-17 incidents ].
- first token latency on 8 epyc vCPUs is tens of seconds — the startup
  monitor and self-test timeouts are sized for that
  [ `coding.http-timeouts.data-start` scales with prompt size ].

## 6b. jobsite : point assessments at the model this host serves

the repo pins `jobsite.cfg.assessment_model` to a gpu-host model. the
jobsite zenka now loads `/etc/protocol-7/jobsite/host.cfg` too
[ `[load_host_config]`, 2026-10-18 ] -- as root :

```
mkdir -p /etc/protocol-7/jobsite
## the same <amos>:<amos> model id as inference.model.amos_id in the
## coding host.cfg above
echo 'jobsite.cfg.assessment_model = <model id>' > /etc/protocol-7/jobsite/host.cfg
## root:root 0644 like the other host.cfg files : read as root before
## the privilege drop, and the zenka cannot loosen its own settings
```

then restart the jobsite zenka [ `p7c v7-zenki.restart jobsite` -- check the
name resolves first ] so the pin is read.

## 7. test : one jobsite assessment

jobsite assessments are coding-zenka tasks with a `:model:` pin
[ `jobsite.util.build_prompt` → `jobsite.cfg.assessment_model` ]. there is
no direct 'reassess' p7c command — reassessment is triggered from the
jobsite web ui [ reassess action on one job ] or by re-upserting one job.
end-to-end check of exactly that path :

```
## via the jobsite web ui : click 'reassess' on ONE job
##   [ or : p7c jobsite.job-upsert with that job's current data ]
p7c jobsite.progress                       ## watch 'assessing' → done
p7c coding.list-tasks                      ## note the assessment task id
p7c coding.get-result <task-id>            ## the assessment text
```

pure coding-zenka smoke test without jobsite state :

```
p7c coding.submit "read src/base.init_code and summarize the init order in 5 lines"
p7c coding.list-tasks                       ## note the task id
p7c coding.get-result <task-id>
```

success = a finished assessment / summary served by the cpu backend. during
the run, re-check layer 2/3 : rss pinned under 14 GB, no system-zenka
MEMORY USAGE ALERT lines.

**caveat** : `jobsite.cfg.assessment_model` is pinned in the repo config to a
model the cpu host does not serve — every assessment would demand a model
switch and fail. until that key is host-overridable [ see open questions ],
point it at the host's model in the repo config or skip step 7's jobsite half
and use the smoke test.

## open questions

1. `jobsite.cfg.assessment_model` has no per-host overlay today [ the jobsite
   zenka has no `[load_host_config]` ] — a cpu host either needs that hook or
   a repo edit to assess with its own model.
2. `coding.cfg.cpu_ram_overhead_mb` [ 4096 ] and `cpu_ram_hard_fraction`
   [ 0.5 ] are repo defaults tuned elsewhere — verify against this host's
   real zenki count on first load [ §6 ] and set in host.cfg if tight.
3. the per-token compute-buffer multipliers [ 6x soft / 15x hard ] are
   wide-margin stopgaps from two 2026-09-17 incidents, not measured values —
   if a first load lands far from the prediction, record the real number here.
4. layer 2 assumes systemd v246+ [ pidfd scope placement, exec-in-place ] —
   ancient distros get the unscoped loud-log path instead.

#,,,,,.,,,,..,.,.,,..,,,,,.,.,..,,,,,,,,.,.,,,..,,...,...,.,,,..,,..,,,,.,,,.,
#PVH2FXZQHPU4I7TCRGZPIXRRBSBYP6JT2EDGZ3M2CSA6RRWKCTOFR6CVG5T7J2ES6IM2Z3VHMC3N6
#\\\|DRLPQ2KPT4HZDSPMFVAXQKDPTVG54WAO27DPZTO42YDHUA5C3D3 \ / AMOS7 \ YOURUM ::
#\[7]CXLFCRBI4745ZF5LX74WXBXOR7WQDAHU2RPTJI225MJWA6N2AOAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
