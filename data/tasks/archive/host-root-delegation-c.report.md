# host-root delegation : C client side [ lane 3 ] -- report

## files changed

- `bin/c_src/p-7-r.c`
- `bin/p7-auth-keypair-helper.pl`
- `bin/p7-link-upgrade-helper.pl` : NOT changed [ not needed ]

## changes

### bin/p7-auth-keypair-helper.pl

- **new subs** [ one statement parser for the C side ] :
  - `delegation_statement` : the spec's pack template
    `Z* a32 a32 n/a* N N n/a*` [ used by self-test to build vectors ]
  - `host_root_fingerprint` : `encode_b32r( Digest::BMW::bmw_384( <32 raw
    bytes> ) )` -> 77 chars [ checked : `Digest::BMW->new(384)->add` and
    `bmw_384` agree ; the module is the system XS one,
    `/usr/local/lib/x86_64-linux-gnu/perl/5.42.3/Digest/BMW.pm` -- not in
    `data/lib-path/pm` ]
  - `parse_delegation` : last 64 bytes = sig ; the statement must START
    with the literal bytes `p7 delegation v1\0` [ no `unpack Z*`, which
    would take any label ] ; then a32, a32, n-length name, N, N, n-length
    scope, every length checked, NO trailing bytes
  - `verify_delegation( wire, s_pub, now )` -> `( { fingerprint, name } )`
    or `( undef, reason )`. order : parse -> sig under the issuer pub ->
    not_before <= not_after -> not_before <= now <= not_after [ both ends
    inclusive ] -> subject eq the announced S_pub [ byte compare ] -> name
    charset -> scope
  - `pin_compare( dir, file, fp, strict )` : PIN_VALID \ PIN_MISMATCH \
    PIN_UNPINNED [ nothing written ] \ PIN_NEW [ O_EXCL, 0600, dir 0700 ] ;
    dies on an unreadable \ empty \ corrupt pin and on an OLD 52 char S_pub
    pin [ separate message ; never re-pinned ]
  - `arg_b32_var` : variable length b32 [ 1 .. DLG_B32_MAX = 2048 chars,
    length mod 8 in 0 2 4 5 7, decode, canonical re-encode ]
- **`check-pin <host> <port> <s_pub> <delegation> [strict]`** [ all public,
  argv ] -- the delegation is verified BEFORE the pin store is touched :

  | output [ stdout ]          | exit | meaning |
  |---|---|---|
  | `PIN_VALID <fp> <name>`    | 0 | pinned host-root ; incl. a ROTATED S it delegates |
  | `PIN_NEW <fp> <name>`      | 0 | first contact, fingerprint pinned now |
  | `PIN_UNPINNED <fp> <name>` | 5 | strict, nothing written |
  | `PIN_MISMATCH <fp> <name>` | 6 | other host-root, never re-pinned |
  | `DELEGATION_INVALID <why>` | 7 | pin store not read \ written |
  | `PIN_ERROR <why>`          | 8 | pin file unreadable \ corrupt \ `old server key pin` |

  pin file : unchanged path `~/.n/remote-keys/servers/<host>_<port>.public`
  [ host lowercased, `:` -> `_` ] ; content now `<77 char fingerprint>\n`.
  the old S-vs-pin compare is gone [ otherwise a rotated S could not pass ].

### bin/c_src/p-7-r.c

- **select reply** : exactly `TRUE <S_pub 52> <nonce 52> <delegation
  1..2048 b32>`. a v2 3-field reply is refused [ exit 4 ].
- **select line read** : buffer grown from 512 to fit the 4th field
  [ `5+52+1+52+1+DLG_B32_MAX+2` ] ; the line MUST end in `\n` inside the
  buffer -- before, `read_line` truncated silently at max-1 and the rest of
  an over-long line would have been read as the NEXT reply. refused now
  [ `too long or not terminated`, exit 4 ]. an embedded NUL [ byte count
  != strlen ] is refused too [ the old 3-field parse had the same gap ].
- `check_server_pin` takes the delegation and passes it to `check-pin`
  [ execv, no shell, unchanged `helper_exec` ]. the helper's fingerprint
  [ 77 b32 ] and name [ safe token `[A-Za-z0-9._-]` -- server supplied,
  gets printed ; no terminal escapes ] are re-checked in C before any
  fprintf ; a DELEGATION_INVALID \ PIN_ERROR reason only if it is a safe
  token.
- first contact prints `: pinned host-root <fingerprint> [ <name> ]`
  [ `-v` adds a hint to compare via `p7c crypt.C25519.host-root-fingerprint` ].
