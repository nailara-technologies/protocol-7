## task: migrate stepstone job IDs from decimal to VAX-encoded form

### motivation

Stepstone job IDs are currently stored and used in their raw decimal form
(e.g. `11867113`). The project already has a compact, URL-safe encoding for
32-bit integers via `bin/vax-int` (e.g. `11867113` → `5EJ3K`).

Using the encoded form for filenames and in-memory keys:

- shortens paths and log lines
- makes it obvious at a glance which identifiers are stepstone-derived
- avoids the visual ambiguity of long numeric strings
- aligns with the project's existing use of VAX/BASE32 identifiers elsewhere

This task plans the migration. A helper script and the actual code changes
are left for follow-up work.

---

### scope

#### in scope

- numeric Stepstone job IDs used as filenames, in-memory keys, and YAML `id` fields
- all jobsite directories under `/var/protocol-7/jobsite/jobs/`
- web cache directories under `/var/protocol-7/web/jobs/`
- site-yaml's own staging directory under `/var/protocol-7/site-yaml/jobs/`
- `/var/protocol-7/jobsite/index.yaml`
- `/var/protocol-7/site-yaml/fetch-state.yaml`
- code that parses Stepstone URLs, builds paths, or derives IDs from filenames

#### out of scope / preserved as-is

- non-numeric IDs such as `import-<hex>.yaml` from CSV import
  (they keep their opaque string form)
- the URL checksum store under `/var/protocol-7/jobsite/checksum-store/`
  (it stores checksums, not job IDs)
- the stray-job transfer IDs in `site-yaml.job.scan_stray`
  (those are AMOS checksums over `size:ntime`, not job IDs)
- task IDs from the coding zenka (those are unrelated)

---

### encoding contract

- encode: `bin/vax-int 11867113` → `5EJ3K`
- decode: `bin/vax-int 5EJ3K` → `11867113`
- implementation: `Crypt::Misc::encode_b32r(pack 'V', $num)` /
  `unpack('V', Crypt::Misc::decode_b32r($str))`

A new helper pair should be added so consumers do not shell out:

- `src/base.vax-int.encode` — encode a numeric ID, pass non-numeric through
- `src/base.vax-int.decode` — decode a VAX string back to numeric,
  pass non-numeric through

Both helpers must be idempotent and preserve non-numeric IDs unchanged.

---

### pre-migration decisions

1. **In-memory key format.** Decide whether hash keys like `<jobsite.tasks>`,
   `<jobsite.job.index>`, `<data{'jobs'}{'store'}>`, and the web cache indexes
   keep the numeric form or switch to encoded form.

   Recommendation: keep in-memory keys numeric for now and encode only at the
   storage boundary (filename, YAML `id`, sync JSON, index.yaml). This limits
   the code churn and keeps arithmetic/comparison on IDs trivial. The web UI
   can receive encoded IDs in JSON if desired.

2. **YAML `id` field.** Decide whether job records store the encoded or numeric
   `id`. Storing the encoded ID makes the file self-describing; storing the
   numeric ID preserves backward compatibility for external readers.

   Recommendation: store the encoded ID in the YAML file to match the filename.

3. **Sync JSON contract.** `/jobs.json` and `/jobs-sync` currently carry numeric
   `id`. Decide whether to encode those as well.

   Recommendation: encode IDs in sync JSON and web responses so the public
   surface is consistent with filenames.

4. **URL parsing.** Stepstone URLs contain the numeric ID. The parser must
   continue to extract the numeric ID and then encode it before storage.

---

### migration steps (execution order)

1. **Add helper modules.**
   - `src/base.vax-int.encode`
   - `src/base.vax-int.decode`
   - register both in relevant subroutine white-lists (jobsite, site-yaml, web)

2. **Stop writers.** Ensure no site-yaml fetch, jobsite assessment, or web sync
   is running during the migration. The safest path is to stop the jobsite,
   site-yaml, and httpd/web zenki.

3. **Rename on-disk files.**
   - `/var/protocol-7/jobsite/jobs/<status>/<id>.yaml` → `<status>/<encoded>.yaml`
   - `/var/protocol-7/jobsite/jobs/blocked/<epoch>/<id>.yaml` → `<epoch>/<encoded>.yaml`
   - `/var/protocol-7/jobsite/jobs/deleted/<epoch>/<id>.yaml` → `<epoch>/<encoded>.yaml`
   - `/var/protocol-7/web/jobs/...` mirror the same renames
   - `/var/protocol-7/site-yaml/jobs/...` mirror the same renames

   Non-numeric IDs (`import-<hex>.yaml`) must be skipped.

