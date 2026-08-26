## plugin.web.jobs — rewrite init_code + state.load, write missing modules

### context

the `plugin.web.jobs.*` namespace exists but several modules are broken or
missing. the existing `init_code` and `state.load` were written by a local
LLM that hallucinated a "pipeline state manager" unrelated to the actual design.
they must be fully replaced.

**signatures note**: do NOT add, modify, or investigate AMOS7 signatures at
the end of module files. leave existing signature blocks unchanged. new files
get no signatures — the signing system adds them automatically.

**descr line max 55 chars**: the `# descr =` line in each module header must
not exceed 55 characters or the pre-commit hook rejects the file.

### storage layout (already in place from jobsite zenka)

    /var/protocol-7/jobsite/jobs/<id>.yaml   — one file per job record
    /var/protocol-7/jobsite/index.yaml       — lightweight index

jobs are read via `<[jobsite.job.load_all]>` (returns hashref keyed by job id).
jobs are written via `<[jobsite.job.write]>->( $id, $job_hashref )`.
the web plugin does NOT maintain its own storage — it reads/writes through the
jobsite zenka's existing modules.

### domain split (two authoritative owners)

jobsite zenka owns (written by assessment pipeline, read by browser):
    score, score_reason, score_summary, fetched_at

browser owns (written by browser via POST sync, read by pipeline):
    stage, notes, date_applied

conflict resolution: latest ntime timestamp wins per field.
neither side overwrites the other's domain.

### what to do

**1. rewrite `src/plugin.web.jobs.init_code`** (replace entirely)

the correct init_code should:
- register template command aliases for use in .tmpl files:
    web.jobs.list  → plugin.web.jobs.list
    web.jobs.stats → plugin.web.jobs.stats
    web.jobs.data  → plugin.web.jobs.handler.get
    web.jobs.sync  → plugin.web.jobs.handler.sync
- log "plugin.web.jobs : initialized" at level 1
- end with `0;`

do NOT implement any "pipeline state manager". that is wrong.

reference pattern: `src/plugin.web.space.init_code`

---

**2. rewrite `src/plugin.web.jobs.state.load`** (replace entirely)

this module is vestigial — the correct approach is to call
`<[jobsite.job.load_all]>` directly wherever job data is needed.
rewrite to be a thin pass-through:

    calls <[jobsite.job.load_all]>
    returns the hashref directly (no wrapping in {mode=>..., data=>...})

this keeps it usable as a template command.

---

**3. write `src/plugin.web.jobs.state.save`** (new file)

saves a single job record update from browser. accepts ($id, $delta_hashref).
- loads existing job via YAML::XS::LoadFile from
  `/var/protocol-7/jobsite/jobs/$id.yaml`
- merges only browser-owned fields: stage, notes, date_applied
  (never overwrites score, score_reason, score_summary, fetched_at)
- writes updated record via `<[jobsite.job.write]>->( $id, $job )`
- returns TRUE on success, FALSE on error

---

**4. write `src/plugin.web.jobs.handler.get`** (new file)

GET endpoint handler — called from `httpd.http_post` routing (or a new
GET route) to serve `/jobs.json`.

- loads all jobs via `<[jobsite.job.load_all]>`
- converts hashref to JSON array sorted by fetched_at descending
- each element includes all fields from the YAML file
- sets Content-Type: application/json
- uses `<[base.perlmod.autoload]>->('JSON::XS')` for encoding
- follows the same HTTP reply pattern as `httpd.http_post` `/context` branch:
    - appends `<[httpd.new_header]>->( 200, $reply_header )` to output buffer
    - appends body to output buffer
    - returns 2

the session id `$id` is passed as the first argument (same as all httpd handlers).

---

**5. write `src/plugin.web.jobs.handler.sync`** (new file)

POST endpoint handler — called when browser POSTs a delta to `/jobs-sync`.

- reads body from `$session->{'buffer'}->{'input'}`; clears it after reading
- decodes JSON body: expects `{ "id": "...", "stage": "...", "notes": "...",
  "date_applied": "..." }` (any subset of browser-owned fields)
- validates: job id must be non-empty and the job file must exist
- calls `<[plugin.web.jobs.state.save]>->( $id, $delta )`
- replies 200 `{"ok":true}` on success, 400/500 with `{"ok":false,"error":"..."}` on failure
- sets Connection: close (same as `/context` in httpd.http_post)
- returns 2

---

**6. add routing in `src/httpd.http_post`**

add two new branches in the elsif chain after the `/cursor` branch:

    } elsif ( $http_uri eq '/jobs.json' ) {
        return <[plugin.web.jobs.handler.get]>->($id);
    } elsif ( $http_uri eq '/jobs-sync' ) {
        return <[plugin.web.jobs.handler.sync]>->($id);

add before the `else { ## unsupported }` branch.

also add routing for GET in `src/httpd.http_get` if `/jobs.json` is not
already handled there — check first and only add if missing.

---

**7. add to web zenka subroutine whitelist**

file: `cfg/zenki/web/subroutine.white-list`

add these lines (in the plugin.web.jobs section, alphabetically):
    plugin.web.jobs.handler.get
    plugin.web.jobs.handler.sync
    plugin.web.jobs.state.load
    plugin.web.jobs.state.save

---

### style rules

- lowercase comments, no capital-first sentences in comments
- `<[module.name]>` call syntax (no `->()` for zero-arg calls)
- `<[base.perlmod.autoload]>->('Module::Name')` for lazy module loading
- `<[base.logs]>->( level, fmt, args )` for logging (note: `base.logs` not `base.log`)
- `$ARG` not `$_` in loops
- no inline subs — if helper logic is needed, it goes in a separate module file
- descr lines max 55 chars
- end each module with `0;` only if it has no explicit return value

### verification

after writing all modules, run:
    ptd -c src/plugin.web.jobs.init_code
    ptd -c src/plugin.web.jobs.state.load
    ptd -c src/plugin.web.jobs.state.save
    ptd -c src/plugin.web.jobs.handler.get
    ptd -c src/plugin.web.jobs.handler.sync
    ptd -c src/httpd.http_post

report any syntax errors and fix them before marking complete.

#,,,,,,,.,...,,.,,,..,,..,..,,..,,,.,,..,,,.,,..,,...,...,..,,,..,.,.,,.,,,,.,
#RESIIULGOVDZDIR75ETKHQ2GHMRRY34Y3QIQFH4E3GN3UWZRDVVVGVH7RE33I4XIABQV72JJVB2S2
#\\\|2SGMC3VXG4IPOJGXHTB6UJBFXAAJ7QMI22IB24ZT7AQOOJYINAD \ / AMOS7 \ YOURUM ::
#\[7]A2FR64WQVAN64WQJNW3FYWR4RDGF2YKZX2LQNVOMUACFNC6NACAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
