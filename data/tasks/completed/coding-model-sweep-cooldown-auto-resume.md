## [:< ##

# name  = task: model-sweep cool-down auto-resume -- /proc/loadavg, uniform for both backends
# descr = auto-resume a sweep paused with paused_reason=yield-timeout once
#         the SYSTEM has genuinely gone quiet, instead of requiring a
#         human to notice and issue model-sweep-resume <backend> :force:

## why now

surfaced live 2026-09-17: `coding.model_sweep.handler.poll_sweep`'s yield
gate (see [[reference-model-sweep-yield-300s-cap-not-stream-aware]]) uses
a flat 300s wall-clock cap with zero awareness of whether the real task
activity it's waiting on is actually healthy -- a legitimately long but
actively-streaming task (confirmed live: self-test/switch probe chunks
climbing steadily into the thousands, genuinely alive, extending its own
timeout correctly) tripped the cap anyway and paused the sweep, needing a
manual `:force:` resume mid-session. happened twice in one session.

## design history -- read before "improving" this, don't re-litigate

first explored GPU temperature (already-shipped precedent:
`data/tasks/completed/task-zenka-cold-queue-gpu-cooldown-trigger.md`,
task zenka, 2026-07-21/22 -- landed, live-tested, a real, physically-
grounded idle signal for a different purpose) and a CPU-temperature
equivalent. **CPU temperature was investigated extensively and ruled
out for this host, don't re-attempt it:**
- WSL2 (this host, Linux guest side): confirmed zero cpu temp sensors --
  `sensors` reports "No sensors found!", no `/sys/class/thermal/
  thermal_zone*`, empty `/sys/class/hwmon/*`.
- Windows host side, via the `powershell` zenka
  (`powershell.exec` + a new STRM feed mirroring
  `powershell.cmd.pointer-stream`'s already-proven shape was a real,
  buildable option architecturally): native WMI
  (`root/wmi` `MSAcpi_ThermalZoneTemperature`) returns "Access denied"
  -- confirmed the querying process is not elevated
  (`IsInRole(Administrator) = False`). `FanControl` IS running on this
  host and DOES have real sensor data (embeds `LibreHardwareMonitorLib.dll`
  directly, confirmed on disk at `/mnt/c/Program Files (x86)/FanControl/`)
  but exposes it only via an internal, undocumented GUI<->Service IPC
  (`FanControl.IPC.dll`, gRPC-over-named-pipes) -- not a public API, not
  worth reverse-engineering. Neither standalone LibreHardwareMonitor nor
  OpenHardwareMonitor's WMI namespaces exist on this host at all.
  **Root cause of the whole dead end: temperature sensor access on
  Windows generically needs elevated/driver-level privileges** -- exactly
  why FanControl itself ships a separate `FanControl.Service.exe` rather
  than running its own GUI elevated. Getting real CPU temp here would
  need either an elevated scheduled task or installing+running
  standalone LibreHardwareMonitor as its own service -- both real host-
  config changes, explicitly deferred, not blocking this task.

**user's own pivot, this task's actual scope**: for THIS new sweep-
auto-resume mechanism specifically, defer temperature entirely -- INCLUDING
the GPU-temp-based trigger design floated earlier in this same
discussion for this same new feature (coding already has the temp
buffer, would have been easy to build) -- in favor of `/proc/loadavg`,
uniformly for both backends, explicit decision. **This does NOT touch,
replace, or deprecate the existing, separately-shipped
`task.handler.cold-queue-sweep` feature** (task zenka, landed
2026-07-21/22, gates that zenka's own summary-of-summary background
work) -- that is a different zenka, a different config namespace, a
different feed subscription, and a different purpose; it is not
mentioned anywhere else in this task file and stays completely as-is.

The kernel's own 1/5/15-
min exponential decay gives the exact same "free smoothing from physical
accumulation" property that made GPU temp attractive in the first place
(a queue-depth check structurally can't have it -- it can go from busy to
empty in zero time with no smoothing) -- loadavg already IS the smoothed
signal, no `base.balanced-average` layering needed on top of it (that
helper is for smoothing genuinely noisy per-sample deltas like
`system.cpu-load`'s percent-busy figure, which loadavg's kernel-side
decay already makes unnecessary here). Also simpler to implement than
either temperature path: `/proc/loadavg` is a plain file read, same
technique `v7-zenki.sub-process.get_ppid` already uses for
`/proc/<pid>/status` -- no new access.zenki grant, no cross-zenka round
trip, no dependency on X-11/GPU-specific infrastructure at all.

