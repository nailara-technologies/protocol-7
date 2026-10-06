---
name: project-2026-10-06-session-handover-security-sweep
description: handover of the 2026-10-04 -> 06 session [ last a35a0ae62, release AMOS7-v6.13.5 ] -- osf-cache stages 3 \ 4 \ 4b live incl. holders behind encrypted external links ; security : link-upgrade nonce reuse, fail-open frame writer, PRNG seeded without OS entropy -- all fixed ; v7-zenki liveness sweep ; host-root replaces the old shared key ; trust chain = design only
metadata:
  type: project
---

session 2026-10-04 evening -> 2026-10-06, last commit `a35a0ae62`, release
**AMOS7-v6.13.5** [ tag on `1282c3cd6`, source 3XYPZNFNJI-9777.0, pushed ].
previous handover : [[project-2026-10-04-session-handover-osf-cache-stage2]].

## landed

- **osf-cache stage 3** [ `16e32691c` ] : segment serving + fetch + verify
  [ kimi k2.8 ; review added a request `seq` against late replies ] ; live
  needed the `segment` grant on the CUBE user line [ `512c58752` ]
- lookup answers known anchors, lists unknown ones ; nothing known -> false
  [ `30636818e` ]
- **stage 4** [ `1c15c65d9`, kimi k3 ] : binary merkle tree [ 64 KiB leaves,
  bmw384, \x00 \ \x01 prefixes, odd promoted ], root agreement [ all asked
  agree, quorum //= 5/7 ], parallel multi-source fetch, bad holder excluded ;
  live via `osf-cache[peer2]` ; apt archive names with epoch `%3a`
  [ `ee2d3623d` ], fetched files 0644 [ `4cf66d582` ]
- **stage 4b** [ `ac117a6dd`, kimi k2.8 ] : holders as route prefixes
  [ `<sid>` \ `external.<link>.<sid>` ], `osf-cache.cfg.remote_links`,
  live : 4 holders [ 2 local + 2 via `external.self` ], 12 segments, 0.7 s
- **external links** [ `201605f07`, `c26bfb171` ] : real Perl client
  handshake [ replaced a stub ], `external.connect <name> <host[:port]>`
  -> encrypted session registered under the name -> `external.<name>.<zenka>.<cmd>`
- **security** :
  - link-upgrade reused key + nonce across directions -> direction word in
    the nonce, `link_role` [ `deb4431db` ] -- [[project-2026-10-05-link-upgrade-nonce-reuse-fixed]]
  - frame writer FAILED OPEN [ plaintext on cipher failure ] -> fails
    closed [ `a35a0ae62`, found by kimi's test task ]
  - `base.prng` seeded only from PID + ms time [ CryptX `new($seed)` uses
    no OS entropy ] -> OS-seeded fortuna + BMW-512 pool added + continuous
    `add_entropy` [ `ead1c649e`, `1c77e322f` ] -- [[project-2026-10-06-prng-seeded-without-os-entropy]]
  - `v7-zenki.restart` \ `terminate` refuse any unknown name [ `083ca776f` ]
- **v7-zenki liveness sweep** [ `fa550b716` ] : dead tracked pids fed
  through SIGCHLD, child entry restored ; live : no false positives
- **host-root** [ `25a60f33b` ] : random per-host root created by
  v7-zenki's first start ; the older shared-key path purged entirely
- tests : `test-prng-entropy.pl` [ 13 ], `test-v7-liveness-sweep.pl`
  [ 24 ], `test-link-upgrade-client.pl` [ 35 ], osf-cache harness [ 228+ ]

## next steps

1. **host-root check** at the next v7-zenki start [ atom ; pri after its
   code update ] : `host-root.*` appears in /home/protocol-7/.n/user-keys/,
   public key random per host
2. discard + regenerate the `.base` placeholder keys [ made with the weak
   seed ; nothing uses them ]
3. **trust chain** [ [[vision-2026-10-05-generic-trust-chain]] ] -- design
   only ; first build step : server proof in link-upgrade [ cube signs the
   exchange with its host key ], which unblocks a REAL second host for
   external links \ osf-cache [ today : own nodes \ localhost only ]
4. 63K vs 64K leaf size : waits for the user's re-derivation of the 63 \ 64
   logic [ 1K header idea = 64512 payload ] -- osf-cache keeps 65536
5. use **pri** [ ~10 GB more RAM ] once updated to current code
6. osf-cache stage 5 [ credits ] later ; routing-as-search later

## live facts

- the `self` loopback link uses the TEST identity `test-auth-keypair`
  [ cube access.users : link-upgrade list + osf-cache has \ merkle \
  segment ] ; external's grants `self.*` + `self.*.has|merkle|segment`
- access grants : `*` matches ONE dotted segment, `**` any depth
  [ base.parser.access_conf ]
- peer calls routed via cube arrive as user `cube`
- `osf-cache[peer]` + `[peer2]` instances use `/var/protocol-7/osf-cache/
  peer-archives` \ `peer2-archives` [ manually started, not always-on ]
- link session keys are named after the link [ `self` ] in the protocol-7
  key dir -- consider a `link-` prefix [ suggested, not done ]

## workflow lessons

- [[feedback-never-feed-command-substitution-into-destructive-cmds]] : an
  error text in `$( )` restarted cube and killed invoke ; recurrence plan
  for dead pids listed online is in that file
- [[feedback-release-version-tag-explicit]] : release flow + explicit tag
- k3 took kimi's 5h window 18% -> 100% on stage 4 ; k2.8 is the default
- after a kimi job : run its tests yourself, check `git status` scope,
  regenerate the zenka whitelist if it did not
- kimi's test tasks find real bugs [ the fail-open writer ] -- worth
  dispatching test-only tasks for code verified only live

#,,,.,..,,,..,,.,,.,.,,..,..,,.,.,,,,,..,,..,,..,,...,...,,..,,..,.,,,,,.,.,.,
#EDRPFO32PKHOGRDSW57NSRQIWHTMMEGD2RLVMWA644EA7Z2LBBDQI2RV7GYQLSVAV37EV4ZIHKPWM
#\\\|AWKGGYASRDQQEYNL25KLRW3UEDRGZ7AJPMK4XM23HGIXWCE3QX5 \ / AMOS7 \ YOURUM ::
#\[7]2K5KUN5U2LYVPDK5VKX3UWEKNWBY7ZSHVHN3CLYS76WMUPQUWODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