4. **Rewrite `index.yaml`.**
   - Load `/var/protocol-7/jobsite/index.yaml`
   - Encode numeric keys, preserve non-numeric keys
   - Write atomically to `index.yaml.tmp` then rename

5. **Rewrite `fetch-state.yaml`.**
   - Encode numeric `id` fields in the fetch queue
   - Preserve non-numeric fields

6. **Update code modules** (see list below).

7. **Rebuild in-memory indexes.** On next start, `jobsite.job.index.build` and
   `plugin.web.jobs.cache.read_all` will rebuild from the new filenames.

8. **Restart zenki and verify.**

---

### code modules to update

#### core storage

- `src/jobsite.job.write`
  - encode `$job_id` when building filename
  - store encoded `id` in the YAML record
  - update `<jobsite.job.index>` key (numeric or encoded per decision)

- `src/jobsite.job.read`
  - if index key is numeric, encode when building path
  - decode ID from filename only if needed

- `src/jobsite.job.load_all`
  - decode filename stem to numeric for in-memory store, or use encoded per decision

- `src/jobsite.job.index.build`
  - same as load_all

- `src/jobsite.index.rebuild`
  - rebuild `index.yaml` with encoded keys

#### jobsite handlers / commands

- `src/jobsite.init_code`
  - flat-layout migration fallback deriving ID from filename must handle both forms

- `src/jobsite.dispatch.assessments`
  - encode `job_id` in queue entries if sync/JSON uses encoded form

- `src/jobsite.dispatch.next`
  - decode before `task.create` if task needs numeric ID

- `src/jobsite.handler.assess-done`
- `src/jobsite.handler.repair-done`
- `src/jobsite.handler.task-created`
- `src/jobsite.handler.repair-created`
- `src/jobsite.handler.translate-done`
- `src/jobsite.handler.rewire-all`
- `src/jobsite.handler.rewire-assess`
- `src/jobsite.cmd.approve`
- `src/jobsite.cmd.reject`
- `src/jobsite.cmd.list-jobs`
- `src/jobsite.cmd.status`
- `src/jobsite.cmd.progress`
- `src/jobsite.cmd.show-prompt`
- `src/jobsite.cmd.group-jobs`
- `src/jobsite.stage.review`
- `src/jobsite.assert.init`
  - adapt to the chosen in-memory key format

- `src/jobsite.cmd.reset`
  - replace hard-coded `m{^(\d+)\.yaml$}` with a regex that accepts VAX strings
    or use the helper to decode any filename stem

- `src/jobsite.sync.push`
- `src/jobsite.sync.push_chunk`
- `src/jobsite.sync.apply_reverse`
  - encode IDs in outbound JSON; decode inbound IDs before resolving paths

- `src/jobsite.handler.stray-jobs-listed`
- `src/jobsite.stray.claim_next`
- `src/jobsite.handler.stray-job-exported`
  - transfer IDs stay checksums; filename stems from site-yaml must be decoded
    if they arrive encoded, or encoded if they arrive numeric

#### site-yaml

- `src/site-yaml.stepstone.search`
- `src/site-yaml.stepstone.job`
  - continue extracting numeric ID from Stepstone URL
  - encode it before passing to `site-yaml.jobs.upsert` or storing in queue

- `src/site-yaml.cmd.import`
- `src/site-yaml.handler.fetch_tick`
- `src/site-yaml.fetch.state`
  - encode numeric IDs in fetch queue and known-job store

- `src/site-yaml.jobs.upsert`
- `src/site-yaml.jobs.save`
- `src/site-yaml.jobs.init_code`
- `src/site-yaml.cmd.set-status`
- `src/site-yaml.cmd.list-jobs`
- `src/site-yaml.init_code`
  - use encoded IDs consistently

- `src/site-yaml.job.scan_stray`
- `src/site-yaml.cmd.export-stray-job`
- `src/site-yaml.cmd.confirm-stray-claimed`
  - filename stems are now encoded IDs

#### web cache

- `src/plugin.web.jobs.cache.write`
  - encode ID when building filename

- `src/plugin.web.jobs.cache.read_all`
  - decode filename stem when populating in-memory cache