## scope

add a small watcher (timer, ~15-30s interval, mirroring
`task.handler.cold-queue-sweep`'s own sweep-timer shape) in the coding
zenka that:

1. only runs at all when at least one backend's model-sweep state is
   `paused` with `paused_reason eq 'yield-timeout'`
   (`<coding.model_sweep_state>->{$backend}`) -- for EITHER backend, gpu
   or cpu, the same check either way, no backend-specific branching
   needed since the signal (system loadavg) isn't backend-specific
2. reads `/proc/loadavg` directly (first field, the 1-minute average --
   confirmed live this session: real host values seen both ~8.x under
   heavy concurrent gpu+cpu sweep load and would be near 0 genuinely
   idle; pick the actual threshold from a real idle-floor measurement
   the same way the gpu-temp precedent did [ that task's initial guess
   of 45C was wrong, measured idle floor was 59-61C -- don't just guess
   a number here either, measure this host's genuine idle loadavg first ]
3. new config value `<coding.cfg.cold_loadavg_threshold> //= <measured>`
   -- do the live measurement before picking a default, exactly like the
   gpu-temp precedent's own retuning note
4. once below threshold [ a single `/proc/loadavg` read already reflects
   the kernel's own decayed average, so a single fresh read genuinely is
   "sustained low", not a noisy instant sample the way a raw queue-depth
   check would be -- confirm this reasoning holds before skipping any
   additional debounce, don't assume without checking ], call
   `model-sweep-resume <backend> :force:` for every backend currently
   paused on `yield-timeout`, logging clearly that this was an automatic
   cool-down resume, not a manual one -- distinguishable in logs from a
   human-issued `:force:`

## explicitly out of scope

- the existing flat 300s yield-cap itself
  (`coding.model_sweep.handler.poll_sweep` lines ~294-372) -- untouched,
  stays as the escalation-to-pause mechanism. this task only adds an
  automatic way OUT of that paused state, not a change to when it's
  entered.
- `coding.helper.backend_idle` (the queue-depth/lock-based idle check
  used for the initial yield decision, before the 300s cap) -- untouched,
  out of scope.
- ANY temperature-based approach, gpu or cpu -- see design history above,
  deliberately deferred for uniformity, don't reintroduce without a fresh
  explicit decision.
- the task zenka's own `task.handler.cold-queue-sweep` -- separate zenka,
  separate config namespace, not touched or coordinated with.
- `check_resource_fit`, `calculate_safe_context`, `get_children`,
  `pid_alive`, `gone_child`, the `access.zenki` grant fix, or anything
  else touched earlier the same session -- all separately committed and
  working, don't re-investigate.

## verification

fully live-testable on this host, no elevation/hardware-dependency
caveat this time: trigger a real yield-timeout pause (or wait for one
during a long real task -- happened twice already this session without
any deliberate triggering), confirm loadavg genuinely drops post-pause
(the paused sweep itself stops generating load, so this should be
observable), confirm the new watcher correctly auto-resumes once below
threshold. `bin/format-code -c` on every touched/new file. leave the
tree uncommitted, report back with what changed and how it was verified.

## status [ 2026-09-17 ] — DONE, live-verified, committed `2961a0212`

kimi (k2.8) landed cleanly on first pass: new
`coding.model_sweep.handler.cooldown_resume` watcher + timer in
`coding.init_code`. Threshold measured, not guessed (idle floor
0.11-0.18, sweep load ~8, default set to 2.0). Live-verified both the
negative gate (high loadavg, paused sweep -> correctly does nothing)
and the positive path (low loadavg -> auto-resumes, advances on its
own, manually-paused backend left untouched). Existing
`task.handler.cold-queue-sweep` (task zenka) confirmed untouched.

#,,,.,..,,,,.,...,,,.,.,,,...,,,,,..,,...,,,,,.,.,...,..,,...,,,.,...,,,.,,..,
#QTDSYGBI2DS74T7TIOPEU32CDMSYGI24DXBEJFLPXSZN6TLM25JJRRCQPGOCU2P7GM6RGBSR4B4VM
#\\\|BBENPMYASWYTARODIDJ3TVIUEHVC7DBZDNL26UFHQYIAACZMJUC \ / AMOS7 \ YOURUM ::
#\[7]ZGJ4HRZJXACNOVZYPLQCVGDZKADHJ6SYFJD5LTKCPPFFR7KKV4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
