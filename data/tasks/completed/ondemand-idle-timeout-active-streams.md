# task: don't idle-shutdown an on-demand zenka while it's serving open STRM streams

## background

`graphics-matrix` (and likely other on-demand zenki using the STRM-push pattern from
[[topic-orbital-strm-push-rollout]] in memory) shuts down on its idle timeout
(`base.zenki.set_ondemand_timeout`) even while actively serving a subscriber via an open STRM
push stream. Confirmed live: `web` subscribes to `graphics-matrix.orbital-sync` (args
`subscribe`), the subscribe succeeds, but graphics-matrix's own `push_state_if_subscribed`
timer (see `src/graphics-matrix.orbital.push_state_if_subscribed`) only ever *writes out* to
the subscriber — no further *inbound* command ever arrives once subscribed. The result: the
zenka idle-shuts-down mid-subscription every `ondemand_timeout` seconds regardless of the live
consumer, which then presumably has to notice the drop and re-request/re-subscribe, producing a
visible on-demand-restart loop even though nothing is actually wrong with the subscription.

## root cause

`src/base.event.callback.io-idle-restart:33-47` re-arms the shutdown timer whenever the
event loop goes idle, gated only by:

```perl
if not defined $data{'route'}
or not keys $data{'route'}->%*;   ## no outstanding command replies ##
```

`$data{'route'}` tracks commands *this zenka itself sent out and is waiting on a reply for* —
unrelated to whether other zenki are currently subscribed to *this* zenka's push output.
`src/base.handler.command:114-121` cancels the timer on inbound command traffic only.
Neither path accounts for open outbound STRM streams this zenka is producing.

## the fix

`base.stream.open` / `base.stream.push` / `base.stream.close` already maintain exactly the state
needed, generically, with no new bookkeeping required:

- `base.stream.open` (`src/base.stream.open:40-47`) creates
  `$session->{'streams'}->{$cmd_id}` with `{'producer'} = 1` when this zenka opens a push stream
  to a subscriber.
- `base.stream.close` (`src/base.stream.close:25-41`) deletes that entry on close.

So "does this zenka currently have any open producer stream to anyone" is answerable purely by
checking whether any `$data{'session'}{$sid}{'streams'}{$cmd_id}{'producer'}` exists across all
sessions — no per-zenka-specific listener-list convention needed (graphics-matrix's own
`<graphics-matrix.orbital.listeners>` array is a separate, zenka-side convenience list for its
push loop; don't touch or depend on it — the fix should live entirely in `base.*` using the
already-generic `base.stream.*` state, so it covers every current and future STRM-producing
on-demand zenka automatically, not just graphics-matrix).

Add a check in `src/base.event.callback.io-idle-restart`, before arming the shutdown timer
(around line 45's existing condition): also require that no session currently has an open
producer stream. Something in the shape of:

```perl
my $has_open_producer_stream = 0;
for my $sid ( keys %{ $data{'session'} // {} } ) {
    my $streams = $data{'session'}{$sid}{'streams'} // {};
    if ( grep { $_->{'producer'} } values %$streams ) {
        $has_open_producer_stream = 1;
        last;
    }
}

<base.timer.ondemand_timeout> = <[event.add_timer]>->(...)
    if ( not defined $data{'route'} or not keys $data{'route'}->%* )
    and not $has_open_producer_stream;
```

(adapt to the file's actual style/bracket conventions — read the whole file first, this is a
sketch of the logic, not a literal diff)

## verification

- confirm `graphics-matrix` stays online (does not idle-shutdown) while `web` has a live
  `orbital-sync subscribe` STRM open to it — leave it subscribed past the configured
  `ondemand_timeout` (64s per `cfg/zenki/graphics-matrix/zenka-startup.v7`) and confirm
  no shutdown/restart happens.
- confirm it *does* still idle-shutdown normally once the subscriber's stream actually closes
  (no regression to the base on-demand-timeout behavior for the no-subscriber case).
- confirm `sys-deps` (fixed for an unrelated ondemand-registry bug this same week, see
  [[project-ondemand-zenki-registry-wipe]]) is unaffected — it has no STRM producer streams, so
  this change should be a no-op for it.
- check whether any *other* currently-running on-demand zenka uses `base.stream.open` as a
  producer (grep `base.stream.open` across `src/*.cmd.*` for `type => 'STRM'` push-subscribe
  patterns) and sanity-check the fix covers them too, without needing per-zenka changes.

## signatures note

module files have a 4-line AMOS7 signature footer — do not reproduce or invent these. leave
edited files without a footer; the signing tool adds it. existing signatures on files you don't
touch must not be modified.

## dispatch notes

- this is a small, well-scoped, single-file base-layer change (plus verification) — a good fit
  for `kimi_dispatch model=k2.7` rather than K3, the investigation/design decision is already
  done, what's left is implementation + live verification
- do not modify `graphics-matrix.orbital.listeners` or any graphics-matrix-specific code — the
  whole point is that the fix lives in `base.*` and needs zero zenka-specific wiring
- root-cause investigation trail: this session's `v7.ondemand_zenki` registry-wipe fix (see
  [[project-ondemand-zenki-registry-wipe]]) prompted the user to recheck graphics-matrix's
  long-standing, previously-deferred restart-loop annoyance, which turned out to be this
  unrelated bug, not the same one

#,,..,.,,,.,.,...,,,,,..,,,,.,.,.,,,.,.,,,..,,..,,...,...,.,.,..,,,..,.,.,..,,
#CDX44ANOUBYVKBJ2GYCNOBNNDL36A3QY33PVHRFEAHG6VSVY5KCWUDM3B6PRGJVPTKDN6CPG3VEE2
#\\\|XI7VEGXYQ7GT2V4OFZYX3HYA7BCVNIPHJD4WNKMYNEF4F3TUYCQ \ / AMOS7 \ YOURUM ::
#\[7]R7526OAGHHZHPEWIYYGJU3B6VVOTXSJJORGWHB4ZMIDBINFWOODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
