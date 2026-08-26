## [:< ##

# name = ZENKA-IDENTITY-COMPONENT
# descr = per-zenka/per-host identity as a chain of signed keys, built
#         entirely on existing crypt.C25519 primitives — the "identity"
#         candidate component derived from the umbrella doc

spun off 2026-07-30 from `ZENKA-IDENTITY-AND-TRUST-TOPOLOGY.md`
(umbrella doc), per its own "how to use this document" process: the
"identity" candidate component has enough of an answer to act on. this
document narrows umbrella questions 1, 3 and 5 for this component's
scope; it does not close them there.

## the core move: identity IS the tree

the umbrella doc's candidate list could be read as two components —
"identity" first, "signature trees" (delegation/vouching chains) as a
later phase. they are one. a per-zenka/per-host identity **is** a chain
of signed keys:

- the identity is a keypair. nothing more is required to exist.
- the identity's *standing* is the set of signature edges pointing at
  that key from other keys.
- the "tree" is not a second structure bolted on later — it is what the
  edge set looks like once more than one key exists.

so this is one component whose natural output is the tree, designed
once, not two sequential phases. this follows the repo's
demystification discipline (`demystification-through-correspondence`
reasoning template): every piece below is a standard, named mechanism —
self-generated identity key, web-of-trust vouching edge, TOFU pin,
old-signs-new key rotation — already present in working code. no new
cryptographic primitive is introduced anywhere in this document.

## layer 0: what already exists and is reused as-is

```
crypt.C25519.gen_keys_typed          Ed25519 keypair generation,
                                     optional seed passphrase (virtual keys)
crypt.C25519.sign_keys               signer key signs subject's pubkey →
                                     writes <subject>.ks.<SKEY> (signature)
                                     and <subject>.sk.<SKEY> (signer pubkey)
crypt.C25519.verify_key_signature    one-hop edge verification, raw
crypt.C25519.create_signature_request  subject signs
                                     <ntime:subject-chksum:signer-chksum>
                                     proving it holds its own private key
                                     and *asked* to be vouched for
crypt.C25519.load_all_signatures /
key_signatures_list                  the edge set in memory: %signatures
crypt.C25519.store_remote_key        TOFU pin writer
                                     (remote.<host>_<port>.public, ntime-
                                     stamped, atomic rename, 0600)
discover's presence-packet path      working multi-hop chain verification
                                     rooted in a known/trusted key
keys zenka virtual keys              passphrase-rederived keys, never at
                                     rest — existing loading mode for
                                     user-held identity keys
```

the signature footer shape from `SIGNED-COMMAND-INTERFACE.md` (BMW384
hash + C25519 signature + key fingerprint + ntime + nonce) is reused
verbatim wherever this component needs a signed statement on the wire
(first-contact key announcement, rotation announcement). same footer,
same crypto, new context — exactly as that doc already did relative to
AMOS7 module signatures.

## layer 1: genesis — generate on first use

no pre-provisioning, no central CA, no certificate expiry. a zenka or
host that needs to sign something and has no key yet generates one:

```
zenka 'jobsite' first signed operation on host 'alpha':
  → no identity key found for jobsite@alpha
  → crypt.C25519.gen_keys_typed( 'jobsite.alpha', type => 'Ed25519' )
  → keypair stored under the owning user's key dir
  → first signed statement carries the public key inline,
    footer marked NEW KEY (SIGNED-COMMAND-INTERFACE's marker)
  → receiver stores it as a TOFU pin via store_remote_key semantics
```

a key with zero incoming signature edges is a **valid root**. this is
umbrella question 1's answer (b) — every key its own root — taken as
the base case, with answer (a) — single root with members — expressible
later as nothing more than a dense set of edges toward one key
(`global-root` / `protocol-7.base` already exist as de-facto anchors).
both perspectives hold over the same data; nothing in this layer
pre-registers a key into either model, so the question does not need
further resolution before this component is built.

