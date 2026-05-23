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

## codebase findings

### existing patterns to reuse

**Async HTTP/HTTPS client modules (18 files):**
- `modules/clients.http.init_code`, `clients.http.pre_init`, `clients.http.request`, `clients.http.get`, `clients.http.post`, `clients.http.parse_response`, `clients.http.handler.io`, `clients.http.handler.timeout`, `clients.http.cleanup`
- `modules/clients.https.init_code`, `clients.https.pre_init`, `clients.https.request`, `clients.https.get`, `clients.https.post`, `clients.https.handler.handshake`, `clients.https.handler.io`, `clients.https.handler.timeout`, `clients.https.cleanup`

These provide the **baseline TCP connection pattern** that `transport.handle.direct-tcp` should follow:
- `IO::Socket::IP->new(PeerHost, PeerPort, Type=>SOCK_STREAM, Timeout=>7)` → blocking connect → `$sock->blocking(0)` → register `<[event.add_io]>` with `poll=>'r'` and handler → timer watcher for timeout.
- For HTTPS: `IO::Socket::SSL->start_SSL(..., SSL_startHandshake=>0)` → non-blocking handshake via `clients.https.handler.handshake`.
- Socket I/O primitives: `<[base.s_read]>->($sock, \$chunk, 65536)` for reads; direct `syswrite` for writes.
- **Reuse for:** `transport.handle.direct-tcp` can wrap `clients.http.request` and `clients.https.request`, adding quality measurement hooks around connect, read, and write operations.

**Network primitives in `modules/base.net.*`:**
- `modules/base.net.connect` — core cube connection logic supporting `unix`, `ip.tcp`, and `pipe` types. Authenticates via `auth.zenka.authenticate` or `auth.unix.authenticate`. Calls `<[base.session.init]>` on success.
- `modules/base.net.send_to_socket` — writes data to client filehandle, respects session-bound `output.handler` filter chain, tracks `bytes.in`.
- `modules/base.net.client.auth_with_pwd` — plain-text password auth client-side.
- Underlying: `base.s_read`, `base.s_write`, `base.open` (used as `<[base.open]>->(qw| ip.tcp output |, $host, $port)` for blocking TCP).

**Cross-zenka dispatch via `protocol-7.route-send`:**
- `modules/base.protocol-7.route-send` — prepends `protocol-7.network.parent_route` hops to a command string and calls `<[protocol-7.command.send.local]>->($params)`.
- Used by `radio.handler.stream-chunk` to send commands to `mpv[audio-0]`:
  ```perl
  <[protocol-7.route-send]>->(
      {   'command'   => 'mpv[audio-0].fade',
          'call_args' => { 'args' => '0' },
      }
  );
  ```
- **Reuse for:** transport selector can use route-send to query remote cube nodes for transport availability (UDT endpoint registration, hysteria status).

**SIZE / STRM-SIZE protocols:**
- Documented in `data/md/documentation/SIZE_PROTOCOL_MODES.md`. Default character-count framing for p7 responses.
- `STRM-SIZE` transparently fragments large responses across zenki-to-zenki routes. Cube fragments, reassembles, delivers as single SIZE response with idle + absolute dual timers.
- **Reuse for:** if the transport selector needs to stream large data or push quality metrics to other zenki, STRM-SIZE is the native path.

**External transport registry (`modules/external.init_code`):**
- Already initializes `<external.transports>` with `available`, `preferred`, `registry`, `connections`, and `stats` (`bytes_sent`, `bytes_received`, `connections_ok`, `connections_fail`).
- Also initializes `<external.bridges>` and `<external.connections>`.
- Has auto-connect logic to orbital neighbors.
- **This is a significant existing foundation.** The transport selector can extend `<external.transports>` rather than invent a new registry.

**UDT transport stub (`modules/plugin.external.udt.init_code`):**
- Checks for `UDT::Simple` Perl module.
- If available, registers `udt` in `<external.transports>->{'registry'}` with capabilities: `reliable`, `ordered`, `message_oriented`, `high_bdp`, `nat_traversal`. Priority 100.
- Default config: `default_port: 9000`, `listen_backlog: 128`, `buffer_size: 8192`, `timeout_ms: 5000`.
- **Reuse for:** `transport.handle.udt-tunnel` should build on this stub rather than start from scratch. The stub already knows how to register with the external transport system.

