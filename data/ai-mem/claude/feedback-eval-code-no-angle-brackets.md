---
name: eval-code-no-angle-brackets
description: "eval-code strings must use $data{...}/$code{...} directly — <registry> angle-bracket syntax is NOT pre-processed"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: be9c58bb-2e39-476f-8bcb-6ea253d0c195
---

Code strings passed to `p7c <zenka>.eval-code '...'` (or via `p7c_eval`) are NOT processed by the Protocol-7 pre-processor. This means:

- `<transport.registry>` in an eval-code string is treated as Perl glob/readline, NOT as `$data{transport}{registry}`. Under `strict refs` this gives: `Can't use string ('transport.registry') as a HASH ref`.
- `<transport.cfg.probe_interval>` similarly returns the literal string, not the config value.

**Use the expanded forms directly:**
- `<transport.registry>->{key}` → `$data{transport}{registry}{key}`
- `<transport.cfg.foo>` → `$data{transport}{cfg}{foo}`
- `$code{"module.name"}->()` — this is already plain Perl, works fine

**Why:** the p7 pre-processor compiles `<X.Y.Z>` to `$data{X}{Y}{Z}` when loading module source files, but eval-code skips this step and evals the string as raw Perl. Compiled modules (like `transport.select`) use `<transport.registry>` fine because they were pre-compiled; only in-flight eval-code strings are affected.

**How to apply:** whenever writing eval-code snippets (in task files, test harness scripts, or inline `p7c <zenka>.eval-code` calls), always write out the full `$data{...}` hash path. See also [[feedback-p7-data-nesting]].

#,,,,,...,.,.,.,,,,,.,,,,,,,.,.,,,.,.,,,,,,..,..,,...,..,,..,,.,,,..,,..,,.,.,
#V2EMNPS5JYWWHTYDWBWV5EYEG4G6BIRNAI3XTFJY4S5TWDZV3OFAAPP7YNKCUDQNOPZRNIPG24LQM
#\\\|VHCH6IXODO7FZ23MC35R2AADB66NOPLBMYVHNTST4TRI7ZEE7RV \ / AMOS7 \ YOURUM ::
#\[7]6CWHUB5CIF4CLWJM7TQW2LV2F34J4R7CHLIQCPLQKVWIGQPGQWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
