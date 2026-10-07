# report : tests host-root key creation [ crypt.C25519 ]

script : `bin/test-scripts/test-host-root-keygen.pl` [ new, only file added
besides this report ]. `bin/format-code -c` : syntax valid [ the file was
reflowed once with `bin/format-code` ]. result : **48 checks, 48 ok, 0 fail**,
exit 0, ~0.5 s.

compiled REAL modules : `base.prng.entropy_pool`, `base.prng.reseed`,
`base.prng.add_entropy`, `base.prng.bytes`, `crypt.C25519.gen_keys`,
`crypt.C25519.post_init`. stubbed : `base.log[s]`, `base.s_warn`,
`base.caller`, `base.ntime`, `base.ntime.b32`, `base.time`,
`base.assert.harmony`, `base.sleep`, `event.once`, `crypt.C25519.key_vars`
[ echoes the explicit name, key_dir = File::Temp tempdir ] ; for post_init
also `chk_key_dir`, `base.cfg_bool` [ FALSE : user-key autocreate skipped ],
`load_keypair`, `file.slurp`, `generate_session_keypair`, and recorders for
`key_exists` \ `gen_keys` \ `write_keys`. no real key dir touched, nothing
written to disk by the code under test [ write_keys is a recorder ].

## full output

```
: gen_keys : fresh random path [ host-root ]
  ok   : returns the entry + name, stored under $keys{C25519}{'host-root'}
  ok   : returned entry is the stored entry
  ok   : secret  : 32 bytes
  ok   : private : 64 bytes [ ed25519 ]
  ok   : public  : 32 bytes
  ok   : public == ed25519 public key of the secret
  ok   : generate_keypair( secret ) reproduces public + private
  ok   : the pair signs and verifies
  ok   : public passes the harmonic truth check [ raw + b32r ]
  ok   : time-loaded set
  ok   : no fortuna-only fallback : /dev/random contributed
: gen_keys : fresh generations differ
  ok   : round 1 : public passes truth
  ok   : round 2 : public passes truth
  ok   : round 3 : public passes truth
  ok   : round 4 : public passes truth
  ok   : round 5 : public passes truth
  ok   : round 6 : public passes truth
  ok   : round 7 : public passes truth
  ok   : round 8 : public passes truth
  ok   : 8 generations : 8 distinct secrets
  ok   : 8 generations : 8 distinct public keys
  ok   : none repeats the first generation
: gen_keys : passphrase path is deterministic
  ok   : same passphrase + name twice -> same key
  ok   : passphrase key passes truth
  ok   : other passphrase -> other key
: gen_keys : error branches
  ok   : 31-byte secret -> undef, nothing stored
  ok   :   :.. warns : 32 bytes
  ok   : 32-byte secret + passphrase -> undef, nothing stored
  ok   :   :.. warns : mutually exclusive
  ok   : already loaded name -> FALSE
  ok   :   :.. existing key unchanged
  ok   :   :.. complains via base.s_warn
: gen_keys : explicit 32-byte secret [ observation ]
  ok   : explicit secret with a TRUE public key : kept as given
         explicit secret with an UNTRUE public key : REPLACED by a fresh random secret
  ok   :   :.. stored key passes truth either way
  ok   : no unexpected perl warnings in gen_keys
: post_init : host-root decision
  ok   : v7-zenki : post_init returns 0
  ok   : v7-zenki, nothing on disk : gen_keys('host-root') once [ no secret ]
  ok   :   :.. write_keys('host-root') once
  ok   :   :.. key_exists consulted
  ok   :   :.. create_host_root_key defaults to TRUE
  ok   : cube : neither gen_keys nor write_keys
  ok   : httpd : neither gen_keys nor write_keys
  ok   : v7-zenki, host-root on disk : neither called
  ok   : v7-zenki, host-root virtual [ key_exists 4 ] : neither called
  ok   : v7-zenki, create_host_root_key FALSE : neither called
  ok   :   :.. key_exists not even consulted [ short-circuit ]
  ok   : v7-zenki, host-root in %keys but not on disk : write_keys only
  ok   : the recorded gen_keys call, replayed on the real gen_keys : valid key

all checks passed
```

## what each check proves

