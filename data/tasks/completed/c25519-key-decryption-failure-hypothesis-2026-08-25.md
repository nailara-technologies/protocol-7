# C25519 key decryption failure — hypothesis report

Date: 2026-08-25
Symptom: `crypt.C25519.decrypt_priv_keystr` returns 64 bytes but
`compare_keypair` reports mismatch with the known-good public key.
Trigger: `sudo cpanm --force Git::Native` upgraded system perl 5.40.1 →
5.42.3 and libcryptx-perl 0.089 → 0.090 and cascaded Inline::C
recompiles.

## FULLY CLOSED 2026-08-26 — see feedback-cpanm-triggered-inline-elf-utf8-boundary-bug.md

Everything below this note reflects the state understood at the time it
was written. Since then: the `.private`/`.public` migration described
below succeeded (checksum-verified unchanged), which surfaced a key
with a `.secret` file that couldn't migrate the same way — leading to
new `keys.backup.*` infrastructure AND a THIRD independent 2021-era bug
in `crypt.C25519.load_keypair` (unrelated to `inline_elf`, a copy-paste
wrong-file-read + unconditional prefix-strip). All fixed, verified
against a real key, committed (`0875c8668` + `94aa460a7`). Full account
of that final stretch is in `data/ai-mem/claude/feedback-cpanm-
triggered-inline-elf-utf8-boundary-bug.md`'s "FULLY CLOSED" section —
read that for the complete, current picture rather than treating this
doc's original RESOLVED section below as the end of the story.

## RESOLVED 2026-08-26

H1 confirmed and root-caused precisely, via a live diagnostic (`P7_ELF_DIAG`
instrumentation in `AMOS7::CHKSUM::ELF::elf_chksum`, since removed) rather
than the falsification steps below — same conclusion, faster path. Two
distinct, real bugs in `inline_elf`'s C source
(`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm`), both now fixed:

1. **Stale `len`** (~line 48): `STRLEN len = SvCUR(input_str)` was
   captured *before* `sv_2pvutf8_nolen()` grows the buffer for any byte
   >= 0x80. The loop decrements `len` by the real bytes consumed each
   iteration, so near the end of a high-byte-dense buffer `len -=
   u8_len` can go negative on an *unsigned* STRLEN, wrapping to a huge
   value and reading past the buffer into adjacent memory. Fix: compute
   `len` from `SvCUR(input_str)` *after* the upgrade call.
2. **Forced `u8_len = 1`** (~line 132, since removed): after decoding,
   `if (character < 256) u8_len = 1;` was intended to treat the decoded
   *value* as byte-like, but it also cut the buffer *advance* to 1 byte
   — wrong for every upgraded high byte, which is always a genuine
   2-byte UTF-8 sequence. This misaligned the cursor onto the trailing
   continuation byte and cascaded "unexpected continuation byte" errors
   through the rest of the buffer. Fix: removed — advance by the real
   decoded `u8_len` always; `character`'s value was already correct
   without the override. Also needed a companion fix: `next_chr` (the
   `send` boundary arg to `utf8_to_uvchr_buf`) was an **uninitialized**
   local, giving the decoder no real bounds at all — replaced with a
   proper `str_end = str + len` computed once before the loop.

Why this wasn't visible in the falsification steps as originally
planned: `is_true($enc_bin, FALSE, TRUE)` on `pack("Q*", @quad_int)` is
exactly the high-byte-dense 32-byte case that triggers both bugs
together — confirmed directly via the diagnostic (263 real "Malformed
UTF-8" warnings fired per `key_32` call before the fix, 0 after).

**Verified**: C and pure-Perl fallback now agree exactly (640/640
random binary vectors, lengths 1–512 bytes, both elf modes; see
`elf-chksum-c-vs-pure-perl-utf8-divergence.md`). Real key decryption
independently confirmed working via `v7.keys enc-key-chksum` on a
remote server that never received the triggering `dist-upgrade` (still
perl 5.40.1, original untouched `.so` — a clean pre-incident
reference, not a test of this fix).

**Important, and it cost real time to establish**: fixing the algorithm
does **not** recover the key. `key_32('test-passphrase-13chars')` now
gives a *third* value (`7143e78d...`), matching neither the historical
5.40 value (`47639ed1...`, from kimi's now-destroyed old-`.so` A/B test)
nor the broken 5.42 value (`89965518...`) — because the original key was
encrypted using whatever the *buggy* behavior produced at the time, not
a mathematically correct computation. Recovery and fixing are two
separate goals: recover first (bit-exact reproduction of the original
buggy behavior — the remote server, above), fix second (this), then
re-encrypt/re-sign under the corrected algorithm.

**Fallout, accepted as normal migration cost, not a new problem**: the
corrected algorithm changes checksums for any file whose signed payload
contains non-ASCII bytes, so ~2233 of 8177 files need a one-time re-sign
once a working signing key is available locally again (via the decrypt
→ re-encrypt path above). Precedented — comparable in kind to earlier
re-sign requirements from footer/endline-state changes.

**Backlog captured for later** (not urgent, deferred until after this
cleanup): `-VL7`'s reference string (`bin/amos-chksum`, ~line 242) was
designed to catch `Digest::Elf`-vs-custom-implementation drift, not
this bug class — it happened to catch bug #2 (single stray high byte
is enough) but would *not* reliably catch bug #1 (needs real high-byte
*density* to underflow, which a 25-byte/1-high-byte string can't
produce). Also: no warning exists today when a module's live-recomputed
version tag doesn't match its last-recorded one. Longer-horizon: a
nightly forensics-zenka sweep across the main checksum/crypto
algorithms (BMW, ELF, JHA, Twofish/Curve25519 round-trip), comparing
live output against pinned known-good reference vectors, would catch
this whole class of silent algorithm-output divergence early instead of
after production signature failures.

