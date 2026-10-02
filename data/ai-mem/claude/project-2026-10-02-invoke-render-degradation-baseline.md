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

[ history : `/var/log/protocol-7/<host>.invoke-web.invokeai.log`, rises during
the day, an invoke.ai restart did NOT reset it -> system level ]. the 02:50 row
changed reboot AND driver [ 591.86 -> 616.92 studio ] at once.

**gpu-only probe** : scratchpad gpu-probe.py [ 50 fp16 4096^2 matmuls after
warm-up ] = 0.26 s \ ~26 TFLOPS healthy. same speed while renders are slow ->
memory \ swap \ streaming, not the GPU. pressure counters :
/proc/pressure/{memory,io}.

**ruled out** : NVIDIA sysmem fallback -- user checked 2026-10-02 : "Prefer No
Sysmem Fallback" was already set [ persisted through the driver update ].

**suspects, untested** : device_working_mem_gb 5 in invokeai.yaml [ leaves the
model cache too little VRAM -> partial loading streams UNet layers from RAM ],
WSL page cache \ swap \ host paging building up with uptime, the old driver.

#,,..,...,.,,,.,,,.,.,,.,,.,,,.,,,...,,,,,..,,..,,...,..,,,,,,,,.,,,.,.,,,...,
#VUEP2OLGZH2FX7V2NPMUHPOYG7TRI56IMN3UVVWAW2X5CS674LMBTW7XMNKPL3YSW4HHZLPA4C2BW
#\\\|AW3WXXAO2JBV6LJXNHDU24OVNW4N27XRKRQQFTXHSD4GG5X3EFI \ / AMOS7 \ YOURUM ::
#\[7]J5AAJNGFDOGQ6AMS772RN4T3TMXVRSUAJV4Y3NTGM77JSH5GB6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