gen_keys, fresh random path [ `gen_keys('host-root')`, no passphrase \ secret ] :
- entry stored at `$keys{'C25519'}{'host-root'}` and returned with its name.
- **stored format** [ differs from the task text ] : `secret` 32 bytes,
  `private` **64** bytes, `public` 32 bytes, plus `time-loaded`. the keys
  are **Ed25519** [ `Crypt::Ed25519` ], not Curve25519 : `public ==
  eddsa_public_key(secret)`, and `generate_keypair(secret)` reproduces both
  public and private ; the pair signs + verifies. not a bug, a spec note.
- public passes both truth checks gen_keys loops on [ raw + `encode_b32r`,
  `scalar( is_true(..) )` ].
- no "no kernel random bytes" log line : `/dev/random` contributed the 32
  extra bytes [ not fortuna-only ].

fresh generations : 8 rounds [ entry deleted between ] -> 8 distinct secrets,
8 distinct publics, none equal to the first generation, all pass truth.

passphrase path : same name + passphrase twice -> identical secret \ public
\ private ; other passphrase -> other key ; key passes truth.

error branches : 31-byte secret -> undef [ warns "must be 32 bytes" ],
nothing stored ; 32-byte secret + passphrase -> undef [ warns "mutually
exclusive" -- a 32-byte secret is used so the length check cannot mask this
branch ], nothing stored ; already loaded name -> FALSE, entry is the same
ref with unchanged secret \ public \ private, complaint via `base.s_warn`.

post_init host-root block [ real post_init, `auto_load_keys` on, `%data` \
`%keys` \ recorders reset per case ] :
- `v7-zenki`, nothing on disk -> `gen_keys('host-root')` once [ single arg,
  no secret ] + `write_keys('host-root')` once, `key_exists` consulted,
  `create_host_root_key` defaults to TRUE, returns 0.
- `cube`, `httpd` -> neither called.
- host-root on disk [ key_exists TRUE ] and virtual [ key_exists 4 ] ->
  neither called.
- `create_host_root_key` = FALSE -> neither called, key_exists not even
  consulted.
- host-root in `%keys` but not on disk -> write_keys only.
- the recorded gen_keys call replayed on the real gen_keys gives a valid,
  truth-passing key [ ties the decision test to the real generator ].

## suspected real bug [ described, not fixed ]

**gen_keys silently replaces an explicit 32-byte secret whose public key
fails the truth check.**

- input : `gen_keys( 'explicit', undef, $secret )` with a 32-byte `$secret`
  whose `eddsa_public_key` fails `is_true` [ most random secrets do ].
- expected : either the key derived from exactly that secret, or a failure
  [ undef ] -- a caller passing a secret wants THAT key back.
- actual : the truth loop takes the `not defined $key_seed_passphrase`
  branch and does `$secret_key = $fresh_secret->()` -- the caller's secret
  is discarded and a random key is stored and returned as success. a
  secret whose public DOES pass truth is kept [ checked ], so the outcome
  depends on the secret.
- where it matters : `src/letsencr.child.load_account_key` restores an
  Ed25519 ACME account key from a cached secret this way. a cached secret
  originally made by gen_keys already passes truth, so that path works
  today ; any externally sourced secret [ or a future change of the truth
  rule ] would silently yield a different account key on every load.
  `gen_keys` with `$file_entropy_bin_32` \ `$key_seed_entropy` callers pass
  it as the passphrase argument, so they are not affected.
- this is not part of the host-root path [ host-root passes no secret ].

nothing wrong found in the host-root creation itself.

#,,..,,.,,,.,,.,,,,,,,,,.,...,.,.,,.,,...,,,.,..,,...,...,,..,...,.,.,,.,,,.,,
#MEBSPZ3YXXJJ5HIHE3SXFNFAKG2F5W4RSXA47XDKNPADDBWTXVUOI3YLEQ32P56RFBEMMHUBSU73I
#\\\|NZYB3PVBBRARE652MP2OHW7YHR6A7PX452QEZGBVBJSSYOTLMBU \ / AMOS7 \ YOURUM ::
#\[7]4SZSOGFSG4MB35V4M4ZUWKIR7GU3ZFW46QXOAJ6RVKAK7Z6PVODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
