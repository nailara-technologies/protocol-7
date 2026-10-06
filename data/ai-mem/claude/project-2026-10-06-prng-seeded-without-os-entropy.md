---
name: project-2026-10-06-prng-seeded-without-os-entropy
description: base.prng.reseed seeds Crypt::PRNG::Fortuna ONLY from PID + ms time + perl rand [ itself srand(PID+time) ] -- CryptX uses no OS entropy when a seed is given [ verified ], nothing adds any later -> every base.prng draw [ gen_keys secrets, chars-anum incl. cube.key ] is bounded by a ~2^20-2^30 guessable seed ; FIXED same day : BMW-512 pool of OS entropy + optional machine data, truth-filtered [ harmonic kept ], long-term keys mix /dev/random
metadata:
  type: project
---

**found 2026-10-06** while answering the user's question about machine
entropy for embedded systems that boot with identical entropy.

## the defect [ verified ]

- `src/base.prng.reseed` : `srand( $PID + ntime )`, then a "harmonic" seed
  from `base.ntime(13)` [ ms ] + `rand(142857)`, then
  `Crypt::PRNG::Fortuna->new($harmonic_seed)`
- CryptX : `Fortuna->new($seed)` uses ONLY that seed, no /dev/urandom --
  verified : two instances with the same seed give identical bytes ;
  `->new` without a seed is OS-seeded. `add_entropy` is used nowhere
- -> the whole `base.prng` stream is a deterministic function of PID + ms
  time. a key file's mtime [ ns, visible to anyone who can list the dir ]
  narrows the time -> roughly 2^20 - 2^30 candidates : minutes to hours
- `base.fork` reseeds children the same way
- consumers : `crypt.C25519.gen_keys` [ ALL generated C25519 secrets ],
  `base.prng.chars-anum` [ 136 call sites, incl. `cube.key`, the v7-zenki
  <-> cube session secret ], `base.shm.write`, `httpd.handler.shm_write`,
  `crypt.C25519.compare_keypair`
- NOT affected : link-upgrade ephemeral keys, nonce sid and the Perl client
  handshake use `Crypt::Misc::random_bytes` [ CryptX default, OS-seeded ]

## impact [ user, 2026-10-06 ]

- `.base` keys : placeholders, nothing uses them -> discard + regenerate
- the sourcecode key was made from file entropy + a long passphrase and is
  stored encrypted under another passphrase -> NOT affected
- `host-root` did not exist yet anywhere -> must be created only after the
  fix
- user's thought that runtime keys drawn "after many gen_id calls" count as
  seeded : NO -- draws add no entropy ; the attacker replays the stream from
  the brute-forced seed and tests every position [ the unknown call count
  adds only ~log2(count) bits ]

## fix [ done 2026-10-06, user's go ; uncommitted until signed ]

1. `base.prng.entropy_pool` [ new ] : BMW-512 [ user's choice, not SHA ]
   over OS entropy [ Crypt::Misc::random_bytes + /dev/urandom read
   directly, either one suffices ] + machine data + PID + hi-res time +
   the harmonic seed. EVERY machine source optional [ eval, skipped when
   missing -- user : "resilient against machine specific parts being
   missing" ] : boot_id, machine-id [ two paths ], devicetree serial,
   cpuinfo Serial, interface MACs, hostname. sets <base.prng.os_entropy> ;
   no OS entropy -> level-0 warning, never fails
2. HARMONIC kept [ user : "filter the seed by a truth assertion ... just
   change the source" ] : the digest is rehashed with a counter until
   AMOS7::Assert::Truth holds [ bounded 1300 rounds ; costs ~log2(1/p) of
   512 bits ]
3. `base.prng.reseed` seeds Fortuna from the pool [ also covers
   base.fork's child reseed ]
4. `crypt.C25519.gen_keys` : every fresh secret [ incl. harmonic-loop
   re-draws ] = BMW-256 over the fortuna stream + 32 bytes from
   /dev/random [ waits for the kernel CRNG, select-bounded 30 s, falls
   back logged -- never hangs ]
5. test : `bin/test-scripts/test-prng-entropy.pl` [ 8 checks : size,
   per-call difference, harmonic, os flag, no warnings with missing
   sources, same PID + time -> different streams, bare-seed reference ]
- after landing : discard + regenerate the `.base` placeholders ;
  host-root gets created by the fixed code on the next v7-zenki start
- gotcha in my own test : AMOS7::Assert::Truth::is_true returns a LIST in
  list context -> wrap in scalar() inside ok( .. )

related : [[project-2026-10-05-link-upgrade-nonce-reuse-fixed]],
[[vision-2026-10-05-generic-trust-chain]]

#,,,.,.,.,.,.,,.,,..,,..,,,,,,,,.,.,.,,..,,.,,..,,...,...,,,,,,..,,.,,.,.,,,.,
#EC5CWEFDVDCZP6QYIGAX7OJ74AOZHEIYHJQX5HCIBUTAMOH5JT2HTQ3MQADEJF4N2OP3QHSDGCVFA
#\\\|56LZTVBIHBRLT5KGQZR2FSBBKHNVNNOKHBBVBMIKTRXTMQ7B6VK \ / AMOS7 \ YOURUM ::
#\[7]BWDB26IV37OJNETFHTDSNE54LDNQGHMUP736ZG7INNZANHO5ZEAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
