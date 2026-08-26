## task: jobsite sync multiplexing — multi-endpoint + multi-jobsite coordination

### vision

`jobsite.sync.push` currently targets one `jobsite.cfg.sync_url`. the
upgrade has two orthogonal improvements:

1. **multi-endpoint push** — push to ALL configured web endpoints; whichever
   is reachable receives the data. no single point of failure for sync.
2. **multi-jobsite coordination** — multiple jobsite zenki can run
   simultaneously (e.g. local + pri.v7.ax). ntime-based merge rules already
   handle conflict resolution implicitly if implemented correctly.

---

### multi-endpoint push

#### config

replace single url with a list:

```
jobsite.cfg.sync_urls = http://172.24.33.224/jobs-sync https://pri.v7.ax/jobs-sync
```

(space-separated; config parser already handles lists with split)

#### push logic change in jobsite.sync.push

iterate all configured endpoints; push to each; log per-endpoint result:

```perl
my @urls = split /\s+/, ( <jobsite.cfg.sync_urls> // <jobsite.cfg.sync_url> // '' );

for my $url ( @urls ) {
    next unless length $url;
    ## existing push logic, target = $url ##
    ## log: 'sync push to %s: %d jobs', $url, $count ##
}
```

failure on one endpoint does not abort others. use per-endpoint
`last_server_ntime` tracking:

```perl
<jobsite.sync.last_ntime>->{$url} = $server_ntime;
```

(hashref keyed by url instead of a single scalar)

---

### multi-jobsite coordination

#### design constraint: implicit convergence

if the data model is correct, multiple jobsite zenki converge naturally
without special coordination logic:

- each job record has a `last_modified` ntime (set on every write)
- merge rule: highest-priority status wins; equal status → newest ntime wins
- ntime is monotonically increasing per node (P7 ntime is network-global)

so: jobsite-A assesses job X → status=review, ntime=3TBL...
    jobsite-B has job X as status=assessed, ntime=3TB5...
    merge → jobsite-A's record wins (higher status + newer ntime)

this rule is ALREADY implemented in `plugin.web.jobs.sync.merge` (from the
web-jobs-status-dir-layout.md task). the same merge function handles both
multi-endpoint sync and multi-jobsite convergence without modification.

#### what multi-jobsite requires

1. each jobsite zenka has a unique **node identity** (use its nshell session
   key AMOS checksum, or a configured `jobsite.cfg.node_id`)
2. job records carry a `node_id` field identifying which jobsite wrote them
   — used for tiebreaking when ntime matches exactly (rare but possible)
3. web endpoints accept pushes from multiple jobsite zenki simultaneously;
   merge on write using the existing merge function
4. reverse sync (browser → jobsite) must fan out to ALL connected jobsite
   zenki, or use a pub/sub approach (web zenka notifies all subscribed
   jobsite zenki of reverse changes)

#### reverse fan-out for browser state changes

when the browser pushes a stage change via `/jobs-sync`, the web zenka
currently calls `jobsite.sync.apply_reverse` on ONE jobsite zenka. for
multi-jobsite, the web zenka should notify all currently-connected jobsite
zenki:

```perl
## plugin.web.jobs.sync — on reverse entry ##
for my $jsite_zenka ( @{ <plugin.web.jobs.connected_jobsites> } ) {
    <[protocol-7.route-send]>->(
        { 'command'   => "$jsite_zenka.sync.apply_reverse",
          'call_args' => { 'args' => $encoded_reverse_entries },
        }
    );
}
```

connected jobsite zenki register themselves on first push:
```perl
<plugin.web.jobs.connected_jobsites> //= [];
push @{ <plugin.web.jobs.connected_jobsites> }, $caller_zenka
    unless grep { $ARG eq $caller_zenka }
           @{ <plugin.web.jobs.connected_jobsites> };
```

---

### relationship to checksum store

checksum stores (title/url/status dirs) are local to each jobsite zenka.
they do NOT need to be synced between jobsite zenki — each one builds its
own dedup index from its own assessment history. the merge of job YAML
records is sufficient for state convergence.

---

### priority

**lower priority** — implement after:
1. web-jobs-status-dir-layout (phase 2) is live
2. auth + sessions are in place (needed for secure multi-site push)

implement `sync_urls` list config first (trivial, no arch change).
multi-jobsite reverse fan-out requires auth to be safe.

## dispatch

#,,,.,,,,,..,,.,.,,..,,..,,,,,.,,,..,,,,.,.,.,..,,...,...,...,.,.,,,.,..,,,.,,
#HH52WKYKSU3BVLL7GGM7VFYAXWTLFQNKFHKPBCVPFGFAKPGON2DNYHV5TAXDC7DANM7YYII2S6I4W
#\\\|GMHGRALR2TNFAA72RXCQVXR3OUPLZYHB66JHFWVSQOD3TSWALOE \ / AMOS7 \ YOURUM ::
#\[7]5POUKB4VEFK4ALTQ7V5BVMJGRQ4ZCO2ECQEZSG7S5YOA55QHOUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
