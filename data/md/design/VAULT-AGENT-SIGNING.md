# vault agent : sourcecode signing without passphrase prompts

draft 2026-10-29 [ todo HX4, first slice of Y7O's agent ]. design + minimal
core. builds on : data/md/design/CREDENTIAL-LAYERS.md [ the vault agent row :
serves granted requests from an unlocked state, runs as the USER, never a
protocol-7-uid process ], todo Y7O [ the agent model, ssh-agent style over a
local socket ], todo PBS [ temp-key history + the time-window audit shape the
signed end record feeds ].

scope of THIS slice : the sourcecode signing agent and the ':agent:' option on
update-signatures. menu-zenka approvals, PIN, click delegation, per-zenka
vault grants : LATER slices [ hooks reserved here, not built ].

## map : how signing gets the key today [ read 2026-10-29, base ]

`sourcecode.console.update-signatures` [ runs in the sourcecode console
zenka, which the user starts as THEMSELVES : `cfg/zenki/sourcecode/zenka.v7`
has no `root.drop_privs` ] :

1. `<[source.load_signature_key]>->('proto-7.sourcecode')` ->
   `crypt.C25519.load_keypair` [ `$ask_for_password = TRUE` ]. When the
   `.private` key file is passphrase-encrypted [ b32 prefix `FY5` after
   decode, 66 octets ], the prompt happens at
   `crypt.C25519.load_keypair` : the `RE_READ_PWD` block calls
   `AMOS7::TERM::read_password_single("'$name' key decryption password")`.
   Decryption : `AMOS7::13::key_32` [ passphrase -> 32 bytes ] +
   `AMOS7::Twofish` -> the 64-octet expanded Ed25519 private key, verified
   against the `.public` half via a test signature
   [ `crypt.C25519.compare_keypair` ]. The unlocked key sits in
   `$keys{'C25519'}{'proto-7.sourcecode'}{'private'}` for the rest of the
   process, mlock'd.
2. per file, `source.cmd.get-code-signed` reads the file,
   `source.extract_sig_body` strips the old footer [ strict mode ],
   computes the stable body-only BMW-512 checksum, then
   `source.create_harmonic_footer` searches an AMOS7 octal header that
   passes the ELF-truth checks and derives `data-chksum` =
   BMW-384( stripped body + first-header-line + '#' ).
3. `source.fill_source_template` builds the actual sign buffer :
   `sprintf "%s#%s\n%s", $first_header_line, $data_chksum,
   $sig_template_prefix` and signs it : `source.sign_data` ->
   `crypt.C25519.sign_data` -> `Crypt::Ed25519::sign( $msg, $pub, $priv )`.
   NOTE what is signed : NOT the file content, but a short buffer whose
   middle element is a BMW-384 over the exact stripped bytes -- a signature
   transitively commits to the content through that checksum.

`bin/p7-vault` is a different key system : `AMOS7::Vault`, argon2-wrapped
master key, unlocked per interactive session [ `vault_unlock`, three tries,
auto-lock timer, `vault_lock` wipes the key on the way out ]. Nothing in
protocol-7 reads a vault yet. The sourcecode signing key is NOT a vault
entry : it is the `proto-7.sourcecode` C25519 keypair in
`~/.n/user-keys/`.

the parallel pool [ landed 149b7a0ba ] : update-signatures shards the file
list into ~4 chunks per worker [ size-balanced, largest first ], keeps
`$workers` children running through `<[base.fork]>`, each child calls
`sourcecode.sign_file_list` on its own shard [ the per-file TOCTOU guard
stays valid : shards are disjoint ]. Children report via
`/tmp/p7-sourcecode-sign.<run_tag>.w<N>.tmp` result files; a DONE sentinel
marks success, pid-liveness alone is never trusted. KEY POINT for the
agent : the children are FORKS of the console process -- anything the
parent set in `%data`/`%keys` before forking is visible to them, so a run
id + socket path set once in the parent reach every worker unchanged.

## the agent

**`bin/p7-sign-agent`** -- a standalone bin script [ ssh-agent model ], NOT
a p7-vault subcommand and NOT a zenka. Justification : p7-vault is the
portable backup tool, copied next to every vault backup -- a signing oracle
must never travel with backups. It also unlocks a different key system
[arg-on2 master key vs the C25519 keypair in ~/.n/user-keys] and a
subcommand would couple the two lifetimes. Y7O's vault-entry grants later
reuse the same process shape; whether they join this script or a sibling is
a later decision [ open question 4 ].

- **process** : runs as the USER, started by the user, in the user's own
  login context. Never a protocol-7-uid process, never a sessions child
  [ CREDENTIAL-LAYERS is explicit : the vault key -- and here the sourcecode
  key -- is never handed to a zenka ]. The unlocked private key lives in
  this process's memory only; it is wiped on exit and on INT/TERM [ same
  discipline as p7-vault's `vault_lock` ]. mlock of the key buffer : not in
  the minimal core [ no IO::AIO in standalone context ; later hardening ].
- **socket** : `$XDG_RUNTIME_DIR/p7-sign-agent.sock` when set, else
  `$HOME/.n/run/p7-sign-agent.sock` [ dir 0700, socket 0600 ].
  `P7_SIGN_AGENT_SOCKET` overrides on both ends. One op per
  connection, single-line requests and responses [ space-separated
  fields, base32-encoded ], newline-terminated; the agent serves
  connections SEQUENTIALLY [ no forks, no threads -- the key stays
  in exactly one process; workers wait in the listen backlog, signing
  requests are tiny ].
- **peer check** : `SO_PEERCRED` on every accepted connection, exactly like
  `io.unix.socket.input.connect`. CHECKED : peer uid == the agent's own
  euid, nothing else. The socket's 0700 dir + 0600 mode already keep every
  other OS user out; SO_PEERCRED additionally pins the peer to the same
  uid even if the socket file was swapped. NOT checked : pid, gid,
  process name -- ANY process of the same user may ask. That is deliberate
  [ this slice's gate is the approval prompt ; stronger caller identity --
  the menu-zenka authenticated session, a zenka name as cube
  authenticated it -- is B2K / a later slice ]. A same-user attacker who
  can already run code as the user does not need the agent to alter the
  repo ; what they cannot do without it is mint a signature, and the
  approval prompt + run binding are the control for that.
- **request protocol** [ one op per connection, single line, space-separated
  fields, base32 for everything outside `[0-9A-Za-z_.-]` ] :
  - `HELLO` -> `OK <protocol-id> <pub_b32>` [ identity check : the client
    compares `pub_b32` against the on-disk `.public` half of the requested
    key BEFORE the run -- a decoy agent holding a different key is caught
    with public material only ]
  - `RUN <run_id> <work_tree_b32> <count>` + count `F <rel_path_b32>`
    lines + `GO` -> `OK` \ `NO denied`. The agent prints key name, run id,
    work-tree, FILE COUNT + the full list and asks y/n on ITS OWN terminal
    [ /dev/tty, falling back to stdin only when there is no controlling
    terminal ]. The run is registered WITH the exact relative path set and
    work-tree root. Approval is per run, never 'always'.
  - `SIGN <run_id> <rel_path_b32> <body_chksum_b32> <body_length>
    <buffer_b32>` -> `OK <sig_b32>` \ `NO <reason>`. Relative paths only on
    the wire : the agent joins them under the approved work tree, rejects
    `..` \ empty components, and refuses any path outside the approved set.
    Per request the agent :
    1. checks the run is known + approved + not ended ;
    2. re-reads the file from disk and re-strips the old footer with the
       SAME strict-mode rules the signer uses [ the PLACEHOLDER \ fake-
       footer pre-strips + the anchored footer cut + separator restore ] ;
    3. recomputes BMW-512 of the stripped body + its length and compares
       with the request's `body-chksum` \ `body-length` [ catches content
       that changed since the requester read it ] ;
    4. recomputes BMW-384( stripped body + first-header-line + '#' ) and
       compares with the `data-chksum` inside the presented sign buffer
       [ catches a buffer that was not derived from this file ] ;
    5. signs the buffer bytes and returns only the signature.
    WHAT IT SIGNS AND WHY THAT IS SAFE : the Ed25519 signature commits to
    `data-chksum`; step 4 proves `data-chksum` is BMW-384 over exactly the
    stripped bytes of the on-disk file at an approved path, read AT SIGN
    TIME ; step 3 binds the request itself to the same read. The agent
    recomputes NOTHING ELSE on purpose : the AMOS7/ELF truth properties of
    the header are harmonic cosmetics, not security [ verify-signatures
    judges them independently ], and re-running the header search would
    burn the same proof-of-work for no security gain. Any mismatch is a
    refusal, never a best-effort sign -- the checks fail CLOSED.
  - `END <run_id>` -> `OK <ntime_b32> <end_sig_b32>` : the agent signs
    `p7-sign-agent:end:<run_id>:<ntime_b32>` with the sourcecode key and
    appends begin \ end records [ ntime, run id, list checksum, peer pid ]
    to its runs log [ `<run_base>/runs.log`, 0600 ]. THE SIGNED END
    TIMESTAMP : an immutable capability-reduction record -- an auditor can
    verify that no signature for this run exists legitimately after the
    signed time. This is the audit anchor todo PBS's window story wants.
