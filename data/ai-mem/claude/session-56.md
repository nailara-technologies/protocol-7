---
name: session-56
description: "Session 56 — index terminal, schema v3 cube storage, chunked persist, v7 restart fix, FastText/pluggable model design"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4ffce75b-8148-4209-bf51-e550e77dd5ce
---

## Session 56 (2026-05-26) — index terminal + schema v3 cube + v7 restart fix

**`<index.terminal>` boundary tracking** — implemented across 6 modules: `index.deduplicate` (ring-0 loop + boundary check at space/EOS), `index.rank` (terminal lookup replaces hardcoded `1`), `index.init_code`, `index.persist`, `index.restore`, `index.cmd.search` (shows `[ exact, terminal ]` vs `[ exact ]`); kimi session 288b78fa

**corpus versioning task files** — 4 task files created:
- `data/tasks/index-terminal-boundary-tracking.md` — done (implemented this session)
- `data/tasks/index-contribution-vector-store.md` — `<index.contributions>` keyed by checksum
- `data/tasks/index-source-map-active-set.md` — `<index.sources>` + `<index.active_checksums>` + per-chain policy
- `data/tasks/index-cmd-replace-remove.md` — `index.cmd.replace` + `index.cmd.remove`

**INDEX-CORPUS-VERSIONING.md additions** — removal as first-class operation (`deactivate HEAD + remove source_id`); definition-agnostic note (same primitive for chars/bytes/tokens/checksums/base32); references as index-transparent sequences (`:<sum1>:<sum2>` as plain strings, separate index instance)

**job control multiplexing task** — `data/tasks/index-job-control-multiplexing.md`; per-job state machines nested under `<index.jobs>->{$job_id}` (same isolation as `$data{'session'}{$sid}`); unified `index.callback.tick` dispatcher; chunked file processing with carry buffer (7 chars = max_window-1); `index.cmd.stop-job` already works generically; `<index.cfg.rebalance_deferred>` global flag → per-job `cfg.rebalance_deferred`

**corpus re-feed** — data/md/ + data/yaml/ re-fed with terminal tracking; 11,826,892 chars; rank took ~15min; index.rank + index.persist now have before/after base.log calls

**FastText design docs** — two new docs:
- `data/md/design/INDEX-PLUGGABLE-MODEL-FRAMEWORK.md` — three-axis parameterization (model type / storage type / token definition); contribution vectors as universal intermediate (Layer 1); instance registry; transfer routines; non-destructive experimentation
- `data/md/design/INDEX-FASTTEXT-SOURCECODE-EMBEDDINGS.md` — FastText bridge; token definitions (namespace/content/checksum/reference); adapter loading path; corpus perspectives taxonomy (structural/relational/temporal/cognitive/discourse); trie-as-subconsciousness; dedup feeding history → one-command reproducibility; chat channels as discourse corpus; 3D grid connection

**key insights**:
- removal is definition-agnostic: works for chars/bytes/diff-chunks/checksums, any chain topology
- references (`:<sum1>:<sum2>`) are index-transparent: fed as plain strings, index never parses the `:` prefix
- FastText is definition-agnostic too: same pipeline for natural language, namespace tokens, checksum N-grams, reference pairs
- trie IS the subconsciousness: feed raw deduplicated trie with metadata to a model; it maps internally to strong associative references without explicit retrieval
- chat channels as corpus: models embed the grammar of this network's collaboration style, spontaneous reply behavior without explicit workflow step

**logging fix** — `index.rank`: logs `start [N ring-0 tokens]` and `complete`; `index.persist`: logs `compressing [N chars]` before XZ; timestamps free via `base.log`

**startup / verification timeout fix** — `index.restore` was calling `<[index.rank]>` synchronously; rank blocks event loop for minutes on 11.8M corpus; two-stage fix: (1) removed rank from restore, set `dirty=TRUE`; (2) tried 0.2s deferred timer in init_code — fired AFTER cube connection but BEFORE verification completed, blocked event loop, verification timed out; (3) final fix: removed timer entirely; added lazy rank at top of `index.cmd.search` + `index.cmd.lookup`:
```perl
## lazy rank rebuild after restore ##
<[index.rank]> if <index.meta>->{'dirty'} // 0;
```

