## task: web plugin job storage — mirror status-dir layout + sync

### prerequisite

`data/tasks/jobsite-status-dir-layout.md` must be completed first.
this task assumes the jobsite job store uses the new status-directory layout.

---

### motivation

`plugin.web.jobs` currently uses a flat `/var/protocol-7/web/jobs/<id>.yaml`
layout mirroring the OLD jobsite flat layout. the web store is the endpoint
for the browser UI and for remote atom sync. once jobsite uses status dirs,
the web plugin should mirror the same structure so that:

1. sync becomes a directory comparison + selective copy (no full-scan parse)
2. status changes on either side are immediately visible in directory structure
3. epoch-bucketed terminal states auto-prune identically on both sides
4. a future multi-site merge can operate by comparing status dirs across nodes

---

### new web plugin directory structure

root: `/var/protocol-7/web/jobs/`

```
jobs/
  new/<id>.yaml
  assessed/<id>.yaml
  review/<id>.yaml
  apply/<id>.yaml
  applied/<id>.yaml
  rejected/<id>.yaml
  blocked/<epoch_v7>/<id>.yaml    minimal stub only
  deleted/<epoch_v7>/<id>.yaml    pruned at age > 1
```

identical layout to jobsite store. web plugin owns this directory;
jobsite syncs into it via the existing route-send push path.

---

### modules to update

#### plugin.web.jobs.cache.path

update to return the new base path. if needed, return both the base path
and a helper that constructs the full path given id + status.

#### plugin.web.jobs.cache.write

current: writes flat `<cache_dir>/<id>.yaml`

new: write to `<cache_dir>/<status>/<id>.yaml`.
if the job already exists under a different status dir, rename atomically.
maintain `<plugin.web.jobs.index>->{$id} = $status` in-memory index
(same pattern as jobsite `<jobsite.job.index>`).

blocked stubs: write minimal stub only (id, url, status, blocked_epoch,
checksum_hit) — do NOT write full content.

#### plugin.web.jobs.cache.read_all

current: glob `jobs/*.yaml`

new: scan active status dirs (`new`, `assessed`, `review`, `apply`,
`applied`, `rejected`). skip `blocked` and `deleted`.
populate `<plugin.web.jobs.index>` as side effect.

#### plugin.web.jobs.data

currently serves all jobs as JSON. update to scan active status dirs
only (same as read_all). the `since=` delta filter operates on
`last_modified` timestamps — no change needed there.

#### plugin.web.jobs.init_code

add index build from dir scan at init.

#### new module: plugin.web.jobs.store.prune

same two-phase prune logic as `jobsite.store.prune`:
- `blocked/<epoch>/` → `deleted/<epoch>/` when epoch distance > 0
- `deleted/<epoch>/` → removed when epoch distance > 1

the web store does NOT have its own checksum store — it does not need one.
prune is purely file-lifecycle management.

call from `plugin.web.jobs.reverse.flush` or a periodic event.

---

### sync path awareness

the existing sync push (`jobsite.sync.push` → `plugin.web.jobs.sync`) sends
job records from jobsite to the web plugin. update it to carry the status
so `cache.write` routes to the right subdir:

```perl
## jobsite side: include status in pushed record ##
$job_record->{'status'} = $job->{'status'};

## web side: cache.write routes to correct dir ##
```

for blocked stubs pushed from jobsite: the web plugin should write the
minimal stub only — same 5-field format. do not expand stubs on the
web side.

---

### merge / conflict resolution (multi-site basis)

when merging two stores (e.g. local + remote atom), the rule is:

**highest-priority status wins, with newest `last_modified` as tiebreaker.**

status priority order (highest first):
```
applied > apply > review > assessed > new > rejected > blocked
```

implementation: for each `<id>`, compare status from both stores using
the priority order above. if local status is higher priority, keep local.
if remote is higher, overwrite local. if equal priority, keep newest
`last_modified`.

a new module `jobsite.sync.merge` (or `plugin.web.jobs.sync.merge`) can
implement this as a standalone pass: given two job records for the same id,
return the winning record.

```perl
my %priority = (
    applied  => 7,
    apply    => 6,
    review   => 5,
    assessed => 4,
    new      => 3,
    rejected => 2,
    blocked  => 1,
);

sub merge_job {
    my ( $local, $remote ) = @_;
    my $lp = $priority{ $local->{'status'}  // '' } // 0;
    my $rp = $priority{ $remote->{'status'} // '' } // 0;
    return $lp >= $rp ? $local : $remote
        if $lp != $rp;
    ## equal priority : newest wins ##
    return ( $local->{'last_modified'} // '' ) ge
           ( $remote->{'last_modified'} // '' )
        ? $local : $remote;
}
```

---

### in-memory index

`<plugin.web.jobs.index>->{$id} = $status` — same pattern as jobsite.
for blocked/deleted: `"blocked:<epoch_v7>"` / `"deleted:<epoch_v7>"`.

---

### delta sync compatibility

the existing `?since=<B32ntime>` delta sync in `plugin.web.jobs.data`
filters by `last_modified`. this is unaffected by the dir restructure —
the filter operates on YAML content, not filenames.

---

## signatures note

do NOT manually write or edit signature lines. existing signatures on
modified files will be regenerated by the signing system. do not add
fake/stub signatures to new files.

## dispatch

#,,..,,,.,.,.,...,.,,,,..,,,.,,..,..,,,,,,.,.,..,,...,..,,,.,,,..,,..,,..,,..,
#J2WIPK5XMRIYXL3I4UTTOSBRT2PAWVHNDI3OLNATGD4MWOSHDIYE272CT6VGILIW4ZEMUIEJVOMKG
#\\\|FZJNAFNIVD533J3FOLDG7DFKIEE3766GAVOG344T2Y7DTFZO64N \ / AMOS7 \ YOURUM ::
#\[7]XG342HPAN6JZWT2GQMOEJY65ODB7NRUJHO7CJ25C3HMHPMLXL2CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
