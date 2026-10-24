---
name: project-2026-10-24-srv-a-third-worker
description: 2026-10-24 srv-A set up as srv-U's 3rd jobsite worker [ cpu, link label = its host name ] ; twofish random-key swap on srv-A + srv-U ; mem scope never worked non-root [ fixed 9406bea69 ] ; p7c 'task.create+' double-encodes ; open : first live assessment, srv-U reboot test
metadata:
  type: project
---

follows [[project-2026-10-24-session-handover-link-live-ids-qlk]] item 1.
srv-A runs only `:no_tools:` tasks [ srv-U's foreign-task guard ] -- that
is what makes offloading into another security context safe, and why the
tool-call hang does not block it.

## srv-A [ 6 epyc, 11 GB, no gpu, debian sid, live name server ]

- srv-U's build tree copied, same paths [ cpu flags identical, native
  build ok ] : `/data/source/ik_llama.cpp/build-cpu/` bin + 3 .so
- model from hugging face, sha256 = srv-U's ; registry id KMUVFQQ:QDBKEXY
  [ same as srv-U : resolves only after a models restart, scan-path-add
  writes the file but not the in-memory registry ]
- /etc/protocol-7 : coding host.cfg [ srv-U's keys, threads 5, mem_max 8G,
  round_soft_ceiling 777 ], system host.cfg [ llama-server 72 % ],
  models host.cfg [ task_zenka = external.<srv-U record>.task ],
  v7-zenki host.cfg `v7-zenki.host.zenki.enable = external models`
  [ .bak-2026-10-24-worker ]
- link : protocol-7 own key id_ed25519_link + ssh config + srv-U host key
  [ fingerprint checked against srv-U ], host-edit record for srv-U with
  link_user = srv-A's label. LIVE : `link <srv-U> : up over ssh-w`,
  `external.<srv-U>.task.queue` answers
- the default 7777 context should fit : assessments ~10-11.5 k chars,
  `/no_think` ; srv-U cpu takes 3-10 min [ srv-A ~13 min max < ttl 1800 ]

## srv-U

- `access.cmd.usr.<srv-A label>` [ 9406bea69 ] ; `external.authorize-link`
  done [ task-worker line kept ] ; jobsite assess_parallel = 3
  [ .bak-before-assess-parallel-3, reload config ]

## owner's choices

- link label = the HOST name [ owner : 'simply use the hostname' ] -- one
  label per host, the grant = what that host may do. authorize-link keeps
  ONE key per label : reusing task-worker would have cut off the local gpu
- swap on the remotes : file + dm-crypt plain twofish-xts-plain64, 512 bit
  RANDOM key per boot [ /etc/crypttab cswap, /dev/mapper/cswap in fstab,
  modules-load.d/twofish-swap.conf, swappiness 10 ]. srv-A 4G reboot-
  tested ; srv-U 8G reboot-tested 2026-10-25 [ external now starts at boot via its overlay, both links back by themselves ] ; srv-V [ 2026-10-25 ] its
  install-time sda3 partition, crypttab by-partuuid [ mkswap wipes the
  fs UUID each boot ], initramfs RESUME=none [ it pointed at the old
  UUID ], reboot-tested ; srv-F already had twofish random-key swap
  [ /var/swap, retiring host -- left as is ]
- memory entries name servers srv-<x>, never the host names

## found

- coding mem_max [ layer 2 ] never worked for a non-root zenka :
  drop_privs sets XDG_RUNTIME_DIR = home, systemd-run --user finds no bus.
  fixed 9406bea69 [ child gets /run/user/<uid>, 'bus' OR 'systemd/private'
  accepted -- srv-A has only the latter ; MemorySwapMax=0 ]. srv-U sets no
  mem_max at all [ unscoped ]
- the dbus zenka [ session dbus-daemon ] cannot stand in for the systemd
  user manager
- `p7c task.create+` [ stdin body ] adds one encoding level : test tasks
  hold 'SÃÂ¤tze' where jobsite's own hold 'SÃ¤tze' on disk [ that one level
  = the layered-write pattern, [[zenka-open-default-utf8-layer]] ] --
  show-prompt prints clean utf-8. not fixed yet
- test tasks = `:no_tools:` + `jobsite.show-prompt <job>` piped into
  `task.create+` on srv-U [ owner : the same as an assessment ]

## live result

- 5 test tasks on srv-U : srv-A claimed 1, done in 6'53" [ valid yaml,
  german ] ; rss ~6.9 GB in the 8G scope [ MemorySwapMax=0 live ], swap
  unused ; ctx 7777 enough. self-test 2/3 [ cat prompt 3 'Mouse' ] did NOT
  leave restart_needed

## FOUND : host overlays had no trust boundary [ fix built, see below ]

- /etc/protocol-7 is protocol-7:protocol-7 775 on all four servers, most
  zenka dirs protocol-7-owned [ base.load_host_config creates them so ] :
  the unprivileged zenka user can write ANY zenka's host.cfg, including
  root v7-zenki's [ srv-A's v7-zenki/host.cfg is protocol-7-owned ]
