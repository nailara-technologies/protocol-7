# Degraded-state audit [ azurum, 2026-10-27 ]

Observed on a fresh azurum install running `cube` with a largely
incomplete dependency set. This state is valuable -- it exposes what a
normal install never shows. Loader resilience fixes from this session
are in place; everything below is *still open*.

## Missing modules surfaced [ profile gaps for p7-deps / p7-install ]

| module                | debian package              | needed by |
|-----------------------|-----------------------------|-----------|
| Digest::BMW           | pm-src build                | chksum chain [ known, minimal profile ] |
| Crypt::Misc           | libcryptx-perl              | link-upgrade chain, C25519 register-master-key |
| Const::Fast           | libconst-fast-perl          | base.init_code:35, crypt.C25519.init_code |
| Crypt::Curve25519     | libcrypt-curve25519-perl    | base.handler.link-upgrade:108 |
| Crypt::Ed25519        | libcrypt-ed25519-perl       | crypt.C25519.gen_keys_typed:95 |
| File::Which           | libfile-which-perl          | base.file.pre_init:10 [ see below ] |
| IO::Uncompress::AnyUncompress | libio-compress-perl | inline-subroutine decompression [ pipe-mode fallback engaged ] |

Inline::C [ libinline-c-perl ] is *optional by design* -- the pure-perl
alternatives engaged with a single warn. Not a profile requirement.

## Code issues found in degraded state

[ update 2026-10-27 : issues 1-3 fixed ; issue 4 still open ]

### 1. ~~base.chk-sum.elf.inline:62 -- unguarded elf_chksum call~~ FIXED

Was : bare `return AMOS7::CHKSUM::ELF::elf_chksum(...)` -- died with
`Undefined subroutine` when the module chain could not load.

Now : soft `eval { require AMOS7::CHKSUM::ELF }` with the true
AMOS-13-ELF-7 pure-perl fallback from the AMOS7::INLINE src registry
[ `inline_elf()->{'fallback'}` ] -- verified byte-identical to the
module path [ `030574180` for 'hello world' ].

### 2. ~~crypt.C25519.init_code:68 -- 'const' without Const::Fast~~ FIXED

Was : bare `const <name> => {...}` -- a compile-time syntax error when
Const::Fast was not imported yet [ readline-glob parse ].

Now : plain assignment + runtime-guarded `$set_c25519_readonly` helper
[ `&Const::Fast::const( $ref, $val )` prototype bypass ] -- read-only
semantics preserved when Const::Fast is loaded, plain writable hash
degraded. Same pattern still needed in
`src/plan-9.protocol.constants.pre_init` [ bare `const` at line 20 ].

### 3. ~~File::Which -- core-only replacement exists but is bypassed~~ ADDRESSED

`src/base.file.pre_init:10` already loads through
`base.perlmod.load` -- with `auto_install_deps` enabled it now
self-installs via the compile-path hook [ see below ]. The
os_package core-only replacement remains the deeper fallback.

### 4. C25519 functionality unavailable degraded [ by design? ]

Key generation [ Crypt::Ed25519 ] and link-upgrade [ Crypt::Curve25519
+ Crypt::Misc ] simply break. Decide explicitly : either these are
essential-profile members, or each feature needs a degraded-mode
statement [ disabled with named reason ].

## Auto-install path [ added 2026-10-27 ]

Gap analysis and the strategic fix :

- `base.perlmod.load` auto-install existed but only for modules loaded
  through it -- bare `use` in templates bypassed it entirely
- `p7_load_code` now parses `cannot locate X.pm` out of compile
  failures and, when `base.perlmod.auto_install` is set [ root +
  host opt-in, startup window only ], installs via
  `base.perlmod.install` and recompiles once
- host opt-in : `v7-zenki.cfg.auto_install_deps = yes` in host.cfg
- remaining : `p7-deps` / `p7-install` essential profiles still need
  the audit-list modules [ Const::Fast, Curve25519, Ed25519,
  File::Which, IO::Uncompress ]

## Notes

- the decompression anyuncompress -> pipe-mode fallback works; the
  noisy multi-line error banner on the way is acceptable for now
- `2 broken` + `5 broken` subsystem compile reports are the useful
  degraded signal -- keep them visible, do not silence

#,,.,,,..,,,,,..,,,..,,..,,,.,..,,,.,,.,,,,,.,..,,...,...,,,.,.,,,,..,,,,,,.,,
#WJDTK3YLRXX4SN4BR3TZWGF4MHN7RAC7P4W4T3F6JPPLDZOV6ZFYZL6CPZNSZJHHZ2YK3KEQE5YI6
#\\\|DU6ZPTTEM5WDNGKYFRCHOHHHHITR54ZYTFMUUGDJDH5WYP4W2SW \ / AMOS7 \ YOURUM ::
#\[7]4QK7ZQTBKC2MO4YDQCA53YP3JPEYA5A3G7VZMFP37ZT45KR2AGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
