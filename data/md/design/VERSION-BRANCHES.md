# version branches : code as namespace views [ draft ]

design [ 2026-10-28, user ]. part of the one entity model
[ ai-mem : vision-2026-10-28-entity-types-one-model ] -- versions are
branches in the dot namespace like any other.

## three views

- `p7.nfs` : the current state from the local perspective [ what this
  host runs now ]
- `protocol-7.<source version>` : every source version as its own next
  level branch, e.g. `protocol-7.32H3XL7KKA-10311.0` -- its content never
  changes, only new siblings appear
- `protocol-7-release.<release version>` : releases only, e.g.
  `protocol-7-release.AMOS7-v6.48.9`, with a 'latest' pointer

## supersession is read from the name

a source version is `<id>-<counter>.<revision>` :

- a higher counter is a **successor** [ normal progress ]
- the same counter with a higher revision is a **replacement** :
  `protocol-7.32H3XL7ZYX-10311.1` supersedes `protocol-7.32H3XL7KKA-10311.0`
- the reading layer treats a replacement as important : a host on the
  superseded revision should move, and views show the superseded one as
  replaced, not merely older

no separate 'superseded' record is needed for this case -- the name
carries it.

## revocation

- release versions have no revision part : a release is never superseded
  through its name -- withdrawing one is technically a **key-style
  revocation** of that exact identifier [ signed, checked fail-closed ]
- content stays immutable : a version's bytes are not unpublished
- **trust** is what gets revoked : a signed statement 'version \ release X
  : do not run' [ a vulnerable release, a compromised signing key ]
- hosts check it before a start or an upgrade ; 'latest' skips revoked
  entries ; revoked versions stay visible as revoked [ nothing disappears
  silently ]
- same shape as the trust chain's distrust lists and revocation
  [ data/md/design/TRUST-CHAIN-STEP2.md ] -- releases become one more
  subject kind

## per-release keys [ user ]

- **one key per release, delegated immutably** : the signer [ a user or a
  zenka ] issues a fresh C25519 key, delegates to it the right to sign
  exactly this release, signs with it
- **pre-signed revocation** : before the secret goes, the release key also
  signs its own revocation statement ; that statement is encrypted into
  the SIGNER's vault [ user or zenka branch ] -- unused until needed
- **the secret is discarded** when the signing intent completes : nobody,
  the signer included, can ever sign different content as this release ;
  the only remaining act is the revocation
- **the public key is recorded** in the release history chain, and a
  revocation lands in the same chain when it is published
- **the old data stays obtainable** wherever it is cached -- depending on
  interest ; forensics zenki keeping history create that interest by
  themselves
- a pre-signed statement cannot carry a later reason or date -- pre-sign
  a small set [ e.g. 'vulnerable' \ 'key compromise' \ 'withdrawn' ] if
  the reason should be stated ; the publication time comes from the chain

## import and re-signing [ user ]

the scalable native alternative to appending multiple signature footers :
each file carries exactly ONE signature [ the current authority's ], the
history lives in the trailer archive and the release chain -- files do not
grow with every party in the chain.

taking a release into another signing space [ e.g. an organization key ] :

- **proof first** : the import records that the original checksums and
  signatures verified -- a signed import statement naming the original
  release key, its chain entry and the content checksums
- **then re-sign** with the importing key ; the result points back to the
  import statement, so its origin stays provable
- **signed modifications** : changes on top are signed by the importing
  key as derived from the imported content, never as the original
- **restoration** : the original signed content and the proof are kept
  [ branch \ vault ], so any modified state can be taken back to the
  verified original
- **the stripped signatures are archived** : re-signing replaces each
  file's signature trailer ; the originals go into one compressed, B32
  encoded archive [ small : trailers only ]. with the original public key
  kept too, the cryptographic tree stays complete -- a later modification
  of the original content can still be detected, long after re-signing
- **provenance, not authority** : a deployment's security profile needs to
  assign NO authority to the original protocol-7 source signature key --
  the deployment trusts only its own key ; the original key and the
  archived trailers remain evidence of origin
- **re-signing is the hand-over gate** : it is preceded by the security
  review and is the last translating step -- authority passes to the
  local key there, and only there
- **the complete revocation check happens once, at the gate** : every
  original key and release is checked against the full revocation chain
  while re-signing -- a check too costly for every later signature
  verification. afterwards a verification only needs the local key [ and
  its own revocation state ]
- **the distributed revocation problem stops existing there** : the local
  authority knows all its own systems and can notify them of a key change
  at any time -- revocation becomes an internal announcement, not a
  global lookup

## distributed re-signing [ user ]

a full re-sign is long on one host [ ~2.5 hours before the parallel
workers ; they now default to 2 per cpu ] -> a network workload, spread
over all available hosts by default :

- **the hosts already hold the data** ; the job is checksum-based : the
  file list with its checksums is fixed before signing starts, so no
  worker can sign anything else
- **throwaway worker keys** : the authority issues each worker a fresh
  key, delegated for exactly its share [ the checksum list ] -- discarded
  when the share is done
- **time-locked by default** : each delegation is valid only inside the
  job's time window ; after it, the worker key can sign nothing, even if
  its secret survived somewhere
- **verification by the coordinator** : every returned signature is
  checked against the fixed checksums before it counts
- open : whether the authority key then signs one manifest over all
  worker signatures [ keeps 'one authority' at the top of each chain ]
  or the delegations alone carry it

## open

- where the revocation statements live [ the release signing key's
  branch ] and how fast they propagate [ discover \ links ]
- whether a replacement [ same counter, higher revision ] alone triggers
  an upgrade prompt or an automatic move, per host policy

#,,,.,.,,,.,.,.,.,..,,,,,,,,.,,,.,.,,,.,,,.,,,..,,...,..,,.,.,..,,.,,,.,.,,..,
#3BFZOCO3BPJFMJQB73YTVDFJIYT72JH5BXLX2PAMPEHNJBR6YKLT5ZOLUK3PY6WZGXJI27G3YQB6K
#\\\|QA2YCDJX74KM2POOJ57L2YQ767LDMZOT54L6HDEDTYO4HFOPE43 \ / AMOS7 \ YOURUM ::
#\[7]IK67ARCUBSVYCDF7GWD6W433H5R3FIXPW2ZQ7FYINGVCFGGLE6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
