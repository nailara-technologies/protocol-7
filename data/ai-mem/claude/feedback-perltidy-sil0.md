---
name: feedback-perltidy-sil0
description: format-code/ptd -sil=0 canonicalizes over-indented P7 modules to col0
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4d1cd39b-4703-4113-9ed7-a5f1d54c7cff
---

when sub-extraction (or any edit) leaves a whole P7 module uniformly indented (e.g. +4 spaces on `# name`, `# descr`, and body — `## [:< ##` marker stays col0), perltidy does NOT fix it: it auto-detects the uniform leading indent as the intended "starting indentation level" and PRESERVES it. so `format-code`/`ptd` ran clean but changed nothing.

**Why:** a uniform indent reads as deliberate to perltidy; a lone first-line prefix, by contrast, gets dedented. the over-indent also silently broke `bin/dev/dep-graph` (its `extract_module_name` required `#` at col0) → those modules were absent from `gen-sub-whitelist` output → lazy-loaded at runtime instead of preloaded.

**How to apply:** the fix is the perltidy flag `-sil=0` (`--starting-indentation-level=0`), now added to `bin/format-code` and `bin/dev/ptd` arg lists — they are kept in parity. this forces the top-level baseline to col0 (inner blocks still indent normally) and preserves `<[...]>` P7 syntax. it makes the formatters SELF-HEALING: just run `bin/format-code modules/<name>` on an over-indented module and re-sign. verify with `git diff -w` (should be empty = whitespace-only) — note perltidy may also re-wrap a line that now fits `-l=78` differently at col0 (benign, semantically identical). `bin/dev/ptd -c` is only a syntax check (`perl -c`-like), NOT a format diff — run without `-c` to see reflows. relates to [[topic-memory-tree-zenka]], [[utf8-module-literals]].

#,,,,,...,,,,,,.,,,.,,,..,,..,,.,,.,,,,,.,.,,,..,,...,...,.,,,,.,,,,.,,,.,,,.,
#4YWVUIW6SCUIXE4Y2B5NP2RFDGH5FJSTUSF4JOTJ5I33DAOEIVNRJKWSLNDMF2JS6VFSDDAWI7DBK
#\\\|TKA3F5PJ6A6FZGZKVA4MWDGTYWBJPZ4SOTRHUKSPIOE22P5LANL \ / AMOS7 \ YOURUM ::
#\[7]3HFDC4U7QD5UH46PGTI7PNHYAGEZUMNALUCQ3VNJXWM6G2X4EYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