---

Static-analysis conclusion: the most probable culprit is **`inline_elf`
(the compiled `AMOS7::CHKSUM::ELF::inline_elf`, called reachably from
`AMOS7::13::key_32` via `is_true`), which is silently sensitive to the
libperl UTF-8 decoding API for byte inputs with any octet >= 128** — and
that API has almost certainly shifted in observable behavior between
libperl 5.40 and 5.42 for malformed continuation bytes. This is exactly
the surface that got a fresh .so tonight (see
`~/.7/inline-code/inline_elf.IJGVOPICH2BTB6Q/lib/auto/COMPILE/000/AMOS7/CHKSUM/ELF/inline_elf/inline_elf.so`,
mtime Aug 25 06:04 — after the cpanm --force cascade).

## H1 (primary) — inline_elf UTF-8 upgrade on binary input; libperl UTF-8 error handling differs 5.40 vs 5.42

Reachability, verified by re-reading production code (not the summary):

- `crypt.C25519.decrypt_priv_keystr` → `AMOS7::13::key_32(\$dec_passwd)`.
- `key_32` (no keyname_seed) → `gen_entropy_values($pass_sref, 113,
  \@pwd_entropy_val)`, then loops:
  `is_true($enc_bin, FALSE, TRUE)` on the packed 32-byte candidate, and
  `is_true(\$result, 2, 1)` inside `gen_entropy_values`.
- `AMOS7::Assert::Truth::is_true`
  (`data/lib-path/pm/AMOS7/Assert/Truth.pm:108`) →
  `calc_true( elf_chksum($data_ref, 0, $elf_mode, $shift_bits) )` for
  each mode in `@assertion_modes = qw| 4 7 |`.
- `AMOS7::CHKSUM::ELF::elf_chksum`
  (`data/lib-path/pm/AMOS7/CHKSUM/ELF.pm:91`) →
  `inline_elf( $$data_ref, $start_chksum, $elf_mode, $shift_bits,
  $overflow_threshold )` — dereferenced by value.
- `inline_elf` C source
  (`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm:48-49`):

    ```
    STRLEN    len = SvCUR( input_str );       // <-- can contain \0 bytes
    U8* str       = sv_2pvutf8_nolen( input_str );
    ```

  `sv_2pvutf8_nolen` **upgrades the SV in place to UTF-8**. `len` is
  captured *before* that upgrade — i.e. `len` is the original byte
  count, but `str` afterwards points at a longer UTF-8 byte sequence
  (every 0x80..0xFF octet gets replaced by two bytes).

- The loop then reads `str` byte-by-byte using `len` (the original,
  pre-upgrade byte count) as its termination counter. For a
  high-bit octet the decode path
  (`utf8_to_uvchr_buf(...)` → `character < 256` → `u8_len = 1`)
  intentionally recovers the original codepoint value on the *first*
  iteration for that octet, but only advances `str` by 1. The **second**
  byte of the two-byte UTF-8 sequence (0x80..0xBF) is then read as if
  it were the start of the next codepoint on the next iteration — and
  it is not a valid UTF-8 start byte.

- What `utf8_to_uvchr_buf` returns for that spurious continuation byte
  and how the following iterations behave (how many bytes it "consumes",
  what codepoint it emits, whether it substitutes REPLACEMENT
  U+FFFD, etc.) is exactly the surface of libperl's UTF-8 malformed
  input handling — and that surface is not part of the Perl 5.4x stable
  language contract. It is well-established that Perl bumps the
  `PERL_API_VERSION` on every even-numbered production line
  (5.40 → 5.42 is one such bump; every XS module MUST be rebuilt) and
  makes small internal API/behavior tweaks.

Why this specifically breaks *key derivation* but not the isolated tests
that were already run:

