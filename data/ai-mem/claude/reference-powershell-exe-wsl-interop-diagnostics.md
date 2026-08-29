---
name: reference-powershell-exe-wsl-interop-diagnostics
description: "powershell.exe / pwsh.exe are directly callable from inside WSL via interop (no extra setup) -- useful for querying Windows Event Viewer, Windows Update history, etc. when diagnosing anything that crosses the WSL/Windows-host boundary"
metadata:
  type: reference
---

Confirmed live, 2026-08-29 (diagnosing [[feedback-wsl-oom-full-vm-crash-2026-08-29]]):
`powershell.exe -Command "..."` and `pwsh.exe` are both directly callable from a WSL bash
shell, no extra setup needed on this host — `which powershell.exe pwsh.exe` finds them
under `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/` and
`/mnt/c/Program Files/PowerShell/7/`. This is standard WSL interop (Windows/Linux
executables can invoke each other by default unless interop is explicitly disabled), but
worth remembering explicitly: it means the Windows host's own diagnostic surface is
reachable directly from here, not just the Linux side.

**Useful query shape** for Windows Event Viewer:
```
powershell.exe -Command "Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date '2026-08-29 01:58:00'); EndTime=(Get-Date '2026-08-29 02:05:00')} | Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message | Format-List"
```
`LogName` can be `System`, `Application`, etc.; add `ProviderName='...'` to narrow (e.g.
`Microsoft-Windows-WindowsUpdateClient` for update history, `Microsoft-Windows-Kernel-
Power` for sleep/wake/unexpected-shutdown events). Useful when diagnosing anything that
might originate on the Windows side of a WSL host — VM restarts, sleep/resume, resource
pressure — that the Linux-side journal alone can't explain.

**How to apply**: when a WSL-hosted session hits something that looks like it originated
outside Linux (a whole-VM restart, a mysteriously dropped connection, timing that doesn't
match any Linux-side event), check Windows Event Viewer via this route before concluding
"no visibility into the Windows side" — there often is visibility, it's just one
`powershell.exe` call away.

#,,..,.,.,..,,,,.,,.,,...,,,.,...,,,.,.,,,,,,,..,,...,...,..,,..,,...,,,.,,,.,
#HKI3IWDJJNLKQAJBHD72G4M4EGVQBFEQDW73HK7JDEVU4T775EJMVBTULVFE2W3CDKN5OPUPLJV5A
#\\\|RBROYKMGGZMJ7W4EMS6AXTXWG5MQ34DE45QCPKZXXGFTSG3IOR2 \ / AMOS7 \ YOURUM ::
#\[7]BVQVXKPHJFYRC5VYIEFU7NS53E6PNROL4HD725FGGJJLMYIUBYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
