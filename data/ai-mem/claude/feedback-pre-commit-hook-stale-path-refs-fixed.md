---
name: pre-commit-hook-stale-path-refs-fixed
description: bin/dev/git-hooks/pre-commit had hardcoded pre-rename 'modules'/'configuration' path strings that silently broke its signature-exclusion list; fixed 2026-08-21, plus how its exclude-pattern matching actually works
metadata:
  type: feedback
---

`bin/dev/git-hooks/pre-commit` (symlinked live from `.git/hooks/pre-commit`,
edits take effect immediately, no reinstall step) had three leftover
`modules`/`configuration` literals from before the [[zenka-naming-cleanup]]
era renames (`modules/`→`src/`, `configuration/`→`cfg/`), fixed in
commit `c465ba265`:
- loaded `sourcecode.source_path_set_up` from the old `modules/` path,
  so the `open()` silently failed and `@sig_exclude_paths` was always
  empty — no exclusion ever worked
- the staged-file inclusion gate `m{^(modules|bin|configuration)/}`
  still checked the old dir names instead of `src`/`cfg`

**Exclude-pattern matching in this hook** (`src/sourcecode.source_path_set_up`'s
`!`-prefixed lines): if the pattern ends in `$` it's used as an
unescaped regex (`$file =~ m{$e}`, matches anywhere); otherwise it's a
literal prefix match (`$file =~ m{^\Q$e\E}`). No mid-string globs — a
prefix like `!data/asc` covers the whole subtree, not `!data/asc/**`.

**Why it still false-flagged plain docs after the path fix**: the
hook's "does this look like source" heuristic is content-based, not
tied to the real include-list (`@copy_sources` in
`sourcecode.source_path_set_up`) — it flags any staged file matching
`.md`(nested)/`.yaml`/etc. whose content has a line starting `---`
(any YAML-frontmatter-style **or plain markdown `---` divider**) or
`# name = ` or a perl-ish `use`/`my $`/`sub` line, unless an AMOS7
signature marker is also present. Docs entirely outside the real
signed-source tree (root `CLAUDE.md` family, `data/asc/` archives) can
still trip this by accident — needed explicit new exclude lines added
for `!.claude_readme_first`, `!CLAUDE.yaml`, `!data/asc`,
`!cfg/zenki/work/source` (the last because `cfg/zenki/*/*` in the
include glob is only 2 levels deep, doesn't reach a 3rd-level `source/`
subdir).

**How to apply**: if the pre-commit hook flags something as
"unsigned" that clearly isn't part of real source (no AMOS7 footer
expected), don't run `sourcecode update-signatures` on it — check
whether it's actually inside `src/sourcecode.source_path_set_up`'s
`@copy_sources` first. If not, the fix is a new `!`-exclude line in
that file, not signing the file.

#,,.,,.,.,.,.,.,.,..,,.,,,,,,,.,.,..,,.,.,,..,..,,...,...,,.,,.,,,,,,,,,.,,.,,
#SOIFNGE2M2TOWI76RXQ4TH3BA6FMXGF34CBW3LPGMF7S7FVMUEWV2S756OTS46ESA4HQDLZKR3RKI
#\\\|YGC7PMF2GP5UIQAJTMKOWFQV7XO7FAOGVXLFDPISTURX46DNK5U \ / AMOS7 \ YOURUM ::
#\[7]YLMMIRVU424M63HRLDM4E7OXI4YRS7ZBQY2NY7WJACQM4PE5ISBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
