---
name: bug-inline-elf-perl-version-infinite-loop
description: "RESOLVED 30d990d9c/31158e821: inline_elf's dangling-if (missing braces) let a malformed-UTF-8 decode with u8_len==0 spin while(len>0) forever at 100% CPU, zero syscalls; only manifested after a Perl 5.40.1->5.42.2 dist-upgrade feeding raw binary (an Ed25519 pubkey) through elf_chksum's UTF-8 codepath. gdb backtrace on the hung process was the decisive diagnostic."
metadata:
  type: feedback
---

Landed 2026-07-26. Production host ("atom") froze on every zenka start at
`crypt.C25519.gen_keys`'s session-key generation, 64.7s timeout, killed by
v7. Worked fine on WSL dev machine. User had just `dist-upgrade`d + rebooted
atom.

## the bug

`data/lib-path/pm/AMOS7/INLINE/src/AMOS_13_ELF.pm`'s `inline_elf` C source
(and an identical, currently-dead-code duplicate in
`data/lib-path/pm/AMOS7/CHKSUM/ELF/Inline.pm`) had a classic dangling-`if`
(no braces) in its UTF-8 decode branch:

```c
character = utf8_to_uvchr_buf( str, next_chr, &u8_len );
if ( character < 256 )
    u8_len = 1;   // only THIS line was conditional
    len -= u8_len;   // ran unconditionally either way
    str += u8_len;
```

Harmless on well-formed UTF-8 text (`u8_len` is always sane either path).
But `elf_chksum` was being fed a raw 32-byte Ed25519 public key via
`AMOS7::Assert::Truth::is_true` — random binary, not text — guaranteed to
hit malformed UTF-8 byte sequences. On Perl 5.42.2 (not 5.40.1), some
malformed sequence apparently decodes to `character >= 256` (skipping the
`u8_len=1` safety line) while `u8_len` is *also* 0 from
`utf8_to_uvchr_buf` — so neither `len` nor `str` advance, and
`while(len>0)` spins on the same byte forever. 100% CPU, zero syscalls,
deterministic and 100% reproducible on that exact Perl version — not a
probabilistic/timing bug.

**Fix**: brace the `if` properly, and unconditionally floor
`u8_len` at 1 after the decode — guarantees forward progress regardless
of what any given Perl version's UTF-8 decoder returns for malformed
input.

## why the diagnosis took the shape it did

- **First theory (wrong): entropy starvation.** Fresh-VM/`getrandom()`-
  blocks-at-boot is the generic "hangs on fresh host, works on dev
  machine" pattern-match — plausible-sounding but wrong here. Ruled out
  by: (1) user reporting the process pegs 100% CPU, not blocked/idle —
  a real blocking syscall would show near-0% CPU; (2) `-vvq` trace
  showing an unrelated periodic timer log line interleaved during the
  "hang," proving the event loop was still alive elsewhere — inconsistent
  with the whole process being frozen in one syscall.
- **Second theory (wrong): infinite retry loop** in
  `crypt.C25519.gen_keys`'s `while (not $TRUE)` harmonic-truth-seeking
  loop (probabilistic, ~169 expected iterations). Ruled out directly by
  the user: "it enters the while loop, but there is only one iteration."
  That single fact eliminates every "loops many times" theory instantly
  and points at a hang *inside one native call* in that one iteration.
- **Decisive step: `gdb -p <pid> -batch -ex bt`** on the live hung
  process. Immediately named the exact blocking line
  (`AMOS7::Assert::Truth::is_true(...)`), which is Inline::C-compiled —
  invisible to any Perl-level reasoning or testing. This should be the
  *first* move next time a P7 process pegs CPU and never returns, not a
  late resort — Perl-level theorizing about probabilities/loops burned
  several turns that a 10-second backtrace would have skipped.
- **Stale-Inline::C-cache-ABI theory (plausible but wrong here, worth
  keeping as a checklist item anyway)**: Inline::C's build cache is keyed
  by a hash of the *C source text* (`encoded_bmw_chksum`), not by Perl
  version/ABI — so a `dist-upgrade` that bumps Perl leaves old `.so`s
  cached and reloaded into a new, possibly ABI-incompatible interpreter,
  a real and distinct risk from the bug above. Ruled out here because
  deleting `~/.7/inline-code/` and letting it recompile fresh against
  5.42.2 *still* hung — proving Perl 5.42.2 itself (not a stale build)
  produces the u8_len==0 behavior. **Still worth checking first** on any
  future "works pre-upgrade, breaks post-upgrade" Inline::C report, since
  it's a one-command check (`rm -rf ~/.7/inline-code/`, retry) done
  before reaching for gdb.

## residual risk (not yet audited)

`AMOS7::INLINE.pm`'s `$source_registry` has 4 more Inline::C entries
sharing this exact caching mechanism: `true_int`, `true_float`,
`num_to_bit_string`, `bit_string_to_num`. Only `inline_elf` happened to
get exercised with adversarial (raw binary, non-text) input on this code
path. None of the other three have been read for a similar
dangling-if/unbounded-loop hazard — worth a pass if another
version-dependent hang surfaces anywhere near truth-assertion or
bit-string code.

## duplicate-code lesson

`grep -r carryover data/` turned up a **second, byte-identical copy** of
the buggy C source in `AMOS7::CHKSUM::ELF::Inline.pm` (dead code — only
`bin/dev/update-amos-versions` references it, and only for `$VERSION`
bookkeeping, never actually compiles/runs it). Fixed anyway since it's a
landmine for whenever someone wires it back up. **How to apply**: once a
bug is found in an Inline::C/AMOS7 algorithm implementation, grep for a
distinctive local variable/comment from the buggy snippet across the
whole tree before declaring it fixed — near-identical logic gets
hand-copied into a second module in this codebase, not always something a
plain "who calls this function" search would surface.

#,,,,,,.,,.,.,,,,,.,.,..,,,.,,,..,,,.,,.,,,,,,..,,...,...,.,.,...,,,.,,,,,.,.,

#,,,.,...,.,.,,.,,...,.,,,...,,,,,...,.,.,,.,,..,,...,...,,..,.,,,.,.,..,,,.,,
#FJQSIAHEBGURIGYSQD64K4OUNAUR2DCN3WWCHM5KL3PLW2YYZZCMBU7TIRO7RALTP2UEIAK54IUJE
#\\\|UFNRKTCUGMLG2P4HEWJJR6BM3JJVYHYECP3JUK22TR56ZC7XABQ \ / AMOS7 \ YOURUM ::
#\[7]UJNTKEXLJE4QAYG7QGZYRJKA3U2GZAU2DNAEOEAQD3SFGIVGTMCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
