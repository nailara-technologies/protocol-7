---
name: reference-amos7-canonical-color-palette
description: reuse AMOS7.pm's exported %C hash (or AMOS7::TERM's more fully-named %p7_colors) for terminal color output in any bin/ script instead of hardcoding ANSI escapes -- it's the actual palette ncode/nshell/ssh.hash-hostkey already draw from
metadata:
  type: reference
---

`AMOS7.pm` (`data/lib-path/pm/AMOS7.pm`) exports `%C` by default (it's
in `@EXPORT`, so plain `use AMOS7;` after the standard lib-path BEGIN
block pulls it in — no import list needed). Keys are short and terse:
`T` (a rich blue, "true"), `0` (blacklight purple), `g` (neon green),
`o` (gold/amber, used for errors), `G` (dark blue), `B00`/`B01`/`B02`/`b`
(background darks), `B` (bold), `R` (reset). Used across `bin/ncode`,
`bin/nshell`, `bin/ssh.hash-hostkey`, `bin/create-session-seed-file`,
`bin/amos-13-comp`, `bin/amos-data-pager-56`.

`AMOS7::TERM.pm` (`data/lib-path/pm/AMOS7/TERM.pm`, around line 94) has
the same values under more descriptive names in `%p7_colors`:
`p7_fg_0000` purple, `p7_fg_0001` blue, `p7_fg_0002` brown,
`p7_fg_0003` phosphor green `[cursor]`, `p7_fg_0004` **TRUE blue
`[text]`** (= `$C{'T'}`), `p7_fg_0005` neon amber (= `$C{'o'}`),
`p7_fg_0006` neon green (= `$C{'g'}`) — but that module also carries
nshell-specific state (history, cursor), so it's not meant for casual
reuse in a standalone script the way `AMOS7.pm`'s lightweight `%C` is.

**How to apply:** when a `bin/dev/*` (or any standalone) script needs
terminal color, `use AMOS7;` and reference `$C{...}` directly rather
than copy-pasting a hardcoded `\e[38;2;R;G;Bm` — even if the RGB values
happen to already match this palette (as `bin/dev/diff-modified`'s
locally-defined colors do), sourcing from `%C` means a future palette
change propagates automatically. Built into `bin/dev/md-link-tree`
2026-09-04 after the user asked for "the 'true' color" specifically —
$C{'T'} for validated/resolved markdown-file nodes in its tree output.

#,,.,,..,,,.,,,,,,...,,,.,,,,,.,.,,,.,,,.,,.,,..,,...,...,.,.,.,,,...,,.,,,,.,
#ZMCVCUYCT5GTKOXDUGM4NGWUD4ZR7BTCMSSMDKCKF4LTS3PPH6TLT7IWJAEZG4S6DQLFCJTCRWVJW
#\\\|TFMCEPSICTLH247LTFEJK2ICYPYY74OGMQYPYABRPGR67KR7GZR \ / AMOS7 \ YOURUM ::
#\[7]KTDIKGOTKRJLRD7LOARUBBK3HLEMI43JLSXMJMHH2IHJM4WZB2CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
