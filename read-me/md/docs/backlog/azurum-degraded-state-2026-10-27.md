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

### 1. base.chk-sum.elf.inline:62 -- unguarded elf_chksum call

The template ends with a bare
`return AMOS7::CHKSUM::ELF::elf_chksum(...)` -- fully qualified, no
load attempt, no fallback. When the AMOS7::CHKSUM::ELF chain cannot
load [ missing deps on its own path ], the truth-check chain dies with
`Undefined subroutine &AMOS7::CHKSUM::ELF::elf_chksum called at
base.chk-sum.elf.inline line 62`.

Expected : eval-require inside the template, falling back to the
template's own pure-perl ELF-7 loop when the module is unavailable.

### 2. crypt.C25519.init_code:68 -- 'const' without Const::Fast

`const <crypt.C25519.regex> => {...}` compiles as a readline-glob
syntax error when Const::Fast has not been imported [ see the comment
at src/base.init_code:35 : 'loading too late causes const to be a
syntax error!' ]. Degraded result is a confusing *syntax error near
'$data{'* instead of a clean 'requires Const::Fast' refusal.

Expected : soft-degrade the regex table when Const::Fast is absent
[ plain hash assignment ], or fail with a named dependency error.

### 3. File::Which -- core-only replacement exists but is bypassed

`AMOS7::deps::os_package` carries a core-only replacement for
File::Which::which [ os_package.pm:208 ], yet
`src/base.file.pre_init:10` loads the real module through
`base.perlmod.load`, which errors on a bare host.

Expected : route through the os_package replacement when the module
is absent, or add File::Which to the essential profile.

### 4. C25519 functionality unavailable degraded [ by design? ]

Key generation [ Crypt::Ed25519 ] and link-upgrade [ Crypt::Curve25519
+ Crypt::Misc ] simply break. Decide explicitly : either these are
essential-profile members, or each feature needs a degraded-mode
statement [ disabled with named reason ].

## Notes

- the decompression anyuncompress -> pipe-mode fallback works; the
  noisy multi-line error banner on the way is acceptable for now
- `2 broken` + `5 broken` subsystem compile reports are the useful
  degraded signal -- keep them visible, do not silence

#,,,,,,..,,..,,,.,,..,,..,,..,...,,,,,.,.,..,,..,,...,...,,,,,.,,,..,,.,.,..,,
#O43KNTXHTK4UEOWBN5TR7LYFOIZKQY7Z3AIHVWLYODDKN2CQFDMJD27GCCE6GXIL5XQL32VFYXAR2
#\\\|52AFBL3GWZRJ7VM7BCEAVFC6NGUTTJBEG4ZGA4HDHKJHPA4OMEJ \ / AMOS7 \ YOURUM ::
#\[7]USZTZLRKSWYPGTJIAVNDJ6QI7NIN7LTAGA7TK6IPQWIREETJFQDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
