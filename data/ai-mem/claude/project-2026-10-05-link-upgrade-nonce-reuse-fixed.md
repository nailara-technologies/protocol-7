---
name: project-2026-10-05-link-upgrade-nonce-reuse-fixed
description: link-upgrade ChaCha20-Poly1305 reused key + nonce across the two directions [ one key, counters both from 0, all-zero nonce suffix ] -- fixed 2026-10-05 with a direction word in the nonce, role-based [ link_role ], fail-closed ; old p-7-r binaries no longer interoperate
metadata:
  type: project
---

**found 2026-10-05** while evaluating p-7-r links as the cross-host
transport for osf-cache [ [[project-2026-10-04-session-handover-osf-cache-stage2]] ].

## the bug

- one key per session : `SHA256( dh_shared_secret . pack('N', nonce_sid) )`
  for BOTH directions
- nonce : `pack('N', nonce_sid) . pack('N', counter) . "\0" x 4`, separate
  read \ write counters both starting at 0
- -> the client's frame k and the server's frame k were encrypted under
  the identical key + nonce : chacha20 keystream reuse [ XOR of the two
  ciphertexts = XOR of the plaintexts ] and poly1305 one-time-key reuse
  [ forgery ]. every session, every frame index ; protocol traffic is
  highly predictable -> practical, not theoretical
- present in all three implementations : `protocol.protocol-7.encryption.init`
  [ inline writer ], `base.handler.link-upgrade.input` \ `.output`, and
  `bin/p7-link-upgrade-helper.pl` [ used by `bin/c_src/p-7-r.c` ]

## the fix

- nonce suffix = `pack('N', direction)`, 1 = client -> server, 2 = server
  -> client ; each end writes with its own, reads with the peer's
- direction comes from `$session->{'link_role'}` : the end that ANSWERS
  the upgrade sets `server` in `protocol.protocol-7.link-upgrade.init` ; a
  future Perl client handshake must set `client`. encryption.init REFUSES
  without a role, the frame handlers shut the session down without a
  direction -- never a fallback to the zero suffix
- helper encrypt \ decrypt take a required `<direction>` [ 1|2 ] ;
  p-7-r encrypts with 1, decrypts with 2

## gotcha hit while fixing

first attempt keyed the direction on `$session->{'mode'} eq 'server'` --
WRONG : accepted tcp sessions have handle mode `input` [ io.ip.tcp.input.connect ],
so the server picked the client direction and every link broke. session \
handle modes say nothing about link-upgrade roles ; use `link_role`.

## verified live [ localhost, cube reloaded via `reload source` ]

- new p-7-r : link negotiated, `list sessions`, a full 64 KiB osf-cache
  segment intact
- same key \ session \ counter, direction 1 vs 2 -> different ciphertexts
- old p-7-r + old helper [ zero suffix ] -> fails closed [ cube cannot
  authenticate its frames ]
- the installed `/usr/local/bin/p-7-r` is stale until v7-zenki recompiles
  it [ install_bin_p7r on v7-zenki start ]

**How to apply:** any new link-upgrade client [ e.g. the osf-cache
cross-host session layer ] must set `link_role = client` before state 3,
and must never reuse one counter space for both directions.

## follow-up 2026-10-06 : fail-open frame writer fixed

found by kimi's test task [ `bin/test-scripts/test-link-upgrade-client.pl`,
reported, not fixed by it ] : the inline writer `encryption.init` installs
[ `base.handler.link-upgrade.frame-<id>` ] returned the PLAINTEXT payload
when the session was gone, no key was set, the cipher could not be created
or encryption failed -- sent in clear on a link both ends believe
encrypted. now FAIL CLOSED like `base.handler.link-upgrade.output` : warn
[ format + args ], set the session's shutdown flag, send nothing. also
`Crypt::AuthEnc::ChaCha20Poly1305->new` CROAKS on an invalid key [ not
undef ] -> wrapped in eval. regression checks : no key \ invalid key ->
'' + shutdown + one complaint. live : encrypted p-7-r list + 64 KiB
segment fine after cube `reload source`.

second finding, NOT acted on [ latent ] : 39 src modules call
`bytes::length` but nothing in src/ loads the `bytes` pragma -- production
works only through a transitive load [ bin/Protocol-7 : use utf8 \ Encode ] ;
tests must `use bytes` themselves. would break if that transitive load
ever went away.

#,,.,,,.,,...,,.,,...,,..,,,.,,,,,..,,.,.,..,,..,,...,...,.,.,,,.,...,...,,,.,
#4PWFIJF52WK6VI76TAPCVNRSNGABA3N7FW77S4IPJV7ALHDGJZBUMBGBSTPYIJPNKRCX63XHW5XVK
#\\\|5RUFNBUWI7QLY3QHVIY2XBSIJKNLHGFMMNKGT6KTQM654BAPLGF \ / AMOS7 \ YOURUM ::
#\[7]RQES3QMOATRS4GJZFTAGBCDTG2PKIPSZRSO2KP4ATSLFK4ACT4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
