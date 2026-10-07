# auth-link-binding : C client side [ lane C ] -- report

## files changed

- `bin/c_src/p-7-r.c`
- `bin/p7-auth-keypair-helper.pl`
- `bin/p7-link-upgrade-helper.pl` : the argv-secrets fix [ the scope change
  the user approved mid-task, see below ]. The new binding verbs went into
  the auth-keypair helper, because that helper already loads the client
  key C.

## changes

### bin/p7-auth-keypair-helper.pl

- **One place for the pack templates** : `auth_message`,
  `bind_transcript` and `bind_message( client|server )`. They are
  byte-for-byte the spec's templates. `gen-auth`, `gen-bind`,
  `verify-bind` and `self-test` all go through them.
- **`load_client_key`** : the old gen-auth key loading, factored out
  [ `$HOME/.n/user-keys/<user>.base.secret` ]. The secret never comes in
  on argv.
- **Strict argv checks, fail closed** :
  - b32 values : exact length [ 52 for 32 bytes, 103 for 64 ], alphabet
    `[A-Z2-7]`, canonical round-trip.
  - username : `^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}$`.
  - nonce_sid : 1 .. 2**32-1.
  - encoding : `[A-Za-z0-9._-]{1,64}`.
- **Verbs** [ every argv value is public ] :
  - `gen-auth <username> <server_nonce> <s_pub>` -> two lines :
    session_pub, v2 auth_sig. The session C25519 key is still random per
    call, as before [ see open questions ].
  - `check-pin <host> <port> <s_pub> [strict]` -> pin store
    `~/.n/remote-keys/servers/<host>_<port>.public`, created 0600 with
    O_EXCL in a 0700 dir. The file holds the bare S_pub b32 line [ spec ].
    Results :
    - `PIN_VALID`, exit 0.
    - `PIN_NEW <S_pub b32>`, exit 0, on first contact.
    - `PIN_MISMATCH`, exit 6. Never re-pinned.
    - `PIN_UNPINNED`, exit 5, in strict mode. **Nothing is written** [ the
      old TOFU helper pinned before refusing ].
    - A pin file that is unreadable, empty, corrupt, or a dangling symlink
      -> die [ exit != 0 ] -> the client refuses.
    - The host is limited to `[A-Za-z0-9.:-]` with `:` -> `_` ; the port
      to 1..65535.
  - `gen-bind <username> <server_nonce> <s_pub> <server_eph> <client_eph> <nonce_sid> <encoding>`
    -> client_bind_sig b32.
  - `verify-bind <server_bind_sig> <username> <server_nonce> <s_pub> <server_eph> <client_eph> <nonce_sid> <encoding>`
    -> `BIND_OK`, exit 0. Anything else -> `BIND_FAIL`, exit 1.
  - `self-test` : the spec test vector through the same builders and the
    same verify sub, plus negative cases. Exits 1 on any mismatch.

### bin/c_src/p-7-r.c

- **New order** :
  connect -> banner -> `select auth-keypair` -> parse the reply as exactly
  `TRUE <52 b32> <52 b32>` [ a v1 reply or anything else is refused ] ->
  `check-pin` [ BEFORE the auth line ] -> `gen-auth user nonce S_pub` ->
  auth line -> `AUTH_TRUE` -> **mandatory** link-upgrade + binding -> the
  encrypted command.
- **Link-upgrade is no longer optional** :
  - `PROTOCOL_7_LINK_UPGRADE` is removed.
  - There is no plaintext fallback. Any failure prints a clear stderr line,
    closes the socket and exits 4.
  - The "negotiated" line is now `-v` only.
- **Exact reply parsing** in `negotiate_link_upgrade` :
  - `TRUE link-upgrade OK <52 b32>`
  - exactly `SIZE 0`
  - exactly `encoding-confirmed`
  - `link-complete-ok <103 b32>`
- **Binding steps** :
  - Sends `link-complete <nonce_sid> <client_bind_sig>`.
  - Verifies server_bind_sig via `verify-bind` against the S_pub that
    passed the pin check. It needs `BIND_OK` **and** helper exit 0.
  - nonce_sid = time[NULL] [ forced to >= 1 ]. The same value goes into the
    key derivation, `link-complete` and the transcript.
  - encoding = `none`, the same string that is sent and signed.
