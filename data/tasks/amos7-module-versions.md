# AMOS7 module versions : define, generate, stop exporting

brief [ 2026-10-18 ]. module `$VERSION` strings were never generated --
placeholders, invented and broken forms side by side. `bin/dev/update-
amos-versions` only covers the three ALGORITHM versions.

## found

| kind | modules |
|---|---|
| placeholder `0000001` | N7FS [ all ], Vault, NTIME, TERM::Frame, TERM::Editor |
| placeholder `AAAAAAA` | SHM + its 4 submodules |
| not base32 [ 0 1 8 9 ] | Backup `ZK4M9P1`, Metadata `YT9K8L2` |
| looks copied | CHKSUM::Nested `7UA5BUI` [ CHKSUM is `UXA5BUI` ] |
| `my $VERSION` -- a LEXICAL : the package `$VERSION` stays undef, invisible outside | 13::cipher [ also empty : `qw\|  \|` ], 13::Compression [ `0.07` ] |
| exported `$VERSION` -- importers' `$VERSION` gets aliased and overwritten | CHKSUM::ELF [ `@EXPORT` ], INLINE::src::AMOS_13_ELF [ `@EXPORT_OK` ] -- at runtime `$AMOS7::CHKSUM::ELF::VERSION` reads CHKSUM's |

## proposal

- module version = amos checksum over the module's own SOURCE, excluding
  the signature footer and the `$VERSION` line itself ; format
  `AMOS7::<Module>-VERSION.<amos>` ; `our $VERSION` in the package
- a new mode of `bin/dev/update-amos-versions` computes and writes them
  [ one place for both kinds ] ; run with the sign run ; a check mode in
  pre-commit reports outdated versions
- algorithm versions stay separate : `amos-chksum -VCS \ -VL7 \ -VS`
  describe OUTPUT behaviour, module versions describe SOURCE
- `$VERSION` never exported -- check unqualified readers first
- N7FS records both : the algorithm versions that produced its
  addresses, the module versions that wrote the store

## open [ owner ]

- AMOS7::CHKSUM : keep `AMOS7::CHKSUM-VERSION.<x>` or switch to the
  algorithm form `AMOS-CHKSUM-V-<x>` that update-amos-versions writes ?
- fixed 2026-10-18 : `amos-chksum -VS` hashed a HASH reference
  [ `inline_elf()` returns { source, fallback, package } ] -> a random
  value per run ; now `->{'source'}`, stable

#,,,.,..,,.,,,,..,..,,..,,...,...,..,,.,.,.,,,..,,...,...,,.,,,.,,..,,..,,,,,,
#FYEKFMJRPN4GOI72LX3J6HDPPVYOHZKTMZ5SU77AZFORH5SST3OGNHLYPPZQDQIVRSHRFS2TFYVOG
#\\\|TLSO23W34F2HDSMRNC55SGVGJLYSEN4JI7KRIEPDHLFNHS4HZJQ \ / AMOS7 \ YOURUM ::
#\[7]GLX6E6HQRDWGXTDPFFVXIIYCA4BBBSBT3TKHWAQORGP2NHAS2ICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
