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

#,,..,...,,.,,..,,,..,...,.,.,.,.,..,,,,,,...,..,,...,..,,,.,,,,,,,,.,...,,..,
#NEFDNWITSOT257DLFM4RMGMJ5JOCH5YNLMJJ5MPLQLBI4HVQXEZ36TIEENIRTMDTLRQW5NZYAAKRW
#\\\|PYL7SY77OQRWWTNDLACVNJFZ5NSM34X6TIOZWRMDUKLWPPCLXFT \ / AMOS7 \ YOURUM ::
#\[7]MFZEIRPEVGWMDWLVJALLOC32E5FSB632JAQZUWERYPEVX2E5J2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
