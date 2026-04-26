# task: web.space context → template layer selection

## what is broken

the template resolver (`plugin.web.space.template-resolver.resolve`) is fully
implemented and correct — it computes `active_layers` from zoom + intent + data
availability. but it is never called in practice, so `active_layers` in
`/templates.json` is always `[]`.

three gaps:

1. **no initial resolve on startup** — `active_layers` stays `[]` until the
   first POST /context arrives. the visualization shows no orbital layers on
   first load.

2. **cmd.context doesn't call resolve** — `plugin.web.space.cmd.context` updates
   `web.space.templates.context` zoom + intent but never calls resolve afterward.

3. **update_context drops intent** — `plugin.web.space.template-resolver.update_context`
   accepts `{ zoom, intent }` params but only uses `zoom`. it re-derives intent
   from history pattern instead of accepting the intent the JS already computed.

## what to fix

### fix 1 — initial resolve call in init_code

file: `modules/plugin.web.space.template-resolver.init_code`

after setting up `web.space.templates.context`, add a deferred one-shot timer
(after 2 seconds) that calls resolve with the default context. this gives time
for the orbital cache to populate before first resolve:

```perl
## deferred initial resolve — after orbital cache has time to populate ##
<[event.add_timer]>->(
    {   qw| after   | => 2,
        qw| handler | => qw| plugin.web.space.template-resolver.resolve |,
        qw| params  | => {
            qw| zoom   | => 1.0,
            qw| intent | => qw| navigate |,
        },
    }
);
```

### fix 2 — cmd.context calls resolve after update

file: `modules/plugin.web.space.cmd.context`

after updating zoom + intent in `web.space.templates.context`, call resolve.
add just before the log line and return:

```perl
## trigger layer re-resolution with updated context ##
<[plugin.web.space.template-resolver.resolve]>->(
    {   qw| zoom   | => $context->{'zoom'},
        qw| intent | => $context->{'intent'},
    }
);
```

### fix 3 — update_context accepts explicit intent

file: `modules/plugin.web.space.template-resolver.update_context`

the module re-derives intent from history (good). but the `intent` field in
`$params` is ignored. after the existing history-based derivation, add:

```perl
## accept explicit intent if provided ##
if ( defined $params->{'intent'} and length $params->{'intent'} ) {
    $intent = $params->{'intent'};
    $context->{'intent'} = $intent;
}
```

## how to verify

```bash
# should show non-empty active_layers after startup
curl -s https://space.v7.ax/templates.json | python3 -m json.tool | grep -A 20 active_layers

# simulate focus zoom
curl -s -X POST https://space.v7.ax/context \
  -H 'Content-Type: application/json' \
  -d '{"zoom": 2.5, "intent": "focus"}' && echo

# orbital-self and orbital-known weights should be > 0
curl -s https://space.v7.ax/templates.json | python3 -m json.tool | grep -A 20 active_layers
```

## summary

| file | change |
|------|--------|
| `modules/plugin.web.space.template-resolver.init_code` | add 2s deferred one-shot timer calling resolve |
| `modules/plugin.web.space.cmd.context` | call resolve after updating context |
| `modules/plugin.web.space.template-resolver.update_context` | accept explicit intent param |

## signatures note

do NOT add stub signature line to modified files.

#,,,.,.,.,..,,,..,..,,.,.,,,.,.,,,.,,,...,,,,,..,,...,..,,..,,...,...,,,,,,.,,
#HRIJD63B47F5WHXTYV2GVZFYYLJP2GTRQLCDMLIV4LSS4CQIKLXLOJ5XTUBIIWHB6HJLXSCGLYIQW
#\\\|3WCQYR4ROPBYU6XYX4TGMKV4L7CVFAYFYR7GU77TAWMUHWQIJDQ \ / AMOS7 \ YOURUM ::
#\[7]MKC44FM5UMPISSSRIGNMU6J4KBGAAHIRC2HZPBTL2CFKK3DYFOAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