- exit codes : 0 ok ; 5 strict unpinned [ prints the offered fingerprint ] ;
  6 different host-root [ SECURITY WARNING ] ; 4 invalid delegation \ pin
  file error \ malformed reply. no auth line is sent on any refusal.
- S_pub is used for gen-auth \ verify-bind ONLY after check-pin returned 0
  [ unchanged flow : `bctx.s_pub` ] ; the binding checks are untouched.

## verification

### self-test [ `bin/p7-auth-keypair-helper.pl self-test` ] -- 56 ok, exit 0

**the delegation vector is SELF-BUILT** -- lane 1's TEST VECTOR was not in
`HOST-ROOT-DELEGATION.md` when I finished [ grep "vector" : no hit,
re-checked last ; no `src/trust.*` yet either ]. it must be swapped in
[ `%want` in `delegation_self_test` ] once lane 1 publishes it -- if lane
1's parameters differ, only the constants change.

self-built vector [ throwaway fixed seeds, never real ] :

```
host-root  = seed 32 x \x03   pub 5VESRRRI2HBMN2XJAM4JAWMVMEUVSJZ2LRR7SNRWYFDBJLEHG7IQ
S          = seed 32 x \x02   pub QE4XODVIPULV6VVDKRTMGTD6ZTFY3CURWTXDPIS56YHVXD6JWOKA [ AUTH-LINK-BINDING S ]
name       = test-host.cube   not_before 1700000000   not_after 1702592000   scope ''
statement  : 70372064656c65676174696f6e20763100ed4928c628d1c2c6eae90338905995612959273a5c63f93636c14614ac8737d18139770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25df60f5b8fc9b394000e746573742d686f73742e637562656553f100657b7e000000
sig b32    : LAL3UIQD4LJVCGNJWXL3TO7DZUD2PCAJ43B2XXPTNWQAQZDDX7GPYH3DYOFIJZUJEUDB2MKQSBZ4HSXBGCQX4GM5LOA4IOSEBMPFQAQ
fingerprint: ZF3ZY24EH66GU56YWPU2R2ZOXZLRVEUQJGHM3AWUQWVUNEJIYFOXRWF4XUSHAAXSUFOXWG2JGKC7G
```

```
[ 17 existing AUTH-LINK-BINDING lines : all ok, unchanged ]
ok   host-root pub
ok   delegation statement hex
ok   delegation sig
ok   host-root fingerprint
ok   delegation ok
ok   delegation ok at not_before
ok   delegation ok at not_after
ok   refuse expired
ok   refuse not yet valid
ok   refuse wrong subject
ok   refuse bad sig
ok   refuse altered statement
ok   refuse sig by another key
ok   refuse wrong label
ok   refuse trailing byte
ok   refuse truncated statement
ok   refuse too short
ok   refuse not_before after not_after
ok   refuse non-empty subject scope
ok   refuse unprintable name
ok   refuse delegation b32 too long
ok   refuse delegation b32 bad length
ok   pin strict unpinned
ok   pin strict wrote nothing
ok   pin first contact
ok   pin file mode 0600
ok   pin same host-root
ok   pin rotated S [ same host-root ]
ok   pin refuse wrong fingerprint [ foreign host-root ]
ok   pin refuse an old S_pub pin
ok   check-pin strict unpinned
ok   check-pin first contact
ok   check-pin second contact
ok   check-pin rotated S
ok   check-pin foreign host-root
ok   check-pin expired
ok   check-pin subject != announced S
ok   check-pin pin file [ lowercased host ]
ok   check-pin old S_pub pin
self-test ok
```

the `pin *` cases use a File::Temp dir ; the `check-pin *` cases run the
REAL verb as a subprocess with HOME = that temp dir and times around now.
`bin/p7-link-upgrade-helper.pl self-test` : still ok [ untouched ].

### compile [ `gcc -Wall -Wextra`, scratchpad only, not installed ]

1 warning, the pre-existing `read_line` sign-compare [ line 60 ] -- same as
the baseline [ HEAD file compiled : 1 warning ]. **no new warnings.**

### format-code

`bin/format-code -c` : syntax valid for both helpers. `bin/format-code`
applied to `p7-auth-keypair-helper.pl` [ reflow ; it also re-wrapped a few
pre-existing lines ]. AMOS7 signature blocks untouched -- need re-signing.

### e2e [ scratchpad mock `hrd-mock-server.pl` + `hrd-run-e2e.sh`, loopback, fresh throwaway HOME `hrd-home` with the test-vector C key ]

