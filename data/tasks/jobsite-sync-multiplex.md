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

### concurrent assessment : who takes which job [ 2026-10-18 ]

the merge keeps state consistent, but nothing stops two hosts from
assessing the SAME job [ wasted work ; with different models, timing
decides which result survives ]. three layers, no central lock :

1. **partition by checksum** : a job's amos residue decides its host
   [ e.g. even / odd for two ] -- known from the job id alone, never a
   double assessment
2. **lease** : a job not assessed within its lease time may be taken by
   another host [ a host being down does not stall its share ]
3. **time offsets for scanning** [ user ] : hosts scan at staggered
   times, so each sees the other's synced results before it scans --
   collisions outside the partition [ leases, imports ] mostly vanish,
   and a slow cpu host gets its own phase beside the gpu host

partition over the PRESENT hosts [ user ] : hosts announce presence
through the sync backend ; the residue split is taken over the hosts
present right now. a host that leaves -- the gpu host while invoke holds
the gpu memory, or the card is away for repair -- drops out and the
remaining host processes the COMPLETE set on its own ; when it returns,
the split resumes. a planned absence [ coding yields to invoke ] is
announced at once, so its share moves immediately instead of waiting
out each lease ; the lease stays the fallback for unannounced failure.
presence is a HEARTBEAT [ present while its entry is fresh ] ; leaving is
announced only as a courtesy, BEFORE teardown -- at the yield to invoke,
or when a terminate is requested -- never in end_code [ it runs after the
network is gone, user 2026-10-18 ]. a lost goodbye only costs time : the
heartbeat expires and the share moves a little later.

until built : run assessments on ONE host at a time. also open from
above : the reverse fan-out [ a browser stage change reaches only one
jobsite zenka today ].

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

#,,..,.,.,,.,,..,,,..,,,.,.,,,..,,,,,,.,.,,,,,..,,...,...,,.,,..,,,.,,.,,,,,.,
#ZBUFSQA6FNLSH42N5MK4NE7SKQ3HS2V67QJ6EL27IEUZKSQ6H3XBNCKZNHRFDQDKL6ZCRULPSJ6DO
#\\\|J2JM4LBONXE5UOIMBNK7V7DDD5K4R7CJCXBYTOGNPPIFCT235A4 \ / AMOS7 \ YOURUM ::
#\[7]WYH6S2OQEEHQL33YTUB3SBEX3JLTFYRWBNCBITH4JPULXKBPGODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
