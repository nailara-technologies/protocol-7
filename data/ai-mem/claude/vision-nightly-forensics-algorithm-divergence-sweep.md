---
name: vision-nightly-forensics-algorithm-divergence-sweep
description: SEED, design-only -- nightly forensics-zenka sweep across main checksum/crypto algorithms comparing live output against pinned known-good reference vectors, to catch silent algorithm-output divergence (like the 2026-08-25 inline_elf incident) before production signature failures
metadata:
  type: project
---

**Origin**: surfaced directly out of [[cpanm-triggered-inline-elf-utf8-boundary-bug]]
-- a perl version bump silently changed `AMOS7::CHKSUM::ELF::inline_elf`'s
output for high-entropy binary input, causing 2212 mass signature-verify
failures and a C25519 key-decryption failure, and nothing caught it until
production symptoms appeared. `bin/amos-chksum -VL7` already computes a
live behavioral fingerprint of `inline_elf` specifically, but (a) it's
scoped to one algorithm, not the others in active use (BMW, JHA,
Twofish/Curve25519 round-trip), and (b) its reference string is too
short/low-entropy-density to reliably catch this whole bug class -- see
below.

**Idea**: a nightly (or on-perl/lib-version-change-triggered) forensics
zenka sweep that, for each main algorithm in active use, runs a small
battery of pinned reference vectors (including at least one genuinely
high-entropy 32+ byte binary blob per algorithm, not just short/ASCII/
single-special-byte strings -- that was the specific weakness found in
`-VL7`'s current reference string) and diffs the live output against
last-known-good recorded values. A mismatch should fire loud (not a
quiet log line) -- this class of bug produces NO crash, NO exception,
just silently-wrong output, which is exactly what made the original
incident take a full session to trace.

**Two smaller, cheaper prerequisites noted alongside this idea** (do
these first / independently, they don't require the full zenka):
- `-VL7`'s reference string should include real byte-entropy density,
  not just one stray high byte -- it currently catches some bug shapes
  by luck rather than by design.
- No warning exists today when a module's live-recomputed version tag
  doesn't match its last-recorded one -- cheap, would have flagged this
  incident immediately at the point the perl bump forced a recompile.

**Status**: design-only, not started. Deferred until after the current
`inline_elf` fix's fallout (key re-encrypt, ~2233-file re-sign) is
cleared -- see [[cpanm-triggered-inline-elf-utf8-boundary-bug]] for that
plan.

#,,.,,,.,,.,,,,,.,...,.,.,,.,,,..,...,...,,,,,..,,...,...,.,.,.,.,,,,,,..,,..,
#5HOXBESHU4OIKHTLODSXIC5KNUEVAZ2NPDIAPKXACISEECICXPWUYUQRZDI6PUQPD7J23MS4VQBPS
#\\\|GMKOO5N3ALO52SM4YMZDCALEQDFHPEOI2D3LCGKO74HQVRLANAF \ / AMOS7 \ YOURUM ::
#\[7]37IJ3TRIXC2RNTRKOLXTWU4NQZN3YXTU6WN56HBKPRJQH3KL64DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
