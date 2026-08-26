---
name: bug-inline-elf-perl-version-infinite-loop
description: "FULLY RESOLVED across atom+pri, both clean-started 2026-07-26: inline_elf's dangling-if (missing braces) let a malformed-UTF-8 decode with u8_len==0 spin while(len>0) forever at 100% CPU on Perl 5.42.2; unpacked into 4 more independent bugs found chasing the full boot end-to-end (ptd's P7-macro false-positive gap, .deps/profiles.yaml gaps for graphics-matrix/opencv, an httpsd ownership-sweep race clobbering web zenka's skins dir, a stale web.cmd.skin path). gdb backtrace on the hung process was the decisive diagnostic for bug #1; live -vvvq tracing + stat timing tests for #3."
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

## full resolution, verified across both hosts (2026-07-26)

What started as this one bug turned into a full clean-upgrade pass across
both `atom` and `pri` (a second production/remote host, freshly getting
`basic-remote-server` + `graphics-matrix` installed for the first time).
Chain of fixes, all landed and live-verified on real hardware (not just
locally), in commit order:

- `30d990d9c` / `31158e821` — the `inline_elf` fix itself (both the live
  copy and the dead-code duplicate).
- `4ed4877bd` — root fix for the false-positive class that made verifying
  the above harder than it should've been: `bin/dev/ptd`/`bin/format-code`
  now translate P7 macro syntax before `perl -c`, via a new
  dependency-free `AMOS7::Protocol::P7Syntax` module.
- `cebd1f647` / `3f47cb3b3` / `d3be26a25` — `.deps/profiles.yaml` gaps
  found installing fresh on `pri`: `graphics-matrix`/`opencv` were missing
  `Graphics::Magick`/`Convert::Color`/`libgd-perl` entirely (only the much
  heavier `X11-Desktop` profile had them — deliberately did NOT pull that
  in for a headless box); renamed the misleadingly-named `development`
  profile to `basic-remote-server` in the same pass.
- `ec8f8f6de` — a second, independent bug found only by testing the real
  multi-zenka boot sequence end-to-end: `httpsd.init_code`'s vhost
  ownership-normalization sweep was blindly `glob()`-ing every entry
  under `/var/httpd`, including `web` zenka's own `skins` dir (not a
  vhost), reverting its ownership on every `httpsd` (re)start. Found via
  live `-vvvq` tracing and a `stat`-before/after-stop timing test — no
  static grep alone would have surfaced this, since `web` was the only
  zenka with `skins` in its own source, but `httpsd` was the one actually
  clobbering it.
- `b2a137e64` — a third, unrelated latent bug surfaced while investigating
  the above: `web.cmd.skin`'s `list`/`info` subcommands used a stale
  `_global_templates/skins` path never wired to `web.cfg.skins_dir`,
  so they'd always report "not found" even with skins correctly in place.

**How to apply**: a single reported symptom ("zenka hangs on start") can
legitimately unpack into several independent, unrelated bugs once you
follow it through a real end-to-end boot on real hardware instead of
stopping at the first plausible fix — don't assume "fixed one thing,
done" until a full clean start/stop cycle is actually re-verified,
ideally on more than one host.

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

#,,.,,...,.,.,.,.,..,,.,.,,,,,,..,,.,,..,,.,.,..,,...,..,,,.,,.,,,,.,,.,.,...,
#66PHVGASFNC5QV7QT6IEG74OBYMYQFRFNLG7UKFBWFUX7EOHOKUZJ2XJWHMHDJMTXICU7GA2GKIZU
#\\\|HINKN7CXAMR26JWK3KOJNNTH6YENAEOIT4TEIFTRLOECCMUI6RT \ / AMOS7 \ YOURUM ::
#\[7]M5CPT4AN24F7AR3ATLEDNZCCP7AUAHILRFNG37HMWI2CUAZR2MDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
