## task: `AMOS7::CHKSUM::ELF` — compiled-C vs pure-Perl-fallback divergence on
## non-ASCII input, correlated with the 2026-08-25 mass signature-verification
## failure (2212 files)

## status: RESOLVED 2026-08-26 — root-caused to two real C bugs in
## `inline_elf`, both fixed, C and pure-Perl fallback now verified identical
## (640/640 random vectors). See "RESOLVED" section below the context, and
## `c25519-key-decryption-failure-hypothesis-2026-08-25.md` for the linked
## key-recovery side of this incident (separate goal, same root cause).

## context

2026-08-25: `v7.sourcecode verify-p7-signatures` reported 2212 of 8177 files
failing signature validation (`bmw-chksum-matches: false` and
`AMOS-chksum-matches: false`, uniformly, for all 2212 — never a signature-
only failure). User also reported `crypt.C25519` private key decryption
failing (`password is not correct`) despite a confirmed-correct password and
an intact key file — investigated separately, inconclusive (every crypto
primitive in that chain — BMW hash, `Crypt::Misc::encode_b32r`/`decode_b32r`,
`Crypt::Mode::CBC`+Twofish including old-CryptX-encrypt/new-CryptX-decrypt,
`Crypt::Curve25519` public-key derivation — tested clean, old vs new
`libcryptx-perl` 0.089→0.090, both directions; no divergence found; still
unexplained, treat as a **separate, still-open problem**, not solved by
this doc).

Investigation started from a real environment event this session: installing
`Git::Native`/`Git::Libgit2` via `sudo cpanm --force` triggered an apt
dependency chain that also updated `libcryptx-perl` (0.089→0.090) and,
separately, caused the system's default `perl` interpreter identity used by
`Inline::C`'s cache-keying to shift, forcing a fresh recompile of several
long-cached `Inline::C` subroutines under `~/.7/inline-code/` — including
`inline_elf` (backing `AMOS7::CHKSUM::ELF::elf_chksum`), `true_int`, and
`true_float` (backing `AMOS7::Assert::Truth::is_true`).

## RESOLVED 2026-08-26

Root cause: two real bugs in `inline_elf`'s C source
(`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm`), not a genuine
decode-model mismatch between the C and pure-Perl implementations.

1. `STRLEN len = SvCUR(input_str)` was captured *before*
   `sv_2pvutf8_nolen()` grows the buffer for bytes >= 0x80 — near the
   end of a high-byte-dense buffer, `len -= u8_len` can underflow the
   unsigned STRLEN and read past the buffer into adjacent memory.
2. `if (character < 256) u8_len = 1;` after decode cut the buffer
   *advance* to 1 byte for every upgraded high byte (always a genuine
   2-byte sequence), misaligning the cursor onto the trailing
   continuation byte and cascading errors through the rest of the
   buffer. A companion bug — `next_chr` (the `send` bounds argument to
   `utf8_to_uvchr_buf`) was an uninitialized local, giving the decoder
   no real bound at all — was fixed alongside it (`str_end = str + len`
   computed once before the loop).

Both fixed. **Verified**: C and pure-Perl fallback now produce
byte-identical output — 640/640 random binary vectors (lengths 1–512),
both elf modes, zero mismatches; plus the original 12 targeted vectors
(ASCII, control bytes, high bytes, random 32B, mixed malformed UTF-8).
The pure-Perl fallback's own `unpack('U*', ...)` codepoint loop was
correct all along — the "KNOWN LIMITATION" comment that used to sit in
its source (see `AMOS_13_ELF.pm`, in the fallback closure) documented
an earlier failed attempt to chase this as a decode-*model* difference
via an `Encode::decode` byte-level rewrite; that attempt correctly
found no improvement, because the actual bug was entirely on the C
side. Comment has been corrected in place.

Full incident timeline, key-recovery status (separate from this fix),
fallout (~2233 files need re-sign once a working key exists locally),
and backlog ideas (VL7 canary hardening, version-mismatch warning,
nightly forensics-zenka algorithm-divergence sweeps) are in
`c25519-key-decryption-failure-hypothesis-2026-08-25.md`'s RESOLVED
section — that's the fuller writeup, this doc stays focused on the
C-vs-pure-Perl mechanism specifically.

---

Two false leads chased and ruled out before the actual mechanism, kept here
because they document real, verified facts even though they're not the
explanation:

- **`libcryptx-perl` 0.089→0.090 itself**: ruled out. Raw `Digest::BMW`
  hashing, `Crypt::Misc::encode_b32r`/`decode_b32r`, and `Crypt::Mode::CBC`
  Twofish encrypt/decrypt were all tested byte-identical between the old
  (0.089, perl 5.40.1) and new (0.090, perl 5.42.3) library, including
  cross-version (encrypt under old, decrypt under new) — the real-world
  scenario. No divergence anywhere in that stack.
