---
name: feedback-wsl-oom-full-vm-crash-2026-08-29
description: "the whole WSL2 session was torn down (v7 TERM'd, all shells SIGKILL'd, WSL gone, auto-restarted) at the end of a very long session -- two SEPARATE findings, don't conflate them: a real kernel OOM-kill of a ~6GB llama-server-cuda process minutes earlier, and a distinct systemd-logind session-wide teardown matching a Windows-host-side WSL shutdown (wsl --shutdown / sleep / update / idle-timeout), NOT a Linux shutdown/reboot command and not something the OOM killer itself does"
metadata:
  type: feedback
---

2026-08-29, end of a very long session (spectrum templates, X-11/web-browser/content
bug-hunt+fixes, three kimi dispatches, a 227-file screenshot-triage batch running for
hours). User reported: v7 zenka got TERM'd with root privileges "like a shutdown or
reboot command", then all shells terminated, then WSL itself was gone -- explicitly not
something the user did themselves. Confirmed via `uptime` (system had been up only ~5
min after) that a real restart happened.

**Two separate findings from `journalctl -b -1`, do not conflate them**:

1. A genuine kernel OOM-kill, ~2 min before the teardown:
   ```
   Aug 29 02:00:51 ... kernel: Out of memory: Killed process 1013605 (llama-server-cu)
   total-vm:84825092kB, anon-rss:6298892kB, file-rss:368kB, shmem-rss:77824kB, UID:777
   ```
   A ~6GB RSS `llama-server-cuda` inference process, already running before this
   session's work even started (visible in the very first `ps aux` check of the night,
   ~9.8GB RSS at that point). WSL2's ceiling on this host is ~16GB (`hv_balloon: Max.
   dynamic memory size: 16354 MB` in dmesg) -- genuinely tight given the full zenka
   network, hours of a live WebKitGTK browser continuously rendering/screenshotting, and
   this Claude session all running simultaneously alongside it.

2. A SEPARATE, later event that actually tore down the session -- NOT the OOM killer,
   NOT a Linux `shutdown`/`reboot` command (no `systemd-shutdownd`/"System is powering
   down" trace anywhere in the log):
   ```
   Aug 29 02:02:21 ... systemd[1]: init.scope: Killing process 7 (init) with signal SIGKILL.
   [ ... every single process in the session scope, one line each, incl. this session's
     own 'claude' and '[mcp-server-p7]' processes ... ]
   Aug 29 02:02:21 ... login[585]: pam_unix(login:session): session closed for user taeki
   Aug 29 02:02:21 ... systemd[1]: session-c4.scope: Deactivated successfully.
   Aug 29 02:02:21 ... systemd-logind[238]: Session c4 logged out.
   ```
   This is `systemd-logind` tearing down an entire session scope (session-c4, which had
   been running 4d 10h+) -- the signature of the WSL2 VM itself being shut down from the
   **Windows host side** (`wsl --shutdown`, Windows sleep/restart, Windows Update, or
   WSL's own idle-timeout closing the VM once its connecting frontend disconnected), not
   anything initiated from inside Linux. No visibility into the actual Windows-side
   trigger is possible from inside WSL -- don't claim a specific cause for THIS half
   without host-side evidence.

**Further confirmed by user**: Protocol-7's own memory watchdog
(`src/system.process.handler.collect_table`, logs to
`/var/log/protocol-7/DESKTOP-FP4OP26.system.zenka.log` and prints to console when it
kills a process) last fired 74 days before this incident (decoded via the project's own
`localtime`/`delta-time` commands against the log's last entry — do NOT use file mtime
as a proxy for last-log-content date, they can differ) — nothing on console that night
either, ruling it out as the mechanism. User confirms: definitely an external TERM,
consistent with systemd, not an app-level kill.

**Windows-host-side evidence, checked via `powershell.exe` reachable directly from WSL
interop** (`Get-WinEvent -FilterHashtable @{LogName=...; StartTime=...; EndTime=...}`):
System log shows the old WSL VM's Hyper-V virtual NIC deleted at 02:03:37, the new one
created at 02:04:26-27 — the restart window, no earlier trigger event in System log at
all (checked back to 01:58, nothing). No Kernel-Power/sleep/reboot event anywhere in that
window — rules out a plain Windows sleep/wake or explicit reboot as the mechanism.
Windows Update had installed unrelated updates hours earlier (18:59 the same day), not
close enough in time to implicate. The one real signal found: Application log,
`02:04:28`, Windows Error Reporting `RADAR_PRE_LEAK_64` fault bucket for `explorer.exe`
— RADAR is Windows' own Resource Exhaustion Detection and Recovery subsystem, flagging
excessive memory growth. Circumstantial (doesn't prove causation of the WSL restart) but
real and well-timed: this points to genuine HOST-WIDE memory pressure (not just WSL's
own ~16GB VM ceiling) as the most likely underlying condition — the Linux-side OOM kill
of `llama-server-cuda` and this Windows-side RADAR flag both look like symptoms of the
same host-wide shortage, not independent events. Still no single definitive "who told
WSL to shut down" event found in either OS's logs.

**How to apply**: when a whole-VM-level event happens, check `journalctl -b -1` in full
before settling on one explanation -- a real OOM kill and a real session-teardown can
both appear in the same log without one having caused the other; report them as
separate findings unless there's a direct causal chain in the log connecting them. The
distinguishing signature for a Windows-host-initiated WSL shutdown specifically:
`systemd[1]: init.scope: Killing process ... with signal SIGKILL` for every process in
a session scope, ending in `session-*.scope: Deactivated` / `Session * logged out` --
NOT a `shutdown.target`/reboot sequence, NOT a single OOM-scored process. Before
resuming heavy work after any such event, still check `free -h` / `dmesg | grep -i oom`
for a real memory constraint (finding 1's kind) independently of whatever caused the
teardown (finding 2's kind) -- they're separate risks, both worth checking.

#,,..,,,,,,.,,,..,,.,,.,,,,,,,,,,,.,,,.,.,.,.,..,,...,...,..,,...,,.,,,,,,,,,,
#IHQLWEL4LYZZPADTE3G2JRG3JKTUHYVGMWI3PECHQB57MXSR2PT6P5W3Q4FYYMRC2D6UWU7HAGMSO
#\\\|5BQQ4UOLVMMYBPKVYY6U4ZH3STYBVAAF2U2N6U5U63A7KET3RVJ \ / AMOS7 \ YOURUM ::
#\[7]JEDMV5EJWKW6GSZTLDHHBSJ4DQBDTK3YNZVCVWZLJIG5HBZLMICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
