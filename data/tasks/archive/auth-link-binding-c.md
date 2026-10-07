# auth-keypair + link-upgrade mutual binding : C client side [ lane C ]

implement the CLIENT half of `data/md/design/AUTH-LINK-BINDING.md` [ read
ALL of it, incl. "hardening rules" and the test vector ] in the C remote
client and its helpers. NO backwards compatibility.

## files you own [ ONLY these ]

- `bin/c_src/p-7-r.c`
- `bin/p7-auth-keypair-helper.pl`
- `bin/p7-link-upgrade-helper.pl`

another agent changes the server + Perl client [ src/, other tests ] in
parallel -- do not touch anything else. no zenka start \ reload, no sudo,
no commit, no signing, no real network, no git command that changes the
tree. never read real key dirs [ `~/.n/` ] ; tests use tempdirs \ env
overrides.

## what changes

- select reply now `TRUE <S_pub> <nonce>` : p-7-r checks \ pins S_pub
  [ its existing TOFU pin logic -- find it ; align the pin location with
  the spec's `~/.n/remote-keys/servers/<host>_<port>.public` if it is
  elsewhere, report what you did ] BEFORE sending auth
- auth line : `gen-auth` takes username + nonce + S_pub [ public values ]
  and signs the v2 message
- link-complete : `link-complete <nonce_sid> <client_bind_sig>` ; read
  `link-complete-ok <server_bind_sig>` and verify it against the pinned
  S_pub ; any failure -> abort the connection with a clear stderr line
- new helper verbs for building \ verifying the bind sigs, argv = PUBLIC
  values only [ nonce, S_pub, ephemeral PUBLIC keys, nonce_sid, encoding,
  username ]

## known issue to report, NOT fix yet

the existing helper verbs appear to pass SECRETS on argv
[ `compute-dh <client_secret_b32> ..`, `derive-key <shared_secret_b32> ..`,
maybe `encrypt|decrypt` ] -> readable by other local users via
`/proc/<pid>/cmdline`. confirm exactly which verbs + args, list them in
the report. do not change them in this task [ the user decides scope ] --
but your NEW verbs must not repeat it.

## verification

- the helper's message builder reproduces the spec's test vector exactly
  [ hex + all three sigs ] -- add a `self-test` verb that checks it and
  exits non-zero on mismatch ; run it
- `gcc -Wall -Wextra` compile of p-7-r.c [ into the scratchpad \ a temp
  dir, never install it ] with no new warnings
- `bin/format-code -c` on the two .pl helpers

## report

write `data/tasks/auth-link-binding-c.report.md` : changes, the argv
secrets finding [ verbs + args ], compile + self-test output, open
questions. spec wrong or ambiguous -> STOP on that point and report it.

#,,..,,.,,.,,,.,.,.,,,,,.,,,,,...,,..,..,,,.,,..,,...,...,,,,,...,,,.,,,.,,,,,
#FSFPWAR5UVKANFA2ZRLYOIG2P5IVMNFYFP7M6YZCZOFF2LATGICQTQDYWW35RNQWUVPRXWOTDHDMA
#\\\|WLAEVHMW4AO67HLMQWPETTRE3WZKTGFCM5J53H6WARIILSKXOTO \ / AMOS7 \ YOURUM ::
#\[7]FFNU5V3FYZET5HTI3X3JYOQBKCHEIZI3MR4GFZ2V4JRJ3Z4XFEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
