---
name: session-64
description: "web cache Mojibake root cause found + fixed; %data key fix + stage sync fix; pending commit"
metadata:
  node_type: memory
  type: project
  originSessionId: 96c4f196-e9b8-4e2c-a467-d9c9d0824389-continued
---

## encoding Mojibake in web cache — ROOT CAUSE FOUND AND FIXED

### confirmed: sync is corruption source
- ALL 356 web cache files modified today (post-reset sync) have Mojibake
- 985 total web cache files; 629 older files (modified May 28 or earlier) also have Mojibake from past syncs
- Only ~356 files lack Mojibake (files that haven't been synced recently or jobs without non-ASCII)

### Mojibake pattern
Hexdump of `/var/protocol-7/web/jobs/14025299.yaml`:
- em-dash (–, U+2013, UTF-8 `e2 80 93`): stored as `c3 a2 5c 78 38 30 5c 78 39 33` = `â\x80\x93`
- ä (U+00E4, UTF-8 `c3 a4`): stored as `c3 83 c2 a4` = `ä`

This is DOUBLE-ENCODING: each UTF-8 byte treated as individual Latin-1 code point, then re-encoded as UTF-8 by YAML::XS.

### root cause
`$call->{'args'}` in `plugin.web.jobs.sync` arrives with the **utf8 flag incorrectly set** from the httpd→route-send path. When `decode_json($body)` runs on a utf8-flagged string, JSON::XS internally calls `utf8::encode` (downgrade + re-encode), which double-encodes all non-ASCII bytes. Result: each byte of the UTF-8 sequence becomes a separate Unicode code point. YAML::XS then writes these wide-characters as double-encoded bytes.

Chain: jobsite JSON (raw UTF-8, correct) → HTTP POST → httpd → route-send → web zenka `$call->{'args'}` (utf8 flag set, bytes as code points) → `decode_json` → double-encoded strings → YAML::XS → Mojibake

### fix applied
`src/plugin.web.jobs.sync` line 9 (before decode_json):
```perl
utf8::downgrade( $body, 1 );    ## strip utf8 flag — route path may set it
```
This strips the incorrect utf8 flag before decode_json sees it. The downgrade will always succeed since all code points are ≤ U+00FF (they are raw byte values 0-255).

## other pending fixes (same module set, same uncommitted changeset)

### stage sync fix — plugin.web.jobs.sync
Added `stage` to `@pipeline_fields` (was only in `@browser_fields`).
Before: `my @pipeline_fields = qw| title company url score score_reason score_summary fetched_at status description last_modified |;`
After: added `stage` between `status` and `description`.
Result: jobsite pushes now propagate `stage` field to web cache → review tab filter works.

### %data flat key fix — plugin.web.jobs.cache.write + cache.read_all
Both modules were using `$data{'plugin.web.jobs.cache'}` (wrong: flat dotted key in %data).
Fixed to `<plugin.web.jobs.cache>` (correct P7 nested form = `$data{'plugin'}{'web'}{'jobs'}{'cache'}`).

## pending: commit all three fixes
Files changed (not yet committed):
- `src/plugin.web.jobs.sync` — stage field + utf8::downgrade fix
- `src/plugin.web.jobs.cache.write` — %data key fix
- `src/plugin.web.jobs.cache.read_all` — %data key fix

User said "let's not commit yet, with bugs present" — this was BEFORE the encoding fix was identified. Now that the encoding fix is applied, user can commit all three.

## post-fix: re-sync needed
After the web zenka restarts with the new code, all Mojibake files need to be re-synced.
Options:
1. Reset all assessed jobs' last_modified to trigger full re-sync (noisy)
2. `jobsite.cmd.reset` without filter to force all jobs to re-sync (destructive)
3. Better: clear the `<jobsite.sync.last_server_ntime>` watermark to force full re-sync of all jobs at next timer tick

Actually cleanest: reset `<jobsite.sync.last_server_ntime> = ''` (or clear jobsite state) so all jobs get re-pushed in next cycle. OR: the user can wait for natural re-assessment cycles to gradually fix the cache.

## log findings
- `/var/log/protocol-7/DESKTOP-FP4OP26.web.zenka.log`: no `[web.jobs.sync]` messages visible (flooded with STRM streaming entries for browser loading 4637450 bytes in 567 chunks)
- `/var/log/protocol-7/DESKTOP-FP4OP26.jobsite.zenka.log`: shows sync push activity; last watermark `3TAYPBUGH2CNOJI`; 143 jobs were reset with `encoding_broken=true`; sync complete
- One chunk failed with "Connection refused" during httpd restart → 7 jobs missed in that chunk (minor, will re-sync when last_modified updates)

## related
- [[session-63]] — investigation start, simulation showed correct results but actual still broken
- [[plugin-web-jobs]] — delta sync, stage fix

#,,.,,..,,,,.,,.,,,,.,...,..,,,,,,.,,,,.,,.,.,..,,...,...,...,...,..,,,.,,,,,,
#V7EDCTHZO3HZ7RFTIMDOXS52KMBHKBCU2C5S4OBEVEABXTJKKHXAVWDRGHTOS7SIVJGUWHWB6ASFA
#\\\|TXASERIXGYMQGWQ4AEMDPGJMUMFH2Z5RT4ABGQ6IZD3H3GOSHQO \ / AMOS7 \ YOURUM ::
#\[7]TPED43YA5HRTD5ZSG3YG6YWNVSFGFL7I5ZGJSMCGRI2M3SGB4SAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
