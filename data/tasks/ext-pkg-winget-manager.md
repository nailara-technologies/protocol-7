# ext-pkg : winget manager [ windows host packages ]

## status

**requirement, agreed direction 2026-10-26.** threshold reached : the
powershell zenka is accumulating windows-host-side tool dependencies —
`usbipd-win` now, a pulseaudio server on the host next, likely an x-11
server after that. three-plus tools is where the "just print the manual
install command" escape hatch stops being charming [ the original deferral
condition in the usbipd discussion ].

pairs with `data/tasks/powershell-zenka-usbipd-commands.md` : that task
ships with a manual-install error message and is upgraded to auto-install
by this one.

## what lands

a fourth manager value `winget` in the ext-pkg registry
[ `cfg/zenki/ext-pkg/packages/<name>.yaml` ] , first entries :

| package        | winget id                  | consumer                              |
|----------------|----------------------------|---------------------------------------|
| `usbipd-win`   | `dorssel.usbipd-win`       | powershell zenka usbipd trio          |
| `pulseaudio`   | verify on host [ see below ] | audio bridge to windows host        |
| `x-server`     | verify on host [ see below ] | x-11 bridge to windows host           |

**winget ids must be verified live on the host with `winget search` before
entering the yaml** — do not guess ids from memory. `dorssel.usbipd-win`
is the one already proven by the 2026-10-26 install.

the lifecycle contract does not change : **install-if-missing only**, never
force-reinstall, never upgrade. unlike the pip/npm/uv-tool entries these
tools are not self-updating — `update_owner` records
`winget upgrade --id <id>` so version management still has a named home.

## the wrinkles [ load-bearing, resolve before coding ]

1. **no elevation.** ext-pkg check/install commands run as the amos user on
   the linux host; there is no tty and no sudo to answer a uac prompt.
   mitigate : prefer `--scope user` packages; when machine scope is
   unavoidable the entry must fail clean with a named manual step in the
   status record — never a half-installed state.
2. **non-interactive flags are mandatory** :
   `--exact --id <id> --accept-source-agreements
   --accept-package-agreements --disable-interactivity`. without these,
   winget can prompt or hang forever inside an open3-spawned process.
3. **PATH-refresh blindness.** after a successful `winget install`, the
   running process's PATH does not gain the tool — this is exactly the
   usbipd failure that motivated the whole effort. every `check` command
   must test an absolute exe path, never `command -v`.
4. **execution adapter.** ext-pkg runs check/install as shell strings on
   the amos host; winget lives on the windows side. decide whether manager
   dispatch grows a per-manager adapter [ winget entries wrapped through
   `powershell.exe -Command` via the existing interop path, or direct
   `/mnt/c/.../winget.exe` invocation ] before writing the first yaml.
5. **winget presence itself.** assume the desktopAppInstaller alias from
   windows 11 onward; absence = clean error naming the store package, not a
   failed install attempt.

## code touch points

- `src/ext-pkg.cmd.package-ensure` — `%known_manager` validation grows
  `winget` ; dispatch follows the adapter decision above.
- `cfg/zenki/ext-pkg/README.md` — manager table, winget wrinkle notes,
  contract carve-out for non-self-updating entries.
- `cfg/zenki/ext-pkg/packages/usbipd-win.yaml` and siblings per the table.
- powershell zenka `usbipd-attach`/friends swap their missing-tool error for
  `package-ensure usbipd-win` once this lands.

## non-goals

- **chocolatey / scoop** — winget is the windows 11 default and already
  proven on this host ; a second windows manager is pure complexity until
  something is genuinely uninstallable via winget.
- **windows update or service management** — installed services [ usbipd ]
  manage their own runtime state; ext-pkg stays bootstrap-only.

#,,.,,.,.,.,.,,.,,.,,,,,.,.,,,..,,,,,,,,,,,,,,..,,...,...,...,,,.,...,,..,,.,,
#VQJ4HYUEZIPXPFQOPOSQ4OKTVOU3XE5M5UIAVPLXMVSWHJOP6W77C72ULDA6ENZUBT6ZTRPNZYUT6
#\\\|LFM4WK6HFFDTQL7K4HTEY3DWH62ETNZWZTUKMQ2I3NFDINLMHPH \ / AMOS7 \ YOURUM ::
#\[7]UYXMMU2M5XYPBDUYZKSVWG5YYCTBWQO6WVGDB2TPHCO3BLSTLMAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
