## task: reconcile status/stage fields in jobsite task records

### problem

two overlapping fields describe job state, causing confusion:

- `status` — stored in job YAML, used for dir routing: `new`, `assessed`,
  `review`, `apply`, `applied`, `interviewed`, `rejected`, `blocked`
- `stage` — stored in task records and YAML, more granular: `queued`,
  `assessing`, `assessed`, `review`, `failed`, `repair_attempted`, etc.

after the status-dir restructure, the **directory name** is the authoritative
status. `jobsite.job.write` routes files to `jobs/<status>/` based on
`$job->{'status'}`. but `jobsite.job.load_all` rebuilds `<jobsite.tasks>`
from YAML content, where `status:` may lag behind the directory.

current symptom: `jobsite.cmd.progress` shows `review: 0` because the task
records have `status=assessed` even for jobs living in `jobs/review/`.

### proposed resolution

**the directory name IS the status.** on load, override the YAML `status`
field with the directory name from `<jobsite.job.index>`:

#### change 1: jobsite.job.load_all

after building the task record, overwrite `status` from the index:

```perl
my $dir_status = <jobsite.job.index>->{$id} // '';
## strip epoch prefix for blocked/deleted ##
$dir_status =~ s{^(blocked|deleted):.*}{$1};
$tasks->{$id}{'status'} = $dir_status if length $dir_status;
```

#### change 2: jobsite.job.write

when writing a job, ensure the YAML `status` field matches the target dir.
the current implementation already does this (routes by `$job->{'status'}`
and writes the job hash which includes `status`). verify this is consistent.

#### change 3: assess-done sets status correctly

`jobsite.handler.assess-done` sets:
- `$job->{'status'} = 'assessed'` always
- `$job_rec->{'stage'} = 'review'` if score >= threshold

this needs updating: if score >= threshold, set `$job->{'status'} = 'review'`
(not just stage). the YAML and directory should both say `review`:

```perl
if ( length($score) and $score >= $threshold ) {
    $job->{'status'}    = 'review';
    $job_rec->{'stage'} = 'review';
} else {
    $job->{'status'}    = 'assessed';
    $job_rec->{'stage'} = 'assessed';
}
```

`jobsite.job.write` will then route to `jobs/review/<id>.yaml` or
`jobs/assessed/<id>.yaml` accordingly.

#### change 4: stage field — keep as in-flight state only

after reconciliation, `stage` should track only transient/in-flight states:
`queued`, `assessing`, `repair_attempted`. the persistent states (`review`,
`apply`, `applied`, etc.) live in `status` and the directory.

update `@clear_fields` in `jobsite.cmd.reset` if needed: `stage` is already
cleared, which is correct.

### migration of existing data

jobs currently in `jobs/assessed/` with `stage: review` in their YAML need
to be moved to `jobs/review/`. a one-time migration pass:

```perl
## in jobsite.init_code or a migration module ##
my $tasks = <jobsite.tasks> // {};
for my $id ( keys %{$tasks} ) {
    my $rec = $tasks->{$id};
    next unless ( $rec->{'stage'} // '' ) eq 'review';
    next unless ( $rec->{'status'} // '' ) eq 'assessed';
    ## move to review ##
    my $job = <[jobsite.job.read]>->($id) // next;
    $job->{'status'} = 'review';
    <[jobsite.job.write]>->( $id, $job );
}
```

run this migration once after deploying the assess-done fix.

### signatures note

do NOT manually write or edit signature lines. do not add stubs to new files.

## dispatch

#,,..,,.,,,.,,.,.,,..,,..,...,,.,,.,,,..,,,,,,..,,...,...,,..,.,.,.,.,,,.,.,.,
#2Q5YWZ7ACSQYYYHNTVHCKF37BXHHUQIG6LXYNPR7THLKHEQL4HJ6EN6N6TBKVPPMJDB2VHCQEBICG
#\\\|MHTXZM4JCP4CLX22OQSUQU62RZITFXYLZPMFBCXARE33QM7UYUH \ / AMOS7 \ YOURUM ::
#\[7]V3XRDUIOGZ474WU6HVTQXY6LO3676N3GYEHXO4NI6UWG6OKMWSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
