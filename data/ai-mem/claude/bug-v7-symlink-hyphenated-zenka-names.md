---
name: bug-v7-symlink-hyphenated-zenka-names
description: "RESOLVED 2026-08-12: every hyphenated zenka name was unreachable via its v7.<zenka> symlink -- base.init's name-split class [\\w|\\.] has no '-', so <system.zenka.name> stayed '<init>' and it died with \"no such zenka found ['<init>']\"; plus bin/Protocol-7's early-whitelist peek still matched the retired 'p7.' symlink form instead of 'v7.'"
metadata:
  type: feedback
---

## symptom

`v7.user-edit` → `<< no such zenka found ['<init>'] >>`. Not new-zenka
specific: `v7.workspace-transfer` (long pre-existing) failed identically,
while `v7.keys` / `v7.work` / `v7.sourcecode` worked. The discriminator
is the **hyphen in the zenka name**, nothing else.

`./bin/Protocol-7 <zenka>` always worked — only the `v7.<zenka>` symlink
form is affected, which is why this went unnoticed for so long. Roughly
25+ hyphenated zenki were affected (`amos-term`, `auto-hide`, `cred-mesh`,
`p7-log`, `web-browser`, `protocol-7-menu`, `workspace-transfer`, …).

## bug 1 — the fatal one : `src/base.init`

```perl
if ( $_[0] =~ m{([^\.]+)\.([\w|\.]+)$} ) {
    ( <system.node.name>, <system.zenka.name> ) = ...
```

`base.init` is called as `base.init("<node>.<zenka>")`. The zenka-name
character class `[\w|\.]` contains word chars, a **literal pipe** (almost
certainly a typo for alternation), and dots — **but no hyphen**. So
`DESKTOP-FP4OP26.user-edit` does not match at all, `<system.zenka.name>`
is never assigned and keeps its `<init>` default, and the very next check
in `base.init` reports `no such zenka found ['<init>']` and exits.

Fixed by adding `-` (trailing, so it stays literal): `[\w|\.-]`.

Verify with a bare regex, it needs no running system:
```perl
"DESKTOP-FP4OP26.user-edit" =~ m{([^\.]+)\.([\w|\.]+)$}   ## no match
```

## bug 2 — `bin/Protocol-7`, `p7_early_whitelist_load`

The early whitelist peek matched `m|^.*p7\.|i` while the real
zenka-name derivation ~330 lines above it matches `m|^.*v7\.|i`.
**Per user: `p7.*` is the OLD symlink form, `v7.*` is current** — so the
peek silently never matched for any symlinked zenka, fell through to
`$ARGV[0]` (i.e. the console command name, e.g. `commands`), found no
whitelist at `cfg/zenki/commands/`, and returned early.

Non-fatal on its own — it only means the early whitelist isn't loaded, so
everything compiles eagerly instead of on demand — which is exactly why
bug 1 masked it. Fixed to `v7\.`.

**How to apply:** when adding or debugging a `v7.<zenka>` symlink, note
that the symlink path exercises name-parsing code that
`./bin/Protocol-7 <zenka>` never touches — test BOTH invocations. And
`v7.*` symlinks are auto-installed by `v7.install_zenka_symlinks` only
for zenki that own a `<zenka>.console.*` module (see
[[reference-v7-zenka-symlinks]]), so a zenka gains its symlink — and this
whole code path — the moment its first console command lands.

Found while landing `user-edit`'s first console command; the user
spotted the `p7.`/`v7.` mismatch and correctly predicted a second,
`'-'`-related bug rather than accepting the first fix as complete.

#,,,.,...,...,,,.,...,,,.,,..,.,.,..,,,.,,.,,,..,,...,..,,.,,,.,.,,,.,,.,,,,,,
#55E3ZSV3EF5DN4EEUHFNBQI52GH5M72E2ZTXFBFBWOFEFWURJEXFI25SPMK5OBGSTJPH6FMEWLELM
#\\\|MDIDXSKP5WJMCAYR3QBHW42BVRBE7SASNGREYIEU6FBFZJ4WHDL \ / AMOS7 \ YOURUM ::
#\[7]XXJPQJX5ARBFKUGPY4VFTNN7WJFL3U2LJW7BDMGFWD3WTP5S76CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
