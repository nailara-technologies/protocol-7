---
name: bug-ntime-b32-2-unix-missing-compint-float-support
description: "base.ntime.B32_2_unix can't decode higher-precision (longer) ntime-b32 timestamps that carry sub-second float precision via BER compressed-integer packing -- cube.cmd.localtime has the correct decode chain, B32_2_unix uses an older simpler one; affects 23 callers"
metadata:
  type: project
---

Found 2026-07-29 debugging `forensics.event.nightly-sweep` (which calls
`base.ntime.B32_2_unix` to parse log-line timestamps): a longer ntime-b32
string (`33WHIVSUBEGYLKXY`, vs. a regular one like `3WKI7OE7AG7CY`)
fails to decode — `base.ntime_BASE32_to_numerical` (the decode step
`B32_2_unix` uses) rejects it, warning "BASE32 decoding error [ timestamp
not valid ]".

**Root cause**: `cube.cmd.localtime` (the `p7c localtime <val>` console
command) has a DIFFERENT, more complete decode chain for base32 ntime
values (lines 57-77):

```perl
eval { $ntime_decoded = Crypt::Misc::decode_b32r($calc_val) };
## ...
if not <[base.comp-int.is_valid]>->($ntime_decoded) # ...
my @nt_val = unpack( qw| w* |, $ntime_decoded );   ## BER comp-int, w* format
$nt_val[1] =~ s|^7|| if @nt_val == 2;    ## saves 0 prefixes
$calc_val = join( qw| . |, @nt_val );    ## seconds.subseconds -- FLOAT precision
```

`unpack('w*', ...)` can yield **two** packed values for a high-precision
timestamp (integer seconds + a sub-second fraction component), joined as
a decimal string. `base.ntime.B32_2_unix` never does this — it goes
straight to `base.ntime_BASE32_to_numerical`, a simpler decoder that
apparently only handles the single-value (whole-second) case, so any
longer/higher-precision ntime-b32 string it's given just fails outright.

**Why this matters:** `base.ntime.B32_2_unix` is called by 23 other
modules — `branch.ntime.tunnel_duration`, `branch.ntime.clock_sync`,
`branch.ntime.relative`, `branch.clock.position`, `memory.tree.score`,
`memory.tree.dedup.exact`, `memory.tree.insert`, `jobsite.sync.push`,
`plugin.web.jobs.data/.cache.write/.sync`, `discover.process_incoming_packet`,
`space.travel.tunnel`, `base.file.read_timestamp`, `base.ntime.delta_seconds`,
`base.cmd.src-age`, `site-yaml.job.scan_stray`, `system.cleanup.check_tasks`,
`pager.sort.multi-key`, `cube.cmd.delta-time`, `cube.cmd.b32-ntime`, plus
`base.list.subroutines`/`forensics.event.nightly-sweep` — any of these
silently mishandling a high-precision timestamp the same way is a latent
bug, not just a forensics-zenka cosmetic warning.

**Why not fixed live**: 23-caller blast radius is too wide for a blind
mid-session patch; the right fix is porting `cube.cmd.localtime`'s
`decode_b32r` → `comp-int.is_valid` → `unpack('w*', ...)` chain into
`base.ntime.B32_2_unix` itself (so all 23+ callers benefit from one
fix), then verifying each caller still gets the same values for the
common single-value case before trusting the two-value case elsewhere.

**How to apply**: scope this as its own task file before dispatching —
needs a test pass across the whole-second (existing, must stay
identical) and sub-second-precision (new) cases, plus a check of which
of the 23 callers actually receive high-precision timestamps in
practice today (likely few, since this bug went unnoticed until now) vs.
which only ever see whole-second values and won't be affected either way.

**RESOLVED 2026-07-29** (kimi, afk session): ported the
`decode_b32r` -> `comp-int.is_valid` -> `unpack('w*', ...)` chain from
`cube.cmd.localtime` into `base.ntime.B32_2_unix`, replacing its call to
`base.ntime_BASE32_to_numerical`.

Corrections to the original diagnosis, found during verification:

1. `base.ntime_BASE32_to_numerical` (inline sub `p7_ntime_BASE32_to_numerical`
   in `bin/Protocol-7`) ALREADY handles the two-value sub-second case
   (`unpack('w*', ...)` + `s|^7||` on `@nt_val == 2`) -- verified live via
   `p7c b32-ntime 3WKI7OE7AGA4XXMERXTB4` -> `3200856756097.000000000798`.
2. `33WHIVSUBEGYLKXY` is NOT a valid high-precision ntime-b32: its decoded
   BER compressed integer is unterminated (last byte 0xf8 has high bit set).
   `p7c localtime 33WHIVSUBEGYLKXY` rejects it too ("decoded value not valid
   [ expected compressed integer ]"). No decoder can accept it; the fix
   makes B32_2_unix reject it cleanly via `base.comp-int.is_valid` instead
   of a swallowed `unpack` die inside eval.
3. The "23 callers" were callers of `base.ntime_BASE32_to_numerical`
   (untouched). Actual callers of `B32_2_unix` per
   `data/training/codebase-depgraph.txt`: only `base.file.read_timestamp`
   and `forensics.event.nightly-sweep` -- both float-safe (definedness
   check + numeric comparison / pass-through).

Verification: 12 hand-picked vectors + 2000 randomized round-trip fuzz
vectors through old vs new module (standalone harness wiring the real
repo implementations): zero output differences. High-precision
`3WKI7OE7AGA4XXMERXTB4` decodes to unix `1785336751.45166683197021`,
matching `p7c localtime 3WKI7OE7AGA4XXMERXTB4`
(`Wed Jul 29 2026 16:52:31 [ +0.45166683197021 ]`).

#,,,,,,,,,,,.,..,,,.,,,,.,,,,,,.,,.,,,,.,,..,,..,,...,...,...,,..,.,.,,.,,.,,,
#X4MBZGHTR44A6XFLT4NGYYWGG5ANEEMICCOYOKTZTTVH3V4F3KVC2CFRGIPF66GZWO4BYXV5B4Y22
#\\\|S2TZ4PXZDX33CDSXFIE6XF5KSBF7IRXWIGEFD5CV5YYRNBE3AYJ \ / AMOS7 \ YOURUM ::
#\[7]BXXHJS62FPWWFZMZIJ2WBXRXLBFDWYUABD6HBTRP7GR2YQJSNKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
