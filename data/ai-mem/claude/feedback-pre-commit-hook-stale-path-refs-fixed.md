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
commit `317319a5d`:
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

**exact content-heuristic trigger, confirmed 2026-08-21**: a staged
file only gets checked for a signature at all if it matches the
extension/path gate (`.pl|.pm|.yaml|.sh`, `^(src|bin|cfg)/`, or a
nested `.md`) *and* its content matches `/^#!|^\s*(use|my\s+\$|
sub\s+\w)|^#\s*name\s*=/m` or `/^---/m`. Plain prose task/doc files
(no embedded perl code, no `# name = ` line, no markdown `---` rule)
sail through with zero signature check regardless of location —
confirmed live when several new `data/tasks/*.md` and
`data/md/architecture/*.md` files committed clean with no signing step
needed, simply because they didn't contain any triggering pattern.
Don't assume "it's under `data/tasks/`" means it will be checked —
check the content shape first.

#,,,.,,,.,.,,,..,,...,.,.,.,,,...,..,,.,,,,.,,..,,...,...,..,,,,.,..,,,.,,.,.,
#N54CHBTBJX3UYHFINAWX27Z76HSPHBC4DEIOK5PESEOA6CJWHG2CCEAE4XXOPJYRQISEH7U3PSCL2
#\\\|UHZFILHNE2S6MGQXDDJZV6FSRT3CPYZU6JLUUPILXPFJQGKTRKD \ / AMOS7 \ YOURUM ::
#\[7]TKW3HYSJRRXJGUPS5FZQWBONUNPYYGBPB4A77S2EMRGPA3WOEEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
