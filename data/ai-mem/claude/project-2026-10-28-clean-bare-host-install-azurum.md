---
name: project-2026-10-28-clean-bare-host-install-azurum
description: 2026-10-28 milestone : azurum [ fresh debian, root, opted in ] went bare -> p7-install -> running boot-enabled service with extended, first clean pass of the whole chain [ wanted for 25 years ] ; commits cf534de4a .. f64d89267 ; open : route-history verdict, discover peers [ wsl nat, owner root ], nodes orbital-p7ref spam
metadata:
  type: project
---

**state 2026-10-28** : azurum installed clean end to end -- `p7-install
-profile extended -enable -start`, cube \ v7-zenki first boot
without warnings, the deps a zenka misses installed at its start. README
gained the p7-install \ profiles \ auto-install sections and the milestone
line [ user : "after 25 years of wanting that" ].

**the chain as it stands [ commits cf534de4a .. f64d89267 ]**
- opt-in gate covers standalone `bin/Protocol-7 <zenka>` starts as root,
  bounded to init [ flag cleared after base.init ]
- boot-early modules [ needed before any install code exists ] : the xz
  inline subs need `IO::Uncompress::UnXz` [ libio-compress-lzma-perl ],
  AMOS7::INLINE needs `Inline::C` -- installed in base.perlmod.pre_init
  inside the window ; the first start uses the xzcat pipe [ one notice
  line ], the next start is clean. `minimal` profile now holds the boot
  crypto + lzma + Inline::C + gcc [ cryptography = tls extras only ]
- pm-src builds [ Digest::BMW ] tried before cpanm ; build dirs under
  `/var/protocol-7/<zenka>/pm-src.<rnd>` [ base.file.temp ], removed right
  after the build -- NOT File::Temp CLEANUP [ exit runs after the
  privilege drop : 'cannot chdir to child' ; user : /tmp paths are not
  acceptable anyway ]
- cpanm \ apt \ systemctl output all through styled log lines [ stderr
  merged, dpkg \r progress collapsed, autoremove list -> one count,
  systemctl -q ]
- shipping copies of CryptX \ Event in pm-src was rejected [ user ] : a
  frozen copy loses distro security updates ; availability instead via
  network copies later [ osf-cache style ]

**open**
- route history [ 9a9459835 ] waits for the next 'reply to unknown route
  id' -- the tcpdump install hang on azurum [ debian at its 420s idle edge
  after discover's dep jobs ] was not reproducible ; next step if it says
  'removed' : a deletion reason
- discover peers : this dev host is WSL2 behind NAT -- multicast never
  reaches the wlan [ tcpdump on azurum saw only its own announces ] ;
  needs `networkingMode=mirrored` or a native host. trust : the owner root
  [ TRUST-CHAIN-STEP2, p7-keys certify-host \ owner-pin ] is the
  implemented 'parent network key' ; user to choose the owner key
- discover asks an offline `nodes` for orbital-p7ref every few seconds on
  azurum [ cube log spam ] -- back off or skip when nodes is absent
- `p7-deps help` display drops the `\` in 'firmware \ hardware' etc

related : [[sys-deps-autoinstall-stage1]], [[perl-loader-gotchas-require-path-inline-c-qw]]

#,,..,,,.,,..,...,...,,..,..,,,.,,,..,,.,,,,,,..,,...,...,,,,,,..,,,,,.,.,.,,,
#PGHKFJPXEJCQ4G6OQVVHLXJFBITX57CIAKBSC3WG5EAEDC3C7VVYBLE45KYTQSOSVYYLECFM6TLUI
#\\\|3EVFEB7UAWMBO3UQW4JY35M7LHH3FAXGTSYM436DLT7WO3NKFN2 \ / AMOS7 \ YOURUM ::
#\[7]CEEJYR4DEXTMSH6GYNU2PGBXH6RBLYCUN3RDMHAMJSOQYWVOFCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
