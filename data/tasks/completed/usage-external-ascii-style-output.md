## [:< ##

# name  = task: prettify bin/dev/usage-external's output to match the project's own console style
# descr = the script currently prints plain printf-aligned lines; the
#         project has its own distinctive box-drawn console style used
#         throughout bin/Protocol-7 and friends -- adopt that instead

## context

filed 2026-09-15, right after `bin/dev/usage-external` (Claude/Kimi
account usage checker, see `data/tasks/mcp-server-usage-query-tool.md`
for full background) was built, live-verified, and moved from
`bin/check-usage` into `bin/dev/`. Deliberately sequenced as a follow-up
rather than blocking the initial commit -- get the working tool landed
first, prettify after.

## the target style, from the user directly

```
 [taeki] /data/projects/protocol-7 :. tail -14 bin/Protocol-7 | head -8

.:[ base.protocol-7.source-key ]:.
:
: ## [:< ##
:
: qw| JXA7AXE6PUORNNRI2F6PEFQKZSGUL2PKIOTXIGMHDUI6GHA4YWRA |
:
:.
```

the shape: a `.:[ TITLE ]:.` header line, content lines each prefixed
with a bare `: ` gutter, a blank `:` separator line where useful, and a
closing `:.` line. This is the same visual family as the colored
`::[...]:.`/`:E:`/`:.` console decorations already used throughout this
session's own tool output (`bin/format-code`, `bin/dev/update-version`,
`bin/dev/gen-sub-whitelist`, the sourcecode signing/verify tools) --
worth grepping those for the actual helper functions/color constants
they use (this session saw `$bl`/`$bg`/`$CT`/`$fg`/`$no`/`$ng` color
variables defined inline in `bin/dev/update-version`, for instance) so
this doesn't reinvent a slightly-different version of an existing
convention.

## scope, not started

- replace `usage-external`'s current plain `printf "  %-12s : ...\n"`
  rows (see `print_kimi_usage`/`print_claude_usage`) with the boxed
  `.:[ TITLE ]:.` / `: ` gutter style.
- also change every runtime-printed `( ... )` annotation (e.g.
  `( remaining 21 )`, `( in 1d 7h 8m )`) to `[ ... ]`, matching
  `CLAUDE.md`'s own bracket-convention rule -- currently only followed
  in the script's source comments, not its printed output. Same
  bracket swap applies to the box style's own `.:[ ]:.` shape above.
- swap which value is primary on every `resets` line: the human
  duration (`in 1d 6h 58m`) should lead, with the raw/absolute
  timestamp demoted into the bracket annotation, not the reverse. Raised
  directly by the user, with the reasoning: a bare ISO8601 timestamp
  (`2026-09-16T21:15:23.345298Z`) is not human-friendly and just gets
  visually skipped past -- swap which value is the headline and which is
  reference detail, don't just re-bracket the existing order. e.g.:
  ```
  before:  resets       : 2026-09-16T21:15:23.345298Z ( in 1d 6h 58m )
  after:   resets       : in 1d 6h 58m [ 2026-09-16T21:15:23.345298Z ]
  ```
  applies to every `resets` line in both `print_kimi_usage` (raw
  ISO8601 via `countdown_suffix`) and `print_claude_usage` (already
  formatted as `2026-09-15 18:30 UTC` via `epoch_to_str` -- same
  primary/secondary swap still applies there for consistency, even
  though that one's already somewhat readable).
- check whether there's a shared helper for this box style already
  (rather than each script hand-rolling its own ANSI color constants
  and box-drawing) before adding a third or fourth copy of the same
  pattern -- if one doesn't exist, this might ALSO be a good moment to
  extract one, but that's a separate judgment call from just matching
  the visual style.
- keep the underlying data/logic untouched -- this is presentation
  only, no changes to the credential-loading, HTTP, or fallback logic
  that was already live-verified working.

no design/implementation work done yet -- this is a capture-for-later
task file only.

#,,,.,,.,,,,,,,,.,,,,,,,.,,,.,...,.,,,.,,,.,.,..,,...,...,...,,,,,,,,,,,,,,.,,
#I4M5XHNBZVDFLV2Y24WLFBQG2SVTXRPCF3CHDFSSVCMEDBLYKL7AY7K2BE54X33TJI4PUYMHWGV5Q
#\\\|V2DVEACA2W46EWMJ4QY24DU25PRGUMTVVP5XVHEWOMBXHCIVQ5U \ / AMOS7 \ YOURUM ::
#\[7]G6XL67LWZ46L3S6RLWM72JVIZYM2R43HSZ6H4QLNQ5ACCT356ABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
