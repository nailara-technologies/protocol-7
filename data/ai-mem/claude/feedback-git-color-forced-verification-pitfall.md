---
name: feedback-git-color-forced-verification-pitfall
description: this shell's git output is color-forced -- any naive grep-based "diff is empty" check silently lies, because every line starts with an invisible ESC byte the filter never accounts for
metadata:
  type: feedback
---

`git diff`/`git status` in this environment emit ANSI color codes even when
piped or captured by a tool (not just in an interactive TTY). A verification
pattern like `git diff ... | grep -v '^\[38' | grep -E '^[+-]'` looks
reasonable but is completely broken: every real line starts with the raw
ESC byte (0x1b) *before* the visible `[38;...` text, so `^\[38` (anchored to
a literal `[`) never matches anything, and `^[+-]` never matches a content
line either, since the ESC byte is what's actually first. Both filters
silently pass everything through unfiltered, or — depending on exact
pattern — silently drop everything, and either way the "diff is empty, this
file is clean" conclusion is not backed by what you think it's backed by.

**Cost this caused, 2026-09-23**: after reverting a batch of files to HEAD,
a `git diff HEAD` check using this broken pattern reported them as clean.
They were not — a concurrent signing/version-bump tool had re-staged the
original (unwanted) content in the index, and the broken filter never
caught it. This led to briefly believing a *new* bug had reintroduced
already-reverted dangerous changes and unrelated file corruption (an
innocent, deliberate user edit misread as fresh damage) — a real "is this
actively corrupting itself" scare that cost real back-and-forth before the
verification method itself was found to be the problem, not the repo.

**How to apply**: for ANY verification that hinges on "this diff is/isn't
empty" or greps diff output for real content lines, disable color at the
source, never try to filter it out downstream:
```
git -c color.ui=false diff ...
git -c color.ui=false status --porcelain ...
```
`git status --porcelain` (v1) is inherently script-safe regardless of the
`color.ui` config and is preferable to `status --short` for exactly this
reason. Never trust a `grep -v '^\[...'`-style ANSI filter — check the
actual byte sequence (`cat -v` or `xxd` a sample line) before assuming any
hand-rolled filter strips it correctly. When re-verifying a revert or a
"nothing changed" claim, use `git -c color.ui=false diff HEAD -- <file>`
and confirm truly empty output, not a filtered-and-hopefully-empty one.

#,,..,..,,,..,,.,,,..,,,,,,,.,..,,..,,...,,.,,.,.,...,..,,...,,,,,.,.,,,,,.,.,
#UJAUO2S6E657FK55MRRRCP7WYVR7TQ4BVFZ7CGJBX26DKTIST7K3DBTJKDFL4VHTIPIS7CFI5HNKS
#\\\|LDTXBDV2JXZH33APOVFUMRS55YDP3JO3Q2N347KOEUANP24ZVL3 \ / AMOS7 \ YOURUM ::
#\[7]736JATCD3Q3GB6QYGE2LWF45VEMA4GFGK5T6OJMVVWM477YKBCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
