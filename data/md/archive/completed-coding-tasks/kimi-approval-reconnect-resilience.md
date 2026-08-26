# task: kimi approval queue — full reconnect resilience

## context

`src/kimi.connect` now flushes `kimi.approval.pending` on reconnect (commit `b986f3335`).
this handles approvals that arrived during the disconnect window.

however there is a second failure mode: if a reconnect happens *while* an approval request
is in flight (kimi-web sends it, but the response hasn't been sent back yet), the approval
may arrive on the new session as a re-sent request. the existing `kimi.approval.responded`
hash deduplicates these, but only if the request_id survives the session reset.

## what to investigate

1. read `src/kimi.connect` — where is `kimi.approval.responded` initialized/reset?
   does a session reset (`:next:`) clear it, potentially allowing replay?

2. read `src/kimi.handler.approval_request` — the `session not ready` guard at the
   top skips replayed approvals during history catchup. does this fire correctly on
   reconnect when `kimi.session.acquired` is reset?

3. read `src/kimi.handler.session_liveness_timeout` — when a dead session triggers
   a fresh reconnect, is the approval state cleaned up correctly?

## goal

after a mid-task reconnect (simulate by restarting kimi zenka while a task runs):
- no manual approval prompts should appear
- task should resume automatically within 1-2 polling cycles
- `p7c kimi.approvals` should show empty after reconnect

## fix if needed

if `kimi.session.acquired` is reset to 0 on reconnect but the approval_request handler
fires before it's set to 1 (during history catchup), the guard would drop the re-sent
approval. verify the timing and add a fallback: if session just acquired and pending
approvals exist, auto-approve them (same as the flush in kimi.connect).

## signatures note

do NOT add stub signature line to modified files.

#,,.,,,,.,..,,.,.,,.,,,,,,,,.,,..,...,..,,...,..,,...,...,..,,,,.,..,,,..,.,.,
#TM3ZOCYXGDRXYQ72ZUCFQVIQM3SBZX7HMCC73H2IUHQDF36FN5IWRLLEWATXSKFX44EQO2ASDDKJA
#\\\|27EMPD5GNTMVECQ7SFJ2RCOVSQNY5EGDWWYHG7G65R72H3Y3NWF \ / AMOS7 \ YOURUM ::
#\[7]W7N55EPXYZB32XZ2E7OQ3SVYKS44ZZO37I7N6JUC47QKKPPCY6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