- **Helper calls** : NO shell and NO popen any more. Every call goes through
  `helper_exec` [ fork + pipe2(O_CLOEXEC) + dup2 + execv ]. argv is a
  C array of public values only ; secrets are written into the child's
  stdin pipe. The exit status is always checked [ previously ignored ],
  and every output is checked as strict b32 before use. The raw helper
  output is wiped [ explicit_bzero ] before it is freed. The buffer grows
  via malloc + copy + wipe, not realloc, so no stale copy is left behind.
- **SOCK_CLOEXEC** on the server socket, so helpers never inherit the link.
  SIGPIPE is ignored, so a helper that dies early makes the write fail
  [ fail closed ] instead of killing p-7-r.
- **Clean-up** : wiping of secrets is described under "Wiping" in the
  argv-secrets section below. The key is wiped and freed on failure.
- **Not used by p-7-r any more** : `validate_tofu_key` /
  `bin/p7-tofu-helper.pl` [ the file is left in place ; not mine ].
- **Smaller fixes** :
  - hostname[:port] is now parsed AFTER option removal. Before, `p-7-r -v
    host cmd` took `-v` as the hostname, even though the old strict-mode
    hint recommended exactly that form.
  - host, port and the unix user name [ from env ] are validated before
    they go on helper argv \ the wire [ there is no shell any more ].
- **Left in place on purpose** : the plaintext branches after the upgrade
  are now unreachable [ enc_state.enabled is always 1 ]. Kept for a minimal
  diff.

## finding : secrets on argv [ existing verbs ] -- FIXED [ scope change ]

**Confirmed before the fix.** All four verbs are in
`bin/p7-link-upgrade-helper.pl` and were called from p-7-r.c via popen
`sh -c`. The secret was therefore in `/proc/<pid>/cmdline` of BOTH the `sh`
and the `perl` process, readable by every local user.

| verb | secret arg | what it is | call site |
|------|-----------|------------|-----------|
| `compute-dh <client_secret_b32> <server_pubkey_b32>` | arg 1 | client ephemeral curve25519 secret | `negotiate_link_upgrade` |
| `derive-key <shared_secret_b32> <session_id>` | arg 1 | DH shared secret | `negotiate_link_upgrade` |
| `encrypt <key_b32> <session_id> <counter> <direction>` | arg 1 | link session key | `lu_crypt`, once per frame sent |
| `decrypt <key_b32> <session_id> <counter> <direction>` | arg 1 | link session key | `lu_crypt`, once per frame received |

The link key sat on argv for the whole session. Anyone polling `/proc`
could take it and then decrypt and forge every frame.
`gen-ephemeral` was already fine : its secret goes out on stdout [ a pipe ].
The old `gen-auth <username>` had no secret on argv.

### signatures before -> after

| before [ argv ] | after [ argv = public ; stdin ] |
|---|---|
| `compute-dh <client_secret_b32> <server_pubkey_b32>` | `compute-dh <server_pubkey_b32>` ; stdin `<client_secret_b32>\n` |
| `derive-key <shared_secret_b32> <session_id>` | `derive-key <session_id>` ; stdin `<shared_secret_b32>\n` |
| `encrypt <key_b32> <sid> <counter> <direction>` | `encrypt <sid> <counter> <direction>` ; stdin `<key_b32>\n` + plaintext |
| `decrypt <key_b32> <sid> <counter> <direction>` | `decrypt <sid> <counter> <direction>` ; stdin `<key_b32>\n` + ciphertext+tag |
| `gen-ephemeral` | unchanged |
| `gen-auth <username>` [ auth helper ] | `gen-auth <username> <server_nonce> <s_pub>` [ v2 ] |
| -- | new [ auth helper ] : `check-pin`, `gen-bind`, `verify-bind`, `self-test` |
| -- | new [ link-upgrade helper ] : `self-test` |

**Strict argument checks.** The secret line must be exactly 52 b32 chars.
The numeric args must be digits, and the direction 1 or 2. The exact arg
count is enforced, so the OLD argv forms are refused rather than misread :
a stale caller fails and does not quietly run with its secret on argv.
Decrypt refuses input shorter than the 16-byte tag.

