
 .:[  zulum → decoder routing : cross-zenka wiring reference  ]:.

## Status : verified working [ Mar 10 2026 ]

Phase 1 wiring confirmed:
- `zulum.cmd.stream-attach`       → `protocol-7.route-send` callback ✅
- `decoder.zenka.init_code`       → `level-5-B32` buffer via `base.buffer.add_line` ✅
- `decoder.zenka.receive_entropy` → `base.buffer.add_line` with size tracking ✅
- `zulum.loop.generate_entropy`   → `$stream->{'is_true'} = is_true($Z)` ✅
- `list buffers`                  → shows `level-5-B32` with correct byte count ✅

## Why Direct Code Calls Fail Across Zenki

The most important thing to understand before wiring zenki together:

**Each zenka is a separate OS process with its own `%data` and `%code` hashes.**

When Kimi wrote:
```perl
<[decoder.zenka.receive_entropy]>->( { 'stream_id' => $sid, ... } );
```

...from inside a zulum callback, this executes in **zulum's process**. The
module `decoder.zenka.receive_entropy` runs there, reading `<decoder.level5>`
which does not exist in zulum's `%data`. It silently returns nothing. The
decoder's accumulator is never touched.

There is a second problem: P7 pre-validates all `<[name]>` syntax at compile
time. If the module `decoder.zenka.receive_entropy` is not in zulum's `%code`
hash, the zenka refuses to start entirely — before a single line runs.

These two failure modes make direct cross-zenka `<[other.zenka.module]>->()`
calls almost always wrong. The correct pattern is a **cube-routed command**.

---

## The Correct Architecture

```
zulum           →   cube (router)   →   decoder
                        ↑
                    cube-13 (Phase 2)
```

The full intended flow from `zulum-cube13-decoder-integration.md`:

```
zulum     →  generates 13 parallel division-by-13 entropy streams
cube-13   →  routes, switches, and jumps between streams (switch matrix)
decoder   →  receives stream via cube-13, decodes multi-encoding layers
```

**cube-13 is not optional.** It is the switch matrix that implements the
`jump true`, `jump reverse`, `jump next` navigation operators. The decoder
registers with cube-13, not directly with zulum. cube-13 holds the active
stream selection and notifies the decoder of stream changes with boundary
markers so it can close level buffers cleanly.

---

## Phase 1 vs Phase 2 Wiring

### Phase 1 : direct zulum → decoder (testing shortcut)

Used to verify the entropy format, accumulator logic, and base32 extraction
before cube-13 is implemented. The callback in `zulum.cmd.stream-attach`
sends directly to the decoder via a cube-routed command:

```perl
## phase 1 : direct wiring for testing — cube-13 is not yet involved ##
my $callback = sub {
    my ( $sid, $entropy, $iteration ) = @ARG;
    <[protocol-7.route-send]>->(
        {   'command'   => 'decoder.receive-entropy',
            'call_args' => { 'args' => "$sid $entropy" },
        }
    );
};
push @{ $stream->{'attached'} }, $callback;
```

This goes: zulum callback → cube router → decoder zenka →
`decoder.cmd.receive-entropy` → `decoder.zenka.receive_entropy`.

### Phase 2 : route through cube-13 (production)

Once cube-13 jump routing is implemented, the stream-attach callback changes
to route through cube-13 instead:

```perl
## phase 2 : route through cube-13 switch matrix ##
my $callback = sub {
    my ( $sid, $entropy, $iteration ) = @ARG;
    <[protocol-7.route-send]>->(
        {   'command'   => 'cube-13.receive-entropy',
            'call_args' => { 'args' => "$sid $entropy" },
        }
    );
};
```

cube-13 then decides which downstream decoder receives the data based on the
current jump state.

---

## Stream State: is_true Required

For cube-13 jump routing to work, each stream must track the harmonic truth of
its current value. From `zulum-cube13-decoder-integration.md`:

```perl
## $data{'zulum'}{'streams'}{$n} = {
##     'seed'      => $generator * $n,   ## cycle position
##     'current'   => $value,            ## current expansion value
##     'iteration' => $count,            ## steps taken
##     'is_true'   => is_true($value),   ## harmonic truth of current value
## }
```

The `jump true` command in cube-13 uses `is_true` to identify which stream to
switch to. Without this field in stream state, `jump true` cannot resolve.

---

## Access Control: cube/access.zenki

For any cross-zenka cube-routed command to succeed, the calling zenka needs
permission in `cfg/zenki/cube/access.zenki`. The format is:

```
access.cmd.usr.CALLING_ZENKA = list of commands it may call
```

For Phase 1 zulum → decoder:
```
access.cmd.usr.zulum = decoder.receive-entropy
```