**`]>->()` obsolete syntax removal** — user ran `ncode -ai-friendly -confirm r src:^index. '\]>->\(\)' ']>'`; all index modules cleaned; startup + verification timeout fully resolved; committed as `fix: index lazy rank on first query`

---

## Session 56 continued — schema v3 cube storage + v7 restart fix

**schema v3 .zxpc cube format** — binary format: 256-byte header (magic `P7IC`, schema_version, ring_count[], dir_base[], dir_stride[], data_base, total_size, 8-byte AMOS header checksum, zero-padded to 256) + per-ring directory (24-byte entries: `'Q N n n a8'` = offset/disk_size/child_count/flags/chksum7) + compartment data (9-byte frame `\x00 + len_byte + 7-byte chksum` + payload `'C N a8 n'` + child entries `'N N'`×N); tamper-evidence chain: depth-0 parent_chksum7 = header checksum, depth-D = parent compartment checksum

**key naming**: `<[chk-sum.amos]>` NOT `<[base.chk-sum.amos]>` — `base.swap_subs` moves the key after init; using base. prefix causes "undefined subroutine reference" at runtime

**cube modules**: `index.persist.cube` (writer), `index.restore.cube` (reader with P7IC validation + eager load rings 0-1 + fallback to .zxps), `index.cube.format` (constants), `index.cube.load_compartment`, `index.cube.get_compartment`, `index.activate`, `index.deactivate`, `index.source.register`

**cube persist performance** — 2.3M compartments × AMOS checksum = blocking; one-ring-per-tick still too slow (ring 7 = 569K entries, pegged CPU at 99.7% for 3+ minutes); chunked to 2000 compartments per tick via `index.tick.persist-cube` job + `ring_offset` state; still needs performance profiling — even at 2000/tick may take many minutes total; future: profile AMOS checksum cost, consider skipping per-compartment checksums or batching larger

**chunked persist job pattern** — `index.persist` enqueues `<index.jobs>->{'persist-cube'} //= { 'job-type' => 'persist-cube' }` (fixed key prevents double-enqueue); `index.tick.persist-cube` 3 phases: (1) init: precompute layout + header, store state; (2) per-batch: 2000 compartments, ring_offset advances, ring complete → current_depth++; (3) finalize: assemble header+dir+comp strings, write file; accumulates to scalar strings (not arrays) for O(1) finalize join

**v7 restart race fix** — race: SIGCHLD fires first → `init_restart_timer` sets 0.05s timer; then STDIO close fires → second `v7.zenka.instance.restart` call cancels timer, re-adds dead PID to restart_pids → permanently stuck; two guards added to `v7.zenka.instance.restart`: (1) return early if timer active AND all processes dead (`v7.instance_pid_count == 0`); (2) call `init_restart_timer` directly if process already dead after `terminate_process`

**sig_chld_ignore_pid wiring fix** — three disconnected key paths: restart used instance-local `$instance->{'sig_chld_ignore_pid'}`, handler checked top-level `<v7.sig_chld.ignore_child_pid.{pid}>`, base handler used `<sig.chld.ignore.pid>`; fixed: restart now sets top-level `<v7.sig_chld.ignore_child_pid>->{$parent_pid}`; handler `next` only skips non-registered PIDs (registered zenka children fall through to process_zenka_end)

#,,,,,,..,..,,,.,,,.,,...,,,.,,,.,...,..,,.,,,.,.,...,..,,,..,,.,,,..,...,.,,,
#KHNYWDEV7VMATJHO3TECEGGZLY2Q452KSSCQEH74ANDOMQGO6XAXWIPUXXXZPHR6C7LV4HLSVBH3U
#\\\|PI2ZT4ZNHK3OVCWSZEMAYDCDVCNKNVH3ELW5IQV7VGZM73GBQYD \ / AMOS7 \ YOURUM ::
#\[7]LSVXQHOIU6PLXA74R65RQRMGGDWRLAB5CRARG65QYAEPKQYCVOCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
