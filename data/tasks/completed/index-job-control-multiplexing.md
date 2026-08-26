## [:< ##

# task: index zenka — job control and multiplexing

unify feed-dir and wordlist-import under a generic tick dispatcher that
round-robins across concurrent jobs. add chunked file processing so large
files do not block the event loop. all mutable job state lives exclusively
under `<index.jobs>->{$job_id}` — no global flags modified by callbacks.

design reference: `data/md/design/INDEX-CORPUS-VERSIONING.md`

signatures_note: do NOT attempt to sign any files — only the repo owner can
sign via `v7.sourcecode update-signatures`.

---

## the problem

current `index.callback.feed-dir` writes to `<index.cfg.rebalance_deferred>`
as a global flag. with two concurrent feed-dir jobs this is a race: job A
sets the flag, job B reads it — B's rebalance is deferred by A's state.

each idle callback is also job-type-specific: separate `feed-dir` and
`wordlist-import` callbacks, each registered as an independent idle watcher.
no fair scheduling between them; first registered runs until complete.

---

## core principle: per-job state machines

all mutable state for a job lives under `<index.jobs>->{$job_id}` — the
same isolation contract as `$data{'session'}{$sid}` in P7 session handlers.
callbacks never write outside their own job subtree. the job struct is the
complete, self-contained state machine for that job.

```perl
<index.jobs>->{$job_id} = {
    'job-type'       => 'feed-dir',        ## dispatch key for tick handler
    'reply_id'       => $call->{'reply_id'},
    'stop-requested' => 0,
    'cfg' => {
        'rebalance_deferred' => TRUE,      ## was: <index.cfg.rebalance_deferred>
        'chunk_size'         => 4096,      ## chars per tick for large files
    },
    'state' => {
        'files'        => \@files,         ## remaining files queue
        'total'        => scalar @files,
        'done'         => 0,
        'current_text' => undef,           ## content of file being chunked
        'chunk_pos'    => 0,               ## position within current_text
        'carry'        => '',              ## last max_window-1 chars (overlap)
    },
};
```

---

## module: index.callback.tick (new, replaces per-type callbacks)

one idle watcher, shared across all jobs. registered once in `index.init_code`.
round-robins across `<index.jobs>` keys per tick.

```perl
# name  = index.callback.tick
# descr = unified job tick dispatcher — one unit of work per idle tick
```

```perl
my @job_ids = keys %{ <index.jobs> // {} };
return unless @job_ids;

## round-robin: rotate job order each tick ##
my $job_id = shift @job_ids;
push @job_ids, $job_id;
## persist rotation state in a stable key outside jobs (tick scheduler) ##
## or simply rely on hash key order variability — acceptable for fairness ##

my $job = <index.jobs>->{$job_id};
return unless defined $job;

## stop-requested: clean up and reply ##
if ( $job->{'stop-requested'} ) {
    delete <index.jobs>->{$job_id};
    <[base.callback.cmd_reply]>->(
        $job->{'reply_id'},
        { 'mode' => 'false', 'data' => 'job aborted [ admin request ]' }
    );
    return;
}

my $type = $job->{'job-type'} // '';
if    ( $type eq 'feed-dir'       ) { <[index.tick.feed-dir]>->($job_id)       }
elsif ( $type eq 'wordlist-import') { <[index.tick.wordlist-import]>->($job_id) }
else {
    <[base.log]>->( 0, "index.tick: unknown job type [ $type ]" );
    delete <index.jobs>->{$job_id};
}
```

---

## module: index.tick.feed-dir (new)

extracted from `index.callback.feed-dir`, rewritten to use per-job state.

```perl
# name  = index.tick.feed-dir
# descr = one tick of a feed-dir job : process one chunk or advance to next file
```

