---
name: feedback-list-hidden-row-collision
description: "base.hide_list hides LIST NAMES ('sessions', 'users' -- a zenka's own connection-session/authorized-user lists), but base.parser.list/list_filtered checked that hash per-ROW instead of per-list -- any list with a row literally named 'sessions' or 'users' (a zenka name, a username) silently lost that row. Fixed 2026-08-13, commit 575530e3c."
metadata:
  type: feedback
---

Found live while debugging why a brand-new `sessions` zenka (and the
pre-existing `users` zenka) silently didn't appear in `v7.list
available`, despite `<v7.zenki.available>` demonstrably containing both
(`v7.dump` confirmed well-formed data). Static tracing of the entire
render pipeline (`base.cmd.list` → `base.resolve_hash` →
`base.reverse-sort`/`base.context.list` → filter-matching →
`base.parser.align`) found nothing wrong — every function individually
checked out correct, including empirically re-verifying the regex
filter matched `"sessions"` fine. The bug was find-able only by
comparing `v7.dump available` (data present) against the actual
rendered table (`v7.list available`, unfiltered — both entries just...
absent) and asking what "sessions" and "users" have in common structurally,
not what's wrong with the zenka.

**Root cause**: `base.hide_list` (called only from `base.init_code:246,254`)
hides two LIST NAMES for every non-cube zenka — `'sessions'` (a zenka's
own active-connection-sessions list) and `'users'` (authorized-users
list) — both security-sensitive, hidden by default (confirmed:
`weather.base.fork_weather_child`/`letsencr.base.fork_letsencr_child`
explicitly re-enable `'sessions'` in a forked child). It works by
setting `$data{'lists_hidden'}{'sessions'} = 1` /
`{'users'} = 1`.

But `base.parser.list`/`base.parser.list_filtered` checked that SAME
hash **per-row**, inside the render loop (`next if exists
$data{'lists_hidden'}{$key_val}`), where `$key_val` is each row's own
key — a zenka name for `v7.list available`, a username for
`base.init_code:140`'s `list.users`. So a zenka or user literally named
`sessions`/`users` collides with the hidden LIST names and gets its row
silently dropped from ANY list keyed that way — nothing to do with the
entity being new/on-demand/recently-added. Confirmed also affected
`list.manual` (zenka-name-keyed).

**Bonus, found along the way**: the direct-access path (`list
sessions`, `list users` typed directly) had NO hide check at all — only
the bare `list` overview correctly hid them from enumeration (that one
legitimately uses row-key=list-name semantics, since its rows genuinely
are list names). A real security gap, not just the display bug.

**Fix** (`base.cmd.list`, `base.parser.list`, `base.parser.list_filtered`,
commit `575530e3c`): removed the buggy per-row check from both parser
functions entirely (no replacement needed — hiding is a property of
*which list* is rendered, not of a row's key). Added the real gate in
`base.cmd.list`, at the point a named list is resolved: `and not exists
$data{'lists_hidden'}{$list_name}` alongside the existing
`defined $data{'list'}->{$list_name}` check — covers both the unfiltered
and filtered named-list render branches with one edit, and a failed
gate falls through to the existing "no such list" message (no new
message needed, doesn't leak that a hidden list exists).

**How to apply**: if a future `list.*` entry (or any new zenka/username)
mysteriously vanishes from a list's rendered output despite `v7.dump`
(or the equivalent raw-data dump) showing it present and well-formed,
check whether its name collides with anything ever passed to
`base.hide_list`/`base.enable_list` (currently just `'sessions'` and
`'users'`, grep `<[base.hide_list]>` for the current authoritative set)
before assuming a rendering/filter/sort bug — the collision is between
two *different kinds of "name"* (list names vs. row keys) that happen to
share a hash, not a defect in any individual list's own logic.

[[project-users-zenka-unblocks-cross-host-testing]]

#,,..,,.,.,.,,,,,,.,.,.,,,,..,,,.,.,,,,,.,,,,,..,,...,...,...,,.,,,,.,,,,,.,.,

#,,..,,,.,,,.,.,,,..,,,,.,..,,,..,..,,.,,,,,.,..,,...,...,,,,,,,,,,..,...,,.,,
#JXNC7UJR66E3VVMGPDKGU3TYMQEP4UEZDDTGC2KXX2Z6NUE6VTC65PTNBMKNZ4JU5UF4OAPEOOC2I
#\\\|QWZYBKMISTHYVSCMV7XQH223TH7VCRESJH7NOFDEQ5BZ2Y7G7BY \ / AMOS7 \ YOURUM ::
#\[7]E57XVSQ4YSZII4SBQBOAOLJTJKNT7KNJIDBVFKLTDUJMMRMGHCCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