**Temp files.** The old `lu_crypt` wrote every frame [ plaintext on send,
ciphertext on receive ] to `/tmp/p7r-lu-XXXXXX`. That was a mkstemp file :
0600, unpredictable name, unlinked after the helper ran. It was not a
predictable path, but it put plaintext on disk. It is gone : the frame now
goes into the helper's stdin right after the key line. p-7-r writes no
temp files at all now. Secrets never appear in file names or env vars.

**Wiping.** These are now explicit_bzero'd :
- client_secret right after compute-dh
- shared_secret right after derive-key
- the stdin staging buffers [ each holds `key\n` + frame ], after every
  helper run
- all raw helper output
- the link key, on a failed negotiation

The link key lives for the whole session [ it is needed per frame ] and is
not wiped at process exit.

**Proof that behaviour is preserved.** `p7-link-upgrade-helper.pl
self-test` compares against golden values. I captured those from the
UNMODIFIED helper's old argv form before editing it, using fixed inputs :
- secret = 32 x \x77
- server pub = curve25519 pub of 32 x \x66
- sid 305419896
- counter 7
- both directions

The self-test runs the new stdin verbs as real subprocesses [ IPC::Open2 ]
and requires byte-identical results :
- the shared secret, the derived key, and both ciphertexts
- a decrypt round trip
- a flipped tag refused
- the three old argv forms refused

**Runtime proof.** I traced a full successful p-7-r run under
`strace -f -e execve` :
- Every exec carries only the helper path, the verb and public values
  [ host, port, S_pub, nonce, username, eph pubkeys, sid, counter,
  direction, sigs ].
- There is no `sh` process and no secret on any argv.

## finding : shell injection from server bytes [ existing, fixed in passing ]

The old p-7-r put server-controlled strings unvalidated into popen shell
command lines [ there is no shell at all now, and values are checked
anyway ] :
1. The select reply `TRUE <pubkey>` went into the TOFU helper command.
2. The link-upgrade server eph key went into `compute-dh`.

A hostile server answering `TRUE $(cmd)` got code execution as the
client user. Every server value is now checked as strict b32 [ exact
length, `[A-Z2-7]` ] before any helper call. The e2e test below sends
`TRUE $(touch ...) <nonce>` : refused, nothing executed.

## verification

### self-test [ `bin/p7-auth-keypair-helper.pl self-test` ]

```
ok   c_pub
ok   s_pub
ok   auth_msg hex
ok   auth_sig
ok   transcript hex
ok   client_bind_sig
ok   server_bind_sig
ok   verify server_bind_sig
ok   reject flipped transcript byte
ok   reject flipped sig byte
ok   reject client sig as server sig
ok   reject server sig under wrong key
ok   refuse nonce_sid 0
ok   refuse nonce_sid 2**32
ok   refuse short b32
ok   refuse b32 shell chars
ok   refuse username slash
self-test ok
exit=0
```

All three sigs, both hex messages and both test pubkeys match the spec.
The first run caught two hand-typed constants I had split wrongly. They
were regenerated mechanically from the spec file [ the builder output was
right all along ].

### self-test [ `bin/p7-link-upgrade-helper.pl self-test` ]

```
ok   compute-dh [ secret on stdin ]
ok   derive-key [ secret on stdin ]
ok   encrypt direction 1 [ key on stdin ]
ok   encrypt direction 2 [ key on stdin ]
ok   decrypt round trip [ key on stdin ]
ok   decrypt refuses a flipped tag
ok   old compute-dh argv form refused
ok   old derive-key argv form refused
ok   old encrypt argv form refused
self-test ok
```

[ The child processes' expected refusal messages go to stderr and are not
shown here. ]

### compile [ `gcc -Wall -Wextra`, into the scratchpad only, not installed ]

- **baseline [ unmodified file ]** : 2 warnings.
  - `read_line` sign-compare [ line 54 ]
  - unused `exit_code` in `validate_tofu_key`
- **now** : 1 warning, the same pre-existing `read_line` sign-compare
  [ line 60 now ]. The other one went away with the removed function. **No new
  warnings.**

### format-code

`bin/format-code -c` : syntax valid for both helpers.
`bin/format-code` was applied to both helpers [ reflow only ].
The AMOS7 signature blocks were left alone ; they need re-signing by the
signing tool.

### e2e [ loopback mock server in the scratchpad, throwaway HOME, test-vector C key ]

