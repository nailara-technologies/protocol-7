# Task: jobsite.sync.push — periodic HTTP push to httpd cache

## Context

The jobs pipeline has two sides:
- **httpd** owns a local cache at `/var/protocol-7/httpd/jobs/` (one YAML per job)
- **jobsite** zenka is the source of truth for job data it fetches and scores

The httpd side is already implemented. Your job is the jobsite side.

## What to build

### `jobsite.sync.push`

Called on a timer (interval from `jobsite.cfg.sync_interval`, default 300s).
Reads all job records from jobsite's own storage via `<[jobsite.job.load_all]>`,
then POSTs each one individually to the httpd sync endpoint.

The endpoint is `<jobsite.cfg.sync_url>` (e.g. `http://172.24.33.224/jobs-sync`).
Use `LWP::UserAgent` with a short timeout (10s). This runs in the jobsite zenka
event loop so keep it non-blocking — use a timer-chained loop, not a blocking
for loop over all jobs. Process one job per timer tick to avoid stalling.

Each POST body is JSON: the job record hash with `id` added.
Content-Type: `application/json`.

The response is JSON: `{ "ok": true/false, "reverse": [ ... ] }`.

After posting all jobs, collect the `reverse` arrays across all responses
and pass the merged list to `<[jobsite.sync.apply_reverse]>`.

Only call apply_reverse once per sync cycle (after the last job is posted),
not once per job.

### `jobsite.sync.apply_reverse`

Receives an arrayref of reverse change entries from httpd.
Each entry is a hashref with at minimum `{ id => "..." }` plus changed fields.

Apply each entry to the local job record:
- `stage`, `notes`, `date_applied` — write these browser-owned fields back via
  `<[jobsite.job.write]>->($id, $updated_job)`
- `action => "delete"` — remove the local job file
  (path: `<system.path.zenka-dirs>->{'var_P7'} . "/jobsite/jobs/$id.yaml"`)
- `action => "blacklist"` — add company to blacklist; the company name is in the
  job record, load it first via `<[jobsite.job.read]>->($id)`, then call
  `<[jobsite.cmd.blacklist-add]>->($company)` if it exists

Log each applied change at level 1.

### Wire into `jobsite.init_code`

Add a repeating timer after the existing rescan timer block:

```perl
my $sync_interval = <jobsite.cfg.sync_interval> // 0;
if ( $sync_interval > 0 ) {
    <[event.add_timer]>->(
        {   'after'    => 30,          ## initial delay after startup
            'interval' => $sync_interval,
            'repeat'   => TRUE,
            'handler'  => 'jobsite.sync.push',
        }
    );
    <[base.logs]>->( 1, 'jobsite: sync push timer %ds', $sync_interval );
}
```

### Config keys (in `cfg/zenki/jobsite/zenka.v7`)

Add these if not present:
```
jobsite.cfg.sync_interval = 300
jobsite.cfg.sync_url      = http://172.24.33.224/jobs-sync
```

## Style notes

- module `# descr =` lines max 55 chars
- comments lowercase
- use `$ARG` not `$_` in map/grep
- `<[module.name]>` is an implicit no-arg call, never add `->()` for zero args
- new module files: do NOT add the `#,,.,,,...` stub line at the end — leave clean

## Signatures note

Do not attempt to add or verify AMOS7 signatures. Leave new files without them;
the signing system adds them separately.

## Deliverables

1. `src/jobsite.sync.push`
2. `src/jobsite.sync.apply_reverse`
3. Updated `src/jobsite.init_code` (add sync timer block)
4. Updated `cfg/zenki/jobsite/zenka.v7` (add cfg keys if missing)
5. Updated `cfg/zenki/jobsite/subroutine.white-list` (add both new modules)

#,,,.,,.,,.,.,,.,,,,,,..,,,,.,.,.,.,,,...,,.,,..,,...,...,...,,..,,,,,.,,,...,
#QDUMLPXMD44473NTOX7GN5TPPRAI3NFWJOVEWZ7KZ6WASIE5WBEWB62Q7S4EJ2EACA4S7TUMHXUKY
#\\\|3JIDAEH5HMVVDI6O3WLOPTR2OLKDKU7CIZFPPY272BQTZVK7UPT \ / AMOS7 \ YOURUM ::
#\[7]RITDOMHO43SCTL7GSS6DHVJ7UBMUPA4CUZXV7NOWS5OMF4JW36DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
