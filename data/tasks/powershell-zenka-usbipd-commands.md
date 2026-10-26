# powershell zenka : usbipd host commands

## status

**requirement, agreed direction 2026-10-26.** motivation came from an actual
need : expose a usb stick to wsl2 to write a debian netinst image with dd.
`usbipd-win` works for this and installed fine via winget, but the freshly
installed `usbipd.exe` was not on PATH in any already-open terminal — a
windows-side PATH-refresh quirk this design must simply not depend on.

scope decision taken together with `data/tasks/ext-pkg-winget-manager.md` :
the commands land **now** with a graceful missing-tool error, automated
install waits for the winget ext-pkg manager.

## what lands

a plugin trio on the powershell zenka [ the existing "windows host bridge" ,
`cfg/zenki/powershell/zenka.v7` ] :

| command           | usbipd operation                                        |
|-------------------|---------------------------------------------------------|
| `usbipd-list`     | `usbipd list` — busids, device state, attach status     |
| `usbipd-attach`   | `usbipd attach --wsl --distribution <distro> --busid`   |
| `usbipd-detach`   | `usbipd detach --busid`                                 |

`usbipd-bind` is deliberately **not** in the trio : `bind` requires admin
elevation once per device, and the plugins run non-interactive — no tty to
answer a uac prompt. instead `usbipd-attach` on an unbound busid returns a
clear error naming bind as the one-time elevated manual step. `list`,
`attach`, `detach` are all non-elevated on usbipd v3+.

## design constraints

- **absolute-path exe resolution, never PATH.** mirror what
  `src/powershell.init_code` already does for powershell.exe : resolve
  `usbipd.exe` as `C:\Program Files\usbipd-win\usbipd.exe` first, then the
  per-user winget location under
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\` as fallback. PATH lookup is
  forbidden here — the trap that started this task bites exactly there.
- **plugin shape per `src/powershell.cmd.mem-used`** : single-line
  semicolon-joined powershell script [ wsl-to-win32 argv marshalling does
  not survive embedded newlines ], heredoc with the trailing newline
  stripped, `try/catch` + `P7ERR:` sentinel, `{ mode, data }` reply shape.
- **wsl distro reuse** : `usbipd attach --wsl` targets the wsl *default*
  distro; use the already-resolved `<powershell.cfg.wsl_distro>` from
  `src/powershell.init_code` with `--distribution` so the device lands in
  the distro this zenka actually runs in.
- **missing tool** : clean `{ mode false, data }` error naming
  `winget install dorssel.usbipd-win` as the one-time host-side step [
  upgraded to auto-install via ext-pkg once the winget manager exists ].
- **access registration** : add the three commands to `access.cmd.usr.*` in
  `cfg/zenki/powershell/zenka.v7`.

## non-goals

- **winget auto-install** — separate task
  [ `data/tasks/ext-pkg-winget-manager.md` ] , deferred on purpose.
- **image writing itself** — once attached, the stick is a normal
  `/dev/sdX` block device on the amos host; dd, verification, and safe
  eject are linux-side concerns outside this zenka.
- **auto-detach lifecycle tracking** — later polish if it proves annoying;
  one-shot commands are the deliverable for now.

#,,.,,...,,,,,..,,,,,,...,.,.,,,,,..,,,.,,...,..,,...,..,,..,,,,,,.,.,,.,,.,,,
#V4TSMCEIM7C2UYLFULKIGBZVC24KRLEP7USHD6DF7QTZEGOL4DYCFQUWTPB4DCJY2PE6I5ESIM6AU
#\\\|QFMCYOWR4UWRLKY6DCB7OEGAX4HKVTMK5KKYX6OIF7GLLUF5KUE \ / AMOS7 \ YOURUM ::
#\[7]AOZCJOMIKGENFVFCXD6QNSPOLTYHW6BLM5XXDWGKQMDXQJHS5OCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
