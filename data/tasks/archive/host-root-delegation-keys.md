# host-root delegation : keys \ key-path call sites [ lane 2 ]

`data/md/design/HOST-ROOT-DELEGATION.md` introduces root-held keys in
`<backend key dir>/root/` and ONE resolver, `crypt.C25519.key_path`
[ read the "root-held keys" and "resolver API" sections -- the API is
FIXED there ; lane 1 implements it in parallel, it may not exist yet when
you start : code against the spec ]. your job : every key-path call site
OUTSIDE `src/crypt.C25519.*` goes through the resolver, and the keys
zenka understands root-held keys.

do NOT start, restart or reload any zenka, no sudo, no commit, no
signing, no git command that changes the tree. never read real key dirs.

## yours

- `src/keys.console.*` [ 13 build key paths today ], `src/keys.backup.*`
- `src/work.console*`, `src/source.load_signature_key`,
  `src/sessions.holder*`, `src/session.console*`, `src/p7-log.anon*`,
  `src/base.root*` -- for each : does it build a KEY FILE path ? then
  resolver ; if it only names the dir for another purpose, leave it and
  say so in the report
- find them : `grep -rln "user-keys\|{'key_dir'}\|<crypt.C25519.key_dir>" src`

## behaviour

- `keys` list [ `p7-keys list` ] : root-held keys as their own group
  [ e.g. `'host-root' [ root-held ]` ], readable only when running as
  root ; as non-root show the names only [ listing `root/` itself may
  fail -- that is expected, say "root-held : not readable as <user>" ]
- every keys.console operation on a root-held key [ change passwd,
  enc \ dec key, backup, delete, authorize ... ] refuses unless running
  as root, with a clear message
- `keys.backup.*` : includes `root/` only when running as root ; restore
  keeps owner 0 + modes
- user-edit : check whether it builds key paths itself ; if it only goes
  through crypt.C25519, report "no change needed"

## not yours

`src/crypt.C25519.*`, `src/auth.*`, `src/trust.*`, `src/v7-zenki.*`,
`cfg/`, every `bin/` file except a NEW test. lanes 1 \ 3 edit those. you
add NO new modules [ if you need one, describe it in the report ].

## test

NEW `bin/test-scripts/test-keys-root-held.pl` : stub
`crypt.C25519.key_path` per the spec API ; listing groups root-held keys,
non-root refusal of each operation you touched, backup inclusion rule.

## pitfalls + report

same P7 pitfalls as `data/tasks/host-root-delegation-perl.md`. report :
`data/tasks/host-root-delegation-keys.report.md` -- every call site [ changed
\ left + why ], test output, open questions.

#,,.,,.,,,...,...,..,,..,,..,,.,.,.,.,...,.,,,..,,...,...,,..,..,,,.,,..,,,,,,
#5CTAANHQ7ZP5VH7CUCLAZIY3E4YE6GGLY7FUDZ23NMXJRA5LBWF37X6YARV4HN2VIUXJKIGS6KISA
#\\\|SCLQ42XUB2LZPV4KKT22V2FALRMEHZQIYEWWZV6G6DEKXI2HCCK \ / AMOS7 \ YOURUM ::
#\[7]LPR7P4LFJERZ7JT4WMIRYY4OUPRTGHREAWQWPNFTG7SUUUBTROAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
