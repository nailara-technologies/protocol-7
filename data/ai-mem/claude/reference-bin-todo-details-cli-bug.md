---
name: bin-todo-details-cli-bug
description: "bin/todo's non-interactive 'details <id> <text>' path is bugged -- always falls through to the interactive TTY editor regardless of args; hand-edit data/yaml/todo/base.yaml instead"
metadata:
  type: reference
---

**FIXED, argv works [ checked 2026-11-06 ]. history :** `bin/todo details <id> [<text>]` (`cmd_details`, `bin/todo` ~line 1283):
even the `if (@_)` "non-interactive" branch calls `edit_details_interactive
($item)` — the same function as the true interactive path — and ignores
whatever text was passed as extra args entirely. There's no way to set an
item's `details` field non-interactively through this CLI in an
environment without a real TTY (confirmed 2026-08-25 trying to document
the `J5N` todo item's resolution from a non-interactive session).

**Workaround**: hand-edit `data/yaml/todo/base.yaml` directly for the
`details:` field — the file is plainly `taeki`-owned (not a live
p7-managed data file, no reownership risk per
[[editing-p7-owned-data-files-reowns-them]]), git-tracked, and parses fine
afterward (`perl -MYAML::XS -e 'YAML::XS::LoadFile(...)'` to sanity-check).

`bin/todo done <id> [<id>..]` (`cmd_done`) is NOT affected by this bug —
it's fully non-interactive, uses `ntime_B32_current()` for the `done_at`
timestamp correctly, and is safe to call directly.

#,,.,,,,,,.,,,...,,,,,...,,.,,.,.,,,,,,..,.,,,.,.,...,...,...,.,,,,,.,.,,,,,,,
#YTI2FFLQZHTP3A2MJKX5YSCRGQCWTO55H7XP26SFIFND7AOUPORBWN2VO4XLK6HW2X5LYQKYJYAX6
#\\\|VNG544DXHOQWL2SIAK3C2SIQ6CFNXAUXDV6YXZLYVREWPPP6K5H \ / AMOS7 \ YOURUM ::
#\[7]PAO67JJ7NZ4U2FTJRV2LGVIVERL5VBVFD34646YO5YL52UQ5UQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
