---
name: servers-dns01-host-config-2026-10-11
description: 2026-10-11 session : three servers, dns-01 live via delegated acme subzones, per-host config overlay, start conditions + profiles, orbital lazy start, teardown restart semantics ; layered config landed ; zone sync design 4CJ
metadata:
  type: project
---

**Servers** [ no addresses here ] : new server 1 [ 8 vcpu avx2, 23 GiB, 441 GB after growpart + online resize2fs, debian 12, systemd 252 -- see [[keep-new-server-1]] ], new server 2 [ 6 vcpu, 12 GB, 12-month contract ], delta [ 3rd provider, 1 vcpu xeon avx-512 \ vnni, 2 GB, kvm, debian 13 \ systemd 257, ipv4 only, rdns delta.protocol-7.network ]. cpu inference on server 1 : fablevibes q4_k_m 56 prompt \ 9 gen t/s [ bin/build-scripts/llama-cpp/build-llama-server-cpu.sh, models in /data/models via base.models_root ]. deploy without manual edits : `p7c v7-zenki.start pull-git` on the host [ taeki has no git \ log access there ; read zenka logs via `p7c <zenka>.show-buffer zenka` ].

**dns-01 LIVE** for protocol-7.network, v7.ax and the private domain [ never name it in the tree ] : registrar zone carries acme.<domain> NS dn0000.. + _acme-challenge.<domain> CNAME _acme-challenge.acme.<domain> ; our nameserv answers ; letsencr host.cfg : challenge.type dns-01, provider nameserv, challenge_alias_prefix acme, alias_ns. nameserv.cmd.ensure-zone creates acme.* subzones [ prefix-restricted, add-txt still never creates zones ]. gotchas found : letsencr child only loads letsencr.child.* [ letsencr.dns.* inwx \ cloudflare never ran there ], on_authz read only prefer_dns01 [ challenge.type now honored ], cube access.zenki needed the ensure-zone grant. name servers decided : DN0000 [ + DN0000.v7.ax ] server 1, DN0110 server 2, DN1110 delta [ harmony beats numbering ]. next : wildcard via request-certificate extra names.

**Host config** : `[load_host_config]` in a zenka.v7 reads /etc/protocol-7/<zenka>/host.cfg [ creates the dir as root ; nameserv, letsencr, v7-zenki use it ]. nameserv default one dual-stack socket :: with ipv4 fallback like httpd. start conditions `dependencies = cube unix_group.httpsd` [ v7-zenki.callback.object.unix_user \ unix_group, re-check timer while unmet ]. zenki.disabled now blocks automatic starts [ on-demand, dependency ; manual v7-zenki.start allowed ] ; zenki.on-demand = allow list ; profile start-set-up.remote-server-lowram. web space plugin subscribes to orbital producers only on first orbital-json request [ every host ran discover \ nodes \ external \ graphics-matrix before ].

**Unit** data/lib-path/systemd/system/Protocol-7.service host-neutral [ /usr/local/protocol-7, dev checkout linked there, desktop env in /etc/default/protocol-7, no network-online ] ; Restart=always [ teardown = restart, as before ] + `teardown :no-restart:` = exit 76 [ RestartPreventExitStatus ] + backoff. see [[changed-established-behavior-silently]].

**Layered config LANDED** [ 110723d8c ] : cfg/ defaults < /var/protocol-7/host/detected.cfg [ base.host.detect : mem_mb, cpus, ipv6 ; written once ] < /etc/protocol-7/<zenka>/host.cfg [ decisions ]. v7-zenki picks start-set-up.<profile>-lowram when host.mem_mb < v7-zenki.cfg.lowram_mb [ 3072 ]. delta still selects lowram through its local-modifications commit -- next : `load.start_setup = remote-server` in its v7-zenki host.cfg, drop the local change, look for the 'start profile remote-server -> remote-server-lowram' log line.

**Late 2026-10-11** : delta ipv6 [ slaac, AAAA set in both zones, ptr = SERVFAIL -> ask the provider, ask for a static v6 ] ; nameserv on delta answers over v6 [ REFUSED, holds no zones yet ]. TTLs : user wants 3900 [ 13 x 5 min, see [[harmonic-values-not-decimal-round]] ] -> nameserv.cfg.default_ttl [ 12e4b4a3b ]. nameserv console verbosity 2 dumped parsed config on every reload [ e66e320fd ]. crypt.C25519.chk_key_dir never created a non-root user's key dir [ `key_dir/..` does not resolve while key_dir is missing ; 94c112ffa, live on delta ]. REFUSED no longer sets aa [ e88c1499b ].

**Zone sync** : instead of axfr -> todo 4CJ, design data/md/design/TIMESTAMP-DELTA-SYNC.md [ signed entries not a secured channel, writer grants per key, last-data-timestamp \ next-data-timestamp \ since \ full, signed state checksum ]. stage 1 [ timestamps + tombstones + checksum ] and 2 [ tcp lines ] = kimi k2.8 AFTER the user has read the doc ; stage 3 [ signing \ grants \ accept rules ] = claude. delta as DN1110 also needs registrar A\AAAA + glue and the acme NS sets.

**Open** : wildcard cert [ request-certificate extra names ], delta port 25 + narrow ufw, new unit on pri.v7.ax + other hosts, old host `zenki.disabled = nameserv`, 7WR socket paths, rename the wsl host at session end, p7-git-pull--rebase vs identical untracked files, path \ port \ mount condition types.

#,,,.,,..,,,,,...,...,..,,.,.,.,.,,,.,,,.,,.,,..,,...,...,.,.,,.,,,,.,.,,,,..,
#JZUKOH6VQY4734AHWWGNRABCAILPX4TWY3FWAJ4NIU3LDM72QJSCNFY5RPWZ5UVD36ASRU46LS2PQ
#\\\|DZCGSCSJO57MF4YBAW7JLQ7H7VVUMHUYEB7NWVU2YFP2HCQ457F \ / AMOS7 \ YOURUM ::
#\[7]GJDHHNLAOAT5Y5XUIEV2JJGS4KCXDWMMUMFAFPOGUNB7JXOVMACI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
