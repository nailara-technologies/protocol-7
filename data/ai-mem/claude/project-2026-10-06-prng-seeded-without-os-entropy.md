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

## how it came about [ user, 2026-10-06 ]

- the harmonic seed was MEANT as ADDITIONAL seed entropy -- the author
  knew its bits alone were not enough
- CryptX only says "If $seed is omitted, the object is automatically
  seeded by the underlying Crypt::PRNG logic" -- it never states that a
  given seed REPLACES the automatic seeding. read next to perl's own
  srand \ rand semantics in the same module [ srand as the normal explicit
  step, rand self-seeding otherwise ], "seed given" reads naturally as
  "seed added". only the behaviour shows it [ the identical-output test ]
- lesson for any code seeding a CryptX PRNG : pass OS entropy IN the seed
  [ as base.prng.entropy_pool does ] or use the unseeded constructor ;
  verify with a same-seed test rather than the docs

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

## fix [ done 2026-10-06 : ead1c649e + the add_entropy restructure ]

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
3. `base.prng.reseed` [ restructured same day ] : the UNSEEDED
   constructor [ CryptX seeds it from the OS ] + `add_entropy( <pool> )`
   -- the pool is ADDED on top instead of replacing the OS seeding [ user :
   "that should have been used for reseeding, then there would have been
   no issue" ] ; also covers base.fork's child reseed
3b. continuous entropy [ what fortuna is built for ; the user had seen
   losing srand's reseed-at-any-time as a drawback when choosing fortuna ] :
   `base.prng.add_entropy <data>` adds fresh OS bytes + hi-res time + PID
   + the data, COMPLAINS [ base.s_warn + caller ] when the data is undef or
   '' [ user's wish ], still adds the OS bytes, never dies ; a timer in
   every zenka [ `base.prng.init_code`, $reinit-guarded, named handler
   `base.prng.handler.add_entropy`, `cfg.add_entropy_interval` //= 137 s,
   eval-armed ] ; gen_keys calls it before every fresh secret
4. `crypt.C25519.gen_keys` : every fresh secret [ incl. harmonic-loop
   re-draws ] = BMW-256 over the fortuna stream + 32 bytes from
   /dev/random [ waits for the kernel CRNG, select-bounded 30 s, falls
   back logged -- never hangs ]
5. test : `bin/test-scripts/test-prng-entropy.pl` [ 13 checks : pool size
   \ difference \ harmonic \ os flag \ no warnings with missing sources,
   same PID + time -> different streams, add_entropy TRUE \ FALSE \
   complaint \ additive, bare-seed reference ]
- after landing : discard + regenerate the `.base` placeholders ;
  host-root gets created by the fixed code on the next v7-zenki start
- gotcha in my own test : AMOS7::Assert::Truth::is_true returns a LIST in
  list context -> wrap in scalar() inside ok( .. )

related : [[project-2026-10-05-link-upgrade-nonce-reuse-fixed]],
[[vision-2026-10-05-generic-trust-chain]]

#,,,.,,.,,,.,,,,,,,,,,,.,,,,.,,,.,.,.,.,,,...,..,,...,...,,,.,.,.,..,,,..,,,,,
#UOB4EYZLSOX3BFP7G4TASSIYG3DBIZW3JF6JVI7IRTC7BQZVH74KMPSCWWSURBY6QTFGRBG7M6LI6
#\\\|YMMEAS3F4XZZM5IK3OH5KF4GJ5ZOA7HSDUFQL2I7PJHL4Z5C2WI \ / AMOS7 \ YOURUM ::
#\[7]MFZQ5E6QNY6MLUJR33FN3XE4O2EZ7WYBYD4QCOPCUNEWNT5FWIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**2026-10-07 regeneration :** `taeki.base` regenerated [ `p7-keys remove taeki.base` + `p7-keys create -U taeki.base`, unencrypted as before -- p-7-r signs non-interactively ] ; cube's pin `remote-keys/incoming/taeki.public` replaced as protocol-7 + cube `reload plugins` [ needed e94d28c39 : authorized keys were load-once ] -> p-7-r login verified. `protocol-7.base` still OPEN : it is now cube's S [ .dlg ], test-auth-keypair [ symlink ] AND the p7-log anon key -> rotate : p7-log reloaded FIRST [ adopts table.bin under the current key id, table.bin.key ], `p7-keys rename protocol-7.base protocol-7.base-anon-<date>`, `p7-keys create -U protocol-7.base`, `p7c p7-log.archive-anon-table protocol-7.base-anon-<date>` [ checks the key id, refuses a wrong name ], restart v7-zenki -> .dlg reissued. store refuses a table written under another key [ no silent mixing ].

#,,,.,,,,,..,,,,,,,..,,..,.,,,..,,.,,,.,,,.,.,..,,...,...,...,,.,,,.,,...,,,,,
#J3KD2BJK4XLGT2PTVL4E3IPBSI5I7HXCEVHOJBYUEXBDJUVTAPXWJHRIFRQX4WI4X2I32M47ARQD6
#\\\|E4C2K4XWSWGGP3TLRLBCF7PRHBD3WVJKBNVMNHOMT2DEAXKAVKF \ / AMOS7 \ YOURUM ::
#\[7]WSAMDITRDSMGYCT3WFNUQ6NSLW64YDQVWPTX5DUHDET7V3XMMEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**2026-10-07 protocol-7.base ROTATED [ live ] :** renamed to `protocol-7.base-anon-2026-10-07`, new key created, `p7c p7-log.archive-anon-table protocol-7.base-anon-2026-10-07` [ key ids matched ], v7-zenki restarted -> `.dlg` reissued 07:52, p-7-r OK, old [L:..] token resolved from the archived table. MISSED STEP [ add to every client-key rotation ] : cube's TOFU pin `remote-keys/incoming/<user>.public` must get the new public key too -- the `authorized/cube/` symlink alone is not enough [ test-auth-keypair got `TOFU: MISMATCH` until the pin was replaced ; cube reads the pin per login, no reload ].

#,,,,,.,.,,,,,,..,.,.,.,,,...,,,,,...,...,,,,,..,,...,...,...,.,.,,..,.,.,,.,,
#6YK4DDUAND3WCM7T6I5WAM2SQPCB6UW3FREBMBHR5ZCCLRUTQRKIO7LXGZOUY4D4QWD53RI24VSTG
#\\\|4LY4X2LHSW3SX725JKQSQG6KZIUB2LVFY4VQERLFTVCZBHZVDJ5 \ / AMOS7 \ YOURUM ::
#\[7]DK2SIQAPMRJ3EAVQOW4ZKAITH6ZJDLXMNAJVHFANBFCJX6PJOSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
