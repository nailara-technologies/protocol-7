# host-root delegation : PERL core [ lane 1 ] -- report

2026-10-07. nothing committed or signed, no zenka touched, no real key dir
read. every touched file : `bin/format-code` + `bin/format-code -c` clean.

## files

new :
- `src/crypt.C25519.key_path` : THE resolver [ spec API ]. root-held
  detection by lstat only [ EACCES as non-root = quiet 'user' ]. for
  `root` : ownership rule on every call ; the checked root/ is held OPEN
  and the returned paths go through `/proc/self/fd/<n>/` so a swap of
  root/ after the check cannot redirect a read or write [ `key_dir_path`
  = the plain path, for display ]. names with `/`, `\0`, `.`, `..`
  refused ; unknown options \ holder values refused
- `src/crypt.C25519.root_key_dir` : `<home of system.amos-zenka-user>/.n/user-keys/root`
- `src/crypt.C25519.delegation_file` : `<backend key dir>/<S>.dlg` [ one place ]
- `src/crypt.C25519.host_root.create` : v7-zenki + root only [ else level
  1, skip ] ; mkdir 0700, chown 0:0 + chmod on the opened dir ; existing
  root/ breaking the rule is refused, never adopted ; writes via
  `write_keys( .., { holder => 'root' } )`
- `src/crypt.C25519.cmd.host-root-fingerprint` : fingerprint from the
  .dlg [ parse + sig valid ], data = the 77 chars only
- `src/trust.statement` : build \ parse \ parse_wire \ wire ; exact
  label, every length, no trailing bytes, re-pack must equal input,
  canonical b32, wire <= 2048 ; list context `( undef, reason )`, scalar
  undef
- `src/trust.fingerprint` : `encode_b32r( bmw_384( pub ) )`
- `src/trust.verify` : generic walker [ <= 8 hops ], order as the spec's
  acceptance rules ; leaf scope must be empty
- `src/v7-zenki.delegation.issue` \ `.startup` \ `.retry` : see below
- `bin/test-scripts/test-host-root-delegation.pl`

changed :
- `crypt.C25519.key_vars` : key_dir \ key_basepath \ key_filename from
  key_path ; optional 2nd arg `{ holder => 'root' }` ; refused root-held
  -> undef [ no user fallback ] ; root holder -> uid \ gid 0 ; a PATH
  passed as name [ `encrypted_key` does that ] -> hash without key file
  paths [ was garbage paths, now none -- no caller used them ] ; base
  key cache only for user holder without options
- `key_exists` : through key_path [ was its own dir listing ]
- `keyfiles` : USER dir only, also as root [ coordinator rule ] ; a
  root-held name -> `()`
- `load_keypair` : no usable key path -> FALSE [ no die ]
- `write_keys` : 4th arg = key_path options ; root holder needs euid 0,
  all files 0600, never chowned ; temp files `sysopen O_EXCL|O_NOFOLLOW`
  and owner \ mode set on the HANDLE [ was path chown after rename ] --
  applies to user keys too
- `post_init` : calls host_root.create BEFORE the auto_load_keys return ;
  old host-root block removed
- `auth.auth_select` : .dlg read fresh every select [ <= 2048 ],
  self-anchored trust.verify [ parse, sig, time, subject == announced S,
  name, scope ] BEFORE a nonce is drawn \ stored ; reply `TRUE <S>
  <nonce> <dlg>` ; refusal logged level 0
- `auth.client.auth-keypair.authenticate` : requires the 4th field
- `auth.client.server_pin.check` : 4th param = delegation ; pin = 77 char
  fingerprint ; 52 char pin refused [ never migrated ] ; first contact
  verifies BEFORE pinning ; log `pinned host-root <fp> [ <name> ]`
- `cfg/zenki/v7-zenki/zenka.v7` : `trust` in modules.load ;
  `[v7-zenki.delegation.startup]` after `[init-done]`
- `cfg/zenki/{cube,external,users}/zenka.v7` : `trust` in modules.load
  [ REQUIRED wiring outside the named files : without it
  `$code{'trust.verify'}` does not exist there -- every call site checks
  and refuses ]
- 125 `cfg/zenki/*/subroutines.load-early` : new module names added
  exactly where `bin/dev/dep-graph -list-subs` reaches them [ nothing
  else changed ; p7-log, keys, user-edit have key_path ]
