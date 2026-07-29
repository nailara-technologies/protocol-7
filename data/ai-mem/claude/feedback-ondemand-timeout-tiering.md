---
name: ondemand-timeout-tiering
description: how to pick set_ondemand_timeout values for on-demand zenki by comparing against existing tiers
metadata: 
  node_type: memory
  type: feedback
  originSessionId: eec99c76-3a6c-4a57-abb3-72c98c78bcdd
---

When tuning `[base.zenki.set_ondemand_timeout:N]` for an on-demand zenka,
survey existing values first (`grep -rn set_ondemand_timeout configuration/zenki/*/zenka-startup.v7`)
rather than picking a number in isolation — there are clear tiers:
- 13–77s: cheap/quick-fire tools called in isolated one-off bursts
  (download/power/fetch-files=33, ffmpeg/fs=42, mediainfo/sys-deps=64,
  melt=77)
- 142–147s: light but episodic tools, gaps of 1-2min between calls
  expected (povray=142, set-up/pdf2html=147)
- 300s+: expensive-to-start or session-long tools (invoke=300,
  kimi/models=1800, transport/kimi-web=3600, coding=4620, jobsite/smtpd=7200)

**Why:** screenshot + powershell zenki were both bumped 69s→147s
(landed 2026-06-19) because they moved from one-off invocation to backing
continuous interactive-desktop use (tile color polling ~33s cycle, ad-hoc
X-11 captures) — 69s caused avoidable cold-start churn between bursts.
Startup cost (module load weight) and call-pattern (steady poll vs bursty
human-triggered) both matter, not just "how heavy is the zenka."

**How to apply:** when a zenka's usage pattern shifts from rare/scripted
to interactive/recurring, re-check its tier against this list rather than
leaving the original guess in place. See [[topic-zenka-naming-cleanup]] for
the related screenshot/X-11 capture rewrite this came out of.

#,,,.,..,,...,..,,.,.,.,.,...,,.,,.,.,,.,,,..,..,,...,...,...,.,,,..,,,,,,,.,,
#DQGLIGWQ752GAGACAY6M3XHF7YRCV2FUWSHMPKV4BNAFJVW5PNGPM6L7UAMGLKCNJUEI6MC7ITOZA
#\\\|VJ6PB72NTOTFHUYSY3OJJZI3A4AE35LWJDOHHTPBJWMXBIYTZQL \ / AMOS7 \ YOURUM ::
#\[7]INSDNX6A4RHOBDYZJ5DHFMRZPW4PNFARF3FWF324N3DPS2LWNMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
