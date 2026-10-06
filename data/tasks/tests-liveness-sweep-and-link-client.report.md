# report : tests-liveness-sweep-and-link-client

task spec : `data/tasks/tests-liveness-sweep-and-link-client.md`
delivered : `bin/test-scripts/test-v7-liveness-sweep.pl` +
            `bin/test-scripts/test-link-upgrade-client.pl`
branch base : TEST-ONLY, nothing under `src/` or `cfg/` changed, no zenka
started/restarted/reloaded, no sudo, no commit, no signing.

both scripts pass : 6/6 repeat runs, exit 0 each, zero FAIL lines.

---

## script 1 : bin/test-scripts/test-v7-liveness-sweep.pl

harness : copied from `bin/test-scripts/test-prng-entropy.pl`
[ `compile_module` via `AMOS7::Protocol::P7Syntax::p7_syntax__translate`,
`%code` / `%data`, `TRUE => 5`, `FALSE => 0`, the `ok()` helper, exit code ].

compiled for real : `src/v7-zenki.handler.liveness_sweep`,
`src/v7-zenki.sub-process.pid_alive` [ the /proc liveness check ],
`src/v7-zenki.child.add`.

stubbed : `base.logs` [ records ], `base.log` [ child.add uses the singular ],
`base.ntime`, `base.s_warn`, `base.caller`,
`v7-zenki.instance_ids` [ returns the test's instance ids ],
`v7-zenki.handler.sig_chld` [ records ( pid, exit ), reaps nothing ].

real processes : live pid = `$$`; dead pid = fork + exit + `waitpid`; zombie =
fork + exit + NOT reaped [ verified state Z via `/proc/<pid>/stat` before the
sweep, reaped at the end ]. a tiny `TestRestartTimer` double provides
`is_active`.

### full output

```
: live pid
  ok   : live pid : nothing recovered
  ok   : live pid : no sig_chld call
  ok   : live pid : no child entry added
: dead pid [ reaped, /proc entry gone ]
  ok   : dead pid : return value counts the recovery
  ok   : dead pid : sig_chld injected as ( pid, -1 )
  ok   : dead pid : child entry restored with instance_id + liveness flag
: zombie pid [ state Z, not reaped ]
  ok   : setup : child really is a zombie
  ok   : zombie : treated like dead [ counted ]
  ok   : zombie : sig_chld injected
  ok   : zombie : child entry restored
: instance being stopped
  ok   : stopping : counted
  ok   : stopping : sig_chld recorded
  ok   : stopping : NO child entry added [ the stop completes instead ]
: pending restart timer owns the instance
  ok   : active restart timer : skipped entirely
  ok   : active restart timer : no sig_chld call
  ok   : active restart timer : no child entry
  ok   : inactive restart timer : NOT skipped [ recovered ]
: still tracked on the next sweeps
  ok   : first sweep : recovered, one injection
  ok   : second sweep : not counted again
  ok   : second sweep : exactly one level-0 still-tracked log
  ok   : second sweep : no second sig_chld
  ok   : third sweep : silence
: forgotten once no instance tracks the pid
  ok   : pid no instance tracks any more is dropped from the recovered map
: non-numeric and too-small pids ignored
  ok   : pids that are not numeric or < 2 are ignored

all checks passed
```

### what each check proves

- **live pid** — a tracked, alive process id produces no recovery at all :
  no `sig_chld` injection, no `v7-zenki.child` entry, return value 0.
- **dead pid, no child entry, not stopping** — the sweep's main path : the
  return value counts the recovery; the dead pid is handed to
  `v7-zenki.handler.sig_chld` exactly as `( pid, -1 )` [ the injection the
  real handler accepts ]; the child entry is restored with the
  `instance_id` and `liveness == TRUE` [ 5 ] so `process_zenka_end` takes
  the restart path instead of deleting the instance. this is precisely the
  invoke-web dropout scenario from the module header.
- **zombie** — a pid that exists in `/proc` but is in state Z is detected
  via the `/proc/<pid>/stat` state parse and treated exactly like a dead
  pid [ counted, injected, child entry restored ].
- **stopping** — with `$data{'zenka'}{'instance'}{'shutdown'}{<iid>}` set,
  the pid is still injected into the sig_chld path [ the stop completes ]
  but NO child entry is added, so `process_zenka_end` deletes rather than
  restarts.
- **pending restart timer** — an instance whose `timer.restart` object
  reports `is_active` is skipped entirely [ the restart owns it ] : no
  injection, no child entry, not counted. an *inactive* timer does not
  protect the instance.
- **still tracked** — on the sweep after a recovery the pid is not
  re-injected : exactly one level-0 "still tracked after recovery" log
  appears, the sig_chld call count stays at one, the return value is 0 ;
  on the third sweep there is complete silence [ the `recovered->{$pid}++`
  latch works, no injection loop ].
- **forgotten** — once no instance tracks the pid, it is deleted from
  `$data{'v7-zenki'}{'liveness'}{'recovered'}` [ the forget loop ], so a
  future re-appearance would be recovered again.
- **non-numeric / < 2** — pids like `'abc'`, `1`, `0` are ignored : no
  injection, no child entry, return 0 [ the `^\d+$` and `< 2` guards ].

---

## script 2 : bin/test-scripts/test-link-upgrade-client.pl

harness : same pattern as above. compiled for real :
`src/protocol.protocol-7.link-upgrade.handshake`,
`src/protocol.protocol-7.encryption.init`,
`src/protocol.protocol-7.link-upgrade.client_activate`.

stubbed : `base.logs`, `base.log`, `base.s_warn`, `base.caller`,
`base.perlmod.loaded` / `base.perlmod.load` [ honest versions : `%INC`
check + real `require` ], `event.add_var` [ encryption.init re-registers
the output-buffer watcher unconditionally at its end ],
`base.session.init_state` [ delegates to the compiled
`protocol.protocol-7.encryption.init` with `( sid, mode, 3 )` ].

fake server : `socketpair( AF_UNIX, SOCK_STREAM )`, child forked per
scenario, speaks the exact server lines [ `TRUE link-upgrade OK <b32>` /
`SIZE 0` / `encoding-confirmed` / `link-complete-ok` ], reports its own DH
result + the received nonce sid through a temp file. every line carries a
trailing `\n` [ the client reads with `readline` ] and both socket ends are
set `autoflush(1)` BEFORE the fork. the test itself is guarded with
`alarm 15`.

### full output

```
: handshake success
  ok   : handshake success : ( 1, { .. } )
  ok   : shared secret is 32 bytes
  ok   : shared secret == the server DH result
  ok   : nonce sid in 1 .. 2**32-1
  ok   : nonce sid == what the server received
: wrong answers
  ok   : wrong answer [first line has no OK] : ( 0, { error } ), no die
  ok   : wrong answer [server key is invalid base32] : ( 0, { error } ), no die
  ok   : wrong answer [answer to link-pub-key is not SIZE 0] : ( 0, { error } ), no die
  ok   : wrong answer [answer to encoding is not encoding-confirmed] : ( 0, { error } ), no die
  ok   : wrong answer [answer to link-complete is not link-complete-ok] : ( 0, { error } ), no die
: silent server
  ok   : silent server : fails instead of hanging
  ok   : silent server : failed within the timeout [ 1s ]
: client_activate on a minimal session
  ok   : client_activate : TRUE
  ok   : link_role client recorded
  ok   : client writes direction 1
  ok   : client reads direction 2
  ok   : dh secret deleted after key derivation
: client_activate input validation
  ok   : wrong-length secret : FALSE
  ok   : missing nonce sid : FALSE
  ok   : unknown session : FALSE
: encryption.init roles
  ok   : server-role encryption.init : TRUE
  ok   : server role : write 2, read 1
  ok   : no link role : refused
  ok   : no link role : complains
  ok   : missing dh secret : refused
: encrypted frame direction [ bonus ]
  ok   : frame handler produced a frame
  ok   : frame length prefix matches
  ok   : client frame decrypts with the server read nonce [ direction 1 ]
  ok   : same frame does NOT decrypt with direction 2

all checks passed
```

### what each check proves

- **success** — against a server that computes the real curve25519 DH, the
  handshake returns `( 1, { shared_secret, nonce_sid } )` where the secret
  is the exact 32-byte DH result the server computed independently, and
  the nonce sid is in `1 .. 2**32-1` and byte-identical to the sid the
  server received on its `link-complete <n>` line. both ends derived the
  same secret from the key exchange alone.
- **wrong answers** — a first line without `OK`, a server key that is
  valid base32 but not 32 bytes, an answer other than `SIZE 0`, other than
  `encoding-confirmed`, other than `link-complete-ok` : each yields
  `( 0, { error } )` with a descriptive message and no die. every refusal
  branch of the handshake is exercised.
- **silent server** — with `{ timeout => 1 }` the handshake fails after ~1s
  [ never hangs ] : each read is bounded by the IO::Select timeout.
- **client_activate** — on a minimal `$data{'session'}{<id>}` it returns
  TRUE, records `link_role == 'client'`, and through the compiled
  encryption.init the session ends up writing direction 1 and reading
  direction 2, with the raw dh secret deleted after key derivation.
- **input validation** — wrong-length secret, missing nonce sid, unknown
  session id : each returns FALSE.
- **encryption.init roles** — `link_role == 'server'` gives write 2 /
  read 1 [ the mirror image of the client ]; no role at all returns FALSE
  with the "link role unknown" log [ refuses rather than guessing ];
  missing dh secret returns FALSE.
- **bonus, frame direction** — a frame produced by the client session's
  `base.handler.link-upgrade.frame-<id>` writer [ length prefix +
  ciphertext + 16-byte tag ] decrypts with the SERVER's read nonce
  [ direction 1, counter 0 ] and the Poly1305 tag FAILS under direction 2
  : the direction byte in the nonce does its job — the two directions
  never reuse key+nonce.

---

## things that looked like real bugs [ described, NOT fixed ]

1. **frame writer fails OPEN on any cipher error**
   `src/protocol.protocol-7.encryption.init`, frame writer closure :
   ```
   my $w_framed = eval { ... };
   return $payload if not defined $w_framed or length $EVAL_ERROR;
   ```
   any failure inside the eval [ cipher object undefined, encrypt error ]
   makes the handler return the ORIGINAL PLAINTEXT payload — the session
   then sends unencrypted data on a link both ends believe is encrypted.
   inputs : any frame send after a cipher failure; expected : the send
   fails closed [ disconnect or error ]; actual : silent plaintext on the
   wire. this bit me in test form : with `Crypt::AuthEnc::ChaCha20Poly1305`
   not yet loaded, the writer "succeeded" while returning plaintext and
   only the length mismatch exposed it. not fixed per task rules.

2. **`bytes::length` needs the `bytes` pragma loaded — works only by
   transitive luck.** `bytes::length` [ used in 39 src files, including
   the frame writer ] dies with "Undefined subroutine &bytes::length"
   unless `bytes.pm` is in `%INC`; no src file does `use bytes`. it works
   in production because the runtime loads it transitively
   [ `bin/Protocol-7` starts with `use utf8` / `use open`, Encode pulls in
   `bytes.pm` ]. any future loader change that drops that transitive load
   breaks all 39 call sites at once. the test mirrors the production
   environment with `use bytes` [ test-side setup only ]. arguably a
   latent fragility rather than an active bug — flagged for awareness.

both items are observations from the test side; no src/ or cfg/ change was
made.

#,,,,,,.,,,,,,,,.,,..,..,,.,.,.,.,,.,,,,,,,.,,..,,...,..,,..,,...,,.,,,,.,...,
#BHXMKMQ67JIJBNPCVDK3MISEVYOBSCJQEOUIMTXENUIBDG7QMNDK54FB6QZDG5YFF4KZ4PBLBML6K
#\\\|EJ5AL7EYU7O3JBN3BND6AGDD4YLCW67ZCJCP5AUNLJ665GLFO4M \ / AMOS7 \ YOURUM ::
#\[7]QUEMZDWURABD2C2VZ5XZJX5C6ZSSGRRKYA44HH4TCTTNZXVWNICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
