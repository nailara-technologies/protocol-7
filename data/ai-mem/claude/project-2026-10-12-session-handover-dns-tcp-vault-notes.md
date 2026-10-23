---
name: project-2026-10-12-session-handover-dns-tcp-vault-notes
description: START HERE -- session 2026-10-11..12 handover [ last ead77ab8d, v9993+ ] : dns over tcp live on all 3 name servers, letsencr propagation check, pm-src vendored + :keep: signing, editor paste fix, p7-vault notes \ codes \ sync ; next : user tests, then Y7O -> B2K -> HS4 after the weekly reset
metadata:
  type: project
---

session 2026-10-11..12, ended near the weekly limits [ claude 90 %,
kimi 92 % ]. follows [[servers-dns01-host-config-2026-10-11]].

## landed [ all committed + pushed to hub base ]

- `1e2cc08f5` pm-src : Digest::BMW, Crypt::Ed25519, Canary::Stability
  vendored [ unmodified cpan, sha256 checked ] + bin/dev/cloud-session-setup
  builds them when cpan is blocked. NEW signing syntax in
  src/sourcecode.source_path_set_up : `!<path>:keep:.pm.pl` = exclude
  the path except those suffixes [ collect_file_list + pre-commit hook ].
  only the perl files of others' work are signed.
- `dba7cf12e` cloud-session-setup : File::Which, Event, CryptX via apt
  [ p7-deps could not start in the cloud ]. untested : next cloud
  session runs `bin/p7-deps list` [ there is no `verify` ].
- `6759f7362` letsencr : dns-01 propagation asks every address of
  letsencr.dns.alias_ns [ resolved once per order ], non-answering
  servers skipped, an answering one without the value blocks.
  query_txt_async takes ipv6. NOT yet seen live : next dns-01 renewal on
  srv-U should log 'txt value on N servers'. letsencr is on-demand there.
- `67fc9f568` nameserv : dns over tcp [ rfc 7766, nameserv.answer shared,
  dns_tcp.* handlers, 77 conns \ 13 s idle \ 64k in \ 4 replies out ] +
  udp replies truncated with tc. LIVE on srv-U \ srv-V \ srv-A, v4 + v6.
  srv-U : ufw 53/tcp opened. tcp binds only in init [ port 53 before
  drop_privs ] -> deploy = nameserv RESTART, not reload.
- srv-A : systemd-resolved held 127.0.0.53\54:53 tcp [ blocks the
  wildcard bind ] -> static /etc/resolv.conf [ provider resolvers, old
  copy in /root ], resolved stopped AND masked [ its monitor socket
  re-activated it after disable --now ]. srv-A also lost ipv6 after its
  02:32 reboot [ /etc/hostname change + dist-upgrade only ] ; a second
  reboot fixed it, provider panel address unchanged [ KUL closed ].
- `0e73d9431` AMOS7::TERM::Editor : editor out of bin/todo, bracketed
  paste, crlf = one enter, ctrl-d de-interlace. the WSL paste bug was
  icrnl [ [[readkey-raw-mode-leaves-icrnl]] ] -- user confirmed fixed.
  bin/todo : timelocal instead of timelocal_posix [ floor perl 5.32 ].
- `ead77ab8d` p7-vault : note bodies in the editor [ -s = old hidden
  prompt ], 'scratchpad' default title + command, `notes` overview,
  3-char codes inside the record [ `codes` backfills ], `sync
  <host>[:<dir>]` = entry file union over ssh [ P7_VAULT_SSH, key files
  never travel, symlinks + unvalidated names refused ].
  test-vault-sync.pl 13, test-vault.pl 78.

## waiting on the user

- try p7-vault scratchpad \ codes \ a first sync to a server copy [ copy
  vault.key.B32 there once by hand ].
- point the hysteria client at srv-U [ unlimited traffic ] instead of srv-F
  [ 1 TB limit ] -- no code needed.
- cloud credit [ $94 of $100, expires 2026-11-05 ] : cloud sessions
  draw the PLAN, not the credit [ seen twice ]. plan : ignore it until
  the weekly limit is hit, then test ; nothing works -> support. see
  [[reference-claude-web-promotion-credits-overflow]].

## next, after the weekly reset [ design first, in this order ]

- Y7O : vault file import \ export [ keyed-checksum blob store, chunked
  aead streaming, union sync ] ; later zenki read the vault through an
  agent with grants, protocol-7-menu approvals as resolvable
  dependencies, code signing through the agent [ key never leaves it ].
- B2K : generic bidirectional STRM channel [ used by HS4 and menu <->
  vault agent ].
- HS4 : proxy -> external link tunnel replacing hysteria [ exit
  permissions, backpressure, C25519 session keys with resumption cache
  reusing host-root pinning, leaf '.proxy-exit', path vs exit
  parallelism with automatic pinning ].
- 4ZW : nameserv[cache] \ nameserv[cache-local] forwarding cache,
  loopback only, later dns over protocol-7 [ udt underneath ].
- smaller : 4CJ expansion [ dns-01 from any host ], VDS parent delegation
  check, srv-V's ipv6 ptr, ns ttl 93600.

## process notes from this session

- kimi hits its 100-step limit near the end of most dispatches :
  `kimi_continue` with 'finish only steps x-y + report' is cheap.
- the user's signing run stages EVERY modified signed file, incl.
  kimi's work in progress -> check `git status` and unstage unreviewed
  files before committing [ the sign tool checks on-disk changes, so no
  edits get lost ]. a new signed file is sometimes NOT staged : add it.
- `p7c v7-zenki.restart <zenka>` on servers runs as root ; srv-U's checkout
  is /usr/local/protocol-7 [ root-owned, pull with
  bin/admin/p7-git-pull--rebase as root ].

#,,,,,,.,,...,,,,,...,,,,,,,.,,,.,.,,,,..,,.,,..,,...,...,..,,,,,,..,,.,,,,,,,
#3BWW66VK76AYK5L365XFYD4RDRRYEFALX77GQU5BHX3RNNIVBET6RKVREEN4FYKXTNR3SHX3NPF24
#\\\|NFO37RSUEDWVUTQBCMPBTVBXGVYSGQYMTBMJMOHFYBDGRYCIN43 \ / AMOS7 \ YOURUM ::
#\[7]2HTZPDNNDRFNT2YNZQSPGQAVDHMGXVO4GWTU7JWFXDDRCFWRBSAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