```perl
my $job_id = shift // $ARG;
my $job    = <index.jobs>->{$job_id} // return;
my $state  = $job->{'state'};
my $cfg    = $job->{'cfg'};

## if current file has remaining chunks, process next chunk ##
if ( defined $state->{'current_text'}
        and $state->{'chunk_pos'} < length( $state->{'current_text'} ) ) {

    my $chunk_size = $cfg->{'chunk_size'} // 4096;
    my $max_win    = <index.meta>->{'max_window'} // 8;
    my $carry      = $state->{'carry'} // '';
    my $text       = $state->{'current_text'};
    my $pos        = $state->{'chunk_pos'};

    ## prepend carry-over for window continuity ##
    my $slice = $carry . substr( $text, $pos, $chunk_size );
    my $is_eof = ( $pos + $chunk_size >= length($text) );

    <[index.ingest.chunk]>->( $slice, $carry, $is_eof );
    <[index.deduplicate.chunk]>->( $slice, $carry, $is_eof );

    ## advance position; new carry = last max_win-1 chars of slice ##
    $state->{'chunk_pos'} += $chunk_size;
    $state->{'carry'}
        = substr( $slice, -( $max_win - 1 ) )
        if length($slice) >= $max_win - 1;
    $state->{'carry'} = '' if $is_eof;

    return;
}

## no current file or fully consumed — advance to next file ##
$state->{'current_text'} = undef;
$state->{'chunk_pos'}    = 0;
$state->{'carry'}        = '';

my $file = shift @{ $state->{'files'} };

if ( not defined $file ) {
    ## all files done — final rebalance if deferred ##
    if ( $cfg->{'rebalance_deferred'} ) {
        <[index.rank]>;
        <index.meta>->{'dirty'} = FALSE;
    }
    my $total = $state->{'total'};
    delete <index.jobs>->{$job_id};
    <[base.log]>->( 1, "index feed-dir complete [ $total files ]" );
    <[base.callback.cmd_reply]>->(
        $job->{'reply_id'},
        { 'mode' => 'size', 'data' => "fed $total files\n" }
    );
    return;
}

## slurp file into job state for chunked processing ##
my $content = <[file.slurp]>->($file);
if ( not defined $content ) {
    <[base.log]>->( 1, "index feed-dir: slurp failed [ $file ]" );
    $state->{'done'}++;
    return;
}

$state->{'current_text'} = $content;
$state->{'chunk_pos'}    = 0;
$state->{'carry'}        = '';
$state->{'done'}++;
<[base.log]>->( 2, "index feed-dir: queued [ $file ]" );
```

---

## window overlap at chunk boundaries

the `carry` field holds the last `max_window - 1` (7) characters from the
previous chunk. each chunk is processed as `$carry . $slice` so N-gram
windows that cross the boundary are captured correctly.

`index.deduplicate.chunk` is a variant of `index.deduplicate` that:
- takes `($text, $carry_len, $is_eof)` arguments
- skips the first `length($carry)` characters for freq counting (already
  counted by previous chunk) but includes them for window scanning
- for terminal tracking: only marks EOS terminals on `$is_eof` chunks

---

## round-robin scheduler

the simplest correct approach: store a rotation index in the tick data
(not in any job):

```perl
<index.tick.cursor> //= 0;

my @job_ids = sort keys %{ <index.jobs> // {} };
return unless @job_ids;
<index.tick.cursor> = <index.tick.cursor> % scalar(@job_ids);
my $job_id = $job_ids[ <index.tick.cursor>++ ];
```

sorted keys give a stable order; cursor wraps. new jobs are picked up
automatically on the next tick.

---

## migration: index.callback.feed-dir

keep the existing module as a thin wrapper that creates the job struct and
registers it. remove the idle watcher registration from it — the unified
`index.callback.tick` handles all dispatch. the wrapper becomes:

```perl
## create job struct with per-job state ##
<index.jobs>->{$job_id} = { ... };
## tick watcher is already running (registered in init_code) ##
return { 'mode' => 'deferred' };
```

---

## migration: index.cfg.rebalance_deferred

replace all references to `<index.cfg.rebalance_deferred>` with
`<index.jobs>->{$job_id}->{'cfg'}->{'rebalance_deferred'}` in all
callbacks. the global key is removed.

---

## module: index.init_code

register the unified tick watcher once at startup:

```perl
<[event.add_idle]>->(
    {   'handler' => 'index.callback.tick',
        'repeat'  => TRUE,
        'desc'    => 'index job dispatcher',
    }
);
<index.tick.cursor> //= 0;
```

remove per-job idle watcher registration from `index.cmd.feed-dir` and
`index.cmd.add-wordlist`.

---

## stop-job

`index.cmd.stop-job` already works correctly — it injects `stop-requested`
into the job struct and the tick dispatcher handles cleanup. no changes
needed.

---

## notes

- `index.tick.wordlist-import` is a thin wrapper of the existing
  `index.callback.wordlist-import` logic, rewritten to read/write only
  `<index.jobs>->{$job_id}` state
- chunk_size of 4096 chars balances responsiveness vs overhead; tunable
  per job or globally via `<index.cfg.chunk_size>`
- the carry buffer for the 214KB file (worst case) is 7 chars — negligible
- terminal tracking in chunked mode: ring-0 terminals only marked at true
  word boundaries within the slice; `$is_eof` gates the EOS terminal check
- future job types (reference corpus import, base32 index feed) plug in by
  adding a dispatch branch in `index.callback.tick` and a corresponding
  `index.tick.*` module

#,,,,,,,.,.,.,...,,,.,,..,...,,.,,..,,..,,,,,,.,.,...,...,..,,...,...,..,,,,.,
#JXAXSJZMDELV7BM3YEBPHLHX4C5I5CKVQVK4WEYPJEIDHPIRNVA4OZ4XSJT427PGWNOGY2AJ5O4TI
#\\\|A3GCLKMVTLA3YXVXLC6XPWQUUDYVDR4SJD6AIC2TYAKIYCTQOYC \ / AMOS7 \ YOURUM ::
#\[7]6OANGMQFBLUATT5ZX3VEE4QL5AKP4LTNO4NCEGJOIGO727MLPSDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
