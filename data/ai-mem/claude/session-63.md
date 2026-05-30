---
name: session-63
description: "STRM had_local_consumer fix, review tab stage sync bug, web cache %data key fix, encoding investigation"
metadata:
  node_type: memory
  type: project
  originSessionId: 96c4f196-e9b8-4e2c-a467-d9c9d0824389
---

## STRM fixes — CONFIRMED WORKING

### had_local_consumer fix
`base.handler.command` STRM close receive path: capture `$had_local_consumer = exists <base.strm.local>->{$cmd_id}` BEFORE deleting the local consumer. Use this flag to decide whether to forward close to source. Without this, `not exists ...` was always TRUE after deletion → stray STRM-reply at cube. Fix WORKING — log is clean.

### session-62 strm_open bugs
All three bugs from session-62 confirmed fixed:
- `$lc->{'content_type'}` undef → use closure var `$content_type` instead
- buffer empty edge case: set `shutdown=TRUE` directly in on_eof if buffer already empty
- log byte count: use `$lc->{'bytes'} // 0` not buffer length

### confirmed working
jobs appear in browser; web STRM streams 4637450 bytes clean; httpd disconnects clean.

## review tab bug — FIXED

**root cause**: `stage` not in `@pipeline_fields` in `plugin.web.jobs.sync`.
When jobsite pushes assessed jobs (stage='review'), the sync handler only copies
`@pipeline_fields` — `stage` was only in `@browser_fields` (not copied from jobsite push).
Result: web cache always has `stage: ''`, JS filter `j.stage === 'review'` → 0 matches.

**fix**: added `stage` to `@pipeline_fields` in `plugin.web.jobs.sync` line 18.
`@browser_fields` keeps `stage` too — browser can still set it independently.

Confirmed: 76 jobsite jobs have `stage: review`, 0 web cache jobs did before fix.

## web cache %data access — style bug (consistent, works)

`plugin.web.jobs.cache.write` and `plugin.web.jobs.cache.read_all` both use:
```perl
$data{'plugin.web.jobs.cache'}  ## WRONG: flat dotted key
```
Correct P7 form: `<plugin.web.jobs.cache>` which expands to `$data{'plugin'}{'web'}{'jobs'}{'cache'}` (nested).

Both modules are CONSISTENT with each other, so the cache works. But data is stored
at wrong address in %data. Fix: change both modules to use `<plugin.web.jobs.cache>`.
`<key.path>` without square brackets = `$data{'key'}{'path'}` (nested, via base.parser.data_hkey_tree).

## web cache encoding issue — source unclear

Web cache YAMLs have Mojibake for em-dash: `â\x80\x93` instead of `–`.
Jobsite YAMLs have correct encoding (U+2013 with utf8 flag).
Both have same `last_modified` → sync ran today. But web cache still has Mojibake.

Root cause analysis:
- YAML::XS::DumpFile on raw bytes (no utf8 flag) → Mojibake
- YAML::XS::DumpFile on utf8-flagged string → correct
- `decode_json(raw_bytes)` → utf8-flagged U+2013 (correct)
- Full simulation (YAML load → encode_json → decode_json → DumpFile) → CORRECT output
- But actual web cache files have Mojibake
- `bin/Protocol-7` has `use utf8;` at line 3 — may affect how string flags interact in module eval context

Open question: WHY does the actual sync write Mojibake when simulation is correct?
Possible causes: description field not being updated (exists check fails?); P7 routing modifies encoding; `use utf8` in main process changes regex capture behavior.

## YAML::XS critical note

YAML::XS::DumpFile behavior:
- string WITH utf8 flag → writes UTF-8 characters correctly (e.g., `–`)
- string WITHOUT utf8 flag (raw bytes) → writes bytes as-is with YAML escapes → Mojibake for multibyte UTF-8

Always ensure text strings have utf8 flag before YAML::XS::DumpFile.

## /var/protocol-7/jobs directory

`/var/protocol-7/jobs/` is empty leftover from `job-site-scan → jobsite` rename (May 2026).
Active paths: `/var/protocol-7/jobsite/jobs/` (jobsite storage) and `/var/protocol-7/web/jobs/` (web zenka cache).

## related

- [[session-62]] — STRM refactor history
- [[plugin-web-jobs]] — updated state (stage sync fix)
- [[topic-stream-reply-modes]] — reply mode design

#,,,,,,..,.,.,,..,.,.,,..,,,,,...,.,.,..,,,,,,..,,...,...,,,.,...,.,.,..,,,,.,
#LG4VOCU5CJELH2JJY3UJXGQK4NA57YKP4C6LLNHXOHX5CYYLNEWBZXPKRVEUL2BYWQ4GZT7P46E3E
#\\\|44B5RH7AKTX4IOSQWPUDCY5Z74GVCG3OICEJU7N23MDKPJAEMX5 \ / AMOS7 \ YOURUM ::
#\[7]67XHTRK4MMPW2PPTQN3DBKXG57KCFH2JNIGIES7ECB66LIBFMODY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
