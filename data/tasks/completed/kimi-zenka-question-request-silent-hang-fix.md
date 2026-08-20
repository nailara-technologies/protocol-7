## [:< ##

# name  = task: kimi zenka — QuestionRequest silently dropped, kimi-web hangs
# descr = a third distinct message type from kimi-web (QuestionRequest) has
#         zero handling -- no response sent back at all -- so kimi-web waits
#         forever until a human manually answers via its own web UI directly

## context

This is a third, separate finding from the same session as two already-fixed
bugs: `data/tasks/kimi-zenka-approval-reconnect-disassociation-fix.md`
(`flush_on_acquisition` never called) and `data/tasks/kimi-zenka-approval-
respond-toctou-race-fix.md` (responded marked before send confirmed) — both
fixed, committed (`8c7644ca1`), and live-confirmed working correctly in a
real dispatch this session (two real `ApprovalRequest`s round-tripped
cleanly, including across a natural reconnect). **This is not a regression
of either fix** — it's a different, never-implemented code path in the same
file that produces the same user-visible symptom (silent hang, manual UI
intervention required).

`kimi` is a P7 zenka (`src/kimi.*`) connecting as a client to a
manually-started external `kimi-web` process. Do not touch
`src/kimi-web.*` (separate, unrelated, immature zenka-management layer).

## the gap — `src/kimi.handler.ws_message`, lines 237-243

```perl
if ( $type eq qw| QuestionRequest | ) {
    ## structured question : not yet implemented
    <[base.logs]>->(
        1, ': question request [ %s ] : not handled', $msg_id
    );
    return;
}
```

Compare the adjacent, already-better-handled `ToolCallRequest` case
(lines 222-235, same file), which is *also* "not yet implemented" but does
two things `QuestionRequest` doesn't:

```perl
if ( $type eq qw| ToolCallRequest | ) {
    my $payload_str = eval { JSON::XS::encode_json($payload) } // '?';
    <[base.logs]>->(
        1,       ': ToolCallRequest [ %s ] payload=%s',
        $msg_id, $payload_str
    );
    ## send reject so kimi-web does not hang waiting for a response
    <[kimi.wire.approval_respond]>->(
        $msg_id, 'reject',
        'ToolCallRequest not yet implemented : log captured for analysis'
    );
    return;
}
```

`QuestionRequest` logs a bare message-id with no payload dump, and never
calls `kimi.wire.approval_respond` (or any response) at all — kimi-web is
left waiting indefinitely with zero signal that anything was received.
**Live-reproduced this session**: dispatching a real task
(`data/yaml/coding-tasks/amos-term-interaction-plugin.yaml`, an
open-ended design task) triggered a `QuestionRequest` for an MCP tool-call
confirmation (one of the `p7_*` tools from `bin/mcp-server-p7`) — logged
as `question request [ 657eda84-... ] : not handled` **twice**, identically,
once before a natural reconnect and again after it, and the task stayed
stuck until the user manually answered it via the kimi-web UI directly.

## what to do

1. **Verify live first**: read `src/kimi.wire.approval_respond` (already
   fixed this session — TOCTOU-safe now) to confirm its signature accepts a
   `request_id`/`response`/optional `message`, same shape `ToolCallRequest`
   already uses for its reject call. Confirm whether `QuestionRequest`'s
   `$payload` structure is actually approval-response-shaped (a
   yes/no/approve/reject decision) or something richer (free-text question
   + multiple choice options, closer to `AskUserQuestion`) — **don't
   assume**, dump the real payload live first (same
   `JSON::XS::encode_json($payload)` pattern `ToolCallRequest` already
   uses) and read a real captured example before deciding the response
   shape.
2. **Minimal, safe fix** (matches the `ToolCallRequest` pattern exactly):
   log the full payload, then send an explicit decline/reject response
   (not a silent drop) so kimi-web stops waiting and surfaces this to
   whatever fallback path it has (likely: falls through to asking the
   human via its own UI immediately, rather than hanging first and only
   then falling back — that's the actual bug-shaped improvement here, not
   full interactive handling). Use the same wire mechanism
   `kimi.wire.approval_respond` already uses if the payload shape is
   compatible; if `QuestionRequest`'s reply format is genuinely different
   from an approval response (check the live payload first per step 1),
   find or build the minimal matching reply — don't force-fit
   `approval_respond` if the JSON-RPC result shape kimi-web expects for a
   `QuestionRequest` reply is actually different.
3. **Do not attempt full interactive question-answering in this task** —
   that's a much larger design (see `data/md/design/CODING-ZENKA-USER-
   INTERACTION-SURFACES.md` and the three-track fallback-chain design this
   session's git history already has, commit `db8e3cbba`, for the
   long-term shape of that). This task's scope is strictly: stop the
   silent hang, log enough for a future real design to work from. If you
   want to leave a pointer for that future work, a short note in the log
   message or a `data/ai-mem/` entry is fine — don't scaffold new
   interaction infrastructure here.
4. Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/
   MEMORY.md` first — this session already logged several kimi-zenka-
   specific gotchas there (bracket-call syntax, `$SIG{PIPE}` danger,
   api-child singleton respawn, cmd-module predefined `$reply`/`$call`
   scope vars, `and`/`?:` precedence). Check all of them before editing.
5. Live-verify: trigger a real `QuestionRequest` if you can find a
   reliable way to reproduce one (the amos-term-interaction-plugin task
   triggered one via an MCP tool-call confirmation — a similar dispatch
   might reproduce it, but don't burn a long real dispatch just for this;
   use judgment on whether a lighter reproduction is possible via
   `devmod.cmd.eval-code` calling the handler directly with a synthesized
   `QuestionRequest`-shaped message instead). Confirm the fix sends a
   real response and doesn't just move the silent-hang problem elsewhere.
6. No existing test harness for `src/kimi.*` — live verification via
   `devmod.cmd.eval-code` is the house-appropriate substitute.

## style / house conventions

- comments lowercase, `[ word ]` not `( word )` for annotations.
- do not commit — leave staged for the user to review/sign/commit.
- commit-message convention: state the concrete mechanism, the fix, what
  was verified live (see `8c7644ca1`, `f332c2e41` this session for style).

## if you learn something non-obvious

Add to `data/ai-mem/kimi/coding-style.md` and/or `data/ai-mem/kimi/
MEMORY.md` in your own established format.

#,,,,,,,,,,.,,,.,,,,,,.,,,,.,,..,,...,,,.,..,,.,.,...,..,,..,,,,,,,,.,.,,,...,
#VZYY76ULWV4ESROY75AU4D3NVWMBHNIN7YCNP4RRVJTYJSNSWYALZ2TW23RDUTC6GR4TEARDVFPDM
#\\\|EZ242AEM2BJNUKO3LMYZPKRQ44RHVPRUC6DSSXPM2DSAKACXSC5 \ / AMOS7 \ YOURUM ::
#\[7]ACYJCQUDW22RD5VHVIJDLFRATE37TREZSFBLBZYQCVMAXUDXBIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
