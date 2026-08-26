---
name: topic-key-recovery-flexible-recreatability
description: "design ideas from a 2026-07-24 conversation: C25519 key recovery via flexible re-creatability (passphrase/file-seed/combined), duress/decoy passphrases, key-archive steganography boundary, key-group equivalence and rotation-transparency questions -- both superseded/answered by pre-existing data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md (parent/child signed-key hierarchy, mode-A/B credential upgrade)"
metadata:
  type: project
---

**Design conversation, 2026-07-24**, prompted by walking the live `keys`
zenka commands (`v7.keys list`/`commands`/`create-stub-key`/`get-sp-pub-key`/
`gen-file-seed-key`) while discussing a term-first ncode Clui zenka
([[topic-ncode-pattern-learning-loop]]/[[topic-write-access-security-infrastructure]]
context — signing candidate `ncode-sign-key` was created live as a
demonstration only, not the real choice yet). Nothing here is built; this
is design ideation on top of already-working `crypt.C25519`/`keys`-zenka
infrastructure, captured before it got lost.

## the core insight, stated directly by the user

"Explains the primary approach to key recovery: flexible re-creatability."
Nothing in this key system depends on *backing up* secret material — every
variant is defined by being **re-derivable** from something already
retained by other means (a remembered passphrase, a file you already have
many copies of context for, or both). Recovery isn't "restore from
backup," it's "reproduce the same inputs." This single property is also
what produces the duress/decoy and canary properties below, essentially
for free.

## already-working mechanisms this builds on (verified live, not new)

- **Virtual/seed-phrase keys** (`v7.keys create-stub-key`, `get-sp-pub-key`)
  — pure passphrase → `crypt.C25519.gen_keys`; stub file on disk is only a
  timestamp placeholder, no key material ever persisted. Regenerated fresh
  each use via `crypt.C25519.load_keypair`'s virtual-keyfile branch, which
  transparently collects the passphrase itself
  (`AMOS7::TERM::read_password_single`/`read_password_repeated`, ≥13 chars
  enforced) when not supplied programmatically.
- **File-seed keys** (`keys.console.gen-file-seed-key`, `n p [-U] [-plain]`)
  — mixes file entropy (`AMOS7::13::gen_key_from_file_entropy`, something
  you *have*) with an optional second password (`AMOS7::13::key_32`,
  something you *know*) via `|.=`, then *persists* the result through
  `crypt.C25519.write_keys`, optionally encrypted at rest with a third,
  independent password (`-U` skips at-rest encryption, `-plain` skips the
  file-seed password). Up to three independent secrets depending on flags,
  vs. the virtual key's single passphrase.
- Both variants already loaded/cached via the same `keys`-zenka-resident,
  `mlock`'d `%keys{'C25519'}{$name}` process memory once entered — the
  "don't retype the passphrase hundreds of times" problem is already solved
  at this layer, independent of any frontend built on top.

## duress / plausible-deniability (emergent, not designed-in)

Because a virtual key is *whatever passphrase you enter, deterministically*,
with zero on-disk record of which passphrases are "real," you get for free:
a genuine key for normal use, a decoy passphrase that also produces *a*
valid-looking key (satisfies someone demanding an unlock), and optionally a
watched-for duress-passphrase checksum that triggers a wipe/lockdown
handler instead — all indistinguishable from outside without already
knowing the specific public-key checksum to test for. Same property that
makes file-seed entropy from e.g. "one specific image in a 30,000-photo
library" a large, low-suspicion haystack — nobody's brute-forcing which
photo without already knowing it's a photo library in the first place.

## key-archive steganography (verified live by reading the actual code)

`keys.write_key_archive_file` + `keys.read_key_archive` already provide a
real, working mitigation for "does this file even contain N keys" — but the
exact boundary of what it hides matters, worked out by reading both modules:

- **Write**: allocates a fixed-size block (`<keys.size.archive_block>`, 13K
  baseline, tripled until the payload fits), fills it entirely with random
  entropy (`AMOS7::13::gen_entropy_string`), splices the real payload in at
  a **randomized bit offset** (`base.parser.splice_in_data`), then encrypts
  the *whole block* — padding and payload together — under one Twofish key
  derived from a single archive password. No header, no length field, no
  key count anywhere in the format.
- **Read**: has no offset to look up — it decrypts, then *searches* for its
  own payload by scanning candidate offsets (compact-ints found near the
  tail) and accepting whichever one decodes to bytes starting with the
  literal module-header magic (`"## [:< ##\n"`). Wrong password → garbage
  decrypt → no valid offset found → fails with "found no payload offset
  [ correct password ? ]", indistinguishable from "this file was never an
  archive at all."
