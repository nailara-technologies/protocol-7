---
name: triple-twofish-name-entropy
description: triple-pass Twofish (fwd-bwd-fwd) on xz payload to defeat header-bruteforce, keyed with name/checksum as entropy source — small crypto idea, may fold into checksum-parenting/transfer-container work
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

## idea (2026-06-11)

Encrypt an xz-compressed payload with Twofish **three times**: forward,
then backward, then forward again ("twoce forward and one backwards in
between").

- **Why three passes, alternating direction**: a known/predictable first
  block (e.g. the xz magic/header bytes) is normally enough to bruteforce
  a single-pass block-cipher encryption of that block in isolation. Running
  encryption forward, then backward over the result, then forward again
  breaks the simple "first ciphertext block <-> first plaintext block"
  relationship a bruteforce would exploit — the backward pass mixes
  late-stream bytes into what becomes the first block of the next forward
  pass.
- **Key entropy source**: the **name** is now mandatory (per
  [[checksum-parenting-namespace-trees]] — every entry has a name, never
  only a checksum) so it doubles as an entropy source for keying/salting
  this encryption.
- **Fallback**: if no name is available, the **checksum of the source**
  works "perfectly fine" as the entropy source instead — consistent with
  the addressing-trinity framing (name and checksum are interchangeable
  identity anchors at the entry level).

## consequence: reverse-reference indices become load-bearing (2026-06-11)

Because the name (or checksum, as fallback) is now the **decryption key
entropy** as well as the tree address, an encrypted entry is only
decryptable/mappable if you can reconstruct that name/path. This makes
**reverse-reference indices** — many parallel references pointing back to
the actual name/full-path-in-tree of an entry — load-bearing rather than
optional:

- without such an index, an encrypted entry is undecryptable/unmappable
  *regardless* of whatever other security attributes get assigned to it
  downstream — the name is a hard prerequisite, not a convenience.
- this elevates the **rolling 3-epoch-wide window** (see
  [[topic-addressing-trinity]] — "Rolling Epoch Validity Window": previous/
  current/next epoch always simultaneously valid) from a sync-smoothing
  mechanism to also being the *substrate that carries these reverse
  reference indices* — many parallel reverse-references per entry, valid
  across the rolling window.
- this is recursive/nestable like the rest of the tree
  ([[checksum-parenting-namespace-trees]]): a reverse-reference index entry
  is itself a tree node with its own name + checksum + position, so the
  "index of names" has the same shape as the data it indexes.

## relation

- [[checksum-parenting-namespace-trees]] — mandatory-name constraint reused
  here as crypto entropy source
- ties to existing `AMOS7::Twofish` and `smtpd` xz+twofish archive pipeline
  (see MEMORY.md System Status: "smtpd: receive -> YAML + LLM classify ->
  route; xz+twofish archive") — likely the natural integration point if
  this is picked up
- could also feed the deparse-code transfer-container work
  ([[topic-deparse-code-features]] consumer feature 6) if canonical source
  is xz+twofish-packed for transfer

## status

idea only, not designed in detail or implemented. small/self-contained —
may be foldable into an existing crypto module rather than needing its own
design doc.

#,,.,,...,...,.,.,,,,,.,.,..,,..,,,..,..,,..,,..,,...,...,.,.,,,,,,.,,...,.,,,
#C7WUITF6DHO2DVSYE2DETKPXD6ZT3GQVAXCLGAYVDNSO6T7HJBWMQFAN56HHUKKDRS4EVIIV72KT6
#\\\|HMVW2N5RXMXQXIM5RBDI2RFYVIOICSW5HIC3IPLS62CO6GKYMMI \ / AMOS7 \ YOURUM ::
#\[7]OE7XH7JVQXSXRYR2E3N3O2K3FBLYJKDJKE5L73QL7ZTPDGIQAWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
