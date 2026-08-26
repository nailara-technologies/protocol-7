## task: update jobsite.sync.push for status-directory layout

### context

`jobsite.sync.push` and `jobsite.sync.push_chunk` send job records from
jobsite to the web plugin via HTTP. after the status-dir restructure
(session 67), job YAMLs live in `/var/protocol-7/jobsite/jobs/<status>/`
subdirs. the sync modules need updating to:

1. read jobs from status subdirs (not flat dir)
2. include `status` in pushed records so web plugin routes to correct subdir
3. send only active statuses (not blocked/deleted stubs)

### modules to update

#### jobsite.sync.push

currently reads all jobs via `<[jobsite.job.load_all]>` (already scans
status dirs), so the data source is fine. the key change: ensure each job
record includes `status` before pushing:

```perl
## ensure status is set from index before push ##
for my $id ( keys %{$jobs} ) {
    my $idx_status = <jobsite.job.index>->{$id} // '';
    $idx_status =~ s{^(?:blocked|deleted):.*}{};
    $jobs->{$id}{'status'} = $idx_status if length $idx_status;
}
```

blocked/deleted jobs: skip — do not push stubs to web plugin.

```perl
next if ( $job->{'status'} // '' ) =~ m{^(?:blocked|deleted)$};
```

#### jobsite.sync.push_chunk (if it batches job records)

same: exclude blocked/deleted, include status field.

#### web plugin: plugin.web.jobs.cache.write

must route to the correct status subdir using `$job->{'status'}`. if the
job's existing entry is in a different subdir, rename atomically.

this is the same logic that should already exist after the web-jobs-status-
dir-layout task (phase 2) is implemented. if that task hasn't run yet, add
a note to dispatch it first.

### reverse queue sync (web → jobsite)

`jobsite.sync.apply_reverse` processes status changes from the web plugin
back to jobsite (e.g., user moved job to apply in the browser). after the
restructure, this must call `jobsite.job.write` with the updated status,
which handles the atomic rename between status dirs.

verify `jobsite.sync.apply_reverse` calls `<[jobsite.job.write]>->($id, $job)`
and does not write to any hardcoded path.

### signatures note

do NOT manually write or edit signature lines. do not add stubs to new files.

## dispatch

#,,.,,,,.,..,,,,,,,,,,.,,,..,,,..,...,,,,,,,.,..,,...,...,,..,,,,,,,,,.,.,..,,
#J7GA3QNUOSHM2FBBFF37FENX2YPVGLSC3CXJIEBOUQF44YG6J3QOBKKU2TAGRVHGI7CED5F2VSVTM
#\\\|DVEKMAPYQULDWIN5GAQDE376X7DESIJSG6BDNBGMU5EH6Q2XUKI \ / AMOS7 \ YOURUM ::
#\[7]J5DXXNO45LTVPRDXYTZYPJQIAEKFOAWYZHQVOWSVRSOIJCBQXIAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
