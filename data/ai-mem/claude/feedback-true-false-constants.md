---
name: feedback-true-false-constants
description: "use TRUE/FALSE constants for boolean values in Protocol-7 modules, never 0/1"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dcbc6065-ca1e-4d35-b876-1a342dfe7eb6
---

In Protocol-7 module code, use the global constants `TRUE` and `FALSE` for any
boolean value — initialization, state flips, conditional return values, default
fallbacks (`//= FALSE`), `eq qw| true |` reply modes, etc.

**Why:** Protocol-7 defines `TRUE => 5`, `FALSE => 0`, `UNKNOWN => 2` (see
CLAUDE.md "Data Structures & Isolation"). The constants carry domain semantics
beyond a generic 0/1 — they participate in three-valued logic with UNKNOWN, and
the codebase reads as a continuous lowercase narrative where `TRUE`/`FALSE` are
part of that visual vocabulary. Writing `0` or `1` for booleans visually
collides with numeric counters/IDs and breaks the narrative flow. The user has
flagged this on multiple occasions and silently fixes it post-edit.

**How to apply:** Whenever writing/editing any module under `src/`,
substitute `TRUE`/`FALSE` for `1`/`0` when the value is semantically boolean.
This includes:
- flag initialization: `my $found = FALSE;` not `= 0`
- flag flips: `$found = TRUE;` not `= 1`
- hash sentinel values: `$seen->{$k} = TRUE;` not `= 1`
- defaults: `<some.flag> //= FALSE;` not `//= 0`
- parsed-config defaults: `$cfg->{enabled} // FALSE` not `// 0`

Leave actual numeric literals (counts, IDs, indices, math) alone.

Related: [[style-philosophy]] (lowercase narrative, visual cohesion).

#,,,,,.,,,,..,,,.,,,.,,..,.,,,...,.,,,.,,,,,,,..,,...,...,.,.,.,,,,.,,.,.,,,,,
#G56FV33RRNIDUJSGWPYOIMIUGGIY7VRK7T7J67I7NP56EPQNIUZVV2MUVDZY3QKQTWS7MSPBGAYIM
#\\\|QNC6W6EHMGI42IHGSRH2VHCEQ4GEPRGJAZLDDMTQB7MVYF26AUG \ / AMOS7 \ YOURUM ::
#\[7]KIGODVQYMUEVBGXAOZAJKLSZVERNPG3M5GA356DXXR273B25HCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
