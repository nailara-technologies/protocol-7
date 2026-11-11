# N7FS stage 6 : intake holders and relays

2026-11-11. follows `N7FS-SEALED-REPLICAS.md` section 5 [ safety rules 1-2 ]
and `N7FS-PLACEMENT.md`. the role word is `intake` [ a holder ] ; `incoming`
stays the category of the stage-2 pool.

## what a relay is

an intake holder takes sealed data quickly [ near, fast, small ] and passes it
on to durable holders. it never counts as a copy. a relay has two halves :

1. **blind copy** : ciphertext blobs move from the intake to a durable
   holder. a blob is named by the checksum of its own bytes, so the receiving
   side can refuse anything changed without any key
2. **adoption** at home : the durable holder's map gains the nodes. each
   holder's map wraps node keys under its own category keys, so home unwraps
   with the intake's and wraps again with the durable's, keeping node id and
   ciphertext. one commit, with the trees whose manifest it now holds

only home can do half 2 : it needs the root. the head is never relayed : it
has one locator on every holder [ derived from the root ], and copying it
would replace the target's head.

## safety

- a relayed copy counts only after a `holder-check` of the target **at its
  current head version**. a receipt now records the head version it checked
  and counts only while the head is unchanged : any commit [ place, relay,
  drain ] waits for the next check. before this, a fresh receipt also counted
  nodes committed after it
- draining an intake keeps its own failure domain : an intake copy counts
  zero, so a durable holder in the same domain is a full copy for it. a
  durable holder's drain still needs copies in other domains
- `holder-gc` removes unmapped blobs, so a relay copies and adopts in one
  command. a blind copy without adoption would be collected

## as built [ part 1 ]

```
n7fs relay <from> <to> -root-key <key> [ -dry-run ]
```

- both are registered holders, `<to>` durable. it copies the blobs of every
  node `<from>` maps and `<to>` does not, checks each against its name,
  publishes it through the usual temporary + rename, then adopts them all
- blobs already on `<to>` with the right size are reused : a rerun after an
  interruption finishes the job
- a node whose blob is missing on `<from>` is skipped and reported
- the target's quota and reserve hold as for `place` [ one shared room
  calculation ] : a relay that does not fit is refused before any copy
- the copy goes through home [ download, check, upload ]. the background
  path below removes home from the data path, not from adoption
- eviction is the existing `holder-check <to>` then `holder-drain <intake>`
  and `holder-gc <intake> -only-root -delete`

tests : `bin/test-scripts/test-n7fs-intake.pl` [ changed blob refused,
interrupted copy finished, old receipt ignored, drain within one domain,
recovery from the target, packed and single content blobs, a reserve refused,
relays to and from an ssh holder through the fake ssh ].

## as built [ part 2 : fan-out by push ]

with several remote holders, home seals and uploads ONCE, to a hub holder,
and the hub pushes the same ciphertext on. home's uplink carries the data
once instead of once per holder ; home only adopts [ small map uploads ].

```
n7fs relay <hub> <far> -root-key <key> -list    at home : list + pending
n7fs-push <holder-dir> relay-list.<tag> <alias>  on the hub : no n7fs key
n7fs relay <hub> <far> -root-key <key> -adopt   at home : map what arrived
holder-check <far>                              then it counts
```

- `-list` writes `relay-list.<tag>` into the hub's holder directory : blob
  names only [ ciphertext the hub already holds ]. `<tag>` is a checksum of
  the target, not its name. home keeps the same names under
  `<host-dir>/relay-pending/`
- `n7fs-push` asks the receiver which listed blobs it has, sends the rest one
  by one, and is safe to rerun. `-bwlimit <bytes/s>` caps it
- `n7fs-receive` is the forced command on the receiving host. it answers
  `has <names>` and `put <name> <size>` only ; it accepts a blob only when
  its bytes match its checksum name, publishes by link [ never replaces ],
  and refuses everything else. a store head is not named by its checksum, so
  it can never be written. `-max-bytes <n>` caps the directory
- `-adopt` maps the nodes whose blobs arrived with the right size and reports
  how many still wait. pending names clear once nothing waits
- `holder-gc` on the target keeps pending names until they are adopted

the receiving host's `authorized_keys`, one line per sending host :

```
command="<repo>/bin/n7fs-receive <holder-dir>",restrict ssh-ed25519 AAAA..
```

the sending host needs that key's private half and a `Host` alias for the
receiver in its own `~/.ssh/config`. a stolen sending key can only add blobs
that match their names ; `-max-bytes` bounds how much. running `n7fs-push`
from a timer on the hub is a deployment step, not built here.

tests : `bin/test-scripts/test-n7fs-push.pl` [ list, adopt before arrival,
push, rerun, gc keeps pending, adopt, check, recovery ; the receiver refusing
wrong bytes, a head, a replacement, other requests, a path, a full holder ].

## open [ owner decisions ]

1. **which hosts push to which** : one hub with a key into each other remote
   [ simplest, one origin ], or pairwise keys. the hub then also needs the
   bandwidth to every other provider
2. **the first receiver's role** : an intake that counts zero until the
   copies are confirmed, or a durable holder that counts at once and forwards.
   both work with the commands above ; drain only applies to an intake
3. whether `place` should seal to the hub only and relay from there by
   itself [ the hub as a write cache ], instead of the manual list \ adopt

#,,,.,...,,.,,.,.,...,...,,..,,,.,...,,,.,,..,..,,...,...,...,,.,,..,,..,,...,
#XRBUTR4QNKYWSD3ODPCG4XSU45SFMYWCSKJ5RVMF2XA4STQGLNGLGDLXK7O7FJI4RNVTKVWDG4LZ4
#\\\|5UQUHP5UFJJE24AN4AXPQADKZWATR6YIPYFIWPF4EMO5OG7E4RF \ / AMOS7 \ YOURUM ::
#\[7]K3W53434T3GYZDWVH2GOTU2E4PTGJWSNHET3N2ZVR2IPHXHMAKDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
