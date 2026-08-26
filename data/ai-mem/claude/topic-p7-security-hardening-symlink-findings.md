---
name: topic-p7-security-hardening-symlink-findings
description: "two unfixed findings in bin/Protocol-7's p7_security_hardening BEGIN block (deferred by user 2026-08-12): first die() missing sprintf, and relative symlink targets breaking @INC lib-path derivation -- both latent, neither caused the v7.* symlink bug"
metadata:
  type: project
---

Found 2026-08-12 while checking `p7_security_hardening` for further
`v7.<zenka>` symlink bugs after
[[bug-v7-symlink-hyphenated-zenka-names]]. **Both deliberately NOT fixed
— user said "it could be later."** Neither is what broke `v7.user-edit`.

**Checked and CLEAN, do not re-investigate:** `$char_map`
(`qr|([^0-9a-zA-Z\-\+\.:_\[\]\/]+)|`) already contains `\-` and accepts
every hyphenated symlink name (`v7.user-edit`, `v7.workspace-transfer`,
`v7.web-browser` all pass). `${^CAPTURE}[0]` also populates correctly —
a test that appeared to show it empty was actually capturing a space.

**Finding 1 — `die` missing `sprintf`.** The program-name check is a bare
`die LIST`, so its `%s` placeholders never interpolate; the link-target
check immediately below it uses `die sprintf` and formats correctly.
Error path only, but it's the message you'd be reading exactly when
something is wrong:
```
FIRST  : << not valid characters [ %s ] in program name %s >>   bad name!
SECOND : << not valid characters [   ] in link target bad name! >>
```

**Finding 2 — relative symlink targets.** The resolution loop does
`$bin_path = $link_target` with `readlink`'s verbatim return, so a
RELATIVE target is subsequently resolved against CWD instead of against
the symlink's own directory. Breaks both the `@INC` local-lib-path
derivation (`rel2abs($bin_path) =~ s|/[^/]+/[^/]+$|/data/lib-path/pm|`)
and any further hop in the `while` loop. Demonstrated:
```
readlink        -> ../../../../data/projects/protocol-7/bin/Protocol-7
derived libpath -> <cwd>/../../../../data/.../data/lib-path/pm   [ NO ]
```
**Latent, not live** — `v7.install_zenka_symlinks` writes ABSOLUTE
targets, which is why every real `v7.*` symlink resolves fine. Only bites
a hand-made relative symlink. One-line fix when wanted:
`File::Spec->rel2abs( $link_target, dirname($bin_path) )` when the target
isn't already absolute.

Note this code lives in a `BEGIN` block inside `p7_security_hardening` —
it runs at compile time, before any zenka-name resolution, so changes
there affect every invocation of every zenka.

#,,,,,,.,,,.,,.,,,..,,.,.,,,.,.,,,...,...,,,.,..,,...,...,..,,,.,,..,,,,.,,..,
#VPR472YPISQGTSCA2RGIG5UCHYZCAGMIMB5GORSI42TK7SHMBQFG4WZNB3INKWXU244VH6VQYGSDU
#\\\|YM3WM7QY3XCLIJ7D43JTPLCURURSRBZJ6QGXTA4ABRWJZHMZ7O3 \ / AMOS7 \ YOURUM ::
#\[7]VZKZ6GC4H22KNESEMIEAWPI5YDXBB3H555VSSPJQTRZCIKGXP6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
