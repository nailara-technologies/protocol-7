# sha → protocol-7 checksums : transition plan

owner 2026-11-14 : sha is avoided in protocol-7 ; it stays only where an external source
defines the value [ git ids, acme, openssh, debian, huggingface ]. everything internal
moves to the project's own checksums [ BMW384 via Digest::BMW \ AMOS7::CHKSUM, b32 names ].
each use is contained per instance, so the moves are independent.

## stays : external requirement

| where | what | why it stays |
|---|---|---|
| data/lib-path/pm/AMOS7/Vault.pm:1363 git_blob_id | sha-1 of `blob <len>\0..` | git's own blob id |
| bin/p7-vault:3340 text_sha1 \ cmd_history | sha-1 hex | git history lookup [ verify : only git ids ] |
| src/letsencr.base.pre_init, src/letsencr.child.init_code | sha256 | acme jwk thumbprint, rfc 7638 \ 8555 |
| bin/dev/acme-mock-server.pl | sha256 | mock of the acme side |
| src/hints.known_hosts | hmac-sha1 | openssh hashed known_hosts format |
| src/osf-cache.debian.read_packages, osf-cache.fetch.complete, osf-cache.holdings.scan_file | sha256 \ sha512 | debian Packages checksums |
| src/fetch.file.huggingface.verify.start | sha256 | huggingface lfs object ids [ verify it hashes there ] |

## moves : internal use

| where | what | plan | risk |
|---|---|---|---|
| src/protocol.protocol-7.encryption.init, bin/p7-link-upgrade-helper.pl [ + C client bin/c_src/p-7-r.c ] | sha256 kdf of the dh secret for link-upgrade | a labelled BMW384-based kdf [ or HKDF over BMW ] as link-upgrade wire v-next ; both ends, version negotiated, old form refused after the switch | HIGH : protocol, both ends, C client ; design + review [ fable candidate ] |
| src/models.storage.init, .move_model, .tier_management | sha384_hex | BMW384 b32 ; existing ids need a mapping or rescan | medium : stored ids |
| data/lib-path/pm/AMOS7/INLINE.pm:413 | sha256 of the source as cache key | BMW384 ; old caches rebuild once | low |
| bin/p7-sort | sha256 file sums for duplicates | BMW384 | low |
| bin/nshell:683 | sha256 [ check the use ] | BMW384 or remove | low |
| src/plugin.web.space.orbital.synthetic-zenka-node | sha256 node id | BMW-derived id ; check stored ids | low |
| src/forensics.event.rule-synthesis, src/forensics.handler.rule-proposal | sha1 rule ids | BMW ; stored rule ids need mapping | low \ medium |
| bin/dev/src-review-one, bin/dev/worklist-iterate | sha1 ids | BMW | low |
| p7-sign agent | [ owner report : uses sha -- locate ; ncode found none by name, check the chain bin/dev/p7-sign-run \ update-signatures ] | BMW | check first |

## order

1. locate the sign agent use ; confirm the two `verify` rows above.
2. low-risk tools in one batch [ p7-sort, INLINE, nshell, dev tools ] -- kimi K3.1 with review.
3. stored-id users [ models.storage, forensics, orbital ] : a one-time mapping \ rescan each.
4. link-upgrade kdf : design stage first, wire version, both ends incl. p-7-r.c.
5. a guard : bin/format-code -c \ a test warns on new `Digest::SHA` \ `sha*sum` outside the
   'stays' list. kimi added sha256sum to n7fs on 2026-11-14 [ removed before deploy ].

#,,,,,,,.,.,.,,,.,,,,,,,,,,,,,..,,..,,...,,,,,..,,...,...,.,,,,,,,.,,,,.,,..,,
#NJGOXAY27MVODPF5GEELBREMFU7YKSILB4HWMOP5NBSWEQT6OCMR65SC3SIXZOUUGQKEGGLFY3OFW
#\\\|OWCGWMSLXCJO2Z67PB4F23YSYGI5G376JKB3IKQCDRFDQ35QBSF \ / AMOS7 \ YOURUM ::
#\[7]WZVSVZUPGQZX2HK7Y47AR3JENGTHP5DSLOGNK22ZB62CV37C3GBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
