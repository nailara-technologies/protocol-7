## [:< ##

# name  = task: debug letsencr renewal reply handler routing
# descr = renewal reply handler not found in child context — debug and fix

## kimi memory

if in doubt about P7 patterns, coding style, or project context — read first:
```bash
cat data/ai-mem/kimi/MEMORY.md
cat data/ai-mem/kimi/coding-style.md
```

## context

the letsencr zenka renewal flow works end-to-end (ACME challenges succeed,
certs are issued) but the reply routing fails with:

```
[child_session_id] not defined reply handler ['letsencr.parent.handler_renewal_reply']
```

this error comes from `base.handler.command` line 731 — it checks
`defined $code{ $route->{reply}->{handler} }` and the handler isn't found.

## what is known

the flow:
1. `letsencr.parent.handler_renewal_check` (timer callback) fires
2. calls `letsencr.parent.queue_renewal_requests`
3. which calls `<[protocol-7.command.send.local]>` with:
   - `command => 'child.renew-certificate'`
   - `reply => { handler => 'letsencr.parent.handler_renewal_reply' }`
4. child processes `renew-certificate` → calls `acme_new` → `continue_challenge_processing`
5. `continue_challenge_processing` calls `<[base.callback.cmd_reply]>->($reply_id, ...)`
6. this writes SIZE reply to the output buffer
7. parent's `base.handler.command` receives it, finds the route, checks handler → **NOT FOUND**

the key question: WHY is `letsencr.parent.handler_renewal_reply` not in `%code`
when the parent receives the reply?

the module exists, is in the whitelist, has correct syntax, and the version
on atom matches local (confirmed via letsencr.src-ver). `letsencr.parent`
loads 40 subs with no errors.

## comparison: what WORKS

`letsencr.parent.cmd.request-certificate` uses the SAME pattern:
- `command => 'child.request-certificate'`
- `reply => { handler => 'letsencr.parent.handler_enrollment_reply' }`

and this works correctly. the enrollment reply handler IS found.

## hypothesis to investigate

the timer callback context may be relevant. `queue_renewal_requests` is
called from `handler_renewal_check` which fires as a timer event. in this
context, the `send.local` reply registration may behave differently than
when called directly as a P7 command handler.

alternatively: the reply route may be registered in the child's session
context rather than the parent's, causing the handler lookup to occur in
the child's `%code` (which only has `letsencr.child.*` modules).

## what to read

```bash
## the renewal flow
cat src/letsencr.parent.handler_renewal_check
cat src/letsencr.parent.queue_renewal_requests
cat src/letsencr.parent.handler_renewal_reply
cat src/letsencr.child.cmd.renew-certificate
cat src/letsencr.child.continue_challenge_processing

## the working enrollment flow for comparison
cat src/letsencr.parent.cmd.request-certificate
cat src/letsencr.child.cmd.request-certificate
cat src/letsencr.parent.handler_enrollment_reply

## the routing mechanism
cat src/base.handler.command    ## around lines 715-735 and 810-820
cat src/base.callback.cmd_reply
cat src/letsencr.base.fork_letsencr_child   ## how parent/child pipe is set up
```

## task

1. trace the exact difference between the enrollment (working) and renewal
   (broken) reply routing paths

2. identify WHY the renewal reply handler lookup fails — is it:
   a. the timer callback context affecting route registration
   b. the reply being delivered to the wrong process context
   c. the handler not actually being in `%code` despite being in whitelist
   d. something else

3. implement the correct fix — do NOT change the working enrollment path

4. verify the fix makes sense by tracing through the code mentally

## signatures note

do not add signature stubs. do not run `bin/Protocol-7 sourcecode update-signatures`.
do not add or modify subroutine whitelists — these are managed separately.

## success criteria

- [ ] root cause identified with explanation
- [ ] fix implemented
- [ ] renewal reply handler lookup succeeds (no more 'not defined reply handler')
- [ ] cert bundle correctly saved via save_certificate after reply
- [ ] no signature stubs, no whitelist changes

#,,..,.,,,,,,,,.,,,..,,.,,,,.,,,,,,,.,,,,,.,.,..,,...,...,...,.,.,.,,,.,,,,,,,
#XFPVRJG7RCIIV3AXX2FBX5CH27JMO4HXS444X5V74VUQBT7D2ZXY42ZPERAVQA5AE6ZEAY2HE6OJI
#\\\|ZKAWRHWVG3VXXBUIW5YSYA6ZARNIME7YYD2ZUEVGRP4GAUMWZ4W \ / AMOS7 \ YOURUM ::
#\[7]ORVHBYU6E3OGDRKQHRIWOXCDFGKU2VXRY2EP5UTXAWCRLVPWPAAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