mock : host-root seed \x03 [ foreign : \x05 ], S seed \x02 [ rotated : \x04,
server_bind_sig signed with the rotated S ], name `mock-host.cube`, 30 d
window. run in sequence against ONE pin file :

| case | result |
|---|---|
| strict, no pin | exit 5, offered fingerprint shown, nothing written |
| first contact | `: pinned host-root ZF3Z...KC7G [ mock-host.cube ]`, auth_sig + client_bind_sig VALID, encrypted command ok, exit 0, pin 0600 \ dir 0700, content = 77 char fingerprint |
| second contact | exit 0, silent |
| **rotated S, same host-root** | **accepted**, binding verified with the new S, exit 0 |
| **foreign host-root** | **exit 6**, SECURITY WARNING, **no auth line sent** |
| expired delegation | exit 4 `[ expired ]`, no auth line |
| subject != announced S | exit 4, no auth line |
| bad delegation sig | exit 4, no auth line |
| 3-field [ v2 ] select reply | exit 4 |
| over-long select line [ 3000 char 4th field ] | exit 4 `too long or not terminated` |
| select line with an embedded NUL after field 4 | exit 4 `embedded NUL` |
| `-strict`, already pinned | exit 0 |
| `-v` | `host-root ... matches pin` ; pin unchanged after all of the above |
| old 52 char S_pub pin file | exit 4 `host-root pin file refused [ old server key pin ]` + hint ; pin unchanged |

## open questions \ spec points

0. **cross-lane state at hand-back** [ checked last ] : no TEST VECTOR in
   the spec, no `host-root-delegation-perl.report.md`, no `src/trust.*`,
   `auth.client.server_pin.check` still on 52 char S_pub pins.
0. **new runtime dependency** : the helper `use`s `Digest::BMW` [ system
   XS, not in `data/lib-path/pm` ]. a host whose `env perl` lacks it
   refuses EVERY p-7-r connection with the generic `host-root pin check
   failed` [ helper stderr goes to /dev/null ]. `bin/p7-deps` profile ?

1. **leaf scope** [ DEVIATION, stricter than the spec ] : the spec only
   says "name within the issuer's scope" with the anchor scope = `*`, and
   "scope empty in this step". I REFUSE a delegation whose own `scope` is
   non-empty [ `subject scope not empty` ]. if lane 1's `trust.verify`
   accepts it, relax one line in `verify_delegation` -- the two clients
   should agree.
2. **name** : not bound to the host connected to [ breaks IP connects ;
   the spec does not ask for it ]. only a charset check
   `^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$` [ for safe printing ] -- not
   required to end in `.cube`. should the client check `<x>.cube` ?
3. **upper bounds not in the spec** : 4th field <= 2048 b32 chars
   [ ~1280 bytes ; a 253 char hostname needs ~670 ]. the spec's `n/a*`
   allows 64 KiB names \ scopes. lane 1's server should never emit more ;
   worth stating a max in the spec.
4. **pin file format must match the Perl client** :
   `auth.client.server_pin.check` still holds 52 char S_pub pins [ lane 1
   changes it ]. C writes `<77 char fingerprint>\n` and refuses any other
   content, an old 52 char pin with a dedicated message. both clients share
   the file -- a different format on either side fails closed.
5. **old pins** : the spec says nobody has pinned yet. any 52 char pin that
   exists [ e.g. from testing the binding step ] is refused, not migrated ;
   the user removes it after checking the host-root out of band.
6. **exit code for an invalid delegation** : 4 [ general refusal ], not 6 ;
   6 stays "different host-root". a bad sig \ wrong subject could also be
   read as an attack -- your call.
7. the TEST VECTOR swap [ above ] once lane 1 publishes it.
8. carried over, still open : `bin/c_src/p7c.c` old link-upgrade argv
   forms [ previous report, point 5 ] ; hardcoded helper paths.

#,,.,,,,.,,,.,..,,.,,,,,,,,,,,,.,,...,.,,,.,,,..,,...,...,...,,,.,,,,,.,.,.,,,
#5O6SX52C6KCOFK56IFYYN3MD3QPF5FJI5BZVDNHTDV7HWMIVH2VJKLAEWGML5ARQIHLN7456YJLA2
#\\\|G2WAXINJTNNFGOSCCUNT23SQVPUSEC22ISIBV2M4ZIOYJVIDBXY \ / AMOS7 \ YOURUM ::
#\[7]KVO2PSL5MZW2QECX7J24MLNQ62NZLRDQG67SU3SHPTHDHZH7JSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
