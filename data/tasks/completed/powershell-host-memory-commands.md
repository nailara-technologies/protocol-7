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

## implemented 2026-09-15

both one-shot commands built, wired in and tested live against the
real windows host :

- `src/powershell.cmd.mem-used` -- `p7c powershell.mem-used` returns
  `{ mode true, data <percent>% }`, mirroring
  `system.memory.cmd.mem-used`'s shape exactly [ two-decimal percent,
  same quoting style ]. queries `Get-CimInstance Win32_OperatingSystem`
  [ TotalVisibleMemorySize / FreePhysicalMemory, in KB ] and computes
  percent used. percent is formatted invariant-culture on the
  powershell side so the decimal point stays '.' regardless of host
  locale. live result at test time : 79.43% host-side vs the system
  zenka's 12.06% wsl-side on the same machine -- the discrepancy that
  motivated this task, now directly visible.
- `src/powershell.cmd.mem-top-proc` -- `p7c powershell.mem-top-proc
  [count]` lists the top N [ default 10, capped at 50 ] host processes
  by working-set memory as `pid<TAB>name<TAB>ws-MB` lines [ mode size ].
  at test time this immediately surfaced `vmmemWSL` at ~15GB WS on this
  15GB-RAM host, followed by the firefox processes -- exactly the
  per-process advance-warning view the incident called for.

both follow the `powershell.cmd.get-event-log` disciplines
confirmed live earlier : single-line semicolon-joined script through
`<[powershell.exec]>->(...)` [ never multi-line -- the wsl-to-windows
argv marshalling breaks on embedded newlines ], and try/catch with a
`P7ERR:` sentinel parsed generically on the perl side.

also touched :
- `cfg/zenki/powershell/zenka.v7` -- added `mem-used mem-top-proc`
  to `access.cmd.usr.*`
- `cfg/zenki/powershell/subroutines.load-early` -- regenerated via
  `bin/dev/gen-sub-whitelist powershell`

## deliberately not built

- STRM-based live-streaming reply mode [ raised as a stretch idea ] --
  noted as a future option in a comment in
  `src/powershell.cmd.mem-used`, not implemented ; one-shot was the
  actual deliverable.

## pending : signatures

the four touched files could not be re-signed in the afk session --
`bin/Protocol-7 sourcecode update-signatures` needs the
'proto-7.sourcecode' key decryption password [ terminal-prompt only ].
run, when back at a shell :

    bin/Protocol-7 sourcecode update-signatures \
        src/powershell.cmd.mem-used src/powershell.cmd.mem-top-proc \
        cfg/zenki/powershell/zenka.v7 \
        cfg/zenki/powershell/subroutines.load-early \
        data/tasks/powershell-host-memory-commands.md

unsigned files load and run fine [ no load-time signature
verification ] ; signing is for commit hygiene / pre-commit.

## confirmed landed, committed, and genuinely useful, 2026-09-17

signed and committed as `b215e000d`. Put to real use the same day it
was needed again: while diagnosing a cpu/gpu model-sweep segfault storm
(`[[project-wsl2-shared-ram-constrains-concurrent-inference]]`), `p7c
powershell.mem-used` and `p7c powershell.mem-top-proc` gave the exact
signal this task was built for -- host at 50.29% memory used, `vmmemWSL`
consuming only ~7.5GB of it, confirming the crash storm's real
constraint was WSL2's own configured memory ceiling, not host-wide
exhaustion. Exactly the "advance warning that would have helped before
tonight's crash" framing from the original incident, now validated on a
second, unrelated incident.

#,,,,,,,,,...,,,,,,,.,,.,,,.,,,,.,.,.,,,.,.,.,..,,...,...,.,,,.,,,,,.,,..,,..,
#IFLCARYABVPW4VOXGGLIUYGQENBWLBMOGB3QPUY3FFJ2JGHO4FDTSB7QWRWDYODG5X3QNFUOCZOEC
#\\\|H2B2RGNDCAACTEBPQXVO65TZYNI6HIENQD3KN7PWOI44OWQKB7Y \ / AMOS7 \ YOURUM ::
#\[7]NCMM2CCTKJTQIB5PODJY2ZCDTHFHYI77EHOEWGIGBIY5HVLELGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
