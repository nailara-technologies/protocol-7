---
name: project-usage-report-format-redesign-2026-09
description: usage.format.report now has 3 formats (pretty default, details=old box, compact=unchanged machine contract); kimi/claude window keys unified to 5h/7d; coding-zenka check_account_usage consumes pretty blocks now, not compact lines
metadata:
  type: project
---

Landed 2026-09-15/16 (commits `5f9593daa`, on top of `64aa89df4`/`c0187d751`
from the earlier kimi-refresh-fix session, see [[reference-ntime-x4200-and-cube-cross-zenka-access]]).

## the three formats, `src/usage.format.report`

- **default** (no arg) — new `pretty` format: one block per provider,
  ` .: <name> :.` header, ` : <key> : <pct> : <duration>` rows, reset
  times via `<[base.parser.duration]>->( <[base.time]>->() - $resets_in, 2 )`.
  Row/block separators use an explicit `$row_sep`/`$block_sep` flag, NOT
  `if (@lines)` — that trap doubles the leading blank line if you also
  unconditionally push one blank line before the loop (hit this live: two
  blank lines instead of one, fixed by switching to an explicit flag).
- **`details`** — the prior long/box format, byte-for-byte unchanged.
- **`compact`** — the original one-line-per-row machine format, kept as a
  stable contract. Note: it is NOT frozen at the data level — the window
  KEYS it renders changed (see below) because `compact` derives its key
  from the same `$row->{'window'} // $row->{'label'}` field the other
  formats use. What's actually frozen is the compact LINE SHAPE
  (`'<provider> <key> <pct> <resets_in>'`), not any specific key string.

## window-key consistency, `src/plugin.usage.kimi.handler.response`

Kimi's rows didn't carry a `window` field (only `label`, e.g. `'plan usage'`,
`'5 hour'`) while claude's rows always had one (`'5h'`/`'7d'`, hardcoded per
window in `plugin.usage.claude.handler.response`). User asked to make kimi's
short keys match claude's convention since they're the same real time
ranges. Two different strategies per row type:
- per-window limit rows: `$window_code` closure derives a short code from
  the api's own `duration`+`timeUnit` metadata (generic, not hardcoded) —
  handles whatever window kimi actually reports.
- the aggregate `'plan usage'` row: the api gives NO window metadata for
  it at all, so `window => '7d'` is hardcoded there, on the user's explicit
  confirmation that it's kimi's known 7-day plan cycle (its own
  `resets_in` reads much shorter than 7d in practice — that's a reset
  countdown mid-cycle, not the window's total duration, don't let that
  reading contradict the 7d label).

Claude's own row order was also flipped (`plugin.usage.claude.handler.response`,
the `foreach my $window (...)` list) from `5h,7d` to `7d,5h` to match kimi's
natural order (plan/weekly row first, then the shorter window).

## coding-zenka tool now uses the SAME format as the human commands

`coding.handler.refresh_account_usage` used to route-send `usage.status`
with `'compact'` args and `coding.handler.account_usage_reply` bucketed
the reply with a per-row regex (`^(\w+)\s+(.+)$`). Both now use the
default (pretty) format instead — `account_usage_reply` buckets by the
pretty format's own block header line (`^\s*\.:\s*(\S+)\s*:\.\s*$`)
instead of per-row regex, caching each provider's FULL block (header +
rows + footer) as one array, so `check_account_usage`'s tool output to
the local model is now identical to what `usage.claude`/`usage.kimi` show
a human. Verified live: single-provider refresh still merges correctly,
doesn't clobber the other provider's cached block.

**If you touch `usage.format.report`'s pretty header line shape again**,
`coding.handler.account_usage_reply`'s block regex depends on it exactly
— grep for `\.:\s*\(\S\+\)\s\*:\.` before changing that line's format.

## known cosmetic wart, not fixed, out of scope

`base.parser.duration`'s day-branch drops the hour unit for
multi-day-plus-hours durations: `1 day 01h 37'51"` → post-regex →
`'1d 01 37'51"'` (the `01` has no trailing `h`). Pre-existing behavior of
a shared function reused here, not introduced by this work — leave as-is
unless asked to fix `base.parser.duration` itself.

## reload gotcha reconfirmed here too

Every one of these edits needed `p7c v7-zenki.restart usage` (or
`restart coding`) to actually take effect — `reload source` reported
success but the live output stayed stale, repeatedly, across this whole
session. See [[feedback-reload-success-doesnt-guarantee-new-file-loaded]]
(now promoted to CRITICAL in MEMORY.md) — don't trust reload for this
zenka family, always restart-and-diff to verify.

#,,,.,.,,,...,,.,,...,,.,,.,.,,..,...,,..,.,.,..,,...,...,...,...,..,,...,..,,

#,,,,,.,.,.,.,,.,,.,,,,,.,,,,,,.,,,.,,..,,,.,,..,,...,...,...,,,,,,,,,,,.,,..,
#F5OARPAQSISXQVEF26YTQOQJH5XKTKJ3AAN4ZWEWFU7XJKQDJDAPBHVX3DUJNMCAP3P345XYSQHMA
#\\\|UIA4ZHND5N7JORK7EQQ5UBFRT4TDYVCIRCMZRV7X5G7VUOTFNEI \ / AMOS7 \ YOURUM ::
#\[7]332OGMX2ZJVDSJZHYN4RJDB55CWFMFRJHY3DCTJYLCCLPHZRIUDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