- The user's isolated `Digest::BMW`, `Crypt::Misc::encode_b32r`,
  `Crypt::Mode::CBC('Twofish',0)`, `curve25519_public_key`, and
  `true_int`/`true_float` tests all operated on either pure-ASCII input
  or well-formed byte payloads passed through APIs that do not perform
  in-place UTF-8 upgrade. None of them exercises `inline_elf`.
- `bin/is-true true|false|TRUE|FALSE` and the user's manual truth vectors
  are all ASCII → no octets >= 128 → the UTF-8 upgrade path in
  `inline_elf` is a no-op → unchanged result.
- `key_32`'s inner loop calls `is_true(\$result, 2, 1)` where
  `$result` is a `divide_13` output, i.e. a `sprintf "%09d"` decimal
  string (ASCII only) — that path is also mostly UTF-8-safe.
- But `key_32`'s *outer* validity check is
  `is_true($enc_bin, FALSE, TRUE)` on `$enc_bin = pack "Q*", @quad_int`
  — packed 32-byte binary with essentially uniformly distributed byte
  values, ~7/8 of which will have high-bit set. This is exactly the
  input class that hits the UTF-8-upgrade / malformed-continuation-byte
  branch on every iteration.
- If `is_true($enc_bin, ...)` returns FALSE where it previously returned
  TRUE (or vice versa), `key_32` reseeds via `RECALCULATE_KEY_32:` and
  eventually settles on a *different* 32-byte key than the historical
  key. Twofish-decrypting the intact 64-byte ciphertext with a different
  key produces valid-length (64 B) but semantically wrong output → the
  compare-keypair signature check fails → "password is not correct".
- This is consistent with the observed shape of the failure: exactly 64
  bytes returned (Twofish-CBC-no-padding is deterministic on length),
  no crash, no length mismatch, no exception — only a keypair-match
  failure. That is exactly what a wrong-key Twofish decrypt looks like.

Falsifiable prediction (please test in this order, cheapest first):

1. Under the still-installed perl 5.40.1 environment, run
   `AMOS7::CHKSUM::ELF::elf_chksum(\pack("Q*",1,2,3,4), 0, 7, 13)` and
   the same call under perl 5.42.3. If the two 9-digit outputs
   differ, H1 is confirmed. (Test on several `pack "Q*", @rand`
   inputs; a single mismatch on any high-bit-heavy input is
   sufficient.)
2. Force `AMOS7::CHKSUM::ELF::inline_elf` to the Perl fallback
   (temporarily rename the freshly built `.so` at
   `~/.7/inline-code/inline_elf.IJGVOPICH2BTB6Q/lib/auto/COMPILE/*/AMOS7/CHKSUM/ELF/inline_elf/inline_elf.so`)
   and retry decryption. This *also* diverges — see H1a below — but if
   the fallback produces a *third* key that matches neither the old
   nor the new C build, H1 is still confirmed on mechanism.
3. Definitive: under perl 5.40.1 (with its original .so), derive
   `key_32(\$dec_passwd)` on the real password and compare the 32-byte
   result byte-for-byte with the same call under perl 5.42.3. If they
   differ, H1 is confirmed end-to-end and the failure is not in
   Twofish, curve25519, or file I/O.

Note on the `.disabled` folder under
`~/.7/inline-code/inline_elf.IJGVOPICH2BTB6Q/`: this shows something has
already been fighting the ELF-inline cache in this session. Whatever
was moved aside there is part of the same problem surface — don't
assume it was benign housekeeping.

## H1a (co-hypothesis, same root) — inline_elf C-vs-fallback divergence is a distinct effect from H1

The separate task
`data/tasks/elf-chksum-c-vs-pure-perl-utf8-divergence.md` documents
that C-`inline_elf` and pure-Perl-fallback `inline_elf` diverge on
multi-byte input (fallback uses `unpack "U*"`, C effectively does the
same per-codepoint interpretation but after in-place upgrade).

This means: **any time the .so fails to load, the fallback runs, and
`key_32` derives a different key than when the .so loads**. So
regardless of H1's Perl-version drift, a load failure alone would
produce the exact observed symptom. So a second falsifiable check:

- Confirm the .so is actually being loaded. From
  `~/.7/inline-code/inline_elf.IJGVOPICH2BTB6Q/`, run under the current
  perl:
  `perl -M'lib qw(data/lib-path/pm)' -MAMOS7::CHKSUM::ELF -e 'warn ref \&AMOS7::CHKSUM::ELF::inline_elf; warn \&AMOS7::CHKSUM::ELF::inline_elf'`
  and diff the coderef address across runs. If a warn
  `<< compilation of 'inline_elf' not successful >>` appears in stderr
  at any point during a real p7 startup, the fallback is silently
  installed and H1a is the acute failure — H1 is the latent one that
  will bite again after the next perl bump.

  I already confirmed empirically in this session that under the
  freshly-installed perl 5.42.3, `AMOS7::BitConv::bit_string_to_num`
  loads the C version (matches `grok_bin` semantics) and the fallback
  (which uses `unpack "Q", pack "B64", ...`) would produce wildly
  different values (e.g. C=8 vs fallback=128 for input "1000"). So the
  BitConv .so is currently OK. `inline_elf` is not covered by that
  test — it should be similarly probed before drawing final conclusions.

