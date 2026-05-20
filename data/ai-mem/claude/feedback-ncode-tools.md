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

#,,..,,.,,,..,,.,,...,.,.,,.,,,..,,,.,...,..,,..,,...,...,..,,...,.,,,,,.,.,.,
#WPHXZHUZMYMH6WBXG7DASAECKL2PPUJVWSWYVSETDJCUHGVQ5M253NZPTFJ3JKK2BYYOI7JL7F73I
#\\\|6JWDHT4RUPHD4U5TQXPO3D7NO3AXZV4RDJPPNSNGUUZUK2OMOOR \ / AMOS7 \ YOURUM ::
#\[7]4GPWRYQNBNP2IPDBNEBUASGWQRRMEYCXFJXH5VTFAB7CRLZ7U2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
