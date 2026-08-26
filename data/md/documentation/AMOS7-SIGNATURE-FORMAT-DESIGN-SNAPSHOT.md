# AMOS7 signature footer: design and security parameter snapshot

- date: 2026-08-04
- scope: the 5-line signature footer appended to every signed `src/*`
  file (and other tracked source), as implemented today. This is a
  snapshot of a live, working mechanism — not a proposal, and not an
  independent security audit. Every code reference below was read
  directly from the source at the paths given; every statistical claim
  was verified against real corpus data, not assumed.
- related: [[topic-harmonic-correlation-ledger]],
  `data/tasks/iteration-counter-quality-results.md` (the empirical study
  this snapshot's statistical section summarizes),
  `data/md/design/CROSS-READOUT-RING-KEY-ADDRESSING.md` (a separate,
  speculative design that borrows the zero-transparency mechanism
  described here as prior art).

## 1. what problem this solves

Every signed file carries a self-contained, verifiable claim: "this exact
byte content, plus this header, was accepted by a specific private key at
some point." The mechanism is a proof-of-work-style harmonization search
(not a fixed-cost signature) — a candidate header is tried, checked
against several independent, overlapping truth conditions, and retried
with a decremented counter until every condition passes simultaneously.
The leftover counter value becomes part of the header, which is where the
`amos-iterations-remaining` field studied in the quality-correlation
report comes from.

## 2. footer layout

Five lines, defined as `<source.sign_template>` in
`src/source.init_code:76-82` (exactly 77 characters per content line,
matching `7 commas + 70 dots` in the raw template before substitution):

```
#<19 groups of 3 bits, comma/dot encoded>,     <- line 1: header (regenerated per candidate)
#<77-char BMW-384 footer checksum, base32>     <- line 2: data-chksum
#\\\|<51-char sig-part-0> \ / AMOS7 \ YOURUM ::  <- line 3
#\[7]<52-char sig-part-1> 7  DATA SIGNATURE ::   <- line 4
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::  <- line 5: fixed closing rule
```

Exact byte offsets within the assembled template (from
`src/source.fill_source_template:60-77`):

| field           | offset | length | content |
|-----------------|-------:|-------:|---------|
| data-chksum     |     80 |     77 | BMW-384 footer checksum, base32 |
| sig-part-0      |    163 |     51 | first half of the Ed25519 signature, base32 |
| sig-part-1      |    242 |     52 | second half of the Ed25519 signature, base32 |
| signature-type label | 233 - len | len | `AMOS7 \ YOURUM` |
| data-type label |    298 |      4 | `DATA` |

## 3. header-line encoding (line 1)

Implemented in `src/amos7.encode_octal_header` /
`src/amos7.decode_octal_bit_header`. 19 octal digits, each mapped to
3 bits, each bit mapped to a character: `0 -> ','`, `1 -> '.'`, each
3-char group followed by a literal `,` separator — 19 x 4 = 76 characters
plus the leading `#` = 77.

Field layout across the 19 octal digits:

| digits | field |
|-------:|-------|
| 0-10   | AMOS checksum-num, `unpack('V*', ...)` of `base.chk-sum.amos`'s output over `{elf_checksum, BMW_checksum}` (`source.create_harmonic_footer:232-237`) |
| 11     | endline-state (encodes original trailing-newline count: 5/6/7, see `source.create_harmonic_footer:209-224`) |
| 12-18  | `amos-iterations-remaining`, octal, max `0o7777777` = 2,097,151 |

**Correction on what feeds digits 0-10** (verified precisely, not
paraphrased): `chksum_parameters` in `source.create_harmonic_footer`
requests a *dedicated* "AMOS7 ELF CHKSUM" entry (`[ELF-7, 7]`, position
4) — but that computed result is `shift`ed off and discarded, never
captured (`source.create_harmonic_footer:135`, `## stripping amos-ELF
checksum ##`). The `elf_checksum` actually passed to `chk-sum.amos`
(line 233) is `$start_chksum_elf{$ELFmode}` where `$ELFmode` resolves to
the *outer* lexical (`= 7`, declared at line 11, not shadowed outside
the `foreach my $ELFmode (@t_elf_modes)` loop at line 130) — i.e. it
reuses `$start_chksum_elf{7}`, the same **FOOTER ELF CHKSUM mode-7**
seed also used later as the mode-7 half of check #4 below. So digits
0-10 are not built from an independently-computed AMOS-specific ELF
checksum (that computation exists in the source but its result is dead)
— they share their ELF-7 input directly with check #4's whole-file
checksum, which is a tighter binding than a first read suggests. The
BMW-512 half (`$bmw_amos_ctx->digest`) is genuinely dedicated, not
shared with any other check.

**Zero-transparency / inverted mode**: when the entire 19-digit payload
would be all-zero (genuinely ambiguous under the normal mapping — an
all-`,` line looks the same whether it encodes 19 zeros or is simply
malformed), the encoding *inverts*: `1 -> ','`, `0 -> '.'`. The decoder
recognizes this specific inverted signature and reconstructs the correct
all-zero payload rather than treating the ambiguous case as an error.
Confirmed a real, live mechanism (not proposed) — 0 inverted-mode
instances actually occur in the current 5055-file corpus, but the
round-trip was verified directly in code.

## 4. the harmonization search

`src/source.create_harmonic_footer:245-431`. A `while` loop starting
`$iterations_left = 0o7777777` and decrementing by 1 per candidate.
Termination requires **every active check below to pass simultaneously
on the same candidate** (`next if not $asserted_true` chaining — strict
AND, not first-pass-wins).

## 5. layered checksum/signature checks (active, in order)

| # | check | scope | mechanism |
|---|-------|-------|-----------|
| 1 | header line alone | candidate header line only | ELF-7 truth assertion, modes [4,7] |
| 2 | payload + header, BMW-384 | entire file payload, chained with the header line | BMW-384, truth-checked twice (with/without trailing newline) |
| 3 | signature parts alone | `sig-part-0`, `sig-part-1` | ELF-7 truth assertion, modes [4,7], each independently |
| 4 | payload + entire footer | entire file payload, chained with the *whole assembled footer including the signature lines* | ELF-7, two independent modes (4 and 7), each must pass |
| 5 | two footer display lines alone | the `\\\|...` and `\[7]...` lines | ELF-7 truth assertion, modes [4,7] |

Two checks exist in the code but are **disabled by default**
(`$check_full_signature = FALSE`, `$check_entire_footer = FALSE`):
combined-signature-as-one-block and whole-footer-as-one-block truth
checks. Also present but disabled: embedded-code-style-syntax checking.

**Overlap, not redundancy**: the header line is checked alone (1), then
again bound into the payload+header BMW hash (2), then again as part of
the full-file ELF check (4). The signature parts are checked alone (3),
then again inside the same full-file check (4). No component is
validated by only one mechanism at only one scope — the broadest check
(4) integrates literally everything upstream of it, in two independently
required hash modes. Forging a valid footer for tampered content
requires satisfying all five simultaneously, which is exactly why the
search is a genuine trial-and-error process rather than a closed-form
computation.

The binding is tighter than the table alone shows: the header's own
`amos-checksum-num` field (digits 0-10, section 3) is built from the
*same* mode-7 ELF-7 seed value (`$start_chksum_elf{7}`) that check #4
reuses as its mode-7 half — see the correction in section 3. So the
header line doesn't just get checked by check #4 as part of the whole
footer string; part of *what the header line itself encodes* is derived
from the identical seed that check #4 independently re-validates.

## 6. cryptographic / checksum primitives

- **Signature**: `Crypt::Ed25519::sign` (standard CPAN Ed25519
  implementation, `src/crypt.C25519.sign_data:36`) over Curve25519
  keys. Not a custom signature construction.
- **What actually gets signed**: by default (`$sign_full_payload = 0` in
  `src/source.fill_source_template:11`), the signature covers
  `first-header-line + '#' + data-chksum + template-prefix` — **not** the
  raw file bytes directly. The link to the actual file content is
  transitive, via the BMW-384 `data-chksum`, which *does* cover the full
  payload (check #2 above). This is a real distinction worth keeping
  precise: the signature directly authenticates a checksum of the file,
  not the file itself byte-for-byte.
- **BMW-384 / BMW-512**: Blue Midnight Wish hash family, used for the
  footer checksum (`data-chksum`, 384-bit) that feeds the signature, and
  a dedicated BMW-512 digest consumed by the AMOS checksum algorithm
  (below) that produces half of header digits 0-10.
- **The AMOS checksum itself (`AMOS7::CHKSUM::amos_chksum`,
  `data/lib-path/pm/AMOS7/CHKSUM.pm:69-322`, the same routine `bin/
  amos-chksum` and `chk-sum.amos` call) is its own distinct algorithm,
  not a simple combination of an ELF-7 value and a BMW-512 value** — an
  earlier version of this section undersold it as a black-box
  combination; correcting that here with what the code actually does:
  1. Takes an ELF-7 mode-7 checksum (32-bit) and a BMW-512 digest — in
     `create_harmonic_footer`'s case, the reused footer-checksum seed
     and a dedicated BMW-512 digest (section 3's correction); standalone
     (`bin/amos-chksum`) it computes both fresh from the input.
  2. Reverses the ELF checksum's bit string (`elf_bits`), then splices
     BMW-derived bits into it: any leading run of zero-bits in
     `elf_bits` is replaced with the equal-length prefix of the BMW
     digest's *left* 32 bits; any trailing run of zero-bits is replaced
     with the equal-length prefix of the BMW digest's *right* 32 bits
     (right side taken from the reversed digest, i.e. effectively the
     original digest's last 32 bits, bit-reversed). The ELF checksum's
     own non-zero "core" bits are left untouched in the middle — BMW
     entropy fills the gaps at both edges without overwriting the ELF
     value's actual signal. (A third 32-bit slice, the BMW digest's
     center bits at offset 240, is computed and exposed as
     `$bmw_b_C` for introspection/visualization but is not otherwise
     used by the algorithm.)
  3. The result is converted to a number and XOR'd against the BMW
     digest's left 32 bits again ("elf checksum protection").
  4. **A second, inner harmonic search loop** (a `goto`-based loop,
     label `INVERT_TRUTH_STATE`) then runs: it checks the current
     numeric checksum for truth in three representations simultaneously
     — as a raw number, as a binary bit-string, and as the final
     base32-encoded string — plus any registered truth template, via
     `AMOS7::Assert::Truth::is_true`. If any representation fails, it
     XORs in the next unconsumed 32-bit chunk of the (zero-prefixed)
     BMW-512 material and retries. If it exhausts the initial material,
     it "resaturates" by pulling a fresh 32-bit slice from a rotating
     offset into the same BMW-512 digest (`offset += 13`, wrapping mod
     480) XOR'd with the current checksum, rather than terminating —
     the entropy pool is renewable, not fixed-size, for this inner loop.
  5. Only once numeric + binary + base32 (+ any template) truth all hold
     simultaneously does it return the base32-encoded checksum used as
     `$AMOS_chksum_enc` back in `create_harmonic_footer`.

  So the "AMOS checksum" is itself a harmonic convergence search nested
  *inside* the outer footer-level harmonization loop — structurally the
  same philosophy (multiple simultaneous truth representations, retried
  until all agree, entropy drawn from one side to preserve the other)
  applied one level down, at the level of a single checksum value rather
  than the whole footer. It is meaningfully stronger and more
  structured than a plain ELF-7 or a plain BMW hash used alone.
- **ELF-7**: a fast, non-cryptographic ELF-hash variant, used as the
  "truth assertion" mechanism at multiple scopes (single line, combined
  payload+header, combined payload+footer, and reused as half of header
  digits 0-10). Two configured modes (4, 7) run independently at several
  checkpoints. Notably substitutes `777` (three 7s) for null bytes
  internally rather than adding literal 0 — see `AMOS_13_ELF.pm` —
  preserving entropy from repeated null bytes that a literal-zero ELF
  hash would silently discard.
- **`AMOS7::Assert::Truth::is_true`**: the harmonic truth-assertion
  function (division-by-13-based) referenced throughout this session's
  math exploration; gates every check above.

## 7. empirically verified statistical properties of the iteration counter

From `data/tasks/iteration-counter-quality-results.md` (full study) —
summarized here as the security-relevant subset:

- **Budget**: max possible 2,097,151 (`0o7777777`). Full-corpus max
  actually observed: 178667 (**8.5%** of budget). p99 across 5055 files:
  93594 (**4.5%**). No file has ever come close to exhausting the search
  space.
- **Distribution shape**: mean/median ratio = 1.443, matching the
  theoretical geometric-distribution constant `1/ln(2) ≈ 1.4427` almost
  exactly — consistent with a true memoryless trial-and-error process,
  not a biased or structured one.
- **No size/complexity leak**: binned by file size (n_code lines) into
  10 deciles spanning 0-5 lines to 90-5058 lines, the implied
  per-candidate pass probability stays flat at **0.000046 to 0.000054**
  across the entire range — no drift with file size or complexity.
- **No quality leak**: REJECTED-ON-CHECK across three independent blind
  quality measurements (local 9B, kimi k2.7, deterministic style metric
  on the full 5055-file corpus), a controlled distortion-injection test,
  and a real `bin/format-code` reformatting check — see the full study
  for numbers. Outliers specifically checked too, not just the average:
  no correlation with quality on either end.
- **No clustering**: 94.1% of 5055 files have a unique iteration count;
  largest collision cluster is 3 files; the survival function `P(X>=k)`
  decays log-linearly across checkpoints from 1000 to 160000 — the
  hallmark of a clean exponential tail, no near-miss pile-up near the
  budget ceiling.
- **Key-dependence**: identical content re-signed under a different
  signing key produces an unrelated iteration count (`ncode.init_code`:
  4637 under its production key vs 22673 under a temp key in the same
  study). This is a *desirable* property from a security standpoint — it
  means the counter cannot be used to fingerprint content independent of
  which key produced it.

## 8. known limitations, stated plainly

- This is a snapshot of the current implementation, not an independent
  cryptanalysis. The Ed25519 signature and BMW hash family are
  standard/audited primitives used as intended; the ELF-7
  "truth-assertion" layer and the harmonic-mathematics gate
  (`AMOS7::Assert::Truth`) are project-internal constructions that have
  not been adversarially tested against a real attacker model in this
  snapshot.
- The overlapping-checks structure (section 5) is a real, verified
  property of the current code, not a formal proof of tamper-resistance.
  No attempt was made here to construct a forged footer or otherwise
  attack the scheme.
- All statistical claims in section 7 describe the *current* 5055-file
  corpus signed under real production keys, plus a supplementary
  30-file real-transformation test signed under one shared temp key.
  They are empirical, not derived from a formal model of the search
  process.
- Two optional checks are implemented but disabled by default (section
  5) — if enabled, the layered-coverage picture above would change and
  this snapshot would need updating.

## 9. version scope

Reflects the code at commit range ending `08afe632a` /
`b405b4739` on branch `base`, 2026-08-04. Re-derive rather than assume if
`source.create_harmonic_footer`, `source.fill_source_template`, or the
active/disabled check flags at the top of the harmonization loop change
in the future.

#,,..,,,.,..,,...,,,.,...,,,,,...,.,.,..,,.,.,..,,...,..,,.,.,.,,,,.,,,.,,.,.,
#BLBRX275CEZO6C2SLMTDORRR7LVZAUIKVZ6NCYQNSYQJR7ODSJ24Y66F76MPOBP2D6MVKD2CD7OMQ
#\\\|3TRFVTRNB2RRS6MXHJFZV22DWQUU5CTA2VUV7LN7T3YC5I3L4SF \ / AMOS7 \ YOURUM ::
#\[7]GWJVG63OXR2NSCZJH5XZJIIKBUWEJDS3ZYOSURHDBM5YDEQ4VUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
