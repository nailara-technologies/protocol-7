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
- the tool REPLACES the old version itself [ user : updating used to mean
  cutting the old version out by hand -- that step goes away ] ; same
  exclusion rules as the compiled-in checksum of bin/c_src/p7c.c and
  p-7-r.c [ binaries work without a signature footer ]
- algorithm versions stay separate : `amos-chksum -VCS \ -VL7 \ -VS`
  describe OUTPUT behaviour, module versions describe SOURCE
- `$VERSION` never exported -- check unqualified readers first
- N7FS records both : the algorithm versions that produced its
  addresses, the module versions that wrote the store

## decisions

- DECIDED [ 2026-10-18 ] : SPLIT the two kinds. `$VERSION` = the module
  source version in the uniform form [ `AMOS7::CHKSUM-VERSION.<amos>` ] ;
  `$ALGORITHM_VERSION` = the output version in the short form :
  CHKSUM `AMOS-CHKSUM-V-<x>` [ -VCS ], CHKSUM::ELF `AMOS-13-ELF-7-<x>`
  [ -VL7 ], ELF::Inline `AMOS-13-ELF-7-SRC-VER-<x>` [ -VS ].
  update-amos-versions writes `$ALGORITHM_VERSION`. "did the code
  change" vs "do results differ" -- only the second matters for N7FS
  addresses and signatures
- fixed 2026-10-18 : `amos-chksum -VS` hashed a HASH reference
  [ `inline_elf()` returns { source, fallback, package } ] -> a random
  value per run ; now `->{'source'}`, stable

#,,..,.,,,,..,...,,,,,,.,,,..,,.,,,,,,,,,,,,.,..,,...,..,,,.,,.,,,..,,,,,,...,
#XJMTO2S4YB3VXYJQVGXL7OPIZN7XS5EYLIQRH33YF33O6UG5IVD7CALMBNUEVOL4LUGG3IIDLSCEI
#\\\|7JOCJRIR3RWC7CQB52WMQRLLJ5DNRUP27KAZYWJP34BI2VKFXFV \ / AMOS7 \ YOURUM ::
#\[7]FG6LSUZO657KIBRIFOSKYM5BH7UMLMUBNLDJLGRTDOU5J5QMTYDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
