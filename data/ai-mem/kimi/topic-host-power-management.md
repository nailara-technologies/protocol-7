2026-10-27 srv-16 host kept suspending to RAM (S3) killing SSH. Culprit chain: GNOME gsd-power idle-suspend -> logind -> systemd. Full runbook in read-me/md/docs/backlog/host-power-management.md.

IMPLEMENTED as `bin/p7-deps host-power [mode]` (AMOS7::deps::hostpower, 41-check harness bin/test-scripts/test-p7-deps-host-power.pl):
- awake [default]: mask sleep/suspend/hibernate/hybrid-sleep targets (hard backstop); guard-based p7-wakeup-disable.service oneshot; GNOME idle-suspend -> nothing per session user (runuser + /run/user/*/bus; warn not failure without bus).
- suspending: NO target masking (zenka/user suspend must stay available); firmware wake defaults kept (keyboard + NIC wake); WakeOnLan persistent via /etc/systemd/network/50-p7-wol-<iface>.link (WakeOnLan=magic, matched by MAC, wired only: device symlink excludes bridges/veth, phy80211/wireless excludes wifi) + immediate best-effort ethtool. Mode switch undoes the other side (unit removed / wol links dropped).
- profiles.yaml `host_power:` key (parser + validation) runs automatically after a clean profile install; basic-remote-server pins awake. p7-install needs no change.

Lessons / gotchas (all test-covered): /proc/acpi/wakeup writes TOGGLE not set; systemd-tmpfiles w-lines dedupe by path AND toggle -> cannot persist wakeup config (use the guard unit); boot-time guard list must cover ALL non-RTC devices in the table (firmware re-enables at boot), not only currently-enabled; own marked unit file must be rewriteable (upgrade path), foreign file refused; unit parent dir must be created; systemd passes literal $d through ExecStart to sh -c (proven on srv-16); '; true' tail so oneshot doesn't inherit grep's exit 1.

ALSO in same session -- p7-install upgrade (commits 00749b254, ea69f275c): base-packages apt output streams through AMOS7::deps::aptlog condenser with framed rows (port of dist-upgrade styling; noninteractive env travels inside the command line); p7-deps bootstraps cpanminus via apt before cpan module installs; cpan: profile entries with a debian mapping in src/base.known_dependencies now install the .deb first (libevent-perl, libio-aio-perl, libjson-xs-perl on minimal -- fresh hosts need no XS toolchain); cpanm runs -q (failure tail as framed warn rows). Verified live on srv-16 end-to-end.

Commits: 00749b254 p7-install styled apt + cpanminus ; ea69f275c debian resolution + quiet cpanm ; 398741922 host-power command ; c9c3cb3b3 boot-time guard list ; 7855c2260 suspending mode + host_power pin.

Next when wanted: KDE/XFCE idle-suspend keys (DE detection); `host-suspend` counterpart for v7-zenka (sleep state select + RTC wake alarm) to pair with its existing host poweroff/reboot commands; srv-16 wired-NIC WoL verification once cabled (ethtool <iface> | grep Wake, expect 'g').

#,,,.,.,,,,,.,,.,,,.,,,,.,...,...,,..,.,,,.,,,...,...,...,.,,,.,.,,,,,.,,,.,.,
#FYXOIXRWWZAASUSDU7KGUTZY4IYCOX67MODWVYCU54E6VTAPHP5UZIFJDYP64YWYIG7QZR4QY5WHE
#\\\|TANG3OEUGUQDO2H43FQXMAX5SCK2WX4AOQVO6YQZOZGLO6EW3U2 \ / AMOS7 \ YOURUM ::
#\[7]3OSX5YQFS5DG3QCB4OULO56EMGQX6KTQXRG3ZYTXSCJ4X7WAFKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