The mock checks the C client's auth_sig and client_bind_sig with its own
copy of the spec pack templates.

| case | result |
|------|--------|
| strict, no pin | exit 5, no pin file written |
| first contact | prints `: pinned server key QE4X...WOKA`, auth_sig VALID, client_bind_sig VALID, encrypted command round-trip OK, exit 0, pin file 0600 [ dir 0700 ] |
| second contact | silent PIN_VALID, exit 0 |
| other server key | exit 6, MITM warning, **no auth line sent** |
| flipped server_bind_sig | exit 4, SECURITY WARNING, **no command sent** |
| v1 select reply [ no nonce ] | exit 4 |
| injection payload in select reply | exit 4, not executed |
| pin file mode 000 | exit 4 |

All cases were re-run after the stdin \ execv rewrite, with identical
results.

## open questions \ spec points

1. **Old pins are not migrated.** Pins used to live in
   `~/.n/remote-keys/known/<host>_<port>.public` [ format
   `NTIME_B32:PUBKEY_B32` ]. I followed the spec : `servers/` with a bare
   b32 line. Effect : the first p-7-r connection after this change re-runs
   TOFU, even for hosts already pinned under `known/`. A one-time seed
   from `known/` [ adopt the key if it matches, refuse if it differs ] is
   not in the spec, so I did not improvise it. **Your decision.**
2. **Pin-file format must match the Perl client** `auth.client.server_pin.check`
   [ not present yet when I looked ]. The C side writes `<S_pub b32>\n`
   and refuses any other content, including the old `NTIME:PUB` form. If
   lane P writes something else, the C client fails closed on that pin
   file. Hostname normalisation should match too [ C : `:` -> `_`, no
   case folding ].
3. **"fingerprint" is undefined in the spec** [ `pinned server key
   <fingerprint>` ]. I print the full S_pub b32.
4. **Session key "stays stable, TOFU" [ spec ]** : the C helper's
   `gen-auth` has always generated a fresh random C25519 session key per
   call, and still does. This is **not a functional problem**. I checked
   read-only : the server's `validate-incoming-tofu` pins the user's MASTER
   key [ `authorized-remote{user}{public_b32}` ], not session_pub [ HEAD
   `plugin.auth.auth-keypair` ]. It is only a mismatch with the spec's
   wording ; the session key is not reused across connections.
5. **`bin/c_src/p7c.c` still uses the OLD argv forms** [ NOT my file,
   not touched ].
   - Its `negotiate_link_upgrade` [ lines ~103-160 ] calls
     `compute-dh <client_secret> <server_pub>` and
     `derive-key <shared_secret> <sid>` via popen.
   - That path only runs with `PROTOCOL_7_LINK_UPGRADE=yes` [ opt-in ;
     default p7c use over the unix socket is unaffected ].
   - With the new helper those calls are refused. p7c then prints
     "negotiation failed, continuing plaintext" on a half-negotiated
     session, so that opt-in mode breaks.
   - That path looks half-built anyway : it never encrypts frames after
     negotiating, and it falls back to plaintext. It also had the same
     argv-secret leak.
   - Options : port p-7-r's `helper_exec` \ stdin calls into p7c.c, or
     drop p7c's link-upgrade path. Needs an owner.
   - No other callers : in the repo, only p-7-r.c, p7c.c and
     `bin/dev/tests/README.md` [ docs ] mention the helper. The Perl lane
     should still confirm that nothing in its tests calls the old verb
     forms.
6. **Hardcoded helper paths** under `/data/projects/protocol-7/bin/` were
   kept as they were.

#,,,.,.,,,...,,,,,,,.,,,,,.,,,.,.,,..,.,.,,..,..,,...,...,...,,,.,..,,..,,.,.,
#7QDSAHZELRPVRW4DDY4YPYBHXQMAMXQOBHPXMGAYVCYEOPLG7A4WMVUY3NZWQ5QQ74ROOOSMWPLUW
#\\\|T577LEXMQPDP3L67Z7JTPAQQEUPLVUVXFJKJSZFJ5HQ6CKIWZMX \ / AMOS7 \ YOURUM ::
#\[7]IFQXPFV2FGYFRKZAWNLQY4P7QHZFB22D652TUNIIX2SF4SGT6OAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
