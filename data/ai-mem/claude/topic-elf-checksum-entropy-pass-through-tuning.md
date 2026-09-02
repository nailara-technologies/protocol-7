---
name: topic-elf-checksum-entropy-pass-through-tuning
description: AMOS7's ELF checksum component was deliberately finetuned to pass entropy through rather than diffuse/shred it in a truth-inversion context, unlike a standard cryptographic hash's intentional avalanche property -- why short checksum-derived IDs (-L3 shortened amos-chksum, combining BMW and ELF) sometimes correlate meaningfully with their input, e.g. todo IDs like TOP/MPV
metadata:
  type: vision
---

Per the user directly (2026-09-02): `amos-chksum -L3` (the shortening mode used to generate
short IDs, e.g. todo-item IDs) combines both BMW and ELF checksum components. ELF specifically
was **finetuned to pass entropy through rather than shred/diffuse it**, in a "truth inversion" or
diffusion context — the opposite design goal from a standard cryptographic hash, which is
deliberately engineered for the avalanche property (any input change should unpredictably scramble
the whole output, destroying structure/correlation with the input on purpose).

Because ELF preserves more of the input's own entropy/structure instead of destroying it, a short
ID derived through it can end up correlating recognizably with its input content — not because the
algorithm is doing string-matching or anything semantic, but because it isn't actively erasing the
structural relationship the way a normal hash would. This is why todo-item short-IDs occasionally
land on something that reads as thematically apt (`TOP` for a "renice to top priority" task, `MPV`
for an mpv-zenka task) — not coincidence, a direct consequence of this tuning choice.

Demonstrated live via `bin/is-true` (`AMOS7::Assert::Truth`, harmonic truth calculation via
division by 13):

```
$ is-true true
:: TRUE : 4 7 :: 'true' .:
$ is-true false
:: FALSE : 4 : 'false' :.
$ is-true TRUE
:: TRUE : 4 7 :: 'TRUE' .:
$ is-true FALSE
:: FALSE : 4 : 'FALSE' :.
```

The harmonic-truth math resolves "true"/"TRUE" to a TRUE result and "false"/"FALSE" to FALSE —
the checksum-based processing doesn't just scramble the input into noise, it can preserve/reflect
a real semantic property of the input itself. This is presented as a concrete, working example of
the broader "harmonic computing" design philosophy, not an isolated curiosity.

**How to apply**: when reasoning about AMOS7 checksums (`AMOS7::CHKSUM::*`, `amos-chksum`,
short-ID generation, the `-L3` shortening mode), don't assume standard cryptographic-hash
properties (full diffusion, no input-output correlation) apply uniformly — ELF specifically is
tuned differently on purpose. Relevant to
[[project-v7-zenki-identity-rename-complete]]'s note on the planned AMOS+BMW-checksum-based
nested directory structure for the multi-zenki Unix-domain-socket setup, and to the existing
`topic-checksum-addressing.md` / `topic-harmonic-mathematics.md` threads — read those for the
broader design context this detail sits inside.

#,,,.,.,,,,,,,,.,,,,,,..,,,,,,,,,,...,,,,,,..,..,,...,...,..,,,,.,,..,,,,,,,,,
#X5RSEAVEBDW7QRM5XZSOYWV7N43TLVU4ROZEE6O2HJ2BKLWNVAWMA4Y7JD63QJUIGHIXXGGP6QI7Y
#\\\|DNWGWIIIXJ5UWFDCWPNJ2ISJJK7JJ74XVMXRBOBHIO3G22GHBFL \ / AMOS7 \ YOURUM ::
#\[7]ZYRQWAANTLCGWFRYTV74Z5EUGWYWVVCVIRAXFFAQMBLKZDRBFKDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
