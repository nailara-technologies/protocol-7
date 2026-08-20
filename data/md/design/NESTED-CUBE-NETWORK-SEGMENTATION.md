## [:< ##

# nested cube network segmentation
# isolated sub-networks bridged by gateway zenki, transparent to both sides

---

## concept

zenki can form isolated sub-networks by running their own cube instance.
a gateway zenka bridges two networks by registering under different identities
at each boundary — transparent to both sides, visible only in the route chain.

```
main network:     [ v7 — cube — system — httpd — ... ]
                                  |
                            gateway zenka
                         (ext-cube on main side)
                         (cube on inner side)
                                  |
inner network:            [ httpd — web — ... ]
```

httpd and web communicate over the inner cube — isolated from main network
traffic. the gateway zenka is the only connection point between them.

---

## gateway zenka identity

the gateway registers at two cubes under complementary names:

```
main cube (inner):  registers as 'ext-cube'  ## main network sees it as external boundary
web cube (outer):   registers as 'cube'      ## web zenki see it as their cube
```

think of it as a satellite between two galaxies that have no direct contact.
the web galaxy is the external world — so from the main network's perspective
the gateway is ext-cube (connecting to the external). from the web galaxy's
perspective the gateway IS their cube — the only cube they know.

```
main network:     [ v7 — cube — ext-cube(gateway) ]
                                      |
web galaxy:               [ cube(gateway) — httpd — web ]
```

from the web galaxy's perspective: there is only one cube, and it is named
'cube'. the main network is completely invisible.

from the main network's perspective: ext-cube is a single zenka that
happens to proxy an entire isolated sub-network beyond it.

---

## route chain — departure route, closest hop first

with source alias propagation enabled, the full routing path is visible
to the destination as a departure chain (closest hop first):

```
v7 receiving a command from web via the inner network:

  usr.cube              ## v7's direct source is main cube
  usr.cube.ext-cube     ## main cube received it from the gateway (ext-cube)
  usr.cube.ext-cube.httpd  ## gateway received it from httpd
  usr.cube.ext-cube.web    ## httpd received it from web
```

each level is only visible if source aliases are propagated at that hop.
the gateway propagates its inner source into the outer chain automatically —
its job is transparent bridging, and identity propagation is part of that.

---

## gateway capabilities

the gateway zenka sits on every cross-network command path. it can:

**filtering**:
  block commands that inner zenki should not be able to send outward
  block commands that outer zenki should not be able to send inward
  enforce inner network isolation at the protocol level

**translation**:
  rewrite command names or parameters crossing the boundary
  adapt inner protocol versions to outer, or vice versa
  normalize auth tokens at the boundary

**rerouting**:
  redirect specific commands to different targets
  load-balance across multiple inner network instances
  failover: if inner cube is down, route to backup

**forensic triggers**:
  log all cross-boundary traffic with full source chains
  alert on anomalous routing patterns
  rate-limit commands by source identity or command type
  emit events to a monitoring zenka without modifying the command path

**access control**:
  enforce access policy at the boundary
  strip commands that are not in the allowed cross-boundary set
  upgrade: with require-source-trace, enforce chain integrity across boundary

---

## configuration

inner network starts its own cube:

```
## cfg/zenki/inner-cube/start
modules.load = cube ...
cube.name = inner-cube
```

gateway zenka connects to both:

```
## cfg/zenki/gateway/start
gateway.outer_cube = /var/protocol-7/run/cube.socket
gateway.inner_cube = /var/protocol-7/run/inner-cube.socket
gateway.outer_identity = ext-cube
gateway.inner_identity = cube
```

main v7 start-set-up includes gateway but not inner cube zenki:

```
## cfg/zenki/v7/start-set-up.base
cube
gateway     ## registers as ext-cube on outer, cube on inner
```

inner zenki are started by the inner cube or gateway, not by main v7.

---

## access control integration

with `base.has_access` hierarchical source matching (see
`data/tasks/base-has-access-source-sid-matching.md`):

