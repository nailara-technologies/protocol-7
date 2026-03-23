# Task: dep-graph — nested .cmd. paths not seeded into reachable set

status: completed
completed: 2026-03-23

## Bug

the cmd seeder in `bin/dev/dep-graph` (line ~831) used the pattern
`^\Q$ns\E\.(?:cmd|console)\.` which only matches direct command paths
like `base.cmd.heart` but not nested paths like `base.net.cmd.timestamp`.
same issue for the console seeder (line ~847).

### affected modules

- `base.net.cmd.timestamp` — missing from cube whitelist despite being
  in cube's access.cmd config
- `base.chk-sum.bmw.cmd.bmw-L13` — appeared in all whitelists via base
  namespace; moved to `cube.chksum.bmw.cmd.bmw-L13` since it's cube-specific

## Resolution

two fixes applied:

1. **cmd/console seeder regex** — changed from `^\Q$ns\E\.(?:cmd|console)\./`
   to `^\Q$ns\E\.(?:.*\.)?(?:cmd|console)\./` to match nested paths.
   applied to both the network cmd seeder (line ~831) and the standalone
   console seeder (line ~847).

2. **module relocation** — `base.chk-sum.bmw.cmd.bmw-L13` moved to
   `cube.chksum.bmw.cmd.bmw-L13` since it's a cube-specific command,
   not shared base infrastructure.

note: the access.cmd filter (line ~884) was NOT the problem. it correctly
handles nested `.cmd.` paths — the issue was that these modules never
entered the reachable set in the first place because the seeder skipped them.

## Verification

- [x] `base.net.cmd.timestamp` is in cube's whitelist
- [x] `cube.chksum.bmw.cmd.bmw-L13` is in cube and cube-13 whitelists only
- [x] old `base.chk-sum.bmw.cmd.bmw-L13` removed from all whitelists
- [x] all 90 whitelists regenerated

#,,..,.,.,...,,,,,,,,,,.,,,,.,.,.,,..,,.,,...,..,,...,...,,..,...,,..,.,.,,,.,
#JRPDPLDWGF3CDAML2SKYVX4GUFJ3VN5VWDHYHRC4NPNWCB7YZFRGJHEKVOB6LSVO5JWPVB5ETPBR2
#\\\|XGTGF4YNNAEA2NY2VF7QCQC6FOWJ272XBW2J7ROZB22ZLYRPOTL \ / AMOS7 \ YOURUM ::
#\[7]VZFE4GEQWOFS4TQX2ULDK66MFOL5FMPUMRYWJVI6DJ63EMJ7SUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
