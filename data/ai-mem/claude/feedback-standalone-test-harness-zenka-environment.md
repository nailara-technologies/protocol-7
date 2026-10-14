---
name: standalone-test-harness-zenka-environment
description: standalone module tests [ compile_module + string eval ] miss four zenka-only behaviours -- utf-8 default layer, File::stat's object stat, the .cmd. $call \ $reply header ; mirror them in the harness or a new zenka fails on first live start despite green tests
metadata:
  type: feedback
---

found 2026-10-04 on the first live start of osf-cache [ `13fddb42a` ] :
100 green standalone checks, then four failures only the zenka showed.

`bin/Protocol-7` sets, and every module compiled inside it inherits :
1. `use open qw| :encoding(UTF-8) |` -> any binary read [ keyrings,
   Packages, hashing input ] needs `'<:raw'` ; a plain `'<'` died on 964
   decode errors and would hash decoded characters, not bytes
2. `use File::stat` -> `stat` returns an OBJECT ; `my @s = stat $p`
   leaves `$s[7]` etc undef. use `CORE::stat( $p )`. undef == undef in a
   reuse check silently matched stale entries
3. `.cmd.` header declares `$call` [ args ] and `$reply` -> read args
   from `$call->{'args'}`, never `my $reply` in a .cmd. module
4. multi-line `.cmd.` replies use `mode => size` ; `true` escapes `\n`

**Why:** the standalone harness [ `bin/test-scripts/test-*.pl`,
compile_module ] lacks all four, so tests pass while the zenka breaks.

**How to apply:** new standalone harnesses start with `use open qw|
:encoding(UTF-8) |;` + `use File::stat;` and prepend `my $call` \ `my
$reply` to `.cmd.` modules [ `test-osf-cache-debian.pl` has the pattern ].
include at least one binary [ non-ascii ] input in tests that hash or
parse files. related : [[use-format-code-not-perl-c]], [[init-code-runs-before-drop-privs]]

#,,,,,,.,,,..,..,,.,,,,..,..,,,..,,..,...,,,,,..,,...,...,...,...,,,.,,,.,...,
#TDH3GWGMBFNTR7QNKEBAHJWMVV36IR4VVNJFZ67O3E2E4Z4F7X2D34EEKNPUS2SNE5ASG4QVO2AS6
#\\\|PKT2OR7MMCYOBVMOJOWWGWVD5BTZZHYGTTT3X752RPYTEKGED75 \ / AMOS7 \ YOURUM ::
#\[7]X3U6DDIEPN765274JYLPFVGXIBXZMDYYNQB7Q56V4DUATPXHOKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

**2026-10-07 [ host-root live run ] :** two runtime-only bugs passed 6 harnesses [ bare list `lstat` under File::stat ; `sysread` on the default :utf8 layer ]. harnesses now compile modules with `$runtime_pragmas = q{no bytes; use File::stat; use open qw| :encoding(UTF-8) |;}` in the eval string [ test-host-root-delegation, -keys-root-held, -host-root-keygen, -discover-delegation, -auth-link-binding(-e2e) ] -- mutation-checked : both bugs now FAIL. GOTCHA : a harness's top-level `use bytes` is LEXICAL and leaks into string-eval'd modules ; under it `sysread` on a :utf8 handle silently works -> it masked the bug. the runtime only has bytes.pm LOADED, not in effect. pragmas go inside the eval, so the test file's own stat calls stay CORE.

#,,,.,.,,,,,.,.,,,...,,,.,...,,..,.,,,...,,..,..,,...,...,...,,..,,.,,,..,,.,,
#BESPQ5VQTVU7XU7DBACNAU5BPC7IWZHK6ZMO7JOUV6J33YUY4AFRNPDCU2BH4NZHV7O4MP6G2FEV6
#\\\|FXGVQ6C4IECOU2N3AWDOXNQD7QQGS7V4YHTSGBCGIM7A5L7QMON \ / AMOS7 \ YOURUM ::
#\[7]M5T2GTFFOVW37G6GTOAI2F3DKMXINRBDBCE37HNW7AYJRCNVXMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
