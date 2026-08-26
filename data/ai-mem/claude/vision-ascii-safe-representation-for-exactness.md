---
name: vision-ascii-safe-representation-for-exactness
description: SEED, design principle -- prefer 7-bit-ASCII-safe representations (namespace paths, identifiers) over arbitrary rich-content payloads anywhere exactness/verification robustness matters, since encoding-dependent bugs can only manifest where non-ASCII bytes are actually present; generalizes beyond checksums to encoding-choice decisions broadly
metadata:
  type: project
---

**Origin**: direct generalization from [[cpanm-triggered-inline-elf-utf8-boundary-bug]] --
the whole 2026-08-25/26 `inline_elf` incident was gated entirely on payload
bytes >= 0x80. Confirmed empirically: every sampled `data/tasks/completed/
*.md` file carried non-ASCII bytes (prose, typographic punctuation), while
17 of 20 sampled `src/*` module files carried zero -- source code here is
already near-purely 7-bit ASCII by convention. A checksum/consensus
mechanism keyed on namespace-path strings (`base.init_code`,
`keys.console.change-passwd`, dot-and-identifier ASCII by construction)
rather than arbitrary content would have been structurally immune to this
entire bug class, independent of whether the underlying bug was ever found.

**The generalized principle**: anywhere exactness genuinely matters --
signature/checksum addressing, consensus, trust anchoring, anything where
"does this match bit-for-bit" is load-bearing -- prefer representations
that are naturally 7-bit-ASCII-restricted (identifiers, namespace paths,
canonical short forms) over representations that carry arbitrary rich
content (free text, user-authored prose, binary blobs). This isn't about
avoiding UTF-8 in general -- it's about recognizing that *where* exactness
is load-bearing, the representation's character-set breadth is itself an
attack/bug surface, and narrowing it removes whole classes of encoding-
layer bugs (UTF-8 decode divergence across library/perl versions being
exactly one instance) before they can exist.

**Broader than checksums**: the same logic should inform encoding-choice
decisions generally -- when deciding what to encode as what for a given
representation (e.g. base32 vs raw bytes vs UTF-8 text vs a restricted
identifier grammar), the choice isn't just about compactness or
readability, it's also about how much of the encoding/decoding stack's
surface area gets exercised, and how much of that surface area is
version-stable vs quietly perl/library-version-dependent. A narrower,
more restricted representation is easier to keep exact across time and
across environments, precisely because there's less of it that CAN drift.

**Status**: design-only aside, not a concrete task. Worth keeping in mind
when designing future checksum-addressed or consensus-bearing structures
([[topic-checksum-addressing]], [[topic-hybrid-namespace-routing]]) --
default to identifier/namespace-shaped representations for anything that
must stay exact, reserve rich/arbitrary content for places where exactness
isn't load-bearing.

#,,,,,.,,,,,,,,,,,..,,,,.,,.,,,,.,..,,,,.,...,..,,...,...,...,.,,,,.,,,,,,..,,
#2NI7XB6PITSN363ZZZGARA37AI2S64SIN2WHDRZLP22V5B3O527AD3QCGTWVJ35UKMT6COGPJE6G6
#\\\|VN2QBUUFTLPBXQUMEORT2JTT4KBW4JOWZEHJXMCPMQ2AAI525VN \ / AMOS7 \ YOURUM ::
#\[7]GFM2BX25VF4ZTUQGATDW6224HIKZYGANB4TKBTOW3U4NCWBUJWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
