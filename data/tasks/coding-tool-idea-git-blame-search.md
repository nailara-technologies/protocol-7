## [:< ##

# name  = task: git-blame-aware search tool for coding zenka
# descr = surface who wrote a line, when, and why, alongside the existing
#         diff/history tools
# param = new tool, small scope -- not a fix, a gap to fill when picked up

## context

surfaced by the model itself during a coding session (task-EQLRAHA,
2026-09-23), when asked what tools it'd want that it doesn't have. most
of what it listed already exists in some form (round_chain rewind/redo,
reasoning.branch registry, task/session persistence, the existing tool
catalog) -- this one doesn't.

## the gap

`coding.tools.definitions` / `coding.tools.dispatch` already cover diff
and recent-changes style tools, but nothing answers "who wrote this
line, when, and why" -- i.e. `git blame` plus the matching commit
message, queryable by file+line (or by symbol/function name) rather
than requiring the model to shell out or guess a commit hash first.

## shape of a fix, not yet designed

- a tool taking `path` + `line` (or a line range), returning the
  commit, author, date, and commit message for that blame hunk
- optionally: walk back further ["show me the blame before this
  commit"] for tracing a line's history across renames/rewrites
- pairs naturally with whatever tool already does `git log`/diff-based
  history, if one exists -- check `coding.tools.definitions` first
  rather than assuming a clean slate

#,,,,,.,,,.,,,.,,,,,.,,,.,,..,.,,,,.,,..,,,,,,..,,...,..,,...,.,,,,.,,,,.,,,.,
#F4BGKCS4PZUQX634PYZRT27D64J2Y23OVAAB7DEZ7O4PZ6M22RPJYF2ZT3XYTQFY7JWABSW5NZUQA
#\\\|BSVKYNJSPVIDHCDFVHA54Q4Z2WBPWOSR6WCKQKQS6IMGC3G27AX \ / AMOS7 \ YOURUM ::
#\[7]VXU64GPGO3IT5ZDQF6SPRN53HTJQDI66VHEGO6BN3ZJAMYX56OBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
