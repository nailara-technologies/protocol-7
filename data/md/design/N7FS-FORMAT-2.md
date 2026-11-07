# N7FS format 2 : as built

2026-11-07. the changes from [ `N7FS-FORMAT-1.md` ], next to the decisions in
[ `N7FS-SPEC.md` ]. paths, content addressing, immutable writes, mount records
and the epoch conversion window are unchanged.

## records

new disks from `init` have `store_format: 2`. meta and state use the existing
signed container : magic + format byte + label + payload + signer_pub + sig.
the format byte is 2, so a format-1 reader refuses them. their new labels are
exactly :

| kind  | magic  | record format | label                | signer   |
|-------|--------|---------------|----------------------|----------|
| state | `P7FT` | 2             | `p7 n7fs state:0001` | store key |
| meta  | `P7FN` | 2             | `p7 n7fs meta:0001`  | store key |

id, mount and use records keep their format-1 containers and labels. the v1
meta and state label spellings are unchanged. a plain format-1 state or meta
record is not valid as the corresponding format-2 record.

the only verification key is `store_pub` from the parent-signed id record.
`signer_pub` must equal it, and the signature is checked against it ; a valid
signature from another key is refused. readers need no store secret. get,
find, verify and status work with the public store alone and on another host.

the delegated secret remains at `<host dir>/stores/<disk>.store.key`.
assimilate, upgrade and confirm load it and check it against the id before any
change. a missing or mismatched key refuses. the store does not provision this
secret to a second host : an operator must copy or otherwise provision it
separately before that host can write. no automatic transfer was added.

## signed meta and location binding

format-2 meta adds `epoch`, the base32 epoch directory name, to the format-1
fields. `disk`, `epoch`, `amos` and `bmw` must all match the node's actual
location. the size and content checksum are verified as in format 1.

every meta record is authenticated and bound by both `find` and full node
verification. consequently a forged, damaged, unsigned or misplaced record
fails find, get-by-name, verify, and get by exact address loudly, naming the
node ; it is never skipped. unchanged-repeat checks authenticate existing meta
before comparing it.

## authenticated state and downgrade rules

the newest state decides the store format and is never silently replaced by an
older readable one. a format-2 state signature must verify, and its record
format must match `store_format`. a plain state is accepted only when no
signed state file remains in the state directory.

the host's signed use witness now also carries `store_format`, the highest
store format seen. old witness records without it mean format 1. use records
add `written` : it orders the append-only witness files, while `first` and
`last` remain the mount rollback window. old records without `written` use
`last`. an upgrade appends a format observation without inventing a mount
event, so conversion from 1 to 2 immediately raises the pin to 2. the
observation is appended after the signed state switch ; a host-side I/O failure
at that point is not rolled back. the signed-state directory rule still applies,
and a later mount event raises the witness.

a state below the witnessed highest format is refused unless
`-allow-rollback` is given. attach keeps its existing rollback option ; status,
get, find and verify accept it too. get, find and verify use the witness when
the host key is available, without requiring the store secret. this catches a
plain downgrade even when the attacker deleted all signed states on a host
with a witness.

**remaining gap** : without the host key a reader cannot authenticate that
host's witness, so it proceeds as first contact. a first-contact host, or a
host whose witness has been lost, cannot distinguish a lone plain state from a
genuine format-1 disk after all signed states were deleted. the directory rule
alone cannot close that case.

## conversion 1 -> 2

the production codec and `register_step` chain provide `upgrade` and
`confirm`. no existing node or record is rewritten. every old node and its
content is verified before the first write, then each node is written and
verified under the next epoch of the existing validity window. the old epoch
stays byte-identical through confirmation and is released only under the
format-1 window rules.

converted meta preserves `import_ntime` and every other field, updates the
location binding to the new epoch, and adds JSON
`converted_from_unsigned: true`. this explicitly records that the format-1
names were not authenticated ; re-hashing verified content, not the old name
assertions. `find -all` displays `converted_from_unsigned` beside the import
ntime. new imports after conversion are ordinary signed format-2 records and
do not carry the flag.

format-1 disks remain readable until converted. get, find and status print a
visible warning that meta names are unsigned ; they do not refuse solely for
being format 1.

## unchanged behavior and known limits

per-source unchanged-repeat handling, `-remove`, `-dry-run`, `get -out`, name
ambiguity checks, checksum verification and synced immutable writes are
unchanged.

signatures still do not detect deletion of a meta record or a whole node ;
that needs references or a manifest. the format pin does not order two signed
states within format 2. replaying an older signed state is otherwise limited
only by the existing mount \ use witness window while that history survives.
witness protection is local to each host, not a network-wide current-state
proof.

#,,,,,,.,,..,,,,.,..,,..,,.,.,,..,..,,,,.,...,..,,...,...,...,,,,,.,.,..,,,..,
#EG4X3CGF64RDLCF4TYTS25K4USB6OPC43MIISJCBVOEZ4WF6PK5UKR2PDOPAADZ7KLHIP4PSLTYMI
#\\\|7DSM7TSB2EXPOSP3COOTNTPGWS3YDQDK45LZUJCLGY27F6QIJNX \ / AMOS7 \ YOURUM ::
#\[7]7D4FUB3X5EIWQBPTIAK7X2IIYAZ7XL7R6SZMQBZJ3LM2NAWNWUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