**SSH tunnel reference (`modules/ssh.connection.start`):**
- Uses `Net::SSH2` + `IO::Socket::IP`. Authenticates via public key, verifies remote hostkey against configured ELF+BMW224 hashes.
- Opens `tcpip` channel to remote proto-7 address/port.
- Registers `ssh.handler.ssh_io` IO watcher and heartbeat timer.
- Tracks `latency` field (initialized to `'unknown'`).
- **Reuse for:** heartbeat timer pattern and IO watcher registration for persistent tunnels.

### integration points confirmed

**Proxy zenka stub replacement:**
- The proxy task defines `proxy.transport.select` as a stub returning `'direct'`.
- The transport selector should register its main entry point at `transport.select` (or keep `proxy.transport.select` as an alias for backward compatibility during transition).
- The interface is fixed: `<[transport.select]>->($context)` → transport config hashref.

**Credential fabric at connection time:**
- Transport profiles reference credential slots (e.g., `atom.udt-psk`, `atom.hysteria-auth`).
- At connection time, the transport handle calls `<[credential.resolve]>->($transport->{'credential'})`.
- This matches the credential fabric task's `credential.resolve` interface.

**Where profiles live:**
- The task spec says `data/yaml/transport/profiles/`. This directory **does not exist yet**.
- Existing YAML config patterns in the codebase use `AMOS7::13::read_yaml` or similar. The transport selector should follow the same loading convention.

### naming conflicts or overlaps

- `modules/external.init_code` already owns the `<external.transports>` registry. The transport selector's state should nest under this or use a distinct namespace like `<transport.profiles>` to avoid collisions.
- `modules/ssh.connection.start` uses `ssh.handler.ssh_io`. Transport handlers should use `transport.handler.*` to avoid collision.
- `modules/plugin.external.udt.init_code` already registers `udt` in `<external.transports>`. `transport.handle.udt-tunnel` should coordinate with (or replace) this stub rather than create a parallel registration.
- **No existing `modules/transport.*` files** — the namespace is clean.

### gaps in the task spec

1. **No connection-quality measurement infrastructure exists.** The task assumes `loss_rate`, `rtt_ms`, `goodput_kbps` can be measured. There are no RTT probes, packet-loss counters, or throughput testers in `modules/`. These must be designed from scratch.
2. **Hysteria is a manual workaround, not a p7 module.** The task lists `transport.handle.quic-hysteria` but there is zero QUIC code in the codebase. The hysteria binary runs externally (SOCKS5 at `10.0.110.7:1040`, HTTP proxy at `:4040` per `data/docker-script/Dockerfile.cuda-build`). The stub should call an external hysteria client or SOCKS5 proxy, not implement QUIC in Perl.
3. **UDT is only a stub.** `UDT::Simple` may not be installed. The scratchpad tests in `bin/dev/script-scratchpad/udt_test_*.pl` show basic usage but no integration with the event loop. The transport selector needs to bridge UDT sockets to the p7 `event.add_io` system.
4. **Graceful degradation timer/probe mechanism is underspecified.** How are demoted transports probed? A background timer per demoted transport? A single global probe timer? The task says "probed on a background timer" but doesn't specify the implementation pattern. The existing heartbeat pattern in `ssh.connection.start` is a good model.
5. **What is a "transport handle"?** The task says `transport.select` returns "a ready transport handle." Is this a socket? A session ID? A coderef? The proxy needs to know what to do with it. The `base.net.connect` pattern returns a connected socket — this is the most natural definition.
6. **`data/yaml/transport/` directory does not exist.** The task assumes profile loading from this path. It needs to be created.
7. **No default profile exists.** The task mentions `data/yaml/transport/profiles/default.yaml` but it doesn't exist. The transport selector needs a hardcoded fallback if the directory is missing.
8. **Quality measurement for passive connections.** "Observe loss/rtt from live traffic" is easy to say but hard to do for generic TCP. For HTTP, we only see application-level retries/timeouts. For UDT, `UDT::Simple` may expose `perfmon`. For hysteria (external SOCKS5), we have no visibility. The task should distinguish between:
   - **Application-level quality** (HTTP timeout ratio, retry count) — always available
   - **Transport-level quality** (packet loss, RTT) — only available from transports that expose it

