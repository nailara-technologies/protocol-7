---
name: ncode-tools
description: using ncode replace and parse-headers for safe codebase-wide refactoring
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bb6d3c05-897e-4fe3-b949-2261e52562d9
  modified: 2026-07-20T09:58:03.404Z
---

`ncode` is the right tool for renaming subroutines and namespaces across the codebase.
use it instead of ad-hoc perl/sed one-liners which risk corrupting files.

**rename workflow (confirmed working):**

1. rename files manually (`mv modules/old.name modules/new.name`)
2. fix `# name =` headers: `ncode -no-color -ai-friendly -confirm parse-headers src`
   (or `ncode r src 'old\.name' 'new.name'` which also catches name headers)
3. fix all callers: `ncode -no-color -ai-friendly -confirm r src 'old\.name\.' 'new.name.'`

**example:** `base.window.*` → `window.*` namespace rename (session 37):
- `ncode parse-headers` updated 5 module name headers cleanly
- `ncode r src 'base\.window\.' 'window.'` caught 12 references across 4 files
  including base.list.subroutines, ticker.open_window, ticker.cmd.set-window-profile

**Why:** ncode uses the project's own code intelligence, respects file structure,
creates backups before applying, and shows a diff preview before writing.
ad-hoc sed/perl in a for-loop risks file corruption (as happened with smtp modules).

**How to apply:** whenever renaming a module or namespace, reach for ncode replace
before considering perl -i or sed.

**escaping braces in patterns:** ncode uses `{...}` as regex delimiters, so `{` and `}`
in search patterns cause errors. mask them with `.` (dot = any char):
- `$data{'space.grid.nodes'}{` → search pattern: `data..space.grid.nodes...`
  (2 dots for `{'`, 3 dots for `'}{`)
- replace: `<space.grid.nodes>->`
- `ncode -ai-friendly -confirm replace src "data..space.X.Y..." "<space.X.Y>->"`
- also works for quotes `'` and other special chars — mask with `.`

**limitation hit (session 5c95ba04):** `ncode replace zenki` returned 0
matches for a pattern using `\K` (`modules\.load\s*=\s*\Kauth\b`), even
though the identical pattern worked correctly under plain `perl -ne`.
Also, `${1}`-style capture-group replacement text errors with "replace
pattern contains unescaped '$' characters" — ncode's replace doesn't
support the same modifier syntax perl does by default (there's an
`e/`-prefixed eval mode per its own docs, untried). For a **conditional**
bulk edit (94 files get plain token swap, 3 files get token-insert-
alongside-existing) `ncode replace`'s single search/replace pair can't
express the branch anyway — used a small `perl -i -pe` script per file
instead, with `git diff --stat` + spot-checked full diffs as the "preview"
step (files were already git-tracked, so this is safe/reversible). Prefer
`ncode` for simple single-pattern renames as before; fall back to a
verified plain-perl one-liner + git-diff review for `\K`-based patterns
or conditional/branching bulk edits.

#,,,,,,..,,,,,.,.,,.,,,..,.,.,.,,,..,,...,,.,,..,,...,...,,.,,..,,..,,..,,...,
#5JI2YK4FT7B5I2MOMIJSH6SGAO3LZ3OSBTF6VMPRIOBCW6I6BIXR5PJR63YL3NRTQAMELG6VCZYQW
#\\\|OJ7H5C7QOKAA74F7LYWOZIYKMEW7RM5NVS6EED7J3H73POFZ2LY \ / AMOS7 \ YOURUM ::
#\[7]XBA6YYHGEAMIFQJG7GW7WBDWD56ISDAJFLOUPOI5XH3YFHYA6IAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
