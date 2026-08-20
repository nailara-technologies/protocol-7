# concept: security and forensics architecture

## security zenki and network patrol

even before llms, custom security zenki were planned to actively patrol the
network — not passive log watchers but agents that roam, respond, and can be
called by any other zenka to handle potential intrusion anomalies and security
incidents. capabilities include:

- **active patrol**: security zenki traverse the network topology looking for
  anomalous behavior patterns
- **callable escalation**: any zenka detecting something suspicious can call
  a security zenka directly to handle the incident
- **core-dump triggering**: compromised or suspicious processes can have their
  memory captured live — process state preserved at the moment of suspicion,
  not reconstructed after the fact
- **forensics pipeline**: core dumps and captured state are exported to forensics
  zenki with sufficient capability to analyze them — evidence preserved before
  a human is even aware something happened
- **regex-based network intelligence**: pattern matching as a first-pass fast
  detection layer across network traffic and event streams

## layered reachability — channels and discover zenki

the `channels` zenka provides encrypted pub/sub channels — security and forensics
zenki are natural subscribers to dedicated security and forensics channels. traffic
on these channels is isolated and encrypted independently of general network traffic.

the `discover` zenka uses multicast to announce node presence even before a dedicated
protocol-7 connection is established — nodes can find each other and reach the network
without pre-configuration or an existing connection.

discover packets already contain: host name, host key, ip address, interface name,
and hardware address (hwaddr / MAC). the MAC is harvested passively from live nodes
and stored by the nodes zenka — solving the bootstrap problem of wake-on-lan
elegantly: you get the MAC while the host is alive, so you can wake it after it sleeps.

```
discover.list nodes output:
  host  :  host key  :  ip addr  :  iface  :  hwaddr
```

together these create layered reachability for incident escalation:

```
normal:      node → p7 connection → channels zenka → security zenka
degraded:    node → channels zenka → security zenka  (direct, no routing)
last resort: node → multicast → any reachable security zenka
```

a compromised or struggling node can multicast for help far before it loses that
capability — no established p7 connection required. the scenario where help was
available but simply not notified becomes structurally unlikely: each reachability
layer is independent, losing the outer one does not silence the inner ones.

## nodes zenka and wake-on-lan

the `nodes` zenka already integrates with `discover` and maintains awareness of
known nodes in frequented networks:

```
modules/nodes.init_code
modules/nodes.handler.discover_node_online
modules/nodes.handler.discover_details_reply
modules/nodes.callback.local_network.offline-node
modules/nodes.send_host_details_request
modules/nodes.parser.connection_status
modules/nodes.parser.connection_target
modules/nodes.parser.node_pkey
modules/nodes.cmd.host-status
modules/nodes.cmd.add-group-user
modules/nodes.cmd.add-trunc
modules/nodes.cmd.update-protocol-elf
```

planned: wake-on-lan capability so node availability can be managed with priority
levels — the MAC address needed is already available from discover packets:

| priority | behavior |
|----------|----------|
| P0 | always on, never sleep |
| P1 | wake on demand — security incident, active forensics need |
| P2 | wake for scheduled tasks — nightly forensics run at 04:07 |
| P3 | deep sleep, wake only on critical escalation |

this makes the forensics and security pipeline fully autonomous end-to-end:
forensics zenka needs analysis capacity → nodes zenka wakes P2 nodes → job runs
→ nodes return to sleep. security escalation needs a specific node →
nodes zenka wakes it at P1 priority → investigation proceeds.

## forensics zenka

a nightly forensics zenka is already scheduled in the events timetable
(`cfg/zenki/events/event-setup.base`, 04:07, `type = zenka-present`).
the slot has existed for years — it wakes when implemented, does nothing until then.

with parameter-preserving compressed buffers as input (see
`CONCEPT-CONTEXT-AWARE-LOG-MANAGEMENT.md`), the forensics zenka has exactly what it
needs: pre-grouped anomalies with triggering parameters already isolated. nightly
analysis becomes pattern detection across sessions:

- "outlier cluster appeared 3 of last 7 nights, always peer=10.0.0.7, queue_depth > 10"
- "dist-upgrade zenka absent for 4 consecutive nights — dependency drift likely"
- "authentication timing anomaly correlates with logfile rotation window"

## llm augmentation

llms change the detection capability qualitatively — rule-based systems catch
known patterns; llms find unknown ones and then write the rules to catch them
deterministically next time. the detection layer compounds:

```
patrol detects anomaly  →  llm analyzes, identifies pattern
  →  llm generates detection rule  →  rule added to patrol logic
    →  next occurrence caught deterministically, no llm needed
```

the whole network topology becomes the detection surface — every zenka is a
potential sensor, security zenki are the response layer, forensics zenki are
the analysis layer, and the llm is the rule-synthesis layer that makes the
whole system smarter after each incident.

## see also

- data/md/concepts/CONCEPT-CONTEXT-AWARE-LOG-MANAGEMENT.md
- data/md/documentation/LOGGING-AND-VERBOSITY-REFERENCE.md
- data/md/concepts/CONCEPT-SELF-MORPHING-CODE-STYLE-CONVERGENCE.md
- cfg/zenki/events/event-setup.base
- modules/nodes.*

#,,.,,,,.,,,,,.,.,,,,,,,.,,.,,,..,..,,,,,,.,,,..,,...,...,...,..,,..,,,..,.,,,
#43A6PLCK7HSVRMUQVMAYYNWTC43C7XCDNIMAJPMYFS746NSO3DENFCME5H2GAQEFZM7WEBCXQE4KO
#\\\|XLC4HSK3SHFJZQTALCZBDQDIWPZAQCKVYLT2MJNMPONW33XBKLG \ / AMOS7 \ YOURUM ::
#\[7]BBAGIY4MYPNQXVDYC7LMDLO4FGHAC3XKA4FYIAETCNXZOPSCFIDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
