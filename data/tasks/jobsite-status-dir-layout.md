## task: jobsite job storage restructure — status-directory layout

### motivation

current layout is a flat `/var/protocol-7/jobsite/jobs/<id>.yaml` directory.
all jobs regardless of status live together, making enumeration by status a
full-scan parse. blocked jobs carry full scraped content despite needing only
a minimal stub. there is no automatic expiry for terminal states.

the replacement uses per-status subdirectories. status transition = atomic
`rename`. epoch-bucketed `blocked/` and `deleted/` dirs auto-prune at
configurable age distance, with cross-store awareness between the YAML
directory and the checksum store.

---

### new directory structure

root: `/var/protocol-7/jobsite/jobs/`

```
jobs/
  new/<id>.yaml               active: waiting for assessment
  assessed/<id>.yaml          active: scored, below threshold
  review/<id>.yaml            active: above threshold, pending user decision
  apply/<id>.yaml             active: user queued for application
  applied/<id>.yaml           terminal: user applied
  rejected/<id>.yaml          terminal: user rejected
  blocked/<epoch_v7>/<id>.yaml  transient: checksum duplicate — minimal stub
  deleted/<epoch_v7>/<id>.yaml  transient: moved here on epoch advance — pruned
```

`<epoch_v7>` is the encoded V7 epoch string returned by
`<[base.ntime.epoch_timestamp]>` (e.g. `V7L36RY`).

---

### cross-store awareness

the YAML blocked dir and the checksum store (`checksum-store/`) are
complementary layers. they must stay consistent:

#### on block (dispatch.assessments finds checksum hit):
1. write minimal stub to `blocked/<current_epoch>/<id>.yaml`
2. call `<[jobsite.checksum.index]>->( 'add', $job )` if the job's
   title/url checksums are NOT yet in the checksum store — this handles
   the case where the original assessment was done in a prior session
   before the store existed, so the checksum record may be missing.
3. delete the `new/<id>.yaml` file.

#### on epoch advance / prune (`blocked` → `deleted`):
when a `blocked/<epoch>/` dir becomes older than 1 epoch:
1. for each stub in the dir: verify its title/url checksums are present
   in the checksum store; if missing, call `add` to backfill.
2. move (rename) each `blocked/<epoch>/<id>.yaml` to
   `deleted/<same_epoch>/<id>.yaml`.
3. rmdir the now-empty `blocked/<epoch>/` dir.

#### on `deleted` prune (age > 1 epoch):
1. unlink all files in `deleted/<epoch>/`, rmdir the dir.
2. the checksum store entries are NOT removed — they remain as permanent
   dedup guards.

#### summary: prune age policy
- `blocked/<epoch>/` → promote to `deleted/` when epoch distance > 0
  (i.e. on the NEXT epoch advance after the epoch they were created in).
- `deleted/<epoch>/` → fully removed when epoch distance > 1.
- checksum store entries: permanent (never pruned by this flow).

---

### blocked stub format

minimal YAML, no scraped content:

```yaml
---
id: '12871544'
url: https://www.stepstone.de/...
status: blocked
blocked_epoch: V7L36RY
checksum_hit: title:AAQLHLE4XOG4Q
```

fields: `id`, `url`, `status: blocked`, `blocked_epoch`, `checksum_hit`
(colon-joined type:checksum string from the hits array).
do NOT include description, company, title, or other scraped content.

---

### in-memory id→status index

since job lookup by ID needs to work without knowing the current status dir,
maintain a hash in `<jobsite.job.index>`:

```perl
<jobsite.job.index>->{$id} = $status;   ## 'new', 'assessed', 'review', etc.
```

- populated at init by scanning all status dirs once
- updated on every status transition (write, rename)
- used by `jobsite.job.read` and `jobsite.job.write` to locate the file

for `blocked` and `deleted`, the value is `"blocked:<epoch_v7>"` and
`"deleted:<epoch_v7>"` so the full path can be reconstructed.

---

### modules to update

#### jobsite.job.read

current: reads `/var/protocol-7/jobsite/jobs/<id>.yaml`

new: look up `<jobsite.job.index>->{$id}` → construct path from status,
then load with `<[file.zenka_dir.load]>->( "jobs/<status>/<id>.yaml" )`.

