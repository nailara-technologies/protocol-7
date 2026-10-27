# Host power management for server-duty installs

Background and runbook for what we had to do by hand on host **azurum**
(2026-10-27), plus the design notes for turning it into a managed
installer/provisioning step.

## Problem

A desktop Debian install used as a headless-ish server host kept suspending
to RAM (S3) on idle, killing SSH sessions and the display. Symptoms: blue
LED turns red, display off, SSH frozen. Power button woke it cleanly and
the SSH session even survived the resume.

## Why the naive fixes are not enough

Each layer can suspend or wake the machine independently. All of them have
to be addressed, or the symptom returns:

| Layer | Role | Fix |
|---|---|---|
| systemd | executes suspend | mask the sleep targets |
| logind | idle action, lid, D-Bus `Suspend()` requests from DEs | mostly a relay — requests below are the cause |
| GNOME `gsd-power` | DE idle-suspend, requests suspend via logind | `gsettings ... sleep-inactive-*-type 'nothing'` |
| desktop environments generally | same pattern as gsd-power | per-DE setting, plus the mask as the hard stop |
| ACPI wakeup devices | what may *wake* the box | trim `/proc/acpi/wakeup` |
| BIOS | sleep/wake defaults | untouched in our case |

Debugging shortcut: `journalctl -b | grep -iE 'suspend|sleep'` plus
`journalctl -b _COMM=systemd-logind` names the requester. On azurum it was
`Delay lock is active (..., PID .../gsd-power) but inhibitor timeout is
reached` — GNOME's power plugin asking, logind complying.

## The working sequence (all as root unless noted)

1. **Stop systemd from ever suspending:**

   ```bash
   systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
   ```

   Idempotent; make this the hard backstop in provisioning — even if some
   future DE/config asks, the request becomes a no-op.

2. **Disable the DE's idle suspend.** GNOME, as the affected user inside
   the session:

   ```bash
   gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
   gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
   ```

   Note for provisioning: `gsettings` needs the user's session bus
   (`DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus`) — plain root
   over SSH cannot set it for a user.

3. **logind extras** (relevant on laptops only, but cheap):
   `HandleLidSwitch=ignore`, `IdleAction=ignore` in
   `/etc/systemd/logind.conf`, then `systemctl restart systemd-logind`.

4. **Trim ACPI wake sources.** Read `/proc/acpi/wakeup`; each enabled
   device is toggled by *writing its name* — writing toggles, it does not
   set. On azurum the PCIe root ports (RP09/RP07, network) and XHCI (USB)
   were enabled; AWAC (RTC) was left enabled deliberately.

   **Persistence gotcha:** `systemd-tmpfiles` `w` lines dedupe by path, so
   three `w /proc/acpi/wakeup ...` lines apply only the first — and each
   application toggles, which can re-*enable* a device that was manually
   disabled before. Do not use tmpfiles for this.

   Working solution: a guard-based oneshot service that only writes a
   device when it is currently enabled (idempotent, toggle-safe):

   `/etc/systemd/system/wakeup-disable.service`:

   ```ini
   [Unit]
   Description=Disable ACPI wakeup devices
   After=sysinit.target

   [Service]
   Type=oneshot
   ExecStart=/bin/sh -c 'for d in RP09 RP07 XHCI; do grep -q "^$d.*enabled" /proc/acpi/wakeup && echo $d > /proc/acpi/wakeup; done'

   [Install]
   WantedBy=multi-user.target
   ```

   ```bash
   systemctl daemon-reload
   systemctl enable --now wakeup-disable.service
   ```

   Verify: `grep -v disabled /proc/acpi/wakeup` shows only `AWAC`.

5. **Wake hardware note:** with XHCI wakeup disabled, USB keyboards cannot
   wake the machine; the power button always can. Bluetooth keyboards
   cannot wake from S3 regardless. That is acceptable for a host that must
   never sleep anyway.

## Installer / provisioning integration

Implemented as `bin/p7-deps host-power [ mode ]` [ `AMOS7::deps::hostpower` ]
with two modes, pin-able per profile via `host_power:` in profiles.yaml
[ runs automatically after a clean profile install ; `basic-remote-server`
pins `awake` ] :

- **awake** [ default ] — server duty, the host never suspends: masks the
  sleep targets, installs and enables the guard-based wakeup-disable
  oneshot [ device names read from `/proc/acpi/wakeup` at run time, RTC
  class excepted ], sets the GNOME idle-suspend keys to `nothing` per
  session user [ a warn, not a failure, without a session bus ].
- **suspending** — zenka \ user suspend duty: the v7-zenka's host power
  commands [ poweroff, reboot, suspend ] must keep working, and the host
  is expected to wake on keyboard or Wake-on-LAN. No target masking
  [ manual `systemctl suspend` stays available ], firmware wake defaults
  untouched, and WoL is made persistent via systemd `.link` files
  [ `WakeOnLan=magic`, matched by MAC, wired NICs only ] plus an
  immediate best-effort `ethtool`. A previous `awake` setup is undone
  [ guard unit removed, p7 `.link` files dropped ] and vice versa.

Testable against a temporary root via `P7_DEPS_SERVICE_ROOT` [ systemctl
steps skipped, unit \ links \ `.link` files still written ] ; pure helpers
covered by `bin/test-scripts/test-p7-deps-host-power.pl`.

Natural next steps : DE detection beyond GNOME [ KDE / XFCE keep their own
idle-suspend keys ], and a `host-suspend` counterpart command for the
zenka side [ select the sleep state, set a RTC wake alarm ].

#,,,.,,,.,.,,,,,,,.,.,.,.,...,.,,,.,.,,..,,,.,..,,...,...,..,,,..,,.,,,..,...,
#UWU7K4M4LIS4QWXXJY7VNMQLVSJSVDVH6IL3OBAYFO2IWCUTGW72OIYYJQQ2LNTHLBHE5GLKHOZBY
#\\\|WCJRJ4PG4AQ2EPBX6JPWYO4T7ZGCKXE7OBMF55D4KNZHOWCURNB \ / AMOS7 \ YOURUM ::
#\[7]NLWPNN7BBNBDO5XKKV2RRX6G5ZN7C24PC23GEX36DI3PIM7GOQCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
