# task: base.zenka.push — well-behaved push helper

## context

fire-and-forget `protocol-7.route-send` to potentially-offline zenki causes
unbounded linear retry, flooding the calling zenka's buffer and the cube log.
`nodes.orbital.update_position` → `discover.orbital-p7ref-update` is the
current live example: when discover is offline, the orbital timer hammers
the route repeatedly with no backoff and no relief.

the correct pattern already exists in `base.log.send-buffer.send-idle-callback`
— detect offline, send `v7.notify_online`, queue payload, retry on reply.
but it is hand-coded per use case. this task creates a generic helper so the
pattern is available by name and LLMs reach for it naturally.

## harmony check

`harmony base.zenka.push` → TRUE [:<  — namespace confirmed.

## base.zenka.push — interface

```perl
<[base.zenka.push]>->(
    {   qw| command |  => qw| discover.orbital-p7ref-update |,
        qw| args |     => { qw| args | => $p7ref },
        ## optional:
        qw| queue_max | => 1,    ## max queued payloads (drop oldest, default 1)
        qw| on_drop |   => qw| base.logs |,  ## callback on queue overflow
    }
);
```

caller never thinks about offline handling — it just pushes. behavior:

```
target online    → send immediately, no overhead
target offline   → register v7.notify_online, queue payload, stop retrying
notify_online    → dequeue and resend, reset state
v7 unavailable   → exponential backoff fallback (1s → 2s → 4s → cap 60s)
never            → linear retry ← eliminated
```

## state per push registration

`<base.zenka.push.state>->{$command_prefix}`:

```perl
{
    queued      => $payload,       ## last payload to send on reconnect
    waiting_no  => TRUE/FALSE,     ## notify_online registered
    backoff_n   => 0,              ## backoff iteration (v7 unavailable path)
    last_attempt => $ntime,        ## for backoff calculation
}
```

one state entry per target zenka prefix. multiple push registrations to the
same zenka share the notify_online wait — only one `v7.notify_online` sent
regardless of how many callers are waiting.

## modules to create

- `modules/base.zenka.push` — main helper, handles routing + offline detection
- `modules/base.zenka.push.reply-handler.offline` — reply handler: detects
  offline response, registers notify_online, queues payload
- `modules/base.zenka.push.reply-handler.notify-online` — handles
  `v7.notify_online` reply: dequeues and resends
- `modules/base.zenka.push.pre_init` — swap `base.zenka.push` → `zenka.push`
  (optional, if short form desired)

## immediate fix: nodes.orbital.update_position

replace the raw `route-send` call with `base.zenka.push`:

```perl
## before:
<[protocol-7.route-send]>->(
    {   qw| command |   => qw| discover.orbital-p7ref-update |,
        qw| call_args | => { qw| args | => $p7ref },
    }
);

## after:
<[base.zenka.push]>->(
    {   qw| command | => qw| discover.orbital-p7ref-update |,
        qw| args |    => { qw| args | => $p7ref },
        qw| queue_max | => 1,   ## only latest position matters
    }
);
```

`queue_max => 1` is correct for orbital position — only the latest matters,
older queued positions are stale and should be dropped.

## reference implementation

see `modules/base.log.send-buffer.send-idle-callback` lines 58-79 for the
`v7.notify_online` dispatch pattern.
see `modules/base.zenki.ondemand.handler.startup_reply` for the notify_online
reply handler pattern.

## core subs

```
bin/Protocol-7 -core-subs load_code
```

check before implementing any runtime load paths.

## signatures note

do not modify or regenerate any AMOS7 signature lines. the signing system
handles all footer blocks — leave them untouched.

#,,,,,,..,..,,,..,,,.,,..,,..,,.,,.,,,...,.,.,..,,...,...,..,,,.,,..,,,,.,,..,
#JIWFTWHHTTGMVYNJCNEW3X6JLZ7IR2H3JCT3FKKT22N4E4P3SLY2DU3GVFVHH5CN6UDRX7L2FV2F2
#\\\|EKHIQ4D45BVQWXHOFJFCZFVQPA6FQKUTFP7FXLRJQZO3UX6EJRQ \ / AMOS7 \ YOURUM ::
#\[7]EYO75FRAVRTMOPOZHWXKXGQ72IHGBBVJFUTW6KSB3JLADWDVVGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