For Phase 2 with cube-13:
```
access.cmd.usr.zulum   = cube-13.receive-entropy
access.cmd.usr.cube-13 = decoder.receive-entropy
```

Without these entries the cube router rejects the command silently.

---

## Routing Pattern 1 : protocol-7.route-send

Use when: fire-and-forget command, no return count needed, no reply handler.

**Real example — `ticker.callback.request_updates`:**
```perl
<[protocol-7.route-send]>->(
    {   'command'   => "v7.notify_online",
        'call_args' => { 'args'    => 'rss-ticker' },
        'reply'     => { 'handler' => 'ticker.request_rss_update' }
    }
);
```
With optional reply handler — reply arrives asynchronously via the named
handler module in the calling zenka.

**Real example — `letsencr.parent.notify_httpd_challenge`:**
```perl
## space-separated args when multiple params needed ##
my $args_string = join ' ', $domain, $token, $key_auth, $type;

my $result = <[protocol-7.route-send]>->(
    {   'command'   => 'httpd.setup-acme-challenge',
        'call_args' => { 'args' => $args_string }
    }
);

## $result is truthy on success, falsy if target offline ##
if ($result) { ... }
```

The target command's `$call->{'args'}` receives the args string. The target
module splits it: `my ( $domain, $token, $key_auth, $type ) = split m| +|, $call->{'args'}, 4;`

---

## Routing Pattern 2 : protocol-7.command.send.local

Use when: need the exact count of targets reached, or with a structured reply
handler that carries extra context params.

**Real example — `coding.resolve_model_path`:**
```perl
my $clients_reached = <[protocol-7.command.send.local]>->(
    {   'command'   => 'cube.models.get_path_by_amos',
        'call_args' => { 'args' => $model_amos_id },
        'reply'     => {
            'params'  => { 'model_amos_id' => $model_amos_id },
            'handler' => 'coding.handler.model_path_reply'
        }
    }
);

## returns integer: 0 = target offline, 1 = reached, N = broadcast ##
unless ( $clients_reached == 1 ) {
    ## target zenka not up yet, schedule retry ##
}
```

The `'params'` block passes extra context that arrives in the reply handler
alongside the response data — useful for correlating async replies when
multiple requests are in flight simultaneously.

---

## When to Use Which

| pattern | use case |
|---------|----------|
| `protocol-7.route-send` | fire-and-forget, simple callbacks, most inter-zenka calls |
| `protocol-7.command.send.local` | need reach count, structured reply with context params |
| `<[other.zenka.module]>->()` | **NEVER** across process boundary |
| `<[protocol-7.route-send]>` | correct syntax — `]>` before `->` |

---

## Zulum Stream State: is_true in cmd.step

The `zulum.cmd.step` module generates entropy and updates stream state.
It must update `is_true` on each step so cube-13 can query it:

```perl
## after computing $state ##
$stream->{'state'}    = $state;
$stream->{'entropy'}  = $state;
$stream->{'is_true'}  = is_true($state);    ## required for cube-13 jump true ##
$stream->{'iteration'}++;
```

The `is_true` function comes from `AMOS7::Assert::Truth` — already loaded by
the harmonic math modules.

---

## Decoder cmd.receive-entropy : Parameter Convention

`.cmd.` modules receive all input via `$call->{'args'}`, not `shift` or `$ARG[0]`.
The decoder command splits the space-joined args back into fields:

```perl
## decoder.cmd.receive-entropy ##
my $args_str = $call->{'args'} // '';
my ( $stream_id, $entropy ) = split m| +|, $args_str, 2;
```

This matches the format the zulum callback sends:
```perl
'call_args' => { 'args' => "$sid $entropy" }
```

---

## Summary: What Kimi Needs to Change

### zulum.cmd.stream-attach

Replace the raw socket write callback with `protocol-7.route-send`:

```perl
## phase 1 : attach consumer callback — routes via cube to decoder ##
my $callback = sub {
    my ( $sid, $entropy, $iteration ) = @ARG;
    <[protocol-7.route-send]>->(
        {   'command'   => 'decoder.receive-entropy',
            'call_args' => { 'args' => "$sid $entropy" },
        }
    );
};
push @{ $stream->{'attached'} }, $callback;
```

### cfg/zenki/cube/access.zenki

Add:
```
access.cmd.usr.zulum = decoder.receive-entropy
```

### zulum.cmd.step (Phase 2 prep)

Add `'is_true'` field update after computing state:
```perl
$stream->{'is_true'} = is_true($state);
```

---

## Buffer Initialization: Correct Pattern

### What went wrong in decoder

