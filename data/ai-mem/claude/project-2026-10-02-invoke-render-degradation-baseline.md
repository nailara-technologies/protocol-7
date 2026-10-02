---
name: project-2026-10-02-invoke-render-degradation-baseline
description: invoke.ai renders degrade 2-6x with host \ WSL uptime -- fresh-reboot baseline 2026-10-02 [ same graph as item 16005 ] + the gpu-only probe to tell GPU from memory causes
metadata:
  type: project
---

**symptom** [ user ] : fast after a WSL \ host reboot, then renders slow down
up to x10 \ x100 over days. swappiness already 10 [ /etc/sysctl.d/60-swappiness.conf ].

**reference render** : main install item 16005 [ perfection-realistic-ilxl-v32
sdxl, 1144x760, 53 steps heun = ~105 unet passes, cfg 34, 5 loras, 5 ip-adapter
plus vit-h ]. re-run exactly by enqueueing its stored graph [ `enqueue_batch`
with session_queue.session's graph -- `invoke-web.requeue` only takes failed \
canceled items ].

| when | uptime | denoise | l2i |
|---|---|---|---|
| 2026-10-01 08:55 | 14 d | 304 s | ? |
| 2026-10-01 22:24 | 14 d | 798 s | 60 s |
| 2026-10-02 02:50 | 15 min, new driver 616.92 | 125 s | 7 s |
| 2026-10-02 03:17 | 40 min, warm [ same process ] | 120 s | 4 s |

[ history : `/var/log/protocol-7/<host>.invoke-web.invokeai.log`, rises during
the day, an invoke.ai restart did NOT reset it -> system level ]. the 02:50 row
changed reboot AND driver [ 591.86 -> 616.92 studio ] at once.

**gpu-only probe** : scratchpad gpu-probe.py [ 50 fp16 4096^2 matmuls after
warm-up ] = 0.26 s \ ~26 TFLOPS healthy. same speed while renders are slow ->
memory \ swap \ streaming, not the GPU. pressure counters :
/proc/pressure/{memory,io}.

**ruled out** : NVIDIA sysmem fallback -- user checked 2026-10-02 : "Prefer No
Sysmem Fallback" was already set [ persisted through the driver update ].

**model cache too small [ strongest suspect ]** : invoke.ai's RAM cache budget
is 5.79 GB [ heuristic, 16 GB VM ] while this graph loads 9.67 GB of models
[ sdxl + 5 loras + 5 ip-adapters + clip vision ] -> even warm : 38 cache
misses, 1 eviction -> every render RELOADS its models. fast while the files
sit in the linux page cache [ after a reboot ], up to ~10 GB from the ext
disk per render once the page cache got evicted over the day. 6.14 does the
loads inside denoise_latents. the 6.14 'Model cache misses' line +
'RAM used by InvokeAI process (+x)' delta tell cold from warm.

**render statistics** [ 2026-10-02, phase 1 ] : every render writes a row to
invoke-web's state/render-stats.db -- `p7c invoke-web.render-stats`. graph
options : data/tasks/invoke-render-stats-graph.md. first rows [ fresh
reboot, cold + warm ] : ~1.15 s per unet pass, 12-13 GB read from storage
PER render, ~380 MB swapped out during a cold one, 17-18 s io stall, gpu
peak 78 C [ avg 65 ], windows host memory 49 -> 79 %. models disk [ sdd, ext xfs ] : 11 GB in
21.8 s busy = 507 MB/s, 5.75 ms per read -> ~18 % of the denoise step was
disk wait when healthy.

**fix applied 2026-10-02 ~04:00** [ effective after `wsl --shutdown` ] :
host has 32 GB [ no .wslconfig before -> wsl default 16 GB ]. wrote
C:\Users\<user>\.wslconfig `memory=22GB` [ 10 GB left for windows +
firefox, which grows over a week ] and `max_cache_ram_gb: 11` in the main
install's invokeai.yaml [ backup .pre-cache-ram-20261002 ] -- without it the
heuristic stays below the graph's 9.67 GB. success check : warm reference
render readGB ~12 -> ~0, cache misses < 40, ~22 s disk wait gone. watch
win_mem_end_pct : > ~90 % -> back to 20 GB. the fork's yaml is unchanged
[ qwen 2.1 set = 4.6 + 9.4 + 0.7 GB ]. same .wslconfig : `swap=6GB`,
`swapFile=D:\\wsl\\swap.vhdx` [ was a 4 GB growing vhdx in C:'s
AppData\Local\Temp ; D: = 7 GB, otherwise unused ; /mnt/d itself is 9p,
no linux swapfile possible there ].

**suspects, untested** : device_working_mem_gb 5 in invokeai.yaml [ leaves the
model cache too little VRAM -> partial loading streams UNet layers from RAM ],
WSL page cache \ swap \ host paging building up with uptime, the old driver.

#,,.,,.,,,,,,,,,.,,.,,.,.,,.,,,.,,,,.,,,.,,,.,..,,...,.,.,.,,,,,,,,,.,.,.,.,,,
#DQR6OMZHGEJR3RYF4H3G3PK2RO3EAEQG4AMEDSD6PCNJABTUVJ6ZVLQMSJBUA7CMVMQPBS6FZNOQM
#\\\|6MR76RM5XON6A6EQHNUKERO22JOZHJ6QQQRUIQFK7TOZZV73EPS \ / AMOS7 \ YOURUM ::
#\[7]MBEDNACNVJS22QXVTGPMR6OXF4XR6N5HEAOLTIVSX5ZHHR45ACBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
