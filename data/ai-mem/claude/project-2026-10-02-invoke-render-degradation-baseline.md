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

**NOT ruled out [ corrected 2026-10-02 05:08 ]** : "Prefer No Sysmem Fallback"
is set in the NVIDIA control panel, but under WSL CUDA still overcommits :
a qwen 2.1 OOM reported "21.65 GiB allocated by PyTorch" on the 12 GiB
card, after 5 min at 100 % gpu on step 0 [ = running from shared memory ].
the only real guard is invoke.ai's own `max_cache_vram_gb` [ fork : 5 ;
3 screens take ~1.7 GB vram ] + `device_working_mem_gb`. the main install
has no max_cache_vram_gb yet -- candidate if SDXL renders slow again.

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
[ qwen 2.1 set = 4.6 + 9.4 + 0.7 GB ]. same .wslconfig : `swap=6GB` at the DEFAULT location [ C: ]. a
`swapFile=D:\\wsl\\swap.vhdx` [ 2026-10-02 04:00 -> 08:40 ] crashed WSL \
the zenki twice [ 06:40, 08:26 ] : D: is C:\DISKS\projects.vhdx, FAT32
inside -> the swap image could not grow past 4 GiB, hv_storvsc
0xc0000001, swap device offlined, swapped-out pages lost. see
[[feedback-check-filesystem-before-large-files-on-windows-drives]].

**result 2026-10-02 04:21** [ after the wsl restart ] : cache budget 11.0 GB,
warm reference render 0 misses, 0.0 GB read, denoise 94.0 s [ was 121.9 ],
total 101 s [ was 150 ] ; user : gallery image switching now immediate.
cost : windows host at 94 % during renders, invoke.ai 16.6 GB RSS ->
added `[experimental] autoMemoryReclaim=gradual` [ effective after the
next wsl restart ; keep [experimental] LAST in .wslconfig -- swap lines
below it would be ignored ]. still > 90 % as firefox ages -> memory=20GB +
max_cache_ram_gb 10.

**gpu thermals [ 2026-10-02, X-11 clock \ power \ throttle feeds ]** : long
qwen 2.1 renders [ 10.7 min ] at 100 % power : fan 100 % [ ~2700 rpm, one
fan with a worn bearing, audible since ~a year ], 83-85 C, thermal
throttle 0x20 for 57 % of the render, avg clock 1897 MHz. power limit 85 %
[ 144.5 W, user set it via a gpu tool ] : 612.8 s vs 631.6 s [ FASTER ],
avg clock 1912, max 81 C, 0 s thermal, fan ~2580 rpm. steady power limit
beats oscillating thermal throttling -- keep 85 %. check after reboots
that it persists [ `nvidia-smi --query-gpu=enforced.power.limit` ].
2026-10-02 06:40:50 the WSL VM was stopped abruptly [ p7-log 'unflushed
writeback lost' at the next start ] right when the user changed a target in
the NVIDIA App, idle, no TDR \ WHEA \ kernel-power event -- most likely a
gpu reinit dropping WSL's paravirtualized gpu : change gpu tuning only when
a WSL restart is acceptable. the NVIDIA App installs FvKMDSvc [ FrameView
kernel driver ] for its tuning page -- harmless. power limit survived.
gpu : Gigabyte [ subsystem 0x40E2, 3 fans ], host bought 2024-02, one fan
bearing clicks at 100 % [ ~2700 rpm ] -> warranty check [ gigabyte, serial ].
cooldown pauses between images : not needed [ the throttle cost is
steady, not cumulative ]. advised : fan replacement \ cleaning \ repaste.

**suspects, untested** : device_working_mem_gb 5 in invokeai.yaml [ leaves the
model cache too little VRAM -> partial loading streams UNet layers from RAM ],
WSL page cache \ swap \ host paging building up with uptime, the old driver.

#,,,.,.,,,,..,...,,..,,,,,..,,,..,,,,,.,,,.,.,..,,...,...,,,.,..,,,.,,...,,,,,
#HIUT6C5DRYLRY3JBFPNUSQT6YR3WP5PX5ZLGV62XWVRJZPH45PDWHDQM5JVOJXLJQ3B4GKXEJTB52
#\\\|FFYHPXKTJPEUOHUW3PV23URHTDFR6P727KE4EL7QSX5WHF3DH2J \ / AMOS7 \ YOURUM ::
#\[7]INLQKQNTLHCGDB37VFNYJP3EVGELUDPDDCLRSQFISGIRYTETIYAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
