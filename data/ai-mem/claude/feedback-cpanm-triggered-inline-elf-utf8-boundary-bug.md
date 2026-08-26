---
name: cpanm-triggered-inline-elf-utf8-boundary-bug
description: "RESOLVED 2026-08-26: sudo cpanm --force forced a perl 5.40.1->5.42.3 version churn that surfaced two real C-source bugs in AMOS7::CHKSUM::ELF::inline_elf (stale-len STRLEN underflow, forced u8_len=1 misalignment), both fixed and verified (C now matches pure-Perl fallback exactly); caused mass signature-verification failures and the user's C25519 key-decryption failure via key_32's entropy validity check -- key recovery confirmed separately via a remote server's pristine pre-incident environment, fix does not itself recover the key"
metadata:
  type: feedback
---

**2026-08-25, very long single-session investigation.** Two problems
surfaced the same night, both traced back to the same triggering event
but via DIFFERENT, only partially-overlapping mechanisms — do not conflate
them, but do start from this doc for either:

1. Mass source-code signature verification failure: 2212 of 8177 files
   failing (`bmw-chksum-matches`/`AMOS-chksum-matches` both false,
   uniformly, never a signature-only failure). Full investigation and
   reproduction: [[elf-chksum-c-vs-pure-perl-utf8-divergence]]
   (`data/tasks/elf-chksum-c-vs-pure-perl-utf8-divergence.md`).
