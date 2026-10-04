---
name: standalone-test-harness-zenka-environment
description: standalone module tests [ compile_module + string eval ] miss four zenka-only behaviours -- utf-8 default layer, File::stat's object stat, the .cmd. $call \ $reply header ; mirror them in the harness or a new zenka fails on first live start despite green tests
metadata:
  type: feedback
---

found 2026-10-04 on the first live start of osf-cache [ `a632330eb` ] :
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