- **run id** : `sign-<pid>-<epoch>-<bmw13 of the sorted path list>`,
  generated by update-signatures. It groups the workers' requests under
  ONE approval : the agent approves on the `RUN` and every `SIGN` for the
  same run id rides it. The list checksum in the runs log binds the
  approval to exactly these paths [ the Y7O rule : a changed request does
  not match ].

## how the pool workers reach the agent

the parent sets `<sourcecode.cfg.sign_agent_socket>` +
`<sourcecode.cfg.sign_agent_run>` once, BEFORE any fork; both the
sequential path and the forked workers inherit them. Each `sign` request
inside `source.fill_source_template` [ the single signing seam ] opens its
own short connection -- the agent serializes requests but approvals happen
ONCE per run, so the prompt cost is paid exactly one time no matter how
many chunks or workers. The parent sends `end` after the last worker is
reaped [ a worker-crash abort exits without `end` : the run simply stays
open in the agent, harmless -- run ids are one-shot and die with the
agent's session ].

## minimal core [ this slice ]

1. `bin/p7-sign-agent` : the standalone agent above. `--key <name>`
   [ default `proto-7.sourcecode` ], `--socket <path>`, `--key-dir <dir>`
   [ throwaway-key tests ], `--records <file>`. Passphrase asked once at
   startup [ hidden prompt, three tries ], wiped after unlock.
2. `src/sourcecode.agent.sign` : the socket client [ info / begin / sign /
   end ]. Default socket path resolution mirrors the agent ;
   `P7_SIGN_AGENT_SOCKET` wins.
3. `src/sourcecode.console.update-signatures` : an `':agent:'` option
   [ `':agent=<socket path>:'` to override ]. When given : the passphrase
   key load is SKIPPED entirely ; instead info-check + begin [ full list ]
   + end around the existing sequential/pool logic. WITHOUT `':agent:'`
   the module is byte-for-byte the old behaviour [ the key loads, the
   prompt happens, the agent is never contacted ].
4. `src/source.cmd.get-code-signed` : threads `sign-path`,
   `sign-body-chksum`, `sign-body-length` into the footer data [ inert for
   every other caller ], and skips the 'private key loaded' precondition
   when agent mode is configured [ the key is deliberately NOT in this
   process ].
5. `src/source.fill_source_template` : the one signing seam -- when the
   agent socket knob is set, the sign buffer + path + body checksum go to
   the agent and only the returned signature is used ; otherwise the local
   `source.sign_data` call runs unchanged.

## open questions

1. **mlock + scan resistance** : the minimal core wipes the key on exit
   but does not mlock it [ standalone context, no IO::AIO ]. Acceptable
   for a dev-machine agent ?
2. **end-record verification tooling** : who consumes the signed end
   records ? [ PBS window audit needs a small verify tool ; not built
   here. ]
3. **agent idle lifetime** : ssh-agent lives with the login session ; the
   minimal agent runs until killed. An idle auto-lock [ p7-vault's
   LOCK_SECONDS shape ] belongs to the menu-zenka slice ?
4. **one agent or two** : when Y7O's vault-entry grants land, do they join
   p7-sign-agent [ one socket, op namespaces ] or get a sibling process ?
5. **approval echo on refusal** : a refused run currently gets a bare
   'denied' ; should the agent record refusal reasons per run [ forensics
   investment, CREDENTIAL-LAYERS' vigilant-system stance ] ?
6. **`:agent:` default-on** : once the menu approval exists, should
   update-signatures prefer the agent when a socket is present [ with an
   explicit `':no-agent:'` escape ], or stay strictly opt-in ?

## state

2026-10-29 : first slice COMPLETE and smoke-tested. files : this note,
`bin/p7-sign-agent`, `src/sourcecode.agent.sign` [ the socket client ],
and the three signing-path seams [ `:agent:` on
`sourcecode.console.update-signatures`, the sign-context fields +
conditional key check in `source.cmd.get-code-signed`, the agent branch in
`source.fill_source_template` ]. all pass `perl -c` /
`bin/format-code -c` [ including the perl 5.32 floor ].

throwaway smoke run [ `/tmp/hx4-run1`, throwaway Ed25519 keypair in the
real on-disk format : b32 files, `FY5`-prefixed twofish-encrypted
private half, passphrase piped via stdin, approval piped via stdin ;
test script `/tmp/hx4-smoke.pl`, since removed ] -- ALL CHECKS PASSED
against the current `bin/p7-sign-agent` [ `perl bin/p7-sign-agent
--key test-throwaway --key-dir <throwaway> --socket <tmp> --run-dir <tmp>`,
agent pid verified as the single listener before the ops ] :

- HELLO -> agent public half matched the throwaway `.public` file
- RUN [ 1-file list ] -> approved once ; `runs.log` begin record written
- SIGN -> returned signature VERIFIES with Crypt::Ed25519 against the
  presented buffer [ body BMW-512 + buffer BMW-384 binding both checked ]
- SIGN with a tampered buffer -> refused [ `binding mismatch` ]
- SIGN after a content modification -> refused [ `content changed` ]
- END -> signed end record `p7-sign-agent:end:<run>:<ntime>` VERIFIES
  with the throwaway public key ; runs.log shows begin \ sign \ end

bugs found BY the smoke run and fixed, all small :

1. `key_load` assigned the base32 TEXT to the public key instead of
   `decode_b32r()` output -> the agent died at startup with
   'public key decoding failed'. fixed.
2. `AMOS7::TERM::read_password_single` returns a LIST `( pass, abort )`
   in its no-tty stdin fallback ; the scalar-context call got the abort
   flag ['0'] instead of the passphrase -> 'key derivation failed'.
   fixed by calling in list context.
3. `join( qw| |, ... )` -- `qw| |` is an EMPTY list, so the separator
   silently became `''` [ unreadable `runs.log` lines, and `respond_ok`
   would have glued `OK` to its first field ]. fixed to `join( ' ', ... )`
   in `run_log_line` and `respond_ok`.
4. rerun nit : a second `RUN` with an already-open run id is refused
   [ `run already open` ], not treated as idempotent -- harmless for
   update-signatures [ one RUN per run ] but a client retry after a lost
   response aborts an approved run. candidate for a later slice.

test note : the throwaway-key derivation [ `AMOS7::13::key_32` truth
iterations ] takes ~70 s at agent start -- not a hang, wait for the
`agent-start` runs.log line before sending ops.

NOT done : a live `update-signatures :agent:` run against the real corpus
[ needs the owner's real unlocked key + the owner's y at the agent's
prompt ] ; the src client module has only been syntax-checked, not
executed inside the sourcecode zenka [ next step : a small staged run
against the throwaway key dir via `--key-dir` + `crypt.C25519.key_dir` ].
no commit, per task rules. the note and the new files are UNSIGNED on
purpose [ no signing in this slice ] ; they get their footers on the
next update-signatures run. test debris under /tmp was removed after
the run.

#,,..,...,,.,,..,,..,,,,,,.,,,...,,,,,,,,,,,.,..,,...,...,..,,,,.,,.,,.,.,.,.,
#BAXFDUARKTEPKQNEA4RPIPKVAAQFKVP6JWBCLGWETTPHWYMEZQCKQ5V6NAEP6OAKO3AUIPCCQBMLY
#\\\|RCK3V6IYKRXKRTO7SLKNZNZUZ5Q25MMEQWV6PYGJC7UE7UQ2STU \ / AMOS7 \ YOURUM ::
#\[7]JIWJYBMFU5HPJWG57FT6KXROFRDL24LKIT7JQN6DAIBWQBLKL2AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
