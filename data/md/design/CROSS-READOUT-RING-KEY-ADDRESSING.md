# Cross-Readout Ring-Key Addressing — a speculative security architecture

**Status: design-only, speculative, not implemented, not adversarially tested.**
Originated 2026-08-04 in a long free-form design conversation, consolidated
here so the pieces have one canonical home instead of living only in chat
history. Every numeric claim below was checked live during the conversation
(see [[topic-harmonic-correlation-ledger]] for the verification discipline
this follows); the *architecture* itself is a proposal, not a verified fact —
it has not been built, and no attacker model has been run against it yet.

## the core structure

Two axes, radiating from a shared center, each ranging `-13..0..+13`.
Visualized as a cross/plus shape on a plane, each arm built from `BMW-L13`
checksums (`base.chk-sum.bmw.L13-str`, confirmed to always return exactly 13
base32 characters — real, existing code, not proposed) laid outward from
center.

**Zero is transparent**: the center position (`0` on both axes) does not
carry an address of its own and is defined not to leak state across itself —
a non-conducting boundary, structurally similar to differential-signaling
isolation, rather than a rule that has to be separately enforced. What
"leaking" formally means here is not yet specified — open item, see below.

## the security property: centered radial vision

An observer at the shared center is the *only* position from which all four
arms are visible at equal distance and equal angle — any off-center position
sees the arms asymmetrically (foreshortened, unequal distance). This makes
"can this observer see all four arms cleanly, symmetrically" a **self-
verifying test of position** — proof of centeredness doesn't require a
separate credential, the symmetric visibility itself is the proof.

## two readout modes

1. **Rotating observer**: the observer rotates CCW, `-90°` per step, `4`
   steps per full rotation, staying synchronized with an external state by
   continuously re-proving centered position each cycle (each step re-earns
   the symmetric-visibility proof). Connects to already-existing, unrelated
   project material describing a `-90° CCW`, 4-step rotation
   (`ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md:477`,
   `topic-orbital-data-space-archive.md`'s "rotating cube eye" section) —
   **not yet checked whether these are the same rotation or three
   independently-arising instances of the number 4**, flagged explicitly as
   open rather than assumed connected.
2. **Ring rotation, no observer motion required**: instead of the observer
   moving, the underlying data on each axis is organized into rings that
   rotate CCW independently. The readout address stays fixed; the value at
   that address changes every cycle as the ring beneath it rotates, until a
   full ring rotation completes and the sequence repeats. This means the
   same cross-position yields a different secret-key value over time without
   any change to the addressing scheme itself — the key rotates, the address
   doesn't.

## addressing layers — two jobs, same alphabet

The `a..zA..Z` alphabet (52 symbols) does two different jobs at two
different levels, distinguished by context (an explicitly stated design
principle in the originating conversation: "swapping operators depending on
context is not uncommon... context defined as sorted by number of
correlations").

**Layer 1 — position within a snapshot.** Each axis has `13+13=26` non-zero
addressable states (`0` excluded, per the transparency rule above) — exactly
one alphabet case. Two axes together: `26×2=52` non-zero states, exactly the
full alphabet, zero symbols wasted, zero left unaddressed. This is also
exactly `4×13` (four half-axis quadrants of 13 each) — the same 52-element
state space, correctly described two different ways depending on whether
you're grouping by axis or by quadrant; verified these are non-contradictory
partitions of one set, not competing claims.

**Layer 2 — ring selection.** A single letter addresses an entire ring
(the whole rotating structure), not a position within it. Tentatively `13`
rings per axis, `26` total across both axes — this specific count is
**not yet confirmed**, it's the natural extension of the Layer-1 pattern,
flagged as the one still-open number in the structure as of this writeup.

## explicitly NOT the same as an unrelated finding

The C25519 secret/public key format's `52`-character length (see
[[topic-harmonic-correlation-ledger]]) comes from `32` raw bytes encoded in
base32 (`⌈32×8/5⌉=52`) — confirmed, traced directly in
`modules/crypt.C25519.write_keys`. It is **not** built from four concatenated
`BMW-L13` checksums, despite `52=4×13` holding numerically for both. Keep
these separate: one is how an *existing* key format happens to be exactly
`52` characters; this document is a *proposed* addressing scheme that
independently also lands on `52`, for its own, different, internally
consistent reason (the `2×26`/`4×13` state-count above). Two unrelated
facts sharing a product is expected, not evidence they're the same
mechanism — the exact trap this whole session's verification discipline has
been built to catch.

## open items, honestly still open

- What "leaking across zero" formally means — currently a design intent,
  not a specified property.
- Whether the rotating-observer mode's `-90°`/4-step cycle is the *same*
  rotation as `ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md`'s documented one,
  or a separately-arising instance of the number 4.
- The exact ring count (`13` per axis, `26` total — tentative, not derived).
- What drives the ring-rotation clock.
- What the "serialized result of the hop traversal" across the cross-path
  actually carries, and how it differs from what zero blocks.
- No attacker model has been applied yet — "the center has a self-verifying
  proof of position" is a real geometric property, but whether it resists
  any specific real attack (position spoofing, replay, side-channel
  inference of ring state) is completely unexamined.

## related

[[topic-harmonic-correlation-ledger]] — the verification discipline and the
`10989`/digit-complement/`56-63-504` findings this design conversation grew
out of. [[categorical-compartmentalization]] — the prior/current/next
anti-crash principle, a possible model for how ring-rotation state should be
allowed to change without destabilizing an in-progress readout.
`data/md/design/ORBITAL-CYCLE-CLOCK-AND-MAPPING-CANVAS.md` — the
pre-existing `-90° CCW` rotation material this may or may not connect to.

#,,,.,.,,,...,.,,,..,,.,,,.,.,.,,,,..,,,.,.,.,.,.,...,...,,..,,..,,,,,...,,,.,
#A2SX5FKGDXGRCWPJDZI3YFTTZKNSMJKZXAI3GJ44TP6MDPBYC5DJP53AAGGCFLXWUHWLOS6W2HK6S
#\\\|E6OCE2TFI43X7PNRQGMUXPQWXON2CDSIO2Y7Z5DIZAPJEVELHAW \ / AMOS7 \ YOURUM ::
#\[7]G3DMBECNH3KIUQHRPJYPVOKWOWXV7AX6OPLDCO3NAJDANFT2RIAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
