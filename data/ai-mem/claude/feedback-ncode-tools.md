---
name: ncode-tools
description: using ncode replace and parse-headers for safe codebase-wide refactoring
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bb6d3c05-897e-4fe3-b949-2261e52562d9
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

#,,..,,,,,.,,,...,.,.,.,.,...,.,.,,,.,.,.,,..,..,,...,...,,,,,..,,,.,,.,,,,..,
#5CUNE64RVX3L5WMGVRA63PFKXHRT2MTCHKLNVWU42BGC2MF72GJ2KKSGGYJCYH2VXAJGKNRK773R6
#\\\|52GEKV34SO4KU3JWNSJUXSCDFOX3BUD6G3LDKMVSWH5M4ILIG6Z \ / AMOS7 \ YOURUM ::
#\[7]E4V6V5YHOJGBRBOSUWDDOGQOOUQNUFN3IIMVZ4RVRVI7RT62R2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