- `src/plugin.web.jobs.data`
- `src/plugin.web.jobs.list`
- `src/plugin.web.jobs.sync`
- `src/plugin.web.jobs.sync.merge`
- `src/plugin.web.jobs.state.save`
- `src/plugin.web.jobs.reverse.queue`
- `src/plugin.web.jobs.reverse.flush`
- `src/plugin.web.jobs.store.prune`
- `src/plugin.web.jobs.stats`
  - adapt to chosen key format; encode IDs sent to browser

#### web relay

- `src/web.cmd.jobs-data`
- `src/web.cmd.jobs-sync`
  - no direct ID logic, but verify JSON contract

#### dev / admin scripts

- `bin/import-jobs.pl`
- `bin/dev/merge-jobsite-from-backup`
- `bin/dev/repair-jobsite-encoding`
  - replace `m{^\d+\.yaml$}` and numeric-only extraction with VAX-aware helpers

---

### helper script: `bin/vax-int-rename`

A reusable rename utility that behaves like `bin/rename.bmw` but only acts on
files whose basename is a pure decimal number, converting it to the VAX-encoded
form and preserving the extension.

Already implemented at `bin/vax-int-rename`. Usage:

```
bin/vax-int-rename [file|directory] [file|directory] ...
```

It reports each rename, each skip (non-numeric basename), and any errors such
as target collisions. Exit code is `1` if any error occurred.

### helper script: `bin/dev/migrate-jobsite-ids-to-vax`

A standalone Perl script to perform the full on-disk migration and index
rewrite. It should call `bin/vax-int-rename` for the actual renaming.

Suggested behavior:

1. Take `-source-root` (default `/var/protocol-7/jobsite`), `-web-root`,
   `-site-yaml-root` as arguments.
2. Walk `jobs/<status>/`, `jobs/blocked/<epoch>/`, `jobs/deleted/<epoch>/`.
3. For each directory found, invoke `bin/vax-int-rename <dir>`.
4. Rewrite `index.yaml` keys using the same encode/skip rules.
5. Rewrite `site-yaml/fetch-state.yaml` queue IDs.
6. Print summary: renamed, skipped, errors.
7. Dry-run mode (`-dry-run`) is mandatory for first use.

The script must refuse to run if any of the expected zenki are still online
(or require `-force` with big warnings).

---

### post-migration verification

1. Count files before and after; expect same count plus/minus non-numeric skips.
2. Verify a sample decode round-trip for renamed files.
3. Start jobsite and confirm `jobsite.job.index.build` loads without errors.
4. Start site-yaml and run a small import; verify new jobs land under encoded IDs.
5. Start web zenka and confirm `/jobs.json` returns encoded IDs.
6. Trigger an assessment and verify status transitions rename files correctly.
7. Trigger a web sync and verify reverse updates resolve correctly.
8. Run `jobsite.scan` and confirm stray recovery still works with encoded stems.

---

### risks and mitigations

| risk | mitigation |
|---|---|
| collision if two numeric IDs encode to same VAX string | mathematically impossible for 32-bit integers; the script aborts on any filesystem collision anyway |
| non-numeric IDs mis-identified | helper passes them through unchanged; migration script skips non-`/^\d+$/` stems |
| running writers during migration | stop jobsite/site-yaml/web first; script checks for online writers or requires `-force` |
| sync JSON consumers expect numeric IDs | encode on the boundary; update web UI if it parses IDs numerically |
| in-memory key inconsistency | pick one strategy (recommend numeric keys internally) and document it |
| partial migration failure | dry-run first; keep a backup of `index.yaml` and the jobs dirs before rename |

---

### open questions / later additions

- Should the web UI display encoded IDs to users or decode them for display?
- Should the jobsite CLI accept either form from the user?
- Do any external consumers (backups, reports, mail templates) reference numeric IDs?
- Should the migration also rewrite historical `store.yaml` if it still exists?

#,,.,,,.,,,..,,.,,...,..,,..,,..,,..,,...,...,..,,...,...,.,.,.,.,..,,,..,,,,,
#Y5Y23STZOL5YDBIWAYYTTFH3HLGSYVNNSMGDYTKX6O5XJDNMO65OZALSU2WS3M2RHR2EB774SQLC4
#\\\|T7TNRTIWZVSYWHOGR3J543XNQ7DDCXAHRTLWGUM54ZBRCX2OLHT \ / AMOS7 \ YOURUM ::
#\[7]FSZD3HKTWTQSDIGBWT7JDQRJMZCC6DEAFLJRIZCGDYN6SKFM76DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