- tests : `test-auth-link-binding.pl` [ client section : 4th field,
  fingerprint pin, rotated S accepted, foreign host-root refused,
  expired, > 2048, old pin ; logged lines matched rendered ],
  `test-host-root-keygen.pl` [ post_init section : hands over to
  host_root.create with auto_load_keys on AND off ]
- spec : acceptance rules [ coordinator \ lane 3 ], Perl module API,
  TEST VECTOR

## issuing

`v7-zenki.delegation.issue` [ root only ] : host-root must resolve
`holder root` [ never a same-named user-dir key ] ; loaded, used,
unloaded. S [ `<amos-zenka-user>.base.public`, user holder ] is read and
the .dlg written AS THE BACKEND USER [ euid \ egid switched for that
block, restored and checked ] -- the spec says "chown to the backend
user" ; this yields the same end state [ owner backend user, 0644,
temp + rename ] without root ever writing \ following paths in a
directory the backend user owns. temp `O_EXCL|O_NOFOLLOW`. kept while it
verifies for the CURRENT S under the CURRENT host-root with the current
name and >= 7 d left ; otherwise reissued [ covers S rotation at once ].
startup : issue now, daily timer, plus a 60 s retry [ max 60 ] until the
first success [ fresh host : cube writes S after v7-zenki starts ].

## test vector [ = lane 3's inputs, reproduced byte for byte ]

in `data/md/design/HOST-ROOT-DELEGATION.md` under "test vector" :
host-root seed 32 x \x03, S seed 32 x \x02, `test-host.cube`,
1700000000 .. 1702592000, scope '' ; fingerprint
`ZF3ZY24EH66GU56YWPU2R2ZOXZLRVEUQJGHM3AWUQWVUNEJIYFOXRWF4XUSHAAXSUFOXWG2JGKC7G`.
computed by a hand-written pack AND trust.statement ; identical to
lane 3's statement hex + sig.

## test output

```
test-host-root-delegation.pl : passed : 186  failed : 0
test-auth-link-binding.pl    : passed : 155  failed : 0
test-host-root-keygen.pl     : 45 ok, all checks passed
test-external-link.pl        : passed : 84  failed : 0   [ unchanged ]
test-link-upgrade-client.pl  : all checks passed         [ unchanged ]
test-keys-root-held.pl [ lane 2, run only ] : 121 checks, 0 failed
```

## mutation checks [ each restored byte-identical, cmp verified ]