```perl
my $id     = shift // '';
my $status = <jobsite.job.index>->{$id} // '';
return undef unless length $status;

my $rel_path = do {
    if ( $status =~ m{^(?:blocked|deleted):(.+)$} ) {
        "jobs/$1/$id.yaml"
    } else {
        "jobs/$status/$id.yaml"
    }
};

my $raw = <[file.zenka_dir.load]>->( $rel_path, ':utf8' );
return undef unless defined $raw;
<[base.perlmod.autoload]>->('YAML::XS');
return eval { YAML::XS::Load( $$raw ) };
```

#### jobsite.job.write

current: writes `/var/protocol-7/jobsite/jobs/<id>.yaml` (always same path)

new: determine target status dir from `$job->{'status'}` (and epoch for
blocked/deleted). if the job already exists at a DIFFERENT status path,
rename (atomic) the old file to the new path before writing content.
update `<jobsite.job.index>`.

for blocked stubs: write minimal stub hash (5 fields only).

for normal writes: write full job hash.

use `<[file.zenka_dir.write]>` for new files; `rename` for moves.

#### jobsite.job.load_all

current: glob `jobs/*.yaml`

new: scan all active status dirs (`new`, `assessed`, `review`, `apply`,
`applied`, `rejected`) and load their YAMLs. skip `blocked` and `deleted`
dirs (stubs are not useful for dispatch logic). populate
`<jobsite.job.index>` as a side effect.

#### jobsite.init_code

add a call to `<[jobsite.job.index.build]>` (new sub or inline) at init
time to scan all status dirs and populate `<jobsite.job.index>`.

#### jobsite.dispatch.assessments

on checksum hit:
- write blocked stub via `jobsite.job.write` with minimal hash
- call `jobsite.checksum.index` add to backfill if needed (check first)
- do NOT dispatch assessment task

#### jobsite.cmd.reset

after restructure, status filter scan must search within the correct
status subdir. update path construction to use the index.

#### jobsite.cmd.reject, jobsite.cmd.approve

these trigger status transitions. update to use rename via
`jobsite.job.write` which handles the atomic move.

#### new module: jobsite.store.prune

implement the two-phase prune logic described above:
1. blocked → deleted (epoch distance > 0): verify checksums, rename, rmdir
2. deleted → gone (epoch distance > 1): unlink, rmdir

call from `jobsite.handler.rescan-timer` or `jobsite.cmd.scan` before
dispatching new assessments.

epoch distance calculation:
```perl
my $current = int( <[base.ntime.epoch_dec]> );
my $ep_num  = <[base.ntime.epoch_timestamp]>->($ep_dir);  ## decodes V7XXXXX
my $distance = $current - $ep_num;
```

---

### migration

on first run: detect flat layout (files directly in `jobs/`) and migrate:

```perl
## in jobsite.init_code or a one-shot migration module ##
my $jobs_root = catfile( <system.path.zenka-dirs>->{'var_P7'}, 'jobsite', 'jobs' );
if ( glob("$jobs_root/*.yaml") ) {
    ## flat layout still exists : migrate ##
    for my $f ( glob("$jobs_root/*.yaml") ) {
        my $job    = YAML::XS::LoadFile($f);
        my $id     = $job->{'id'} // ( $f =~ m{/(\d+)\.yaml$} )[0];
        my $status = $job->{'status'} // 'new';
        ## use rename for atomic move ##
        rename $f, "$jobs_root/$status/$id.yaml";
    }
}
```

do NOT migrate blocked jobs with full content — if any `status: blocked`
jobs exist in the flat dir, write minimal stub to
`blocked/<current_epoch>/<id>.yaml` and ensure checksum store is populated.

---

## signatures note

this codebase uses AMOS7 data signatures at the end of each module file
(4-line footer starting with `#,,.,,,...`). do NOT manually write or edit
signature lines. existing signatures on modified files will be regenerated
by the signing system. do not add fake/stub signatures to new files.

## dispatch

#,,,,,.,,,.,.,,,.,,,,,,..,..,,.,,,.,,,...,...,..,,...,...,.,.,,,.,,,.,,,,,.,,,
#OJX2TNXUJPM3XGUQVV74WPWPSS6EPL4ODWGQQWEJTTWEP7QIPKFVCN5IFNGZ2PCWMXYLJIPKN5GOS
#\\\|YXWTIMCE3AVRSQPW6G5KYXAJMJHF5Y5LIXS742T6ZSNZJUIHA2J \ / AMOS7 \ YOURUM ::
#\[7]EVCQLYL5TPKXYE5E2AC64AQOGJGK74D3FXHFFDEO2VQH7SWTDSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