`decoder.zenka.init_code` initializes the level-5 buffer with a direct hash
assignment and uses the encoding level number as the key:

```perl
## decoder.zenka.init_code — what kimi wrote ##
<decoder.level5> = {
    'accumulator' => '',
    'bit_count'   => 0,
    'values'      => [],
    'buffer_name' => '5',    ## buffer level identifier ##
};
```

Then `receive_entropy` pushes directly:
```perl
push @{ $data{'buffer'}{5}{'data'} }, sprintf( "%02d", $val );
## size field never set → 'list buffers' shows n/a for bytes
```

Two mistakes:

**1. Numeric key `5` used as buffer name** — intentional (the "5" comes from
"level 5 = base32 layer" in the architecture), but wrong. Buffer names in P7
are always descriptive strings: `'host-status'`, `'perlmod-install'`,
`'zenka'`, `'acme-activity'`. The level number is context for the
implementation, not a name for the network-visible buffer. Should be
`'level-5-B32'` (combines level number and encoding type, readable in context)
or shorter `'base32'` / `'level-5'` depending on what is clearer at the call
site.

**2. Direct push without `base.buffer.add_line`** — `size` is never
initialized or updated. The `list buffers` display reads
`$data{'buffer'}{$name}{'size'}` for the bytes column; since it is `undef`,
it shows `n/a`. No overflow protection either — the buffer grows without
bound regardless of `max_size`.

### Correct pattern: discover.init_code

`discover.init_code` shows all three required steps:

```perl
## discover.init_code — reference implementation ##
if ( not exists <buffer.host-status> ) {
    <buffer.host-status.max_size> = 24 * 1024;    ## 24K buffer size ##
    my $log_level  = 0;
    my $log_msg    = 'host status buffer initialized ..,';
    my $time_stamp = <[base.anum_log_time]>->( 5, TRUE );
    <[base.buffer.add_line]>->(
        qw| host-status |,
        join( ' ', $time_stamp, $log_level, $log_msg ), $log_level
    );
}
```

1. **Guard with `not exists`** — idempotent across re-init
2. **Set `max_size` before first write** — prevents 63K fallback warning
3. **Use `base.buffer.add_line` for first write** — initializes `size` and
   `data` correctly, registers buffer with overflow protection

### What decoder.zenka.init_code should do

```perl
## correct decoder buffer initialization ##
if ( not exists <buffer.base32> ) {
    <buffer.level-5-B32.max_size> = 65536;    ## 64K rolling buffer ##
    my $time_stamp = <[base.anum_log_time]>->( 5, TRUE );
    <[base.buffer.add_line]>->(
        qw| level-5-B32 |,
        join( ' ', $time_stamp, 0, 'level-5 base32 accumulator initialized .., ' ), 0
    );
}
```

And `receive_entropy` updates both `data` and `size` — or delegates to
`base.buffer.add_line` if each extracted value is formatted as a log-style
line. The buffer key `'level-5-B32'` is what `list buffers` and
`show-buffer level-5-B32` will use — readable as "level 5, base32 encoding"
without needing to know the architecture doc.

---

## Test Sequence (Phase 1)

```bash
## 1. restart zenki to pick up changes ##
p7 v7 restart zulum
p7 v7 restart decoder

## 2. attach stream 1 to decoder ##
echo "zulum.stream-attach 1" | p7 zulum

## 3. step stream 1 once ##
echo "zulum.step 1" | p7 zulum
## expect: {"mode":"true","data":"stream 1 stepped"}

## 4. check decoder buffer — should have 8 base32 values (42 bits / 5) ##
echo "decoder.show-buffer 5" | p7 decoder
## expect: {"mode":"true","data":["01","23",...]}

## 5. multiple steps accumulate ##
for i in 1 2 3 4 5; do echo "zulum.step 1" | p7 zulum; done
echo "decoder.show-buffer 5" | p7 decoder
```

#,,.,,,..,,,.,,,.,,,.,,..,,,.,,,,.,.,,,,.,,,.,,..,,.,,,.,..,.,,,,.,..,,...,..

#,,,,,.,,,.,,,,..,,,,,.,.,...,,.,,.,,,..,,.,,,..,,...,...,...,,.,,..,,,,.,...,
#V2SAAIUOJV6J33DSS3STVS6POWJVVIW3ECMEILWOK7QZQBGPKOGYWPXEX2OGDV463OYKPXORS23GK
#\\\|HTYHYDW6OUI6Y7MAWGZB4LMQAW7HSM7WM7X2HNKBOWKIIPULIKL \ / AMOS7 \ YOURUM ::
#\[7]RB2AYQ6BWBSMIDLLI72FCDR63664IJCWRF47F7DTLLAEVIQHEWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
