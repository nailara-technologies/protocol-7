## task: fix review count in jobsite.cmd.progress

### problem

`jobsite.cmd.progress` counts `status=review` from `<jobsite.tasks>`, but
jobs above the assessment threshold have `status=assessed` + `stage=review`
in the task records. the `status` field is always `assessed` after assessment;
`stage` carries the sub-status. result: review count always shows 0.

### root cause

`jobsite.job.load_all` sets `<jobsite.tasks>->{$id}{'status'}` from the
YAML `status:` field. jobs in `jobs/review/` have `status: review` in their
YAML (written by `jobsite.job.write` which routes by status), BUT after the
kimi status-dir restructure, the YAML status field and the directory name
should be in sync. the mismatch is that `<jobsite.tasks>->{$id}{'status'}`
may not reflect the actual directory the job lives in.

### fix — two parts

#### part 1: jobsite.job.index.build + jobsite.job.load_all

`jobsite.job.index.build` maps `id → directory_status` (the dir name, e.g.
`review`, `assessed`, `apply`). `jobsite.job.load_all` should populate the
task record's `status` from the INDEX (directory name), not from the YAML
`status:` field — the directory IS the authoritative status:

```perl
## in job.load_all, after loading YAML ##
$job->{'status'} = <jobsite.job.index>->{$id}
    if defined <jobsite.job.index>->{$id}
    and <jobsite.job.index>->{$id} !~ m{^(?:blocked|deleted):};
```

this ensures `<jobsite.tasks>->{$id}{'status'}` == directory name.

#### part 2: jobsite.cmd.progress — add apply/applied/rejected counts

while fixing review, also add `apply`, `applied`, `rejected`, `interviewed`
counts by scanning the index, and show a richer right bracket:

```perl
my %by_status;
for my $id ( keys %{ <jobsite.job.index> // {} } ) {
    my $st = <jobsite.job.index>->{$id} // '';
    $st =~ s{^(blocked|deleted):.*}{$1};
    $by_status{$st}++;
}

my $new_c    = $by_status{'new'}        // 0;
my $assessed = $by_status{'assessed'}   // 0;
my $review   = $by_status{'review'}     // 0;
my $apply    = $by_status{'apply'}      // 0;
my $applied  = $by_status{'applied'}    // 0;
my $rejected = $by_status{'rejected'}   // 0;
my $total    = scalar keys %{ <jobsite.job.index> // {} };
```

right bracket when idle:

```perl
"assessed:$assessed  rev:$review  apply:$apply  new:$new_c";
```

### signatures note

do NOT manually write or edit signature lines. do not add stubs to new files.

## dispatch

#,,.,,.,,,,.,,,,,,.,.,,,,,,,,,..,,...,,.,,...,..,,...,..,,...,,,.,,..,,.,,,,.,
#7XLDC7FI2MRVFRXMA2OZEYGVEEYCFVDG6UYZ5S5PSDBWELH4HCDVU4PQYJ6QFBS5D7NIQYC4EJS7I
#\\\|JLXQVQC2KACVHYU5N6IAH3BEP4NEK2M4FW3NERG3FOVOEREJLDA \ / AMOS7 \ YOURUM ::
#\[7]62XMBACS2OGACIB4W6NFQND4EYUQAELYTZGSMKGHUQWRO2NQQIBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
