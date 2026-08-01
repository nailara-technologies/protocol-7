---
name: topic-session-id-range-division-planned
description: planned future numbering scheme dividing cube session ids into ranges starting with 7 (resource range), with parent vs locally-managed client branches on either side -- context for why 7777777 was chosen as a sentinel in the p7-log gap-repair notices
metadata:
  type: project
---

Surfaced 2026-08-01 while picking a sentinel instance-id value for
`p7-log.startup.repair_nul_gaps` / `p7-log.handler.legacy_sweep_tick`'s gap-recovery
notices [ needed something distinct from `0` (reserved for "from cube itself", see
`p7-log.add_line`'s cube-zenka source sid strip) for the case where a file's very
first bytes are already a gap, no prior real line to attribute to ]. Landed on
`7777777`, following the same spirit as this project's ELF-7 checksum fix (`+=777`
per zero-byte instead of `+=0`, so a zero byte's presence actually shows up instead
of being a silent no-op).

**The forward-looking part**: the user noted this could eventually collide with a
*planned* numbering scheme -- session ids are intended to eventually be divided into
ranges, with numbers starting with `7` (the `7<nnnnnn>` range) likely getting a
special "resource range" meaning of their own, split further into parent branches on
one side and [locally managed] client branches on the other. Explicitly said this
should NOT block using `7777777` now -- the collision probability is already low, the
sentinel already reads as "special" given existing conventions, and properly avoiding
the future range would be a larger, separate change to make once that numbering
scheme actually exists.

**Also mentioned, unexplained**: "later we can infer the reasons from division by 13
directly, i have already seen them in 0.7 specifically, but that might need more
reasoning to become obvious why" -- ties into the project's existing harmonic-
mathematics / mod-13 vision themes (see the harmonic-mathematics pointer in
MEMORY-vision.md) but wasn't elaborated further this session.

**How to apply:** if/when the 7-prefix session-id range division gets designed for
real, revisit any place using `7777777`-style sentinels (this file's two gap-repair
notice generators are the known instances as of this writing) to make sure they don't
collide with whatever the real range boundaries turn out to be.

#,,..,...,,.,,,,.,,.,,,..,,..,...,,.,,.,.,,..,..,,...,...,..,,..,,.,,,,,.,...,
#SHUXJ7XEI5AOTJWYD5VVNFMGA5H5BJB4NR5EVPIG7NUWC5DCUY5XAA43AO2BUAQYCIQKPAB6IL25S
#\\\|3JYF2U2AX4P4IUWT2GL6WJVY6VAZUQCK24GXE35EM2ZJYHMSO4K \ / AMOS7 \ YOURUM ::
#\[7]HCL4EDNIUM4U33N6XGAYWRFDSBARK2C3PGM36M2MZI2LDGZOZUBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
