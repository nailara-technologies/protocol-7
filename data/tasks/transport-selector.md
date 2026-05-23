# task: transport selector — priority list with graceful degradation

## context

the proxy zenka needs a transport layer below it that selects how outbound
connections are made. the current state is direct TCP only. the target state
is a priority-ordered list of transport types with graceful degradation when
a transport fails or degrades below a quality threshold.

the immediate motivating case: this host connects to atom over a mobile
provider route with ~80% packet loss on one hop. TCP is unusable. hysteria
(QUIC-based) is currently running locally as a workaround. the transport
selector replaces that manual workaround with a p7-native, config-driven,
self-healing transport stack.

design reference: `data/md/design/TEMPLATE-RESOLUTION-ENGINE.md`
(transport selector is one face of the proxy cube — orthogonal to template
resolution but using the same request context hash)

## the priority list model

transport selection is config-driven per destination context. the selector
walks the list until a transport succeeds:

```yaml
# data/yaml/transport/profiles/atom.yaml
context:
  destination: atom.host
  tags: [ mobile, high-loss ]

transports:
  - type:       udt-tunnel
    endpoint:   atom:7000
    credential: atom.udt-psk       ## ref to credential slot
    min_quality: { loss_max: 0.95 }

  - type:       quic-hysteria
    endpoint:   atom:443
    credential: atom.hysteria-auth
    min_quality: { loss_max: 0.95 }

  - type:       direct-tcp
    credential: ~
    min_quality: { loss_max: 0.30 }  ## useless above 30% loss

fallback:       direct-tcp           ## always try, even if below min_quality
```

the proxy calls `<[transport.select]>->($context)` and gets back a ready
transport handle. it never needs to know which type was chosen.

## graceful degradation

when a transport fails or its measured quality drops below `min_quality`,
it is demoted — skipped on the next selection pass — and the next entry
in the list is tried. when quality recovers, it is promoted back.

```
normal state:    udt-tunnel active, quality good
                 → all requests use udt-tunnel

udt degrades:    loss spikes above min_quality threshold
                 → udt demoted, quic-hysteria promoted to active
                 → udt probed on a background timer

udt recovers:    probe succeeds, quality back above threshold
                 → udt promoted back to active

all fail:        fallback transport used regardless of quality
                 → error logged, degraded mode flagged in context hash
```

demotion is temporary. the selector retries demoted transports on a
configurable probe interval (default 30s). no transport is permanently
removed from the list at runtime — only config changes do that.

## transport quality measurement

quality is measured per active transport connection:

```perl
{
    loss_rate     => 0.0,    ## packet loss ratio 0..1
    rtt_ms        => 0,      ## round-trip time in milliseconds
    goodput_kbps  => 0,      ## effective throughput
    last_measured => $ntime,
    consecutive_failures => 0,
}
```

measurement is passive for active connections (observe loss/rtt from live
traffic) and active for probes (small ping-style check on demoted transports).

## per-transport credential references

each transport entry carries an optional credential reference. the credential
slot is resolved via the credential fabric at connection time:

```perl
## transport selector calls:
my $cred = <[credential.resolve]>->( $transport->{'credential'} );
## → returns opaque credential handle
## → credential zenka performs auth, proxy never sees the secret
```

the credential reference is a slot name, not a value. the credential fabric
resolves it. this means rotating credentials don't require transport config
changes.

## context-aware profile selection

the selector chooses which profile to use based on the request context hash:

```perl
## profile selection priority:
1. explicit destination match    ## context.session.destination == 'atom.host'
2. tag match                     ## context.transport.tags includes 'mobile'
3. subnet/domain pattern         ## regex on destination
4. default profile               ## data/yaml/transport/profiles/default.yaml
```

profiles are loaded from `data/yaml/transport/profiles/`. adding a new
destination-specific profile requires no code change.

## dynamic selection — future layer

the current task implements static priority + graceful degradation.
dynamic selection (auto-learn which transport works best per destination,
time-of-day, link conditions) is a future layer that writes back into the
same priority structure:

```
static config     → defines the priority list and quality thresholds
graceful degradation → runtime demotion/promotion within the list
dynamic selection → future: adjusts priority order based on observed history
```

the dynamic layer is not needed now. the interface it will use — mutating
the priority list at runtime — is already the natural operation of the
selector. the config is the interface today; the learner mutates it later.

## modules to create

- `modules/transport.init_code` — load profiles, initialize quality state
- `modules/transport.select` — main entry point: context → transport handle
- `modules/transport.profile.load` — load + cache profile yaml for destination
- `modules/transport.profile.match` — match context hash to profile
- `modules/transport.quality.measure` — update quality metrics for active transport
- `modules/transport.quality.probe` — active probe for demoted transports
- `modules/transport.demote` — mark transport as demoted, schedule probe timer
- `modules/transport.promote` — restore demoted transport after probe success
- `modules/transport.handle.direct-tcp` — direct TCP connection handler (baseline)
- `modules/transport.handle.quic-hysteria` — hysteria tunnel handler (stub, config-driven)
- `modules/transport.handle.udt-tunnel` — UDT tunnel handler (stub, implement when lib available)

## configuration

`data/yaml/transport/profiles/default.yaml` — baseline profile, direct TCP only
`data/yaml/transport/profiles/atom.yaml` — atom host profile (UDT + hysteria + TCP)

transport zenka is on-demand — started when first needed by the proxy.

## integration with proxy zenka

the proxy skeleton (`proxy-zenka-skeleton.md`) has a stub at:

```perl
<[proxy.transport.select]>->($context)   ## → transport config hashref
```

this task replaces that stub. the interface is fixed — the proxy does not
change when this task is implemented.

## harmony checks

```
harmony transport.init_code
harmony transport.select
harmony transport.profile.load
harmony transport.quality.measure
harmony transport.demote
harmony transport.promote
```

## signatures note

do not modify or regenerate any AMOS7 signature lines. the signing system
handles all footer blocks — leave them untouched.

#,,.,,,,.,,.,,,,,,,..,,.,,,,,,,..,.,,,.,.,..,,..,,...,...,...,.,.,,.,,,..,..,,
#L6LJ6CTX6DWEL5UWTPMO44WG6DHEPOXL4M37ARDNRS2RTHV3QURVWQIMJLT7ZBUPLZQ4HEH4CZVHS
#\\\|VBM4DTN5F5TFGUPOQUMW3B2LI25GVBVWZGNOC7SRRS4GRD4KB4A \ / AMOS7 \ YOURUM ::
#\[7]S3Z6YVNFEMUQEWJU4KRHIJU6LPZLXOZSLYTLHPF2AVOZ34GNDYDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
