---
name: project-2026-10-27-session-handover-usbipd-wsl
description: overnight session [ ~04:30 ] : WSL usbipd host-USB commands on the powershell zenka , async deferred attach , wedge-proof powershell.exec , editor wrap-spin fix , kimi-legacy shim repair ; commits c37c63580..54ae2453e ; follow-ups listed
metadata:
  type: project
---

**context.** owner imaging a debian 13.7.0 netinst stick via WSL2 -> needed
USB passthrough -> usbipd-win 5.3.0 on the windows host. session grew into
the full host-bridge hardening of the powershell zenka.

**landed [ commits on base , unpushed ] :**
- c37c63580 : requirement docs : usbipd commands , ext-pkg winget manager
  [ windows-side sibling ] , dependency-chain-self-ensure roadmap
- 45740bff3 : `powershell.cmd.usbipd-{list,attach,detach}` [ list uses
  'mode size' for multi-line , attach is DEFERRED + poll-timer ] ,
  `powershell.handler.attach_poll` , wedge-proof `powershell.exec`
- 11cf1d92a : editor wrap-spin fix : `detail_editor_wrap_segments` clamped
  to width >= 1 [ headless zero-width spun 9h at 99% cpu ]
- 54ae2453e : `powershell.exec` IO::Select autoload WITHOUT import list --
  qw|IO::Select| made base.perlmod.autoload fail , aborting init_code
  midway [ usbipd_path never resolved -> plugins claimed 'not installed' ]

**hard-won operational knowledge :**
- usbipd v5 CLI : `--wsl` takes an OPTIONAL distro value [ --distribution
  is GONE ] ; bare `--wsl` auto-selects , device visible in ALL wsl2
  distros ; `bind`\`unbind` still need elevated manual step per busid
- THE WSL-TETHER STALL : usbipd attach SUCCESS PATH hangs forever when the
  usbipd process runs as a wsl-interop tether [ ANY spawn chain through
  perl/sh , proven via 18-experiment matrix R4..R18 : stdio/stdin/env/
  PATH/fds/signals/sessions/intermediates ALL exonerated ]. ESCAPES :
  `Start-Process -WindowStyle Hidden` [ chosen : headless , no popups ] ,
  schtasks /run [ also works ] , plain bash-direct [ works but manual ] .
  MECHANISM UNKNOWN -- documented in usbipd-attach header
- reply protocol : multi-line output -> 'mode size' ; 'mode true/false'
  REQUIRES non-empty data [ framework rejects empty TRUE replies ] ;
  descr lines <= 55 chars [ pre-commit check ]
- diagnostics that bypass wedged MCP : /dev/shm/.7/STDOUT/NIW7OAQ ring ,
  /var/log/protocol-7/<host>.<zenka>.zenka.log [ init errors land here --
  the autoload failure was found this way ] ; p7c/:: does NOT work from
  agent bash context [ silent hang ] ; MCP server queues behind wedged
  requests and recovers on zenka restart
- kimi_dispatch was BROKEN since the 2026-10-26 dist-upgrade removed
  system python3.13 [ stale venv shebang ] ; repaired via `uv python
  install 3.13` + repointing the venv python symlink [ pin preserved ,
  kimi 1.50.0 ] -- see bug-kimi-legacy-shim-python313-orphan.md

**follow-ups [ next sessions ] :**
- init-runner per-section error containment [ one module-load error must
  not silently amputate the rest of init_code ]
- generic `powershell.exec_async` for remaining blocking commands
- lazy `usbipd_path` re-resolution [ one-shot init probe = sticky failure ]
- ext-pkg winget manager task [ windows-host packages : usbipd-win ,
  pulseaudio server , x server ]
- U2F signing-authorization vision : udev zenka [ events via udevadm
  monitor , udevd IS running in this WSL ] + fido2 challenge bound to run
  hash + usbipd attach-on-demand ; rules in cfg/zenki/udev/rules-set-up.U2F-tokens
- migration context : Blackview MiniPC incoming as main dev machine [
  debian 13.7.0 stick READY : verified + written + detached ] ; old host ->
  native linux later , gfx card RMA ; `bin/p7-install` landed [ parallel
  session ] -- Blackview bootstrap = first exercise of dependency-chain

#,,..,,,,,...,,.,,,.,,...,,,.,,..,,,,,,.,,.,,,..,,...,...,.,.,.,.,.,,,,..,.,,,
#A433GLPL5ZFITC7HUC5OV4Z4AM6IK7K6AO2QYEANM4PT5SYDG7YOD2LIIY5XN5O4MUK6SV2ALXC2O
#\\\|RDAJQAZFJYB3R5EXUBVM5ZMCFKYQ7VRVG76YLNGW56PZ7S2JSI4 \ / AMOS7 \ YOURUM ::
#\[7]I7CB5WWN7LWRGN7J6MQZYXE2KF5MOUK7ZOKKDWAUV27WGFVK4GCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