- **The actual guarantee**: anyone *without* the archive password can't
  tell if the file holds 0 keys or 100 — it's uniform noise either way.
  **But** this is single-password-unlocks-everything: once someone has the
  correct archive password, `read_key_archive` fully unpacks and logs
  `"found %d keys in archive"` — all bundled keys become visible together,
  not selectively. So bundling a recovery key into the *same* archive as
  the work key defeats a no-password observer, but not someone who
  legitimately has (or extracts under duress) that one archive password.
  True "recovery key stays hidden even from whoever unlocks the work key"
  needs the recovery key in its **own separate archive with its own
  separate password** — this format doesn't currently support multiple
  independent passwords each revealing a different subset of one file
  (true hidden-volume style).

## true hidden-volume extension — proposed, not implemented

Two mechanisms floated for making *one file* support multiple independent
passwords, each revealing a different key subset (real deniability even
under archive-password duress, not just separate-file discipline):

1. **Splicing exclusion rules.** Since the archive block already has slack
   space and a randomized splice offset per payload, multiple independent
   payloads could coexist in one block if their offset-selection is
   constrained to avoid collision — "only a matter of math": each
   additional password's payload placement excludes the regions already
   used by prior payloads (or by *plausible* placements of passwords not
   yet used), so writing a second payload doesn't corrupt the first, and
   reading with password A never stumbles onto password B's region. Not
   implemented — `write_key_archive_file` currently assumes exactly one
   payload per file.
2. **Diverging entropy-stream continuation.** A common base
   passphrase-prefix seeds a shared starting entropy stream (same as
   today's single-passphrase generation), which then **diverges into
   different continuation streams depending on context** appended after
   the shared prefix — i.e. instead of HD tree-paths branching from a
   fixed master seed (the mechanism proposed in the section below), the
   *same* entropy stream is extended/continued differently per use,
   generating different downstream keys from one memorized prefix plus a
   contextualizing continuation. Conceptually closer to a KDF continuation
   chain than a derivation tree. Also not implemented.

   **Concrete use case named 2026-08-14, connecting this to
   [[vision-sessions-zenka-key-holding-children]]'s "where does a held
   secret go long-term" question**: per user, this SAME mechanism —
   entropy stream + a context string, here the SITE NAME rather than an
   archive-slot context — is the intended answer for "the entire stack of
   site passwords." Per user: "for now [ `sessions.hold`-staged, native
   entry ] is native and acceptable" for a secret that can't be derived
   (a real, assigned host password — `host_password`, the field landed
   `96e47cc5b`), but a SITE password doesn't need that storage/staging
   path at all — it's regenerated fresh from (entropy-stream seed, site
   name) on demand, never persisted, never held even temporarily.
   Reframes that "still open" question for this subcategory specifically:
   the answer isn't a storage destination, it's "nowhere — recreation
   replaces storage." Not implemented, not scoped into a task file yet —
   the mechanism itself is still the same "diverging entropy-stream
   continuation" primitive this section already proposed, now with a
   real, named first application rather than only the hidden-volume-
   archive motivation it was originally floated for.

