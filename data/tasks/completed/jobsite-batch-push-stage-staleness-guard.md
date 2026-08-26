## task: fix batch push clobbering a fresher browser stage change

### follow-up to

`data/tasks/completed/jobsite-review-tab-disappearing-jobs.md` — found while
testing the fixes from that session: moving a job `apply → review` in the
UI, then immediately forcing a manual jobsite sync to "accelerate" it, made
the card visibly bounce back to `apply` for a while before settling on
`review` on its own.

### root cause

`src/plugin.web.jobs.sync`'s batch (jobsite → web) push path had no
staleness check, unlike the single (browser → web) push path which already
guards against stale writes via `base_last_modified`. `stage` is copied
straight from jobsite's payload in the `@pipeline_fields` loop with no
regard for whether the web cache already holds a *more recent* value.

Sequence that produces the flicker:

1. Browser pushes `stage=review` straight to the web cache (single-push
   path). Cache updates immediately with a fresh `last_modified`. This also
   queues a reverse-sync entry for jobsite to pick up on its next poll —
   jobsite's own on-disk copy still says `apply` at this point.
2. A forced/manual jobsite sync builds its outbound batch from
   `jobsite.job.load_all` — jobsite's own view, which still predates the
   reverse-queue entry it hasn't drained yet. It pushes `stage=apply`.
3. The batch handler copies `stage` unconditionally, clobbering the cache's
   fresh `review` back to `apply`. The existing "preserve user-owned stage"
   check (`plugin.web.jobs.sync`, derive-from-status block) runs *after*
   this same loop already overwrote the value, so it inspects the
   already-stale result and can't undo it.
4. Only after that push's HTTP round-trip does jobsite process the reverse
   queue and write `review` to its own file. The *next* push cycle carries
   that forward and corrects the cache back to `review` — the "moved back
   on its own after a while" the user observed.

A forced manual sync makes this trivial to hit by firing an immediate batch
push mid-flight, but the race exists on any normal push cycle too — just
much less likely to land in the narrow window.

### fix

`src/plugin.web.jobs.sync` — before the `@pipeline_fields` copy loop,
compare the batch entry's `last_modified` (jobsite's own write-time) against
the cache's current `last_modified` via `base.ntime_BASE32_to_numerical`. If
the cache is already newer, skip `stage`/`status` for that field only —
every other pipeline field (score, description, assertions, ...) still
applies normally, since jobsite remains authoritative for those. Naturally
converges on the next cycle once jobsite's own reverse-queue drain catches
up, same as before, just without the visible wrong-value window in between.

### files touched

- `src/plugin.web.jobs.sync`

### verification

- Re-checked `BWZNS` (the job used in the original repro) after the fix
  landed and `httpd.reload all`: both jobsite's and the web cache's copies
  agree on `stage: review, status: review`, distinct fresh `last_modified`
  values (each side stamps its own), no drift.

#,,,,,.,,,...,,,,,..,,.,.,.,.,,,,,,,,,..,,.,,,..,,...,...,,.,,.,.,.,,,...,..,,
#LQTI77CEPJCS2YNU42HOLTJDSKZKIOXVBND45MNINGG5MCWPVVLSKWHHQIS3DQPHPQXRHG56MMVKC
#\\\|FCJQSDNFMVD5MDKVR2ADZQSYASSDSC6ASBDHQOOFUW7DTDVM5V4 \ / AMOS7 \ YOURUM ::
#\[7]2NBCWAHTZRHMEZW7XG22N5OH3BIMJIN7VERO6QX4K22AUSJBV2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