- **`inline_elf` cross-call state-leakage**: real, reproducible (calling
  `elf_chksum($data, 0, $mode, ...)` twice in the same process with
  identical explicit arguments gives a different result the second time —
  confirmed present in BOTH the Oct-2025-compiled `.so` and today's fresh
  recompile, so it's not new). **Directly refuted as the cause** by the
  user: batch verification across thousands of files, with the file/check
  order changing between runs, has passed 100% for months up to the last
  commit before today — a call-order-dependent bug would have made batch
  verification unreliable all along, not suddenly break uniformly. Worth
  fixing on its own merits (violates the function's own documented
  `$start_sum`-controls-all-state contract) but it is not what changed.

## what actually diverges, demonstrated with the real production code

`AMOS7::CHKSUM::ELF::elf_chksum` (compiled via `Inline::C`, source in
`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm`) has a pure-Perl
`fallback` sub (same file, ~line 138) that `AMOS7::INLINE::compile_inline_source`
installs in place of the compiled version if C compilation fails at module
load time. Both claim to implement the same "AMOS-13-ELF-7" algorithm with
identical parameters (`elf_mode=7` default, `shift_bits=13`,
`overflow_threshold=0xFE000000`, `z_val=777` for null bytes).

**They are not equivalent.** Demonstrated directly, both called once each in
a fresh process (no call-order confound), same real file
(`bin/dev/ccdiff`):

```
compiled-C   inline_elf (mode 7): 025013852
pure-Perl fallback      (mode 7): 022105354
```

Root cause, pinpointed via incremental byte-by-byte trace (prefixes of
`"caf\xc3\xa9X"`, the UTF-8 encoding of "café" + "X"):

```
len=1 bytes=[63]           C=000000099  perl=000000099  match
len=2 bytes=[63 61]        C=000012769  perl=000012769  match
len=3 bytes=[63 61 66]     C=001634534  perl=001634534  match
len=4 bytes=[63 61 66 c3]  C=007934717  perl=007869379  DIVERGE
len=5 bytes=[.. c3 a9]     C=009150077  perl=000524841  DIVERGE
len=6 bytes=[.. c3 a9 58]  C=030547581  perl=000079064  DIVERGE
```

Pure ASCII prefixes match exactly. The instant the first byte of a
multi-byte UTF-8 sequence (`0xc3`, lead byte of é) is added, they diverge —
**not** after the full character decodes, at the very first byte. Once one
implementation is one iteration-step ahead/behind the other, every
subsequent incremental hash value drifts further apart (matches the
growing divergence at len=5, len=6).

**Why**: the two implementations use structurally different iteration
models over the input whenever multi-byte UTF-8 appears:
- pure-Perl fallback: `unpack('U*', $input_str)` — decodes the *entire
  string* as UTF-8 upfront, iterates over completed **codepoints** (one
  step per full character, e.g. é = one step, value 233).
- compiled-C: manually walks **raw bytes**, decoding multi-byte sequences
  itself via `utf8_to_uvchr_buf` + explicit `u8_len` tracking (this is the
  code the `9affb84e0` "fix infinite-loop on malformed UTF-8" commit,
  2026-07-26, touched — real, unrelated-to-tonight, already-landed fix,
  confirmed via unchanged `.inl` source MD5 comparison against a still-
  intact pre-tonight cached build for a related sub).

Confirmed exhaustively — every UTF-8/non-ASCII test case diverges, valid
*and* malformed, not just an edge case:

```
valid 2-byte utf8 (e-acute)       DIVERGE
valid 3-byte utf8 (euro)          DIVERGE
valid 4-byte utf8 (emoji)         DIVERGE
malformed: lone continuation      DIVERGE
malformed: truncated 2-byte       DIVERGE
malformed: truncated 3-byte       DIVERGE
malformed: invalid start byte     DIVERGE
malformed: overlong encoding      DIVERGE
raw high bytes (binary-ish)       DIVERGE
```

Null bytes (`\0`), by contrast, match perfectly between C and pure-Perl
across every tested shape (single, doubled, embedded, leading/trailing) —
the `z_val=777` substitution path is NOT where they diverge; it's
specifically multi-byte-UTF-8 iteration.

## a third, independent data point (not part of the divergence, a sanity
## check)

`bin/dev/elf-dbg` — an older, simpler standalone prototype implementing
the textbook/classic ELF hash (`h = (h<<4) + c`, mask `0xF0000000`, shift
24, **byte-level iteration, zero UTF-8 awareness** — a third distinct
model from both of the above) — gives `005327523` for input `"LOVES"`,
which **exactly matches mode=4** of the current compiled-C
`elf_chksum('LOVES', 0, 4, 13)`. Cross-validates that mode=4 of the current
compiled-C path is correct against an independent reference of the
standard ELF hash algorithm. (`bin/elf`, a separate standalone tool, uses
yet another implementation, `Digest::Elf::elf()` — also diverges from all
of the above; it's explicitly a deprecated path per `AMOS7::CHKSUM::ELF`'s
own comment "`will _no_longer_ use Digest::Elf fallback if not compiled`"
and null-terminates on embedded `\0`, giving 0 for most of the null-byte
test cases — not a useful reference for anything, just confirms it's a
genuinely different, abandoned algorithm.)

## correlation with the real failure set

Of 100 sampled currently-failing files (from the live 2212), **99 contain
at least one non-ASCII byte**; only 1 is pure ASCII. Strong correlation,
not yet proven causal — see open questions below.

## what's proven vs. still open

**Proven:**
- The C-vs-pure-Perl-fallback divergence is real, reproducible, and
  specifically triggered by multi-byte UTF-8 (valid or malformed),
  starting at the first byte of the sequence.
- It correlates strongly (99/100 sampled) with the real failing file set.
- The compiled-C path is independently cross-validated as correct (mode=4
  matches the classic textbook ELF hash via an unrelated tool; both
  `true_int`/`true_float` and `elf_chksum`'s mode=4/7 combination via
  `bin/amos-chksum -v` match the user's own long-trusted reference
  vectors).

**NOT proven — the actual gap to close before treating this as solved:**
- Whether the pure-Perl fallback is *actually* what executes during real
  production signing and/or verification, at any point. A plain `use
  AMOS7::13;` in the current environment loads cleanly with no "installing
  pure-perl alternative" warning — meaning ordinary module load uses the
  compiled-C path successfully right now. The captured verbose output of
  the actual `v7.sourcecode verify-p7-signatures -vvq` run
  (`/tmp/verify-verbose.txt` at investigation time) shows zero occurrences
  of "pure-perl", "not successful", or "compilation of" — no direct
  evidence the fallback fired during that specific run.
- User raised a real possibility not yet checked: an `eval` somewhere in
  the calling chain could swallow evidence of a runtime (not just
  load-time) fallback/failure without it surfacing in captured output.
  `compile_inline_source` only runs its compile-or-fallback decision ONCE
  per process at `use AMOS7::CHKSUM::ELF;` time — not per-call — so if a
  *different* process (a long-running zenka, or a differently-invoked
  script) hit a compile failure at some point and silently locked in the
  fallback for its remaining lifetime, that would be invisible to a fresh
  `perl` test script's clean load.
- No process inspection was completed to identify which process(es)
  actually signed the currently-failing files, when, or under which
  compile-or-fallback state — this is the most direct way to close the
  gap and hasn't been done.
- The parallel key-decryption failure (`crypt.C25519`) remains completely
  unexplained by anything in this document — every primitive in that
  separate chain tested clean. Do not assume the two problems share a
  root cause just because they surfaced the same night.

## UPDATE 2026-08-25 (later same session): sharper root cause found, and a
## direct connection to the parallel `crypt.C25519` key-decryption failure

Dispatched an independent Opus analysis (`claude_dispatch`, full budget used,
findings durably saved by Opus itself mid-analysis to
`data/tasks/c25519-key-decryption-failure-hypothesis-2026-08-25.md` — read
that file in full, it's the primary source, this is a condensed pointer to
it). Parallel `kimi_dispatch(k3-256k)` for the same question **failed
outright** — 1800s timeout, no resume session ID, nothing recoverable, no
useful output. Don't retry that combination blindly; if re-dispatching,
consider it may need a smaller/narrower prompt or a different model.

**Opus's finding is sharper than the codepoint-vs-byte-iteration framing
above and supersedes it as the primary hypothesis**: the bug isn't (only)
in the pure-Perl fallback diverging from the C code — it's a real bug
**inside the compiled C code itself**, in `inline_elf`
(`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm` ~line 48-49):

```c
STRLEN    len = SvCUR( input_str );        // captured BEFORE UTF-8 upgrade
U8* str       = sv_2pvutf8_nolen( input_str );  // upgrades SV to UTF-8 IN PLACE
```

`sv_2pvutf8_nolen()` re-encodes the SV to UTF-8 **in place**, which for any
byte >= 0x80 makes the underlying buffer LONGER (one byte becomes a 2-byte
UTF-8 sequence). But `len` was captured *before* that upgrade, so it still
holds the ORIGINAL (shorter, pre-upgrade) byte count. The loop then walks
`str` (the now-longer, re-encoded buffer) but only for `len` (the original,
too-small) iterations — a real, source-level boundary bug, independent of
which perl version runs it. Its *exact* observable behavior for
high-bit/malformed bytes further depends on `sv_2pvutf8_nolen`'s own
internal libperl behavior, which is not guaranteed stable across perl minor
versions (5.40.1 -> 5.42.3 is exactly such a version bump) — so the same
buggy C source can produce different wrong answers on different perl
versions even with a byte-identical `.so` rebuild.

**Direct connection to the OTHER unresolved problem this session
(`crypt.C25519` private key decryption failing, "password is not
correct" despite a confirmed-correct password and intact key file)**:

```
crypt.C25519.decrypt_priv_keystr
  -> AMOS7::13::key_32(\$dec_passwd)
    -> AMOS7::13::gen_entropy_values(...)
      -> AMOS7::Assert::Truth::is_true( $enc_bin, FALSE, TRUE )
         where $enc_bin = pack("Q*", @quad_int)  -- essentially random
         binary, ~7/8 of bytes have the high bit set
        -> AMOS7::CHKSUM::ELF::elf_chksum(...)
          -> inline_elf(...)   <-- the buggy code above
```

This is EXACTLY the input class (high-entropy binary, most bytes >= 0x80)
that hits the `sv_2pvutf8_nolen`/stale-`len` bug on nearly every byte. If
`is_true()` on that blob evaluates differently under today's environment
than it did when the real key was originally encrypted, `key_32` derives a
**different 32-byte key from the same correct password** —
Twofish-decrypts the intact ciphertext into a valid-LENGTH (64-byte) but
semantically WRONG result, which is exactly the observed symptom
(`compare_keypair` reports mismatch, not a crash, not a length error).

**Confirmed directly this session** (not just Opus's static read): tested
`elf_chksum` against 5 genuinely high-entropy 32-byte blobs (10/32,
6/32, etc. bytes with the high bit set — NOT small sequential integers,
which pack mostly-zero and don't exercise this path) — **every single
blob diverges on both mode4 and mode7** between the current environment
and a forced-old-perl-5.40.1 run. Caveat: that forced-old run fell back to
pure-Perl rather than loading the actual old compiled `.so` (an
incidental harness problem, not yet debugged — Inline::C kept reporting
`<< compilation of 'inline_elf' not successful >>` under the forced
5.40.1+extracted-old-CryptX setup), so this specific comparison is still
"current compiled-C vs pure-Perl fallback," not the fully clean
"old-compiled-C vs new-compiled-C" comparison Opus's H1 specifically
predicts. **The gap remaining to fully close H1**: get the actual old
`inline_elf.so` (`~/.7/inline-code/inline_elf.IJGVOPO3EXIKZZY/lib/auto/
COMPILE/000/AMOS7/CHKSUM/ELF/inline_elf/inline_elf.so`, dated Oct 10 2025)
to load and run cleanly under perl 5.40.1 without falling back — likely a
stale `.lock` file or a missing dependency check unrelated to the actual
algorithm; debug that harness issue rather than the algorithm itself.

Opus's own file has the full reasoning, falsifiable predictions in
priority order, and what it independently ruled out (confirmed
`AMOS7::BitConv::bit_string_to_num` loads correctly and matches expected
values under current perl — narrows the surface away from BitConv).
**Read `data/tasks/c25519-key-decryption-failure-hypothesis-2026-08-25.md`
before starting any fix work** — it has the priority-ordered next steps.

## UPDATE 2026-08-25 (later still): a SECOND, independent, likely more
## consequential bug found — `shift_limit` static-vs-per-iteration mismatch

Found by the user directly comparing the C source
(`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm` lines 44-45, 83) against
the pure-Perl fallback (lines 168-169) side by side. This is INDEPENDENT of
the UTF-8/`sv_2pvutf8_nolen` finding above — a plain transcription bug, not
a libperl-version-sensitivity issue, and it can affect ANY sufficiently
long input, ASCII or not, not just non-ASCII content.

**C code** — `shift_limit` computed ONCE, before the loop, from the
*initial* `result` (= `start_sum`, typically 0 for a top-level call —
`~0 >> 4`, a large, effectively-static value near the top of the 32-bit
range for the whole computation):

```c
unsigned int shift_limit = ~result;
shift_limit >>= 4; // limiting left shift [ elf mode ] beyond 27 bits

while ( len > 0 ) {
    if ( left > shift_reset && result >= shift_limit )
        left = shift_reset; // reset to 4 to avoid entropy loss
    ...
```

**Pure-Perl fallback** — recomputes `$shift_limit` fresh on EVERY loop
iteration, tracking the CURRENT, evolving `$result`:

```perl
foreach my $character ( unpack('U*', $input_str) ) {
    my $shift_limit = ~$result >> 4;   ## <-- recomputed every iteration
    if ( $elf_mode > $shift_reset && $result >= $shift_limit ) {
```

Since the C version's threshold barely moves (computed once from
`start_sum`), the entropy-loss-avoidance branch (`left = shift_reset`,
dropping the shift amount from `elf_mode` to 4) essentially never fires in
C for a typical top-level call. In the pure-Perl fallback, the threshold
SHRINKS as `result` grows (since `~result` shrinks as `result` grows), so
it becomes increasingly likely to trigger partway through ANY sufficiently
long input — a structurally different code path taken partway through the
computation, independent of character content. This looks like a plain
transcription error: someone moved a one-time setup line inside the loop
body when writing the "equivalent" pure-Perl version. Fix (once confirmed
as the intended C semantics — check with the original author/design intent
before assuming which side is "correct", though the C code's own comment
"limiting left shift... beyond 27 bits" reads like intentional one-time
setup, not a per-step recalculation): move the pure-Perl fallback's
`$shift_limit` computation OUTSIDE its `foreach` loop, computed once from
`$start_sum` before the loop starts, matching the C structure exactly.

This bug and the `sv_2pvutf8_nolen`/UTF-8 one above are NOT mutually
exclusive — both are real, both live in the same pure-Perl fallback vs
compiled-C comparison, and either (or both together) could explain the
observed divergence depending on the specific input. Whoever fixes the
fallback needs to fix BOTH before treating it as verified-equivalent to
the compiled C again.

## how to close the gap (next steps for whoever picks this up)

1. Identify exactly which process/command signed each of a small sample
   of currently-failing files (git blame the file's own history combined
   with commit timing may narrow this, though signing may happen out-of-
   band from commits via the pre-commit hook or manual `sign`/
   `update-signatures` calls — check both).
2. Instrument (temporarily) `AMOS7::INLINE::compile_inline_source`'s
   fallback-install branch to log unconditionally to a fixed file path
   (bypassing whatever `eval`/log-routing might be suppressing it), then
   re-run a real batch `update-signatures`/`verify-p7-signatures` pass and
   check whether it fires.
3. Once/if the fallback is confirmed as the live trigger: fix
   `AMOS7::INLINE::src::AMOS_13_ELF.pm`'s pure-Perl fallback to match the
   compiled-C's byte-level UTF-8 handling exactly (same `utf8_to_uvchr_buf`-
   equivalent semantics, not `unpack('U*')`), rather than patching around
   it — the fallback existing as a genuinely different algorithm is the
   actual defect.
4. Separately (lower priority, real but not urgent): fix `inline_elf`'s
   cross-call state bug (violates its own `$start_sum`-based statelessness
   contract) — real, demonstrated, present in both old and current
   compiled builds, but confirmed NOT the cause of tonight's incident.
5. Re-run `verify-p7-signatures` after any fix and confirm the 2212 drops
   to (ideally) 0, or a much smaller, independently-explained remainder.

## reproduction

All commands below run from repo root, no special setup beyond the
project's normal `data/lib-path/pm` local lib path:

```perl
use lib 'data/lib-path/pm';
use AMOS7::CHKSUM::ELF qw( elf_chksum );

## compiled-C path (normal) ##
my $c = elf_chksum("caf\xc3\xa9X", 0, 7, 13);

## the real fallback sub, verbatim from AMOS7/INLINE/src/AMOS_13_ELF.pm
## lines 138-186 (copy directly from that file, do not hand-retype) ##
## call with the same args, compare -- diverges from len=4 (first UTF-8
## lead byte) onward.
```

#,,.,,,,.,.,,,...,,.,,,,,,...,.,.,..,,,,.,,..,.,.,...,...,.,,,,..,...,.,.,.,.,
#6SD6NYUGAORHWWIVBSEEHAG7SHS2ZQP2QP2X5VV77CZWWOVRRYOTHUFC5H36P4S5YO7QXKQPECPEI
#\\\|X7BUN6WYC2YDDS2TC2TXYN7JDHR77TZCO45DKBABGPNGLP634KW \ / AMOS7 \ YOURUM ::
#\[7]6VL3Q5VUFBY4JV4XLP7DJSETYLIMH22GRJZ6WVMNW55M6EUNNGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
