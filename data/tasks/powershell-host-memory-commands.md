## [:< ##

# name  = task: add host memory commands to the powershell zenka
# descr = powershell zenka (the Windows-host-side interaction zenka) has
#         no memory-query commands at all -- the only existing memory
#         command lives in the system zenka and reports WSL/Linux-side
#         usage, not the actual Windows host's, which is the more
#         relevant signal for the kind of incident that motivated this

## context

filed 2026-09-15, motivated by a real incident this session: a WSL
shutdown loop forced a full host restart (which also pulled in pending
Windows updates along the way). likely cause, per the user: host memory
pressure -- Firefox's well-known tendency to grow its memory footprint
over a long session, compounded this time by a runaway CPU-side model
load (an unrelated mistake this same session -- see the "eighth/ninth
pass" LoRA activation-probe detour in `data/tasks/coding-lora-p7-idioms.
md`, where an HF probe briefly tried to load a 9B model as fp32 on CPU,
~36GB, on this 15GB-RAM host, before being caught and fixed to load
4-bit on GPU instead, matching every other probe in that thread).

## the gap

`src/system.memory.cmd.mem-used` exists and returns `<system.mem.
used_percent>` -- but that's WSL/Linux-side memory, not the Windows
host's. `src/powershell.*` (display-switch-toggle, get-event-log,
notify-*, pointer-stream, screenshot-capture -- all genuine Windows-host
interactions) has nothing memory-related at all. There is currently no
way to see actual Windows host memory pressure (where Firefox and WSL's
overall VM allocation both live) from inside protocol-7 -- exactly the
signal that would have given advance warning before tonight's crash.

## proposed scope, not started

- a `powershell.cmd.mem-used`-shaped command (or similarly named),
  querying actual Windows host memory via PowerShell (e.g. `Get-
  CimInstance Win32_OperatingSystem` for total/free physical memory),
  mirroring `system.memory.cmd.mem-used`'s simple percent-based return
  shape for consistency between the two zenki's interfaces.
- worth also considering a per-process top-memory-consumer listing (to
  catch a specific runaway process like Firefox before it becomes a
  host-wide problem), not just an aggregate percentage.
- the user raised a STRM-based (live-updating, not one-shot-poll) reply
  mode as worth considering for this -- STRM is an existing cube-level
  reply-mode convention (see `cube.cmd.select-strm-mode`, `channels.
  cmd.test-strm`), not something system zenka's existing mem-used
  command currently uses either. Would let this feed a genuine early-
  warning mechanism rather than only ever being checked reactively
  after the fact. Not scoped in detail -- worth a decision on one-shot
  vs streaming before implementing, not assumed.

no design/implementation work done yet -- this is a capture-for-later
task file only.

#,,,,,,,.,,,.,,,.,,..,..,,..,,,..,.,.,..,,...,..,,...,...,.,,,,,,,..,,,..,,..,
#S2GRBS32A5PCH4D2XFMJZKIQN3H5IIT5ZNT2RWDFYXAFMRYQJDE4DYAIZETANZHCTDTPKFSA55J66
#\\\|VGPP2EAKZ24PAGAPLPEH224VIBKWTUJ56GC5D5ULJRAUZARV7A4 \ / AMOS7 \ YOURUM ::
#\[7]7INM6EWUOM4ETNCH7322S3OHEMTYPH27AL3U3YZID6KDL7WPY4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
