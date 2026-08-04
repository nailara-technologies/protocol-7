## [:< ##

# name  = task: kimi zenka — approval-respond marks 'responded' before send confirms
# descr = TOCTOU race: an approval response can be marked responded+persisted
#         to disk before the actual websocket send is confirmed, so a
#         reconnect between the two silently and permanently swallows the
#         backend's legitimate re-send of that same approval request

## context — read first

This is a follow-up to `data/tasks/kimi-zenka-approval-reconnect-
disassociation-fix.md` (already fixed and deployed, staged/committed
separately) — that fix addressed `modules/kimi.flush_on_acquisition`
never being called on reconnect, for requests that were still genuinely
*pending* (never yet approved/rejected). **This task is a different,
deeper bug in the same area**, found live this session: it happens even
with `<kimi.approval.auto_approve>` **on** (the normal, default state),
which is why the user kept hitting "user has to open the web-UI to
nudge it" even when nothing should have been sitting pending for manual
review.

`kimi` is a P7 zenka (`modules/kimi.*`) connecting as a client to a
manually-started external `kimi-web` process over websocket. Do not
touch `modules/kimi-web.*` (separate, unrelated, immature zenka-
management layer).

## root cause found this pass — TOCTOU in `kimi.wire.approval_respond`

`modules/kimi.wire.approval_respond`:

```perl
unless ( <kimi.ws.connected> and defined <kimi.ws.socket> ) {   # line 13
    <[base.logs]>->( 0, 'kimi.wire.approval_respond: not connected' );
    return undef;
}
...
## track responded ids to suppress re-sent requests on reconnect      # line 42
<kimi.approval.responded> //= {};
<kimi.approval.responded>->{$request_id} = 1;                        # line 43

## persist responded set for session resume across restarts          # line 45
my $responded_str = join( "\n", keys %{<kimi.approval.responded>} ) . "\n";
<[file.zenka_dir.write]>->( 'approval_responded', \$responded_str );  # line 47

return <[websocket.send]>->( <kimi.ws.socket>, $json );              # line 49
```

The connection check at line 13 is correct but insufficient: it only
proves the socket was live at *check* time. Lines 42-47 unconditionally
mark the request as responded — **in memory AND on disk** — before line
49 has attempted, let alone confirmed, the actual send. If the
connection drops between line 13's check and line 49's send (a real,
frequent event in this environment — live session logs from the prior
task showed reconnects on the order of seconds during normal operation),
`websocket.send` either fails silently or the write is lost, but
`<kimi.approval.responded>` already believes it succeeded.

The consequence, traced through `modules/kimi.handler.approval_request`:

```perl
<kimi.approval.responded> //= {};
if ( exists <kimi.approval.responded>->{$request_id} ) {   # line 17
    <[base.logs]>->( 2, ': skipping already-responded approval [ %s ]', $request_id );
    return;
}
```

kimi-web re-sends unacknowledged approval requests on reconnect (per this
file's own comment at line 15: "kimi-web re-sends on reconnect"). But
since `<kimi.approval.responded>` already has this `$request_id` marked
(falsely, from the failed send), the legitimate re-send is silently
dropped — no error, no retry, no log above level 2. The backend never
actually receives an approve/reject, the task hangs, and the only
recovery is a human manually approving it in the kimi-web UI directly —
this matches the user's reported symptom exactly, and explains why it
happens even with auto-approve on (the auto-approve *decision* is made
fine; it's the *delivery of that decision* that can silently fail and
get marked as delivered anyway).

## what to do

1. **Verify live** before fixing, same discipline as the prior task: read
   `modules/websocket.send` to confirm what it returns on a genuinely
   failed/half-closed-socket write (not just the already-checked
   disconnected case) — does it return undef, 0, or throw? Confirm the
   TOCTOU window is real and not already guarded some other way you
   haven't seen yet.
2. Fix: reorder so `<kimi.approval.responded>` is only set (in memory)
   and persisted (to disk) **after** confirming `<[websocket.send]>`
   returned a real success value (a defined, truthy byte count — check
   what `modules/websocket.send` actually returns on success to pick the
   right truthiness check, don't assume). On send failure: do NOT mark
   responded, log at level 0 (this is a real failure, not routine), and
   leave the request recoverable — check whether it needs to go back
   into `<kimi.approval.pending>` explicitly or whether the natural
   kimi-web re-send + (now-fixed) `flush_on_acquisition` reconnect path
   already covers recovery once `responded` isn't falsely set. Prefer
   the minimal fix (just fix the ordering) unless live testing shows the
   re-send path needs more than that.
3. Check `kimi.handler.approval_request`'s own three call sites that set
   `<kimi.approval.responded>`... actually check: does anything besides
   `kimi.wire.approval_respond` write to `<kimi.approval.responded>`?
   Grep to confirm this is the only write path before changing anything
   else that reads it.
4. Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/
   MEMORY.md` first for P7 module conventions before editing — note the
   syntax gotcha already logged there from the prior fix
   (`<[module.name]>->(...)` vs `<module.name>->(...)`, the latter is a
   fatal data-access-not-subcall bug in this codebase's dialect) and
   double check any new/changed call sites use the bracket form
   correctly.
5. Live-verify the fix: with `<kimi.approval.auto_approve>` **left at its
   default (on)** — the user was explicit that testing with it forced
   off does not reproduce their actual reported scenario, since the bug
   is in the auto-approve response delivery path, not the
   manual-approval-pending path. If you can safely force a brief
   disconnect (e.g. via `<kimi.ws.socket>` shutdown from `devmod.cmd.
   eval-code`, NOT by touching the external `kimi-web` process) in the
   narrow window between an approval decision and its send, do so to
   directly exercise the race; otherwise document clearly what you were
   able to confirm vs. what remains theoretical.
6. No existing test harness for `modules/kimi.*` (confirmed in the prior
   task) — live `eval-code` verification is the house-appropriate
   substitute; don't invent a new test style.

## style / house conventions

- comments lowercase, `[ word ]` not `( word )` for annotations.
- do not commit — leave staged for the user to review/sign/commit
  themselves.
- commit-message convention: state the concrete mechanism found broken,
  the fix, and what was verified live (see `84930c1f5`, `a5b64e4c5`, and
  the prior `kimi.flush_on_acquisition` fix this session for house style).

## if you learn something non-obvious

Add to `data/ai-mem/kimi/coding-style.md` and/or `data/ai-mem/kimi/
MEMORY.md` in your own established format, same as any other task
instruction.

#,,.,,...,..,,,,,,.,,,.,.,.,.,,..,..,,.,.,,,.,.,.,...,...,..,,,,,,...,.,.,,,.,
#HSOXYNTOFS47BV6WGDY5L5BJXFKH63DVYQE22NCN3N6HFMDOLFGZHEDHOSNF3AJOFCRLGFQDEAAWE
#\\\|UYBYVH4PPIYEODHK4U7MD6AXB2ZS3X2P74AHBRVBLNJI7CGZZO2 \ / AMOS7 \ YOURUM ::
#\[7]7GUJBQAILZL4QXX6I52UZVX2CHE54MM7ML35RCJQUEI734GAYKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