## H2 (secondary) — file-read path change: NOT LIKELY, but cheap to rule out

The task listed file-read parsing as an open question. I read
`crypt.C25519.load_from_string` and `crypt.C25519.decrypt_priv_keystr`
end-to-end. Both `key_str` and `$dec_passwd` reach
`decrypt_priv_keystr` as raw already-decoded 64-byte and arbitrary-length
strings respectively. Length is guarded (`length($key_str) != 64` early
return). If the file-read step produced a wrong 64-byte ciphertext, the
symptom would still be identical to H1 — same 64 B out, wrong keypair —
so this cannot be distinguished from H1 by symptom alone.

Cheapest ruling-out: hex-dump the encrypted 64 B blob at the point it
enters `decrypt_priv_keystr` under both the old (perl 5.40.1) and new
(perl 5.42.3) environments and diff. If they match, H2 is dead. Given
the user confirmed the file itself is byte-identical and untouched, and
`decode_b32r` cross-version already tested clean, this is a
low-probability lead and I recommend testing H1's step (1) first.

## H3 (tertiary) — pure-Perl integer/bit arithmetic drift 5.40 → 5.42

The task explicitly flagged this as untested. My reading of the code
(`divide_13`, `bits_to_comp_int`, `offset_comp_int`, `get_seed_bits`,
`nor`, `sprintf "%032B"`, `pack "Q*"`, `unpack "w"`) shows nothing that
depends on any of the well-known Perl 5.4x integer/precision changes.
All values stay within 64-bit UV range (`%032B` on values < 2^32,
`pack "Q*"` on 19-digit decimal strings which fit `unsigned long`).
`Math::BigFloat` is invoked only for input length >= 10 in
`calc_true` — this path IS reachable from `key_32` via `is_true` when
the numeric arg check runs. `Math::BigFloat` semantics changing between
versions IS a real historical risk vector, but the user already ruled
out `true_int` (which handles the <2^64 integer branch — the one
`calc_true` takes for `$enc_bin` which is a binary string). This is a
weak lead; test only after H1 and H1a are eliminated.

## What I ruled OUT that the summary implicitly held open

- `bit_string_to_num`: I ran it under the current perl 5.42.3 with the
  freshly-built .so against `eval "0b..."` reference values on
  4-bit, 32-bit, and 49-bit inputs — all match. The freshly-built .so
  is producing correct C-semantics results. If the fallback were being
  used instead, its results would diverge by orders of magnitude for
  short bitstrings (fallback right-pads to 64 bits then unpacks Q,
  which for "1000" gives 128 vs the correct 8). This alone would have
  broken key_32 differently, so the fact that the .so is loading is
  actually good news — it narrows the surface.
- `key_32` determinism within a single run: confirmed identical across
  repeated calls on the same input (`3c70928269856c78e4ff55e9d53ad11b
  ef0718fe17568b05ffcd6734b3626988` on my synthetic passphrase). So
  there is no random-source drift, no PRNG contamination, no
  uninitialized memory. The failure is a *deterministic* different key
  derivation, exactly what a semantic change in `inline_elf` output
  would produce.

## Recommended action ordering

1. Run H1 falsification step (1): compare `elf_chksum` on a
   high-bit-heavy binary input under perl 5.40.1 vs 5.42.3. This is a
   single 10-line script per version. If they differ, H1 is done.
2. If they match, run H1a probe: confirm the .so is loading under
   real p7 startup (grep for the warn text or diff coderef addr).
3. If both come back clean, run H2's blob-diff.
4. Only then consider H3.

Do not attempt any fix (source edit, .so rebuild, cache clear) before
step 1 completes — the current cache state is diagnostic evidence.

#,,,,,.,,,,.,,,.,,,..,,..,..,,,..,,..,,,,,,,,,..,,...,...,.,.,,.,,...,.,,,...,
#VEBNA44C7J4DLA6C2ZCAXQVNCISE42MABKF4E52LTH6AXJ34PXX5TRR7K3YT6PXMA44U3EEY3GKQ2
#\\\|H57TRIEOK3LHUV3GPICPHL5SJK5NPQQV7WDEGZUTGQA3EQD773A \ / AMOS7 \ YOURUM ::
#\[7]7FYENK27AD2SQWVXBNDICNKAOQH6CL4TPRYMFS5LKNUDLKBNX6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