**deliberately left open (human decision):** the key-naming convention.
`<zenka>.<host>` is used in examples here because it reads naturally,
but nothing in the mechanism depends on it — the name is a filename
stem, the identity is the key. also open: whether per-zenka keys live
in the per-user key dir (`~/.n/user-keys/`, today's only storage) or a
per-zenka directory. the mechanism works either way; the choice is
operational.

## layer 2: vouching — one edge, already implemented

an identity gains standing when another key signs its public key. that
edge is `crypt.C25519.sign_keys`, unmodified:

```
host 'alpha' base key vouches for jobsite's key:
  sign_keys( 'jobsite.alpha', 'alpha.base' )
  → jobsite.alpha.ks.ALPHA-BASE   # Ed25519 sig of jobsite.alpha's pubkey
  → jobsite.alpha.sk.ALPHA-BASE   # alpha.base's pubkey, for verification
```

properties that fall out of using the existing primitive unchanged:

- **non-exclusive by construction.** each voucher is its own
  `.ks.<SKEY>` file. any number of keys can vouch for the same subject;
  no edge displaces another. this is umbrella question 3's free,
  nested, non-exclusive grouping — delivered by the file layout, not by
  a new grouping structure.
- **mutual consent, not unilateral assertion.**
  `create_signature_request` already implements the request half: the
  *subject* key signs `<ntime:subject-chksum:signer-chksum>`, proving
  it holds its own private key and asked for this specific voucher.
  the vouching flow is: subject creates `.rq` request → signer verifies
  the request signature → signer runs `sign_keys`. unsolicited vouching
  is detectable (no matching request).
- **verification is a walk, already working.** verify one hop with
  `verify_key_signature`; walk from any root the verifier already
  trusts (a TOFU pin, or `global-root`). discover's presence-packet
  path does exactly this multi-hop walk today.

## layer 3: rotation — old key signs the handoff, as an edge

reused from `SIGNED-COMMAND-INTERFACE.md`'s signed rotation ceremony,
restated in this component's vocabulary: rotation is a **succession
edge** — a `sign_keys` edge where the signer is the old key and the
subject is the new key of the same entity:

```
jobsite.alpha rotates:
  → gen_keys_typed( 'jobsite.alpha.2' )       # new keypair
  → sign_keys( 'jobsite.alpha.2', 'jobsite.alpha' )
      # old key vouches for its own successor — possession of the old
      # private key IS the authorization, no rogue rotation possible
  → rotation announced in a signature footer:
      #<BMW384 of: rotation-statement + ntime + nonce>
      #\\\|<C25519 sig by OLD key>  \ / AMOS7 \ YOURUM ::
      #\[7]<OLD key fingerprint>  7  CMD SIGNATURE :: ROTATE
  → verifiers: validate old-key signature, follow the succession edge,
    update the TOFU pin to the new key
```

continuity of identity is the chain `old → new`, not the name. the old
key's incoming edges do not transfer automatically — re-vouching after
rotation is a deliberate act by each voucher, which is the correct
semantics (a compromised old key cannot drag its reputation onto the
new one without each voucher re-checking).

**deliberately left open (human decision):** whether succession edges
get a distinguishing marker (reserved signer/subject naming, or a
marker inside the request payload) or are recognized structurally
(signer and subject known to be the same entity). both are cheap;
which one is a policy choice, not a mechanism gap.

## layer 4: the tree as data — two relations, not collapsed

"the tree" is the edge set, nothing else:

```
on disk, per subject key:            in memory:
  <name>.ks.<SKEY>   one per voucher   %signatures via
  <name>.sk.<SKEY>   voucher's pubkey  load_all_signatures /
  <name>.rq.<SKEY>   consent request   key_signatures_list
  <name>.vp          virtual-key pubkey
```

two relations coexist over this one edge set, and this component keeps
them as **two coexisting, non-collapsed relations** per umbrella
question 3:

- **lineage** — the derivation/vouching subgraph: who begat whom, who
  stands behind whom. the tree proper. `KEY-TREE-AUTHORITY-FIELD.md`'s
  `derive(parent,label)` chain, when it lands, is a structured way of
  producing edges in this relation.
- **membership** — a group is just a key, and membership in it is an
  ordinary vouching edge from that group key to the member key. a key
  derived under `jobsite.sync.*` can hold membership edges from group
  keys with no relation to its derivation lineage — the edge set is a
  graph; "the tree" is a *view* (the lineage subgraph), not the
  storage. nothing merges the two relations for convenience.

a verifier answers "is this key in group G?" the same way it answers
"is this key rooted at R?": walk edges. same code path, different
starting root.

## layer 5: delegation — downstream, not reinvented

per umbrella question 5's already-made synthesis: delegation = reuse
`sign_keys` for the derivation/vouching edge (this component), plus a
scoped, attenuable authority token carried as signed data on the
existing `sign_data`/`verify_sign` pair. the token's detail is a
separate focused doc; this component only guarantees the token has a
verifiable chain to hang from. no new crypto primitive — structure on
existing sign/verify, as the identity survey established.

## naming collisions — flagged, checked, not resolved here

per the umbrella doc's question 8, checked before adding structure:

- **`credentials.*` vs `cred-mesh.*`** — still unresolved. this
  component adds no credential namespace and takes no position; any
  downstream credential-storage component must reconcile this first.
- **`remote.*` vs `remote-host.*` TOFU pin filenames** — **resolved
  2026-07-30**: exhaustive re-check confirmed *no programmatic writer
  of the `remote-host.*` pattern exists anywhere in `src/`*. the
  `remote-host.local_42.public`-style files seen on disk were manually
  created test artifacts, not evidence of a missing writer function.
  the canonical writer is `crypt.C25519.store_remote_key` →
  `remote.<host>_<port>.public`, and that convention is what this
  component builds on. note: `data/ai-mem/claude/
  project-cross-host-trust-bootstrap-gap.md` still carries the older
  "writer likely exists somewhere, not found yet" framing — correcting
  that memory file is out of scope for this document and left as a
  follow-up.

## explicitly out of scope

- **transport-agnostic handshake** (umbrella question 6) — generalizing
  TOFU/chain-verification to bare HTTP. separate candidate component;
  it consumes this one's edges and pins.
- **discovery/bootstrap** (umbrella question 7) — nameserv TXT/SRV
  extension. later-phase.
- **credential storage/use** — cred-mesh, largely as-is, waiting on
  this component.

## open questions left for a human

1. key-naming convention (`<zenka>.<host>` vs free-form) and per-zenka
   key storage location (per-user key dir vs per-zenka dir) — layer 1.
2. succession-edge marking: explicit marker vs structural recognition —
   layer 3.
3. group-key custody: who holds a group key's private half when the
   group has several administrators (shared secret, N-of-M, or chained
   officer keys) — layer 4. all are expressible; none chosen here.
4. whether lineage vs membership edges ever need to be distinguishable
   in-band (e.g. for "show me only the tree" queries), or whether
   signer-key naming conventions suffice — layer 4.

## relation to other documents

- `ZENKA-IDENTITY-AND-TRUST-TOPOLOGY.md` — the umbrella doc this is
  spun off from; narrows questions 1, 3, 5 for this component's scope
  and should be linked back from the "identity" candidate entry.
- `SIGNED-COMMAND-INTERFACE.md` — source of generate-on-first-use,
  TOFU pinning, the signed rotation ceremony, and the signature footer
  shape, all reused here verbatim in a new context.
- `KEY-TREE-AUTHORITY-FIELD.md` — the namespace-derivation tree; the
  lineage relation of layer 4 is where it plugs in when implemented.
- `CHECKSUM-PARENTING-NAMESPACE-TREES.md` — candidate primitive for how
  grouping/nesting edges could be made collision-proof without explicit
  edge storage; compatible with, not required by, this component.
- `data/ai-mem/claude/project-cross-host-trust-bootstrap-gap.md` (ai
  memory) — the research pass behind the umbrella doc; carries the
  stale `remote-host.*` framing noted above.
- `data/ai-mem/claude/project-zenka-cryptographic-identity-survey.md`
  (ai memory) — ground-truth inventory establishing that delegation
  needs structure, not new primitives.

#,,.,,.,.,,.,,,..,,,,,...,...,..,,,.,,,.,,,,,,..,,...,...,...,...,,,.,.,.,,,,,
#4O7PSZ3LZB553PJSUM6J2VZCXKNRIWZ7DPUDC7SHI6SEQLT3FO5X5AXOF3GED5QJ3R5HWT3WAOHIU
#\\\|AZXCAMZUUHV66LGAQUXROM3K4LD4KNZ5P6WBDB3EU3GK3EKTPQM \ / AMOS7 \ YOURUM ::
#\[7]XHJKTN6YNB7O6OIA3RJHGK2IG6PXW4IUPZXT2TG6VE6JGCSL2ECY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