### suggested refinements

1. **Leverage `<external.transports>` registry instead of a new one.** `external.init_code` already has `available`, `preferred`, `registry`, `connections`, `stats`. The transport selector should extend this structure:
   ```perl
   <external.transports>->{'profiles'}{'atom.host'} = \%profile;
   <external.transports>->{'quality'}{'udt-tunnel'}{'atom.host'} = \%quality;
   <external.transports>->{'demoted'}{'atom.host'}{'udt-tunnel'} = $ntime;
   ```
   This keeps transport state in one place and avoids namespace fragmentation.

2. **Define the transport handle concretely.** A transport handle should be:
   ```perl
   {
       type     => 'direct-tcp',      # or 'udt-tunnel', 'quic-hysteria'
       socket   => $sock,             # connected socket (or undef for external)
       endpoint => 'atom:443',        # host:port
       proxy_url=> 'socks5://...',    # for external proxies like hysteria
       quality  => \%quality_hash,    # live quality metrics
       credential => $cred_handle,    # from credential fabric
   }
   ```
   The proxy then branches on `type`: for `direct-tcp` it uses the socket directly; for `quic-hysteria` it treats `proxy_url` as a SOCKS5/HTTP proxy for `clients.http.request`.

3. **Implement `transport.handle.quic-hysteria` as a SOCKS5-aware HTTP client wrapper, not QUIC.** Since hysteria runs externally and exposes SOCKS5 + HTTP proxy, the "hysteria transport" is really "HTTP client that routes through a local SOCKS5 proxy." Reuse `clients.http.request` with `LWP::UserAgent` proxy settings or `IO::Socket::Socks`.

4. **Add `transport.quality.derive_passive` module.** For transports without native quality APIs, derive quality from application-layer observations:
   - timeout_count / request_count = loss_rate proxy
   - response_time_sample = rtt_ms proxy
   This is always available and good enough for the degradation decision.

5. **Use `ssh.connection.start` heartbeat pattern for probes.** A single global probe timer (`event.add_timer`) fires every 30s, walks demoted transports, attempts a lightweight connect (or HTTP HEAD), updates quality, promotes on success.

6. **Add `transport.handle.socks5` as a shared helper.** Both hysteria and potentially other external tunnels use SOCKS5. A single `transport.handle.socks5` that wraps `IO::Socket::Socks` and presents a connected socket avoids duplication.

## refined module list

**Additions:**
- `modules/transport.handle.socks5` — shared SOCKS5 client for external tunnel proxies (hysteria, future WireGuard SOCKS5, etc.)
- `modules/transport.quality.derive_passive` — application-layer quality proxy when transport doesn't expose native metrics
- `modules/transport.probe.timer` — global probe timer, walks demoted transports (extracted from `transport.quality.probe` to separate timer orchestration from probe logic)

**Renames:**
- `modules/transport.handle.quic-hysteria` → `modules/transport.handle.hysteria-socks5` (clarifies that it uses the external SOCKS5 proxy, not native QUIC)

**Removals (none):** the original list is otherwise sound.

#,,.,,,.,,,,.,,,.,.,.,,,.,...,,,.,.,,,,.,,...,..,,...,...,..,,..,,,..,,..,.,,,
#EBZV333P7S7FXCMUGI2MVC2VJVPMR5WNGO4GDOQOYUAIDQKUK6YQ4HJLHN64MX6DSBLHKKJ5GS6R2
#\\\|M6ABJZ5W3GSHBFVN3JYDNELI4ACXOHGZ5VZBUVF25D2SFHV7AQ2 \ / AMOS7 \ YOURUM ::
#\[7]PX3JCSFZ2MAMKUWTUZIQEM4TFINVCCTAOILKUDBEZOK6NTNCIEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
