---
name: project-2026-10-15-sys-deps-autoinstall-stage1
description: 68bc74a82 : sys_deps start condition [ zenka start waits for declared deps, per-host opt-in auto_install_deps ] ; root apt child had a root-shell hole [ shell string, names checked only in the unprivileged parent ] -- fixed ; v7-zenki probes must never require \ AptPkg in-process. stage 2 [ bootstrap before Event ] open
metadata:
  type: project
---

**landed 2026-10-15 [ 68bc74a82, kimi k2.8 + review ]** : condition type
`sys_deps.<zenka>` [ v7-zenki.callback \ resolve.object.sys_deps ] on every
start path ; apt via debian.install-packages, cpan via debian.install-cpan
[ same serialized queue, the ROOT apt child ] ; failed -> degraded start,
retry_after 3600 ; install_timeout 1800 ; exempt `cube p7-log debian os-pkg`.
OFF until a host sets `v7-zenki.cfg.auto_install_deps = yes` in
/etc/protocol-7/v7-zenki/host.cfg -- none does yet [ yourum first ].

**security fix in the same commit** : `debian.start.apt_child` [ root,
forked before drop_privs ] ran `'apt-get -fy install ' . join ...` as a SHELL
string ; names were checked only in the protocol-7 parent -> anyone writing
to that pipe as protocol-7 had a root shell. now : names checked in the
child, list-form exec, cpanm from fixed paths only. lesson : a privileged
helper re-validates everything it gets from the unprivileged side.

**review catches** [ kimi's tests stubbed them away ] : its cpanm child was
spawned AFTER drop_privs [ unprivileged ] ; cube \ debian would have waited
on their own sys_deps [ deadlock ] ; 'installing' never timed out ; my own
`// qw| a b |` default was a list [ only the last word ] -- mutation-check
new tests.

**probes in long-lived processes** : `AMOS7::deps::module::probe_module`
REQUIREs the module [ loads it + its signal handlers into v7-zenki ] and
`debp::probe_apt` builds AptPkg::Cache [ 0.43 s, ~70 MB, never refreshed ].
v7-zenki uses `probe_module_file` \ `probe_apt_fresh` ; test asserts it.
the sys-deps zenka still uses the old ones [ follow-up ].

**open** : stage 2 -- AMOS7::deps bootstrap check in bin/Protocol-7 before
`use Event` [ user's 2026-08-31 direction : not p7-deps as a separate
process ] ; appmgr policy later. see [[project-2026-10-15-forensics-restart-loop-cube-ids]].

#,,,.,,,.,.,.,,,.,,,.,..,,,,.,...,..,,.,.,.,,,..,,...,..,,.,,,...,,,,,.,.,,,.,
#KHVPRWTEOKDXGFPSJTZUHBIQAU25MN3CMVNUD22LRG6DXPCRR7GYAG7GV2BF56RMRQKM2IM6JUEXO
#\\\|LKODESYVSDILD3AUOKLICYB65JPF2SCZI2DAQCWXJCOOYYAYIBM \ / AMOS7 \ YOURUM ::
#\[7]2CNSAZEXMHCE4F6U4KLRSUJQFI5IIOQE7VYVMXBBD3I45G5QYACQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
