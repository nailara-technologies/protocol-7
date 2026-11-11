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

## open [ owner decisions ]

1. **background push without home** : a small agent on the intake host pushes
   blobs straight to a durable host. that needs an ssh key on the intake host
   that the durable host accepts. proposal : a forced command in the durable
   host's `authorized_keys` that only appends new blobs into the holder
   directory [ write to `<name>.upload`, check the name against the checksum,
   rename ; never overwrite, never delete, refuse the head locator ]. this
   changes the rented servers' trust set-up, so it is the owner's call
2. **what the agent pushes** : home writes a relay list to the intake, the
   blob names to forward and the destination, signed by the host key. names
   are ciphertext the intake already holds, so the list reveals nothing new.
   a dishonest intake can only skip or add blobs ; adoption checks both
3. **adoption timing** : with background pushes, blobs wait unmapped on the
   durable host until home adopts. `holder-gc` must then skip names in a
   pending-relay list, or gc runs only after adoption
4. whether `place` should seal to an intake first when it is the fastest
   holder, and relay from there [ the intake as a write cache ]

#,,,,,..,,.,,,,,,,,,,,..,,...,,..,,..,..,,,.,,..,,...,...,,.,,...,.,.,,,,,.,.,
#3ZMHVX77S4WT7AMS7SDBJUV64IP2F24LRQW4QAZ35PD2K5N5BUN2FHFRKBFOL25AWPVOH3CGKKOC2
#\\\|Y5KFB6A3QWGQEFGUTDSIHGHGPOL2Y46THNIL3THWPVNESUI3TH4 \ / AMOS7 \ YOURUM ::
#\[7]LTIT4JNV4YAOBELWNFDQXEAGS5H2UAOKXWAOLYCMFQQZ7WNPBGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
