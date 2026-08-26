# task: kimi reconnect — flush pending approvals on session restore

## problem

when the kimi-web backend reconnects mid-task (network blip, backend restart, etc.),
tool call approvals that arrived during the disconnect window get stuck in
`kimi.approval.pending` with no one to respond to them. kimi waits indefinitely
for manual approval that never comes, stalling the task.

the user had already implicitly approved the session's tool use pattern before disconnect.
on reconnect, those pending approvals should be flushed automatically so the task resumes.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files. leave files clean.
real signatures are added by `bin/Protocol-7 sourcecode update-signatures` after the fact.

## existing infrastructure

- `kimi.approval.pending` — hash of request_id → approval data, populated by
  `kimi.handler.approval_request`, cleared on approve/reject
- `kimi.approval.responded` — hash tracking already-responded request_ids (dedup)
- `kimi.wire.approval_respond` — sends approve/reject back to kimi-web
- `kimi.connect` — runs on session restore; already restores busy status when
  preserved prompts exist (lines 111-123), but does NOT flush pending approvals
- `kimi.approval.auto_approve` — flag for full auto-approve mode (not what we want here)

## what to build

### modify `src/kimi.connect`

after the existing block that restores busy status on reconnect (after the
`kimi.wire.pending` loop, around line 111-123), add a new block:

```
## flush any approvals that arrived during the disconnect window ##
my $pending = <kimi.approval.pending> // {};
my @stale   = keys %$pending;
if (@stale) {
    <[base.logs]>->(
        1, ': flushing %d stale approval%s after reconnect',
        scalar @stale, @stale == 1 ? '' : 's'
    );
    for my $rid (@stale) {
        delete $pending->{$rid};
        <kimi.approval.responded>->{$rid} = 1;
        <[kimi.wire.approval_respond]>->( $rid, 'approve' );
    }
}
```

place this block just AFTER the `kimi.session.acquired` flag is set to true
(so the approval_respond wire call goes out on a live session), and BEFORE
the log line that says 'reconnected with preserved prompt'.

### verify placement

read `src/kimi.connect` fully before editing to find the exact insertion point.
the block must run:
- after `<kimi.session.acquired> = 1` (or equivalent readiness flag)
- after websocket is confirmed live (session verified at backend)
- before task flow resumes

## testing

after the fix, a reconnect mid-task should log:
  `: flushing N stale approvals after reconnect`
and the task should continue without manual intervention.

manual test path (if zenki are running):
  `p7c kimi.approvals` — should show empty after reconnect
  `p7c kimi.status`    — should show busy/processing, not stuck waiting

#,,..,,,,,,..,,.,,,,,,,,.,,.,,,,,,,,.,,,.,..,,..,,...,...,...,...,,,.,,,,,.,.,
#NXM2DOYGGHQC2DL6XJOVSXNXMRV6VPNJBOJTWZKUDEJOPO4L3XEE6L7JHSFUFV2QSBBXN6BSESU32
#\\\|3Q5GFNJZQ46VZZVOYGLW4AJ7EG6SLPD4XE7WMCOBR4GF6I446RH \ / AMOS7 \ YOURUM ::
#\[7]ZB5NPLGSSX22A3VZGQSG6X75Y2KVYV2SRKCS7KJHVCOI7BRFP2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