2. `crypt.C25519` private-key decryption failing ("password is not
   correct") despite confirmed-correct password and intact key file.
   Opus's hypothesis + falsifiable test plan:
   `data/tasks/c25519-key-decryption-failure-hypothesis-2026-08-25.md`.
   **Not yet fully confirmed** — the cleanest test (old-compiled-`.so`
   vs new-compiled-`.so`, both genuinely compiled, no fallback) has not
   been completed; every attempt so far to force the OLD 5.40.1
   environment fell back to the pure-Perl path instead of loading the
   real old binary, for reasons not yet debugged (looks like a harness/
   `.lock` issue, not an algorithm issue).

**Triggering event**: `sudo cpanm --force Git::Native` (installing a new,
narrow CPAN dependency for an unrelated git-diff-migration task) triggered
a broader apt dependency chain that also bumped `libcryptx-perl`
(0.089->0.090) and — the actually consequential part — caused the
system's effective default perl to shift from 5.40.1 to 5.42.3 for the
first time in a long time, forcing several long-dormant `Inline::C` caches
under `~/.7/inline-code/` to recompile (`inline_elf`, `true_int`,
`true_float`, and the vendored `Crypt::Curve25519`'s XS `.so`, all
timestamped the same minute, ~04:17-04:18). See
[[cpanm-force-install-blast-radius]] for the general lesson about
`cpanm --force`'s blast radius; this note is about what that blast radius
actually turned out to touch, several hours of investigation later.

**The real bug, once found** (`data/lib-path/pm/AMOS7/INLINE/src/
AMOS_13_ELF.pm` ~line 48-49, found by a dispatched Opus analysis, not by
me): `STRLEN len = SvCUR(input_str)` is captured BEFORE
`sv_2pvutf8_nolen(input_str)` upgrades the SV to UTF-8 in place (which
lengthens the buffer for any byte >= 0x80). The loop then walks the
now-longer buffer but only for the original, too-short `len` — a genuine
C-source boundary bug, present regardless of perl version, whose exact
wrong output for high-bit/malformed bytes depends on `sv_2pvutf8_nolen`'s
own internal libperl behavior — which is NOT guaranteed stable across
perl minor-version bumps. Confirmed via direct testing: 5 genuinely
high-entropy 32-byte blobs (not small sequential integers — those pack
mostly-zero and don't exercise this path) diverge on EVERY blob, both
elf-mode 4 and 7, between environments.

**Why this reaches key decryption**: `crypt.C25519.decrypt_priv_keystr` ->
`AMOS7::13::key_32` -> `gen_entropy_values` -> `is_true($enc_bin, ...)`
where `$enc_bin = pack("Q*", @quad_int)` — exactly the high-entropy,
mostly-high-bit-byte input class this bug hits hardest. If `is_true()`
on that blob evaluates differently than when the real key was originally
encrypted, `key_32` derives a genuinely different 32-byte key from the
SAME correct password. Twofish then decrypts to a valid-LENGTH (64-byte)
but semantically wrong result — matching the exact observed symptom
(`compare_keypair` reports mismatch, not a crash/length error).

**What was ruled out first (real effort, real dead ends, don't re-chase
these)**: raw `Digest::BMW` hashing, `Crypt::Misc::encode_b32r`/
`decode_b32r`, `Crypt::Mode::CBC`+Twofish (including cross-version:
encrypt under old CryptX, decrypt under new — the actual real-world
scenario), `Crypt::Curve25519` public-key derivation — all tested
byte-identical old vs new library versions. A separate real-but-unrelated
bug was also found and ruled out as the cause: `inline_elf` has a
cross-call state-leakage bug (same explicit `$start_sum=0` on consecutive
calls in one process gives different results) — reproducible in BOTH the
Oct-2025 and today's compiled builds, so NOT new, and directly refuted as
the trigger by the user: batch verification across changing file
sets/order had been 100% reliable for months up to the last commit before
tonight — a call-order bug would have made that unreliable all along, not
suddenly break. Worth fixing on its own merits, wasn't the cause.

**Dispatch note**: `kimi_dispatch(model=k3-256k)` for this exact analysis
question FAILED outright — 1800s timeout, no resume session ID, nothing
recoverable. `claude_dispatch(model=opus)` succeeded and did the real
work, hit its `$3.00` budget cap before a clean final response but had
already durably saved its findings to a file mid-analysis (smart —
nothing was lost). If re-dispatching a similarly deep investigation,
budget Opus higher up front rather than relying on it to self-save, and
don't assume a parallel kimi dispatch for the same question will
necessarily return anything.

**RESOLVED, same session, by a kimi (k3-256k) dispatch whose MCP call
itself timed out with "nothing recoverable" — but the underlying kimi
process kept working and self-recorded its findings to
`data/ai-mem/kimi/topic-key32-inline-elf-perl542-divergence.md` before I
ever saw a result. Read that file — it independently confirms H1 with the
exact clean old-.so-vs-new-.so comparison this note originally flagged as
the remaining gap**: `key_32('test-passphrase-13chars')` gives genuinely
different output under perl 5.40+old-`.so` vs perl 5.42+new-`.so`, 3/3
test passphrases. Kimi solved the harness problem (booting the real old
`.so` via `DynaLoader::dl_load_file`+`dl_install_xsub` directly, bypassing
Inline::C's own compile-check that kept falling back to pure-Perl in
every attempt I made) and built a working two-step recovery tool.

**Recovery harness, preserved durably** (originally at `/tmp/p7-elf-ab/`,
which will not survive — copied and path-fixed to
`data/ai-mem/kimi/p7-elf-ab-recovery-harness/recover_key.pl`, syntax
verified): `derive` mode (run under `/usr/bin/perl5.40-x86_64-linux-gnu`)
boots the old `inline_elf`+`bit_string_to_num` `.so` files and calls the
real `AMOS7::13::key_32(\$pass)` with them, prompting for the passphrase
via STDIN — never touching an AI session or shell history. `decrypt` mode
(run under current perl) takes the resulting key hex plus the real
`.private`/`.public` key file paths, Twofish-decrypts, and verifies via
`Crypt::Ed25519::generate_keypair` against the known public key, printing
MATCH/NO MATCH. **Never ask the user for their password to run this
yourself — it is designed specifically so only the user's own terminal
ever sees it.** As of this session's end the user had not yet run it;
that's the next step whenever they choose to.

Kimi's file also has extra findings worth reading in full: `no warnings
'utf8'` in `elf_chksum` changes the actual checksum VALUES on malformed
input, not just silences warnings ("warnings-state-dependent crypto");
`bit_string_to_num`'s `.so` WAS also rebuilt tonight (a `COMPILE/003`
build this session initially missed, wrongly calling it stable based on
an older build dir); a separate, unrelated bug in `AMOS7::BitConv`'s own
pure-Perl fallback (`unpack Q, pack B64` pads zeros at the wrong end for
strings under 64 bits).

**Fix applied this session to `AMOS_13_ELF.pm`'s pure-Perl `fallback_sub`
(kept, verified correct)**: moved `$shift_limit` computation outside the
per-character loop, computed once from `$start_sum` — matches the C
code's structure, empirically confirmed to fix divergence for long
ASCII-only input (900-byte test, previously untested, now matches
perfectly). **A second fix attempt (byte-level UTF-8 walking using
`Encode::decode` instead of `unpack('U*',...)`) was tried and reverted**
— it did not close the gap on any UTF-8/malformed/high-entropy test case
despite matching the C code's documented decode rules as closely as
determinable without `utf8_to_uvchr_buf`'s own C source; that negative
result is itself informative (supports H1: the C output may not be a
single stable target to match at all). Don't re-attempt that specific
approach without new information — read the reverted code's inline
comment in `AMOS_13_ELF.pm` for exactly what was tried.

**RESOLVED 2026-08-26, next session.** Both real C bugs found and fixed
in `inline_elf` (`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm`):
(1) stale `len` captured before the `sv_2pvutf8_nolen` UTF-8 upgrade,
which could underflow the unsigned STRLEN near the end of a high-byte-
dense buffer and read past it into adjacent memory; (2) `if (character
< 256) u8_len = 1` after decode, which cut the buffer *advance* to 1
byte for every upgraded high byte instead of the real 2, misaligning
the cursor and cascading "unexpected continuation byte" errors — found
via a temporary `P7_ELF_DIAG` env-gated diagnostic in `elf_chksum`
(re-enabling `warnings 'utf8'` + a `$SIG{__WARN__}` catcher) run
against the real `key_32` chain with only a fixed non-secret test
passphrase, never real key material. A companion fix (uninitialized
`next_chr` passed as the `send` bounds arg to `utf8_to_uvchr_buf` —
replaced with a real `str_end = str + len`) went in alongside bug #2.

**Verified thoroughly**: zero malformed-UTF8 warnings post-fix,
deterministic across repeated runs and all 3 canary passphrases; C vs
pure-Perl fallback now match exactly on 640/640 random binary vectors
(1–512 bytes) plus the original 12 targeted vectors — see
[[topic-key32-inline-elf-perl542-divergence]] and both task docs
(`elf-chksum-c-vs-pure-perl-utf8-divergence.md`,
`c25519-key-decryption-failure-hypothesis-2026-08-25.md`, both updated
with RESOLVED sections) for full detail.

**Recovery and fix are separate, confirmed empirically, not just in
theory**: fixing the algorithm gives a *third* value for the canary
passphrase (`7143e78d...`), matching neither the historical 5.40 value
(`47639ed1...`) nor the broken 5.42 one (`89965518...`) — the original
key was encrypted using whatever the *buggy* behavior produced at the
time, so a mathematically-correct fix cannot recover it. Real recovery
was independently confirmed working via `v7.keys enc-key-chksum` on a
remote server that never received the triggering `dist-upgrade` (still
perl 5.40.1, original `.so` intact) — a clean pre-incident reference,
separate from and unaffected by this local fix. **Never ask the user
for their password** — this held throughout; all local verification
used only fixed non-secret canary passphrases.

**Fallout accepted, not urgent**: ~2233 of 8177 files need a one-time
re-sign under the corrected algorithm once a working signing key exists
locally (via user's own decrypt-on-remote → re-encrypt-under-new-
algorithm migration, entirely on their end). Precedented, comparable to
past footer/endline-state-driven re-sign requirements.

**Backlog surfaced during this fix, captured for later, not urgent**:
`bin/amos-chksum -VL7`'s reference string (designed originally to catch
`Digest::Elf`-vs-custom-implementation drift) is too short/sparse to
reliably catch bug #1's underflow class (it happened to catch bug #2 by
luck, via a single stray high byte) — a robust canary needs real
byte-entropy density, not just any non-ASCII byte. Also missing: a
warning when a module's live-recomputed version tag doesn't match its
last-recorded one. Longer-horizon: see [[vision-nightly-forensics-algorithm-divergence-sweep]]
for the fuller seed (nightly forensics-zenka sweep across the main
checksum/crypto algorithms, comparing live output against pinned
known-good reference vectors, to catch this whole class of silent
algorithm-output divergence proactively instead of after production
signature failures).

Also fixed in the same arc, unrelated bug but same file family: two
call sites in `sourcecode.console.verify-p7-signatures` passed
`\my $src_str` straight into `<[file.slurp]>`'s argument list without
checking its return value — on a permission-denied (or any) read
failure, this fell through to `source.extract_sig_body`'s generic
"scalar ref content was undefined [mode:strict]" warning instead of a
clear read-failure message. Fixed by checking `defined <[file.slurp]>->
(...)` before calling `extract_sig_body`. First attempt at this fix
introduced a real scoping bug — `\my $src_str` declared inside an `if
(...) { }` **block-form** condition only stays in scope through that
if/else chain, not the rest of the enclosing loop body where `$src_str`
was used two more times downstream — caught by the user via a live
compile error ("Global symbol '$src_str' requires explicit package
name"). Fix: declare `my $src_str;` before the `if`, pass `\$src_str`
into the condition. Note for future edits: the *statement-modifier*
form (`next if not defined <[file.slurp]>->(...\my $src_str...);`) does
NOT have this problem — no new block is introduced, so `my` there
scopes normally to the rest of the enclosing block. Only the full
block-form `if (...) { }` needs the variable predeclared outside it.

#,,,.,..,,,,.,..,,,,.,,,.,,,.,,,,,..,,,.,,,,.,.,.,...,...,,.,,.,.,,.,,,.,,...,
#LSSK7USIBVHCCPW4SCMYHCOSBMY6M34SKYG4BHMNCMFZIXDTUSIWME3QULA4RL3BIZK55SOHOZECO
#\\\|EIK6FGXU74AAXGNP37CEOALAFVETVANS5POI5RSSKNO7BQGVPIN \ / AMOS7 \ YOURUM ::
#\[7]3IPJKOCCDSJTLJT4VWGGQH7MGC7H2BOWP2Z4DT7JEKKQ5GQHSYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