Both are real extensions of the existing splice/entropy-stream primitives
already in `AMOS7::13`/`base.parser.splice_in_data`, not a new crypto
primitive — the user's framing: "a lot can be mapped into it," and noted
in-session that this line of thinking is heading toward the broader
**mapped cube structures** vision (checksum-addressing / namespace-tree
concepts already tracked in [[topic-checksum-addressing]] and
`data/md/design/CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md` per
[[topic-next-steps]]'s 2026-06-10 entry) — flagged by the user as getting
ahead of the current thread, not chased further here.

## key-group equivalence for recovery — the important design fork

Proposal: a work key in active use, plus a recovery key that's easier to
regenerate, deliberately never used/observed, treated as implicitly
equivalent authority to the work key.

**The subtlety, worked through and corrected mid-conversation:** knowing a
recovery key *exists* doesn't help an attacker observe or derive it — the
actual design fork is *how equivalence gets established* without ever
needing a stored registry entry linking the two public keys (which would be
observable, though not by itself exploitable). The clean mechanism: **HD
(hierarchical-deterministic) derivation from a shared master seed** — work
key = seed+path-A, recovery key = seed+path-B — so provable equivalence
requires possession of the master seed/derivation scheme itself, not a
lookup anywhere in the system. This is a genuinely different trust
primitive from anything currently in `crypt.C25519.*` (which generates
independent keys per passphrase/file-seed, no derivation-tree relationship
between them) — would need new design work, not just wiring existing calls.

## the complementary, opposite-transparency use case

Recovery keys don't have to stay hidden after use — the user's refinement:
a recovery key can be **fully discernible as a canary once exercised**,
visible in the project signature log, specifically to distinguish
**scheduled vs. unscheduled key rotation**. An unscheduled rotation
signed by the *recovery* key (not the work key) is itself a meaningful
signal — it means access to the work key did not exist at the time of
rotation — directly analogous to force-push events being flagged in git
history (see [[topic-git-watch-zenka]] for the existing force-push
detection precedent to model this on) rather than silently accepted as a
normal commit.

So the two axes are independent and both wanted:
1. **Pre-use secrecy** — the recovery key's public identity/derivation
   should not be discoverable in advance (HD-derivation from an
   undisclosed master seed, no registry entry).
2. **Post-use transparency** — once a recovery key *is* used to rotate
   authority, that event should be unambiguously flagged as
   recovery-triggered (unscheduled) in the signature log, not
   indistinguishable from routine scheduled key rotation.

## found: `PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md` already specifies both
forks above, more maturely than this conversation's ad-hoc proposals

`data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md` (pre-existing,
found by the user mid-conversation) works out both open questions from this
file already:

- **Supersedes the HD-derivation proposal.** Its "key hierarchy integration"
  section: `parent_key` **signs** each `child_key`'s public component as
  authorization (a cert chain), not derivation from a shared seed-path.
  Stated property, word for word what this file was reaching for: "even
  with access to the parent key's public component: you cannot derive
  which child keys exist, you cannot link child key credentials to each
  other, you can only verify that a given child key was authorized by the
  parent." Cleaner than seed-path HD-derivation — no shared master seed to
  protect, authorization is a plain signature check.
- **Supersedes the scheduled/unscheduled-canary proposal.** Its "credential
  upgrade — self-replacing checksums" section: credentials are
  content-addressed by `BMW384(credential)`, and upgrading between them has
  two modes — **mode A** keeps an explicit `next: BMW384(new)` pointer +
  `ntime` (auditable chain, "this identity upgraded to new state at ntime
  T" — the traceable/scheduled case), **mode B** deletes the old
  store-entry and writes the new one with zero link (historyless/clean
  replacement — the recovery-triggered/unscheduled case done as a genuine
  break rather than a flagged event). Which mode a given P7 node accepts is
  **network-configurable policy** (`require_upgrade_reference` /
  `allow_historyless_upgrade`), not a hardcoded choice — more general than
  this file's "flag it like a force-push" framing, since it treats
  traceability as a per-network policy dial rather than an always-on log
  annotation.
- Also directly reuses this conversation's file-archive/duress themes: its
  "forensic resistance — progressive erosion model" (level 0-4, each level
  of correlation requiring a deliberate additional surveillance
  investment) and "connection to p7 infrastructure" section maps every
  primitive (`crypt.C25519.sign_data`/`verify_data`, `base.ntime.b32`,
  BMW384 content-addressing) to code that already exists.

**Practical implication:** if this design area gets picked up for real, go
in through that doc as the primary reference — the parent/child signed-key
hierarchy and the mode-A/mode-B credential-upgrade split are the concrete
mechanisms to implement, not the HD-derivation/log-canary sketches
originally proposed in this file (kept above for the conversation record
and because the file-seed/archive-steganography material isn't covered by
that doc at all).

## status

Design-only, not scoped into task files. Natural next step if picked back
up: read `PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md` in full alongside
[[project-zenka-cryptographic-identity-survey]] (per-user C25519 trust-root
survey) before designing anything from scratch — most of it may already be
answered there.

## related

[[topic-write-access-security-infrastructure]] (signature-gated approval
this could eventually feed into), [[topic-ncode-pattern-learning-loop]]
(the session this conversation branched off from)

#,,,.,,,,,...,,,.,,.,,..,,,,,,.,.,,.,,,,,,.,,,..,,...,...,,..,..,,...,.,,,,,,,
#5NKDNZ7DIKWFYXNXJM4CYTQQOIQUAWG7JASRLJO3DAVEG6D7OO7WXQV5KSXIDRJPFBZ2HGAPUHD4W
#\\\|J2D32JIOSATLHUO5PF2LAUC52HZ5VVB7EWGXILTJMBSYUBZ5YUV \ / AMOS7 \ YOURUM ::
#\[7]ZJJPMK4S2DBPKQI6AD5MLSZ2XRD6Z3QO4AQEOBLL3WQ2VOOKVCBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