```
## v7/start — allow web to call specific v7 commands via the full chain
access.cmd.usr.cube.ext-cube.web = v7.notify_online v7.register_child
```

this is precise: only web, routed through ext-cube (the gateway), can
call those v7 commands. httpd with the same route but different identity
gets a different permission set.

---

## nesting depth

the pattern scales to arbitrary depth:

```
cube.ext-cube.inner-cube.service
```

each level is a gateway zenka bridging two isolated networks.
source alias chains trace the full path regardless of depth.
access control rules remain readable — the chain IS the routing topology.

---

## tunneling mode — virtual hop elimination

the gateway has a second mode where it makes one or more hops disappear
from the route chain entirely. the outer galaxy's topology becomes invisible
to the inner network when the tunnel is active.

**static tunneling**:
  the gateway presents web as arriving directly at cube — no ext-cube hop
  visible in the source chain. from main network's perspective, web and httpd
  appear to be local participants, not members of an external sub-network.
  use case: legacy zenki that don't understand nested routes, or when the
  sub-network topology is an internal implementation detail.

**intelligent tunneling** (per-command or per-route):
  the gateway decides hop-by-hop whether to expose or collapse:
  - forensic/audit commands: full chain preserved, every hop visible
  - heartbeats, routine traffic: collapsed, inner topology hidden
  - high-trust commands: collapse (implicitly trusted sub-network)
  - anomalous patterns: full chain exposed, forensic trigger fires

```
## gateway config:
gateway.tunnel_mode         = intelligent
gateway.tunnel.expose_cmds  = v7.teardown v7.stop    ## always full chain
gateway.tunnel.collapse_cmds = heart notify_online   ## always collapsed
gateway.tunnel.default      = collapse               ## collapse by default
```

the gateway still has full knowledge of the inner topology for filtering
and logging — tunneling only affects what is *propagated* into the route
chain, not what the gateway itself sees. forensic logging happens before
the tunnel decision, so collapsed routes are still fully auditable at the
gateway.

**multi-hop tunneling**:
  deeper nesting — `cube.ext-cube.inner-cube.service` — can have tunnel
  zones at each boundary. a command entering from outside may have all
  intermediate hops collapsed, arriving as if directly from cube.
  the collapsed hops are recoverable from gateway logs if needed.

---

## relation to existing architecture

this is a P7-native network segmentation pattern. no new protocol needed:
- zenki already support multiple simultaneous cube connections
- source aliases already exist (optional, to be made mandatory)
- the gateway is just a zenka — same lifecycle, same auth, same routing

the isolation is provided by the inner cube's own access.zenki —
inner zenki can only talk to each other and the gateway, never to the
main network directly.

the gateway is the DMZ. the inner cube is the protected network.
the main cube is the outside world.

---

## open questions

- should the gateway zenka be a generic configurable zenka, or a
  purpose-built one per boundary? generic is reusable; purpose-built
  allows boundary-specific logic
- does the inner cube need its own v7 instance for lifecycle management,
  or does main v7 manage inner zenki through the gateway?
- require-source-trace interaction: if main cube enables it, does the
  gateway automatically propagate the requirement into the inner network?
  (yes, if the gateway honors the flag — it should, as part of its
  transparent bridging contract)

#,,,,,.,,,...,.,,,,,.,.,,,...,,,,,.,.,.,,,..,,..,,...,.,.,..,,..,,...,...,..,,
#5ZSIT473OMMS4GFCJTNI6S26SFJSCEF2GDR4L3N7QZBLGVI2ND2TDTFTVKWDZS3L53K3BQAIJG2AE
#\\\|654NL54YG43EYXGGQWAIJ2KZFBRMWPSK7W5VDDLX53533XS6GN3 \ / AMOS7 \ YOURUM ::
#\[7]YZIPMFJOOAN2CASLTTCKJKUNS5PCBCPMYYRY3I5WDORZZYFMKIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
