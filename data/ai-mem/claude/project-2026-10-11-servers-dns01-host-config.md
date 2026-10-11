---
name: servers-dns01-host-config-2026-10-11
description: 2026-10-11 session : three servers, dns-01 live via delegated acme subzones, per-host config overlay, start conditions + profiles, orbital lazy start, teardown restart semantics ; next = layered config with auto-detection
metadata:
  type: project
---

**Servers** [ no addresses here ] : new server 1 [ 8 vcpu avx2, 23 GiB, 441 GB after growpart + online resize2fs, debian 12, systemd 252 -- see [[keep-new-server-1]] ], new server 2 [ 6 vcpu, 12 GB, 12-month contract ], delta [ 3rd provider, 1 vcpu xeon avx-512 \ vnni, 2 GB, kvm, debian 13 \ systemd 257, ipv4 only, rdns delta.protocol-7.network ]. cpu inference on server 1 : fablevibes q4_k_m 56 prompt \ 9 gen t/s [ bin/build-scripts/llama-cpp/build-llama-server-cpu.sh, models in /data/models via base.models_root ]. deploy without manual edits : `p7c v7-zenki.start pull-git` on the host [ taeki has no git \ log access there ; read zenka logs via `p7c <zenka>.show-buffer zenka` ].

**dns-01 LIVE** for protocol-7.network, v7.ax and the private domain [ never name it in the tree ] : registrar zone carries acme.<domain> NS dn0000.. + _acme-challenge.<domain> CNAME _acme-challenge.acme.<domain> ; our nameserv answers ; letsencr host.cfg : challenge.type dns-01, provider nameserv, challenge_alias_prefix acme, alias_ns. nameserv.cmd.ensure-zone creates acme.* subzones [ prefix-restricted, add-txt still never creates zones ]. gotchas found : letsencr child only loads letsencr.child.* [ letsencr.dns.* inwx \ cloudflare never ran there ], on_authz read only prefer_dns01 [ challenge.type now honored ], cube access.zenki needed the ensure-zone grant. name servers decided : DN0000 [ + DN0000.v7.ax ] server 1, DN0110 server 2, DN1110 delta [ harmony beats numbering ]. next : wildcard via request-certificate extra names.

**Host config** : `[load_host_config]` in a zenka.v7 reads /etc/protocol-7/<zenka>/host.cfg [ creates the dir as root ; nameserv, letsencr, v7-zenki use it ]. nameserv default one dual-stack socket :: with ipv4 fallback like httpd. start conditions `dependencies = cube unix_group.httpsd` [ v7-zenki.callback.object.unix_user \ unix_group, re-check timer while unmet ]. zenki.disabled now blocks automatic starts [ on-demand, dependency ; manual v7-zenki.start allowed ] ; zenki.on-demand = allow list ; profile start-set-up.remote-server-lowram. web space plugin subscribes to orbital producers only on first orbital-json request [ every host ran discover \ nodes \ external \ graphics-matrix before ].

**Unit** data/lib-path/systemd/system/Protocol-7.service host-neutral [ /usr/local/protocol-7, dev checkout linked there, desktop env in /etc/default/protocol-7, no network-online ] ; Restart=always [ teardown = restart, as before ] + `teardown :no-restart:` = exit 76 [ RestartPreventExitStatus ] + backoff. see [[changed-established-behavior-silently]].

**Next, agreed** : layered config -- cfg/ defaults < /var/protocol-7/v7-zenki/detected.cfg [ auto-detection, written, not recomputed ] < /etc/protocol-7/<zenka>/host.cfg [ decisions ] ; [load_config_file_if_present] ; origin logged per override ; interactive set-up only with a console ; local-modifications commits become obsolete. first : ram -> start profile. also open : wildcard cert, delta port 25 + DN1110 glue, 4EO N7FS design [ committed summary ], CT2 desktop reverse tunnel.

#,,..,,,,,..,,,,,,,,,,,,,,,..,,,,,,,,,,,.,,,.,..,,...,..,,,..,,..,,..,.,,,,.,,
#UBN2KOZWB7DRDA54Z7WN4S7AD6KL3M7RM6GMNZW55ZSYR56BHYCVD2D5ZPY2JCEVBDEU3KOYG5EVI
#\\\|F2LYOMF7QU4GZEMIZSVPFLR5J23ETYKGQX4ELT3WMNQBVJ3MQC7 \ / AMOS7 \ YOURUM ::
#\[7]ENXMRWUHQAYDZZVACRJ6UUXIO5DQOCQIEEOS3GNG7G4ASXDPLYCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
