---
name: session-65
description: "jobsite data recovery: Mojibake commits, 312 garbage files deleted, backup restore, permission fix, 294 repair_failed jobs reset, scan started"
metadata:
  type: project
  originSessionId: session-65
---

## what happened

### Mojibake fix committed (session 64 work landed)
Final root cause: `httpd.route.handler.web-relay` joined raw UTF-8 bytes with a
utf8-flagged string → implicit Latin-1 upgrade → base.s_write re-encoded as double-UTF-8.
Fix: `utf8::decode($body) if length($body) and not utf8::is_utf8($body)` before route-send.
Committed as 6a2d2dcc6. `utf8::downgrade` in plugin.web.jobs.sync removed (was no-op
once the upstream fix was in place). stage, %data key, cache.write/cache.read_all also fixed.

### 312 garbage files deleted
May 15/19 job files from 4B model with bad assessments (garbled score_reason + empty
descriptions from double-encoding). Deleted from /var/protocol-7/jobsite/jobs/.
Web cache orphans (312 files) also cleaned. scan-state.yaml stripped of its `tasks`
section (41783 → 4 lines) to remove stale task state. index.yaml rebuilt via
`p7c jobsite.exec-sub jobsite.index.rebuild`.

### repair-jobsite-encoding script caused damage
`bin/dev/repair-jobsite-encoding` (committed, 1916318) ran on jobsite files and
emptied `description`, `score_reason`, `score_summary` in 667 of 676 files.
Root cause not fully confirmed: `to_unicode()` returned wrong value for those fields.
Restored all 676 files from /data/backup/jobsite.0000.backup.tar.xz (extracted to
/tmp/jobsite/jobs/). Python raw byte copy (open wb + write) was used to avoid
shutil.copystat permission errors.

### permission fix: 127 files were mode 640 (taeki:taeki)
Python restore created files with inconsistent umask; 127 files ended up 640.
The protocol-7 zenka user can't read those. Fix: `chmod 644 /var/protocol-7/jobsite/jobs/*.yaml`
(9 protocol-7-owned 660 files were unchanged and remain readable).
After fix + jobsite restart: `jobsite.manual-sync` correctly returned 676 jobs.

### 294 repair_failed jobs reset to status=new
286 files (295 in backup) had `status: assessed, score: '', repair_failed: 5` — these
were jobs the assessment pipeline tried to repair (encoding) during a prior run, failed,
and marked assessed without writing a score. NOT caused by our changes — already in
this state in the backup. Reset with inline Perl script (not via jobsite.cmd.reset since
tasks hash was empty after scan-state.yaml strip). After reset: 370 assessed, 306 new.

### scan started
Coding zenka started (`p7c v7.start coding`; on-demand so would have auto-started anyway).
`p7c jobsite.scan` triggered — running, will take several hours, found many new jobs.

## new dev script
`bin/dev/merge-jobsite-from-backup` — merges backup scraped fields into current assessment
fields; arg parsing fixed (--dry-run filter). NOT committed. Superseded by raw restore
in this session but may still be useful.

## related
- [[session-64]] — encoding root cause
- [[plugin-web-jobs]] — sync pipeline state

#,,.,,...,.,.,,..,.,.,,,,,,..,,.,,,,,,,.,,..,,..,,...,...,,.,,,,,,,..,,.,,,.,,
#6MCIQKMG7RWDHXBK3WG6DWSEXNVVPJOWQVZJWR7HAWSSEHVYL6GKHY3OXLCWAUOYEBSMMPJR27QPI
#\\\|42ZRSYODG74ZOS65FSLBEXODCIDY4IYQZQUIDJPXWDIDAUOAG2O \ / AMOS7 \ YOURUM ::
#\[7]O7WPWEJDCQ2IYOMGHVIS3SJXO63XUWGHZO7Q3J6MMUC52ULUDOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
