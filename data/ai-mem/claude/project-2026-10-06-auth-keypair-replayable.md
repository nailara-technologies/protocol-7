---
name: project-2026-10-06-auth-keypair-replayable
description: FIXED 2026-10-06 [ ad31ddd5a, not yet live-checked ] : auth-keypair's client line `auth <user> <session_pub> <sig>` signs ONLY the client's own stable session pubkey -- no server nonce, sent plaintext before link-upgrade -> one observed line replays forever from any IP ; nothing later proves possession ; same raw-pubkey message as sign_keys' .sig files [ no domain separation ]. fix = mutual binding, folded into the link-upgrade server proof
metadata:
  type: project
---

found while designing the link-upgrade server proof [ trust chain step 1,
[[vision-2026-10-05-generic-trust-chain]] ].

**verified** [ read, not run ] :
- `auth.client.auth-keypair.authenticate` : `sign_data( \$session_pubkey_bin,
  <user>.base )` -- the message is the 32-byte session pubkey alone ; that
  key is disk-persisted and never regenerated [ on purpose, TOFU pins it ]
  -> the whole line is a constant credential
- `plugin.auth.auth-keypair` verifies only that signature ; no challenge.
  `$keys{'auth'}{'c25519-session'}{$id}` is stored and READ NOWHERE
  [ grep src + bin ] -> no later proof of possession
- `validate-incoming-tofu` : pin keyed `incoming/<user>.<host>_<port>.public`
  else `incoming/<user>.public` -- the client port is ephemeral, so the
  username-only pin decides -> a replay from any IP passes ; unix sockets
  skip TOFU [ kernel peer creds cover them ]
- a replayer gets authenticated state 1 and can then run link-upgrade
  itself [ ephemeral, unauthenticated DH ]
- `crypt.C25519.sign_keys` writes `.sig.*` = Ed25519 over a raw 32-byte
  public key -> structurally a valid auth signature too [ cross-protocol ;
  its post_init call is commented out today ]

**exposure today** : TCP links are localhost \ own nodes only [ external
`self` ] -> low ; it BLOCKS the real second host.

**landed 2026-10-06** : `ad31ddd5a` [ + `8a50cf992` gen_keys supplied
secret kept, `bcca789e1` spec + tests ]. lanes found + fixed on the way :
p-7-r popen shell injection from server replies, plaintext frame temp
files, p7c's half-built link-upgrade [ removed ]. NOT yet live-checked :
cube restart \ reload plugins + source, rebuild p7c \ p-7-r, re-open
external.self, first connections re-pin under `servers/` ; then a kimi
test-only task against the live wire.

**decided 2026-10-06** [ user ] : folded into the link-upgrade server
proof as ONE wire change, NO backwards compatibility. spec :
`data/md/design/AUTH-LINK-BINDING.md` [ incl. a live MITM that RELAYS the
nonce-bound auth -> auth-keypair sessions stay 'pending' until a client
sig over the link-upgrade transcript verifies ; shared test vector ].
lanes : `data/tasks/archive/auth-link-binding-perl.md` \ `-c.md`.
also found : `bin/p7-link-upgrade-helper.pl` takes the ephemeral secret
\ shared secret on ARGV [ /proc/<pid>/cmdline, world-readable without
  hidepid ] -- user 2026-10-06 : fix in the SAME change [ secrets via
  stdin, lane C ].

**fix shape** [ original proposal ] :
- select reply `TRUE <server_pub> <server_nonce>`
- client signs a LABELLED message : `"p7 auth-keypair v1" \ nonce \
  server_pub \ session_pub \ username`
- server proof in link-upgrade signs nonce + both ephemeral pubkeys +
  nonce_sid -> a relaying MITM cannot finish either side
- client-side pin store, fail-closed [ external.link.open checks nothing ;
  TODO in auth.client.auth-keypair.authenticate ]
- clients to change together : auth.client.auth-keypair.authenticate
  [ external.link.open, users.remote_fetch.run, users.cmd.remote-* ],
  bin/p7-auth-keypair-helper.pl, p-7-r, link-upgrade helper -- grep again
  before scoping [ [[feedback-security-fix-verify-both-code-paths-not-just-symptom]] ]

#,,,,,..,,,.,,..,,,,.,...,.,,,.,.,...,,..,..,,..,,...,...,.,,,,,.,...,.,,,,.,,
#LZOE3BDOLNAI5QYSUIC7O3LOE75DLHL2KS4TOOLXHQFRMJVPOIM4PMUPIVUSN6PUFF56ABLO4U7GO
#\\\|SISX4Z5NFLWETYCSCC6QTVR52A6DYEW2FPVGFGXVFBR5R3S3FCY \ / AMOS7 \ YOURUM ::
#\[7]KAHXJX76ZATHLLU2OHK7JJ56SKD45VF2ICPLCV2AHKHJIKTE2KAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
