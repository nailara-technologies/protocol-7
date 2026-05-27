---
name: session-57
description: "schema v4 cube persist complete, idle watcher + ondemand timeout fixes, prev_chk packing perf, graphical storage design"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4ffce75b-8148-4209-bf51-e550e77dd5ce
---

Session 57 (2026-05-27) — index schema v4 cube, performance fixes, graphical storage design

**schema v4 cube** — JHash uint32 checksums replace AMOS 7-char, 20k batch size, array-of-buffers accumulation, prev_chk_packed (pack 'N*') replaces arrayref. First complete v4 cube written: 102MB, 8 rings, 2.3M compartments.

**timing with prev_chk_packed** (packed binary vs Perl scalar arrayref):
- ring 3: 23m53s → 13m48s
- ring 4: 57m15s → 30m29s
- rings 5-7 still slow (46m, 61m, 39m) — remaining bottleneck is `<index.addr>` and `<index.level>->{$D+1}` hash lookups; lifting `my $level_ref = <index.level>->{$D+1}` outside inner loop is next fix

**idle watcher pattern** — `index.tick.start` cancels `<base.timer.ondemand_timeout>` when enqueuing jobs; `index.callback.tick` cancels idle watcher and restarts ondemand_timeout when queue empties. Prevents idle shutdown mid-job.

**deferred restore** — `push @{ <system.callbacks.initialized> //= [] }, 'index.restore.cube'` fires after verification via `base.cmd.verify-instance`. See [[feedback-deferred-init]].

**index.persist rank guard** — calls `<[index.rank]>` if `dirty` before capturing state; ensures trie populated when restoring from pre-trie backup.

**new modules** — `index.cmd.replace`, `index.cmd.remove`, `index.tick.start`

**design doc** — `data/md/design/GRAPHICAL-STORAGE-AND-PROCESSING.md` : ring-trie as polar disk, ray-from-center = trie traversal, APNG as append-only contribution stream, XCF layers as corpus contributions, assertions as constant-time image ops (radial band, arc segment, alpha mask). Thermocam magic-byte coincidence noted.

#,,,,,.,,,...,,,,,.,,,..,,,,.,,,.,,..,,..,,,.,..,,...,...,..,,...,.,.,,..,.,.,
#YV4UDI4YVKSBGNFIMKHMKJOTU6JSGUHLM74UKF4GFT2WL3RIQRKWG22ALVEAOREOVTPVYMPM52XQC
#\\\|PD7RYUMXCWJ6WEH352F33JGVSK7EFRXY5AR66IXJNTUEAAXY32A \ / AMOS7 \ YOURUM ::
#\[7]SFIZSAMMN36XWVR7HHKARIMELXS2CK3TJWB227EGCOIZ2D2KXWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