| mutation | delegation test | binding test |
|---|---|---|
| file uid 0 check removed [ key_path ] | 2 fail | - |
| dir uid 0 check removed | 2 fail | - |
| dir mode 0700 check removed | 6 fail | - |
| dir symlink + isdir checks removed | 0 fail [ masked : a symlink's lstat mode 0777 fails the mode check, and O_NOFOLLOW refuses the open ] | - |
| fingerprint compare [ trust.verify anchor ] | 1 fail | - |
| fingerprint compare [ server_pin.check ] | 0 [ trust.verify catches ] | 1 fail |
| expiry check | 3 fail | 1 fail |
| subject check | 4 fail | 1 fail |

## deviations needing sign-off [ implementation choices, not in the spec ]

- .dlg written under a temporarily switched euid \ egid [ backend user ]
  instead of root + chown ; same end state. the switch and the egid
  restore ran only against rewritten test variables [ needs root ] ;
  failing to regain euid 0 now refuses the issue [ untested ].
- the held-directory `/proc/self/fd` resolver [ `key_dir_fd` ; needs
  /proc ]. modules that still build paths from `key_vars{key_dir}`
  [ encrypted_key, single_file, load_keys_from_secret .. ] get the plain
  root/ path for root-held keys : checked, but not race-proof.
- 60 s retry [ max 60 ] on top of the daily timer.
- `write_keys` hardening [ O_EXCL|O_NOFOLLOW temp, chmod \ chown on the
  handle ] applies to EVERY key, not only root-held.
- real `load_keypair` through the fd paths not run [ the test reads the
  written files back through them instead ] ; issuing stubs load_keypair.
- `root_key_dir` calls `base.get_homedir` on every key_vars call [ level
  2 log each time, level 0 if the backend user does not exist ].
- every touched src \ cfg file [ incl. 4 zenka.v7 + 125 load-early lists
  ] has a stale signature footer : sign before any restart or commit.

## open questions \ spec problems

1. **BLOCKING : `<system.hostname>` is never set** anywhere [ only read
   in `base.p7ref.self`, with a 'localhost' fallback ]. `bin/Protocol-7`
   sets `<system.node.name>` [ hostname(), domain stripped ]. issuing
   follows the spec literally and FAILS CLOSED [ level 0, no .dlg ] ->
   live, cube would refuse every auth-keypair. decide : node.name, or set
   system.hostname somewhere. one line in `v7-zenki.delegation.issue`.
2. scope grammar : only `''` [ nothing ] and `*` [ everything ] ; any
   other value refuses ; the leaf must be empty [ coordinator rule ].
3. not_before = now [ spec ] : a client whose clock lags sees a freshly
   renewed .dlg as "not yet valid" for that lag. backdate a few minutes ?
4. pre-existing gap [ not from this lane ] : `external` and `users` do
   not load the `auth` namespace, yet the client path calls
   `<[auth.binding.message]>` [ authenticate + handshake ] -- looks like
   an undefined `$code{}` call there since ad31ddd5a. `trust` is added ;
   `auth` is not [ heavier, server-side init ] -- please check.
5. `crypt.C25519.cmd.host-root-fingerprint` is reachable in every zenka
   [ public value ] ; add it to base.init_code's cube-only list ? not my
   file.
6. residual : a root-held key READ goes through the held fd, so a swap
   of root/ cannot redirect it ; the parents of root/ are still the
   backend user's -- deleting \ renaming root/ only causes the fresh
   host-root \ refusal the spec accepts. `/proc` must be mounted [ else
   root-held keys are refused, fail closed ].
7. old 52 char S pins [ binding tests, live check ] are refused : delete
   `~/.n/remote-keys/servers/*.public` once.

## what kimi's e2e test [ test-auth-link-binding-e2e.pl ] needs

currently 38 ok \ 7 fail against the new wire. it needs : compile
`trust.statement` \ `trust.fingerprint` \ `trust.verify` and
`crypt.C25519.delegation_file` \ `root_key_dir` [ or stub
delegation_file ] ; a valid `<S>.dlg` in the server's backend key dir
[ `<system.amos-zenka-user>`, stubbed `base.get_homedir` ] signed by a
throwaway host-root ; expect `TRUE <S> <nonce> <dlg>` ; pin content = the
77 char host-root fingerprint ; "server announces a DIFFERENT S" now
means : different S delegated by the SAME host-root -> ACCEPTED
[ rotation ], different host-root -> refused ; the replay case needs the
4-field reply.

## full test output [ 2026-10-07 ]

### test-host-root-delegation.pl
```
: test vector [ trust.statement, data/md/design/HOST-ROOT-DELEGATION ]
  ok   : statement hex
  ok   :   :.. == an independent hand-written pack
  ok   : sig b32
  ok   : wire b32
  ok   : fingerprint [ 77 chars ]
  ok   :   :.. 77 chars
  ok   : parse_wire round trip : every field, statement, sig
: trust.statement refuses invalid fields
  ok   : issuer_pub 31 bytes
  ok   : issuer_pub 33 bytes
  ok   : subject_pub 31 bytes
  ok   : subject_pub wide characters
  ok   : name empty
  ok   : name with a space
  ok   : name with a newline
  ok   : name missing
  ok   : scope with a space
  ok   : scope missing
  ok   : not_before negative
  ok   : not_before not digits
  ok   : not_after > 2**32-1
  ok   : not_after before not_before
  ok   : not_after == not_before : built
  ok   : fields not a hash
  ok   : unknown mode
  ok   : scalar context refusal : undef [ never a reason ]
  ok   : list context : ( undef, reason )
: trust.statement parse is exact
  ok   : trailing byte
  ok   : truncated
  ok   : other label
  ok   : leading byte
  ok   : name length beyond the end
  ok   : the vector parses
  ok   : wire : one char more [ not canonical ]
  ok   : wire : lowercase
  ok   : wire : over 2048 chars
  ok   : wire : sig only
  ok   : wire : undef
: trust.verify
  ok   : valid : { name, anchor, not_after }
  ok   : wrong fingerprint
  ok   : bad signature
  ok   : expired [ not_after + 1 ]
  ok   : now == not_after : valid [ inclusive ]
  ok   : not yet valid
  ok   : now == not_before : valid [ inclusive ]
  ok   : subject mismatch
  ok   : leaf scope not empty
  ok   : name charset [ leading - ]
  ok   : scope violation [ two hops, issuer scope empty ]
  ok   : two hops, issuer scope * : valid
  ok   : undefined scope grammar : refused
  ok   : second issuer != first subject
  ok   : scalar context refusal : undef [ never a reason ]
  ok   : empty chain
  ok   : no anchors
  ok   : now not a number
  ok   : subject not 32 bytes
: crypt.C25519.key_path [ resolver ]
  ok   : root_key_dir : <backend key dir>/root
  ok   : delegation_file : <backend key dir>/<S>.dlg
  ok   : delegation_file : refuses a path
  ok   : no root/ : holder user, today's key dir
  ok   : name with / : refused
  ok   : name .. : refused
  ok   : empty name : refused
  ok   : unknown holder value : refused
  ok   : unknown option : refused
  ok   : host-root in root/ : holder root [ detected ]
  ok   :   :.. paths through the held directory fd
  ok   :   :.. the fd path reaches the real file
  ok   : other name : still user
  ok   : holder root forced for a new name
  ok   : swapped root/ : the held fd path still reads the checked directory
  ok   :   :.. a new call re-opens [ the new directory, checked anew ]
: key_path : every ownership-rule violation is refused
  ok   : root/ not owned by uid 0
  ok   :   :.. logged at level 0
  ok   : root/ mode 0750
  ok   :   :.. logged at level 0
  ok   : root/ mode 0701
  ok   :   :.. logged at level 0
  ok   : root/ a symlink to a uid 0 0700 directory
  ok   :   :.. logged at level 0
  ok   : secret not owned by uid 0
  ok   :   :.. logged at level 0
  ok   : private mode 0640
  ok   :   :.. logged at level 0
  ok   : secret mode 0644
  ok   :   :.. logged at level 0
  ok   : public mode 0664
  ok   :   :.. logged at level 0
  ok   : secret a symlink
  ok   :   :.. logged at level 0
  ok   : public a directory
  ok   :   :.. logged at level 0
  ok   : public mode 0600 : accepted
  ok   : public mode 0644 : accepted
  ok   : forced root, root/ missing : refused
: key_path as non-root [ root/ 0700, not ours to look into ]
  ok   : root-held name as non-root : holder user [ kernel decides ]
  ok   :   :.. quiet : no warning, no level 0 log
  ok   : forced root as non-root : refused
: key_vars \ key_exists \ keyfiles \ load_keypair through the resolver
  ok   : key_vars( host-root ) : root paths, owner 0
  ok   : key_vars( alpha ) : user paths
  ok   : key_vars( a path ) : no key file paths [ encrypted_key compat ]
  ok   : key_vars : root-held rule violated -> undef [ no user fallback ]
  ok   : load_keypair : refused root-held key -> FALSE, no die
  ok   : key_exists : refused root-held key -> undef
  ok   : key_exists( host-root ) : TRUE
  ok   : key_exists( host-root.secret )
  ok   : key_exists( host-root:seed-phrase ) : FALSE
  ok   : key_exists( alpha ) : TRUE
  ok   : key_exists( alpha.secret ) : FALSE
  ok   : key_exists( nothing ) : FALSE
  ok   : key_exists( virtual ) : 4
  ok   : keyfiles() [ euid 0 ] : USER dir only, nothing from root/
  ok   :   :.. no host-root file
  ok   : keyfiles( host-root ) [ euid 0 ] : nothing
  ok   : keyfiles() [ euid 1000 ] : USER dir only, nothing from root/
  ok   :   :.. no host-root file
  ok   : keyfiles( host-root ) [ euid 1000 ] : nothing
: write_keys : root-held
  ok   : non-root : root-held key NOT written
  ok   :   :.. nothing on disk
  ok   : root : written
  ok   :   :.. secret mode 0600
  ok   :   :.. private mode 0600
  ok   :   :.. public mode 0600
  ok   :   :.. nothing in the user dir
  ok   :   :.. erased from memory
  ok   :   :.. no temp files left
  ok   :   :.. passes the ownership rule
  ok   :   :.. public + private read back through the fd paths
: post_init -> host_root.create
  ok   : v7-zenki, root, auto_load_keys 0 : post_init returns
  ok   :   :.. host-root generated
  ok   :   :.. root/ created 0700
  ok   :   :.. host-root written to root/
  ok   : second start : host-root present, not regenerated
  ok   : v7-zenki as non-root : skipped, no root/
  ok   :   :.. logged at level 1
  ok   : cube [ root ] : not created
  ok   : existing root/ 0755 : refused
  ok   :   :.. nothing written
: v7-zenki.delegation.issue
  ok   : first issue : TRUE
  ok   :   :.. the .dlg verifies under host-root for S
  ok   :   :.. name <system.hostname lowercased>.cube
  ok   :   :.. 30 days from now, scope empty
  ok   :   :.. mode 0644, owner the backend user
  ok   :   :.. root regained after the backend-user section
  ok   :   :.. host-root unloaded
  ok   :   :.. no temp file left
  ok   : second issue : kept unchanged
  ok   : 8 days left : kept
  ok   : 6 days left : renewed
  ok   : S rotated : reissued for the new S at once
  ok   : planted temp symlink : refused
  ok   :   :.. the symlink target untouched
  ok   : .dlg a symlink : replaced by a file
  ok   :   :.. the symlink target untouched
  ok   : S public file a symlink : refused
  ok   : <system.hostname> unset : refused
  ok   :   :.. logged at level 0
  ok   : host-root not root-held [ user dir only ] : refused
  ok   : not running as root : skipped
  ok   : restored : issued
: auth.auth_select [ the 4th field ]
  ok   : valid .dlg : TRUE <S> <nonce> <delegation>
  ok   :   :.. nonce stored
  ok   : missing .dlg : refused, no nonce stored
  ok   :   :.. logged at level 0
  ok   : unparsable .dlg : refused, no nonce stored
  ok   :   :.. logged at level 0
  ok   : .dlg over 2048 chars : refused, no nonce stored
  ok   :   :.. logged at level 0
  ok   : expired .dlg : refused, no nonce stored
  ok   :   :.. logged at level 0
  ok   : .dlg for another S [ subject mismatch ] : refused, no nonce stored
  ok   :   :.. logged at level 0
  ok   : .dlg with a bad signature : refused, no nonce stored
  ok   :   :.. logged at level 0
  ok   : trust modules not loaded : refused, no nonce stored
  ok   :   :.. logged at level 0
: client pin [ auth.client.server_pin.check ]
  ok   : first contact : accepted
  ok   :   :.. pin = host-root fingerprint + \n
  ok   : rotated S, same host-root : ACCEPTED
  ok   : different host-root : refused
  ok   : announced S != delegated subject : refused
  ok   : no delegation : refused
  ok   : first contact, bad delegation : refused, NOTHING pinned
: cube command crypt.C25519.cmd.host-root-fingerprint
  ok   : returns the host-root fingerprint from the .dlg
  ok   : no .dlg : false
  ok   : no unexpected perl warnings

passed : 186  failed : 0
```

### test-auth-link-binding.pl
```
: test vector [ auth.binding.message ]
  ok   : C pub b32
  ok   : S pub b32
  ok   : auth msg hex
  ok   : auth_sig b32
  ok   : client message = label . transcript hex
  ok   : server message = label . transcript hex
  ok   : client_bind_sig b32
  ok   : server_bind_sig b32
: builder refuses invalid fields
  ok   : client : short server_nonce
  ok   : client : long server_eph
  ok   : client : nonce_sid 0
  ok   : client : nonce_sid 2**32
  ok   : client : nonce_sid not digits
  ok   : client : empty encoding
  ok   : client : username with space
  ok   : client : wide char username
  ok   : client : undef client_eph
  ok   : unknown kind
  ok   : auth : short session_pub
  ok   : auth and client messages differ
: server plugin [ plugin.auth.auth-keypair, v2 only ]
  ok   : v2 line : accepted
  ok   : v2 line : AUTH_TRUE
  ok   : v2 line : link_binding pending
  ok   : v2 line : C public key kept for link-complete
  ok   : v2 line : nonce kept for link-complete
  ok   : v1 line [ sig over the bare session pubkey ] : refused [ 2 ]
  ok   : v1 line [ sig over the bare session pubkey ] : no binding state
  ok   : v1 line [ sig over the bare session pubkey ] : nonce deleted
  ok   : wrong nonce : refused [ 2 ]
  ok   : wrong nonce : no binding state
  ok   : wrong nonce : nonce deleted
  ok   : wrong S_pub : refused [ 2 ]
  ok   : wrong S_pub : no binding state
  ok   : wrong S_pub : nonce deleted
  ok   : no nonce selected : refused
  ok   : two fields : protocol mismatch, refused
  ok   : two fields : nonce deleted
: base.handler.auth [ pending : not authenticated, not registered ]
  ok   : auth-keypair pending : state change [ 0 ]
  ok   : authenticated = pending
  ok   : not initialized
  ok   : not registered for the user
  ok   : removed from the unauthenticated user
  ok   : auth timeout stays armed
  ok   : state 1 entered
  ok   : auth-keypair without pending binding : disconnect
  ok   : auth-keypair without pending : never authenticated
  ok   : unix method : authenticated yes [ unchanged ]
  ok   : unix method : registered for the user
  ok   : unix method : initialized
  ok   : unix method : auth timeout disarmed
: state 1 gate [ base.handler.command ]
  ok   : pending : 'list users\n' refused [ FALSE + disconnect ]
  ok   : pending : 'exit\n' refused [ FALSE + disconnect ]
  ok   : pending : 'TRUE something\n' refused [ FALSE + disconnect ]
  ok   : pending : '(12)link-upgrade\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-upgrade+\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-upgrade-x\n' refused [ FALSE + disconnect ]
  ok   : pending : '!TRM!\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-pub-key AAAA\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-upgrade utf7 extra\n' refused [ FALSE + disconnect ]
  ok   : pending : 'cube.link-upgrade\n' refused [ FALSE + disconnect ]
  ok   : pending : 'SIZE 3\nabc' refused [ FALSE + disconnect ]
  ok   : pending : incomplete line waits [ 1 ]
  ok   : pending : 'link-upgrade\n' passes the gate
  ok   : pending : 'link-upgrade utf7\n' passes the gate
  ok   : pending : aliased link-upgrade refused after resolution
: link-complete [ base.handler.link-upgrade ]
  ok   : pub key + encoding accepted
  ok   : client eph key kept
  ok   : valid client_bind_sig : complete [ 0 ]
  ok   : reply : link-complete-ok <server_bind_sig>
  ok   : server_bind_sig verifies with S over the same transcript
  ok   : state 3 entered
  ok   : link_binding done
  ok   : authenticated yes
  ok   : registered for the user
  ok   : nonce deleted [ single-use ]
  ok   : auth timeout disarmed once bound
  ok   : nonce sid stored
  ok   : missing client_bind_sig : disconnect [ 2 ]
  ok   : missing client_bind_sig : no link-complete-ok
  ok   : missing client_bind_sig : no state 3
  ok   : missing client_bind_sig : nonce deleted
  ok   : missing client_bind_sig : still not authenticated
  ok   : missing nonce_sid : disconnect [ 2 ]
  ok   : missing nonce_sid : no link-complete-ok
  ok   : missing nonce_sid : no state 3
  ok   : missing nonce_sid : nonce deleted
  ok   : missing nonce_sid : still not authenticated
  ok   : client_bind_sig by another key : disconnect [ 2 ]
  ok   : client_bind_sig by another key : no link-complete-ok
  ok   : client_bind_sig by another key : no state 3
  ok   : client_bind_sig by another key : nonce deleted
  ok   : client_bind_sig by another key : still not authenticated
  ok   : client_bind_sig over another nonce_sid : disconnect [ 2 ]
  ok   : client_bind_sig over another nonce_sid : no link-complete-ok
  ok   : client_bind_sig over another nonce_sid : no state 3
  ok   : client_bind_sig over another nonce_sid : nonce deleted
  ok   : client_bind_sig over another nonce_sid : still not authenticated
  ok   : nonce_sid 0 : disconnect [ 2 ]
  ok   : nonce_sid 0 : no link-complete-ok
  ok   : nonce_sid 0 : no state 3
  ok   : nonce_sid 0 : nonce deleted
  ok   : nonce_sid 0 : still not authenticated
  ok   : nonce_sid 2**32 : disconnect [ 2 ]
  ok   : nonce_sid 2**32 : no link-complete-ok
  ok   : nonce_sid 2**32 : no state 3
  ok   : nonce_sid 2**32 : nonce deleted
  ok   : nonce_sid 2**32 : still not authenticated
  ok   : client_bind_sig not base32 : disconnect [ 2 ]
  ok   : client_bind_sig not base32 : no link-complete-ok
  ok   : client_bind_sig not base32 : no state 3
  ok   : client_bind_sig not base32 : nonce deleted
  ok   : client_bind_sig not base32 : still not authenticated
  ok   : loaded server key ne announced S_pub : refused
  ok   : pending state 2 : unexpected line disconnects, nonce deleted
  ok   : pending : link-complete before negotiation refused
  ok   : pending : timeout disconnects, nonce deleted
  ok   : client eph key not 32 bytes : refused
  ok   : non-pending : link-complete without sig unchanged
: pending sessions invisible to send.local \ route_to_target
  ok   : route_to_target check : cfg_bool( pending ) is false
  ok   : route_to_target check : yes is true
  ok   : send.local : pending session skipped
  ok   : send.local : pending session not reachable by user name
  ok   : send.local : control [ yes ] sent
: client [ auth.client.auth-keypair.authenticate + server pin ]
  ok   : first contact : binding context returned
  ok   : first contact : pin file written
  ok   : pin file mode 0600
  ok   : pin file holds the host-root fingerprint
  ok   :   :.. 77 chars
  ok   : pinned : logged at level 0 with fingerprint + name
  ok   : context : server_nonce, server_pub, username, base_key_name
  ok   : auth line carries the v2 auth_sig
  ok   : signed with the explicit base key name
  ok   : pinned key matches : accepted
  ok   : rotated S delegated by the pinned host-root : accepted
  ok   :   :.. pin unchanged
  ok   : foreign host-root : refused
  ok   :   :.. logged MISMATCH
  ok   : foreign host-root : nothing signed, no auth line sent
  ok   : foreign host-root : pin NOT replaced
  ok   : announced S != delegated subject : refused, nothing sent
  ok   : expired delegation : refused, no auth line
  ok   : select reply without delegation : refused, no auth line
  ok   : delegation over 2048 chars : refused
  ok   : select reply without nonce : refused, no auth line
  ok   : short nonce : refused, no auth line
  ok   : no host \ port for the pin : refused
  ok   : host with a path : refused, nothing written
  ok   : unreadable pin file : refused
  ok   : garbled pin file : refused
  ok   : old 52 char S pin : refused
  ok   :   :.. logged as old pin
  ok   :   :.. NOT re-pinned
: client handshake refuses a bad server_bind_sig
  ok   : server_bind_sig by the pinned S : accepted
  ok   : server_bind_sig by another key : refused
  ok   : link-complete-ok without server_bind_sig : refused

passed : 155  failed : 0
```

### test-host-root-keygen.pl
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
  ok   : explicit secret with an UNTRUE public key : kept as given
  ok   :   :.. public key derived from exactly that secret
  ok   : no unexpected perl warnings in gen_keys
: post_init : host-root creation is independent of auto_load_keys
  ok   : v7-zenki, auto_load_keys on : host_root.create called once
  ok   : v7-zenki, auto_load_keys on : post_init itself neither generates nor writes
  ok   : v7-zenki, auto_load_keys off : host_root.create called once
  ok   : v7-zenki, auto_load_keys off : post_init itself neither generates nor writes
  ok   : cube, auto_load_keys on : host_root.create called once
  ok   : cube, auto_load_keys on : post_init itself neither generates nor writes
  ok   : cube, auto_load_keys off : host_root.create called once
  ok   : cube, auto_load_keys off : post_init itself neither generates nor writes
  ok   : the real gen_keys for host-root : valid key

all checks passed
```

### test-external-link.pl
```
  ok   : regex.base.usr taken from the real base.regex module
external.link.open : argument validation
  ok   : missing name -> false
  ok   : missing name -> no base.open call
  ok   : missing host -> false
  ok   : missing host -> no base.open call
  ok   : missing port -> false
  ok   : missing port -> no base.open call
  ok   : non-numeric port -> false
  ok   : non-numeric port -> no base.open call
  ok   : empty args -> false
  ok   : empty args -> no base.open call
  ok   : invalid link name 'bad name' -> false
  ok   : invalid link name 'bad/name' -> false
  ok   : invalid link name '-lead' -> false
  ok   : invalid link name 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -> false
  ok   : invalid link name 'a[b]' -> false
  ok   : invalid names -> no base.open call
  ok   : a valid name passes the name check
  ok   : no as_username and no cfg.link_user -> false
  ok   : no identity -> no base.open call
external.link.open : failure paths close the socket
  ok   : base.open undef -> false "cannot connect"
  ok   : open failure -> auth not attempted
  ok   : auth undef -> false
  ok   : auth undef -> socket closed
  ok   : auth undef -> no handshake
  ok   : auth dies -> die propagates
  ok   : auth dies -> socket closed
  ok   : handshake ( 0, { error } ) -> false with the error text
  ok   : handshake failure -> socket closed
  ok   : handshake failure -> no session
  ok   : handshake dies -> die propagates
  ok   : handshake dies -> socket closed
  ok   : session.init undef -> false
  ok   : session.init undef -> socket closed
  ok   : session.init undef -> no init_state
  ok   : client_activate false -> false
  ok   : client_activate false -> session.shutdown( id ) once
  ok   : client_activate false -> no link registered
  ok   : auth returns no binding context -> false
  ok   : no binding context -> socket closed
  ok   : no binding context -> no handshake
external.link.open : success and reuse
  ok   : success -> ( true, sid )
  ok   : auth got as_username and the link name
  ok   : auth got { host, port } for the server key pin
  ok   : handshake got the binding context auth returned
  ok   : base.open got ip.tcp output host port
  ok   : session.init got the link name as session name
  ok   : init_state( id, 1 ) called
  ok   : client_activate got id and the handshake link
  ok   : session marked authenticated = yes
  ok   : external.links entry = { sid host port user }
  ok   : success -> socket left open
  ok   : reuse : same name host port -> same sid
  ok   : reuse -> no new base.open
  ok   : same name other host -> false "link lnk is open to .."
  ok   : same name other port -> false
  ok   : conflict -> no new base.open
  ok   : conflict -> old entry kept
  ok   : stale entry -> a new link is opened [ new sid ]
  ok   : stale entry -> one new open
  ok   : stale entry replaced by the new link
  ok   : as_username //= external.cfg.link_user
external.cmd.connect
  ok   : args '' -> false usage
  ok   : args 'onlyname' -> false usage
  ok   : usage failure -> no timer
  ok   : no reply_id -> false
  ok   : no reply_id -> no timer
  ok   : valid -> mode deferred
  ok   : ONE timer with after 0
  ok   : timer carries a callback
  ok   : link.open not called before the timer fires
  ok   : no reply before the timer fires
  ok   : cb -> link.open called once
  ok   : link.open got { name host port as_username }
  ok   : link.open true -> cmd_reply( reply_id, true, "linked .. session N" )
  ok   : port defaults to 42 when unset
  ok   : as_username undef when not given [ link.open applies cfg ]
  ok   : port defaults to protocol-7.remote.default-port when set
  ok   : bare-string args without reply_id -> reply route error
  ok   : link.open false -> that false result passed through
  ok   : link.open dies -> cb itself does not die
  ok   : link.open dies -> cmd_reply false "link setup failed : <msg>"
  ok   : die message trailing whitespace trimmed
  ok   : link.open returns undef -> still a reply [ "no result" ]

passed : 84  failed : 0
```

### test-link-upgrade-client.pl
```
: handshake success
  ok   : handshake success : ( 1, { .. } )
  ok   : shared secret is 32 bytes
  ok   : shared secret == the server DH result
  ok   : nonce sid in 1 .. 2**32-1
  ok   : nonce sid == what the server received
  ok   : client_bind_sig verifies with C over the server-side transcript
  ok   : client signed with the context base key name
: binding failures
  ok   : server_bind_sig by another key : ( 0, { error } ), no secret handed out
  ok   : link-complete-ok without sig : ( 0, { error } ), no secret handed out
  ok   : server_bind_sig not base32 : ( 0, { error } ), no secret handed out
  ok   : no binding context : ( 0, { error } )
  ok   : context with a short server_pub : refused
  ok   : nothing sent without a valid context
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
: fail closed [ never plaintext on an encrypted link ]
  ok   : no key : nothing sent, never the plaintext, no die
  ok   : no key : session shut down
  ok   : no key : complains
  ok   : invalid key : nothing sent, never the plaintext, no die
  ok   : invalid key : session shut down
  ok   : invalid key : complains

all checks passed
```

#,,..,.,,,,,,,.,.,.,,,,..,,.,,,,.,...,..,,..,,..,,...,...,.,,,,.,,,..,...,.,,,
#LJRHENQ3TKXCP4PDQOC4NTAEUDUBLQTJUTHPQ43OYGXISODSBD7PBSKAPA7JBOCQ6E2R3QEG5RJO6
#\\\|FNK6TA2EN6TF7WAOSZVFE2OQD3SOZTUDLHVJCAAH7QKOO5GPDJV \ / AMOS7 \ YOURUM ::
#\[7]5M4QEY5ZM6GZMCVMZ5PK74NA22IIOVS55ROZKMMESKLF6FQAUIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