- proposed [ owner to decide ] : fail-closed owner \ mode check in
  load_host_config [ root or tree owner, no group\other write, whole dir
  chain ], re-own existing files FIRST [ else they silently stop
  applying ], cube [load_host_config] for host-local grants +
  authorize-link reading it, srv-A's grant out of the repo, later the
  overlay for every zenka [ 11 of 127 today ]
- the local-modifications commit used to carry host grants ; it is gone,
  /etc/protocol-7 is meant to replace it
- LANDED 463db3371, DEPLOYED all four servers [ srv-F, srv-V, srv-A,
  srv-U in that order : copy -> pull -> `systemctl restart Protocol-7`
  -> verify -> old files to /root/p7-host-cfg-backup-2026-10-24/ ].
  live : every zenka logs the host-config path [ httpd \ models log no
  level-1 line in that phase -- proven by behavior ], a protocol-7-owned
  probe overlay REFUSED on srv-F, srv-A's link up with the grant only in
  srv-U's host-config/cube.cfg, srv-A coding spawned cpu in the 8G scope.
  LOCAL box NOT migrated [ needs root : owner runs the scratchpad script ]
  -- until then local jobsite + models overlays are NOT applied after a
  restart [ the local gpu stops claiming srv-U tasks ]. overlays move to
  /etc/protocol-7/host-config/<zenka>.cfg [ root:root 0755 dir,
  base.host.config_dir ], fail-closed base.host.trusted_file [ root \
  tree owner != zenka user, no g\o write up to '/' ], /etc/protocol-7
  root:protocol-7 0755 [ check-zenka-paths ; non-root callers skip it ],
  detected facts -> host-config/host.detected [ /var was zenka-writable
  too, v7-zenki root applied it ], old <zenka>/host.cfg logged level 0,
  never moved by code. cube [load_host_config] -> host-local grants in
  host-config/cube.cfg, authorize-link reads it. srv-A's grant leaves the
  repo [ into srv-U's cube.cfg BEFORE the pull ]. design :
  data/md/design/HOST-CONFIG-OVERLAYS.md ; test
  bin/test-scripts/test-host-config-trust.pl [ 19 ok ]
- the zenka etc dir creation in load_host_config was kept [ zenka owned
  state dir, no overlay in it ]
- the service unit is `Protocol-7.service` [ capital P ] -- `systemctl
  is-active protocol-7` says inactive, which is the wrong name
- test-v7-zenki-host-zenki.pl : 1 failure already on HEAD ['without
  host.cfg keys nothing changes'] -- not this change

## start profiles [ owner, 2026-10-24 ]

- external left start-set-up.base [ it came in with 0c9478f48 as a side
  effect, never decided ] : a fresh host must not look like it already
  has connections to other hosts. new start-set-up.minimal = cube p7-log
  [ p7-log : without it no log reaches a file ]. a host with link
  records enables external in host-config/v7-zenki.cfg
  [ v7-zenki.host.zenki.enable = external ] -- srv-A had it, srv-U added
  [ its delta fetch link was DOWN after the restart : remote-server never
  started external at boot ]. owner : balance with fast, intuitive
  config [ the *-edit zenki ]
- external.list links \ orbital landed 5bf4b5d95, all four servers

## format-code [ 2026-10-25 ]

- cfg mode + align-only [ cloud branch dev/format-code-cfg-mode, 8 of
  100 cloud credits ] ; sweep of 78 cfg files locally, step4 join slips
  fixed by hand [ 'path/ x', 'infer-ence', 'host-edit.  init_code' ,
  lost sentence breaks ] -- the join rules are shared with src mode, fix
  them there [ open ]
- -report [ only files needing action + 'N of M' summary, exit 1 ] and
  -parsed [ the module as the -c check compiles it, framed like
  Protocol-7 -core-subs ]
- src/download.init_code:52 'uninitialized value in integer addition'
  in the -c check : the BASE tool reports it too, the module is
  unchanged since the src/ rename and runs fine -- NOT today's commits.
  only -c compiles [ a plain \ sign run never shows it ], so since when
  is unknown ; cause open [ perl 5.42.3 vs a compile-time cpan module :
  compare under the 5.32 floor perl ]

## open

- optional : mem_max 14G + linger on srv-U
- clients.https marker committed [ 463db3371 ; the untracked copy on
  srv-U blocked the pull once : a `pull && restart` chain without set -e
  restarted on the OLD code -- harmless, old files were still in place ]
- systemd-networkd-wait-online fails on srv-A since at least 10-18
  [ pre-existing ]

#,,..,,,.,.,,,,.,,..,,..,,,.,,..,,.,,,,..,,.,,..,,...,...,...,,,.,.,.,...,,..,
#O37TMHC7RI6T2WALF2YOHXW3TVIOKLIUSTSURRDVGSWEQIP2P5COZGUETAKKNNXS7PDHQSMZWJSUA
#\\\|V43NKF2GKH7VMLJMFZT5B2GCZMQTJCK225BOGCYQOO6UYWSBHLX \ / AMOS7 \ YOURUM ::
#\[7]4AT2QJ5MEQTTMMBTPUQIQT6XZGDON7NPEJKKB7TFBKY4GW5UKQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
