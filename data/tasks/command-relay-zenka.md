## [:< ##

# name  = task: command-relay zenka — requirement note
# descr = new zenka: maps input commands/routes to output routes,
#         primarily for connecting two cube zenki (e.g. a local/core
#         cube and a DMZ-facing cube where externally-accessible
#         zenki connect)

## context

session: 2026-06-21. naming confirmed harmonically TRUE via `harmony
command-relay`. earlier candidate names ("firewall", "filter") were
considered and rejected — they describe one possible *aspect* (a
policy you can apply through the mapping) not the zenka's actual
nature, which is command/route mapping itself. filtering/firewalling
would be something built ON TOP of command-relay's mapping, not what
the zenka fundamentally is.

## what it does

```
basic shape: a command-mapping zenka — maps input commands/routes to
output routes. NOT a passthrough bridge — the mapping is the point.

primary use case: interconnecting two cube zenki, where one is the
local/trusted core and the other is externally-facing (a DMZ-style
cube where internet-reachable zenki like httpd/httpsd connect).
command-relay sits between them and decides what maps to what, rather
than the two cubes talking to each other directly.

this is the standard DMZ pattern applied to the zenki network: the
externally-reachable surface (httpd, httpsd, anything else accepting
outside connections) lives on its own cube, never directly bridged to
the trusted core cube — command-relay is the only thing standing
between them, and it only forwards what it's explicitly configured to
map, in whichever direction(s) that mapping is defined for.
```

## open, not yet designed

```
- mapping direction: bidirectional by default, or explicitly
  configured per route (DMZ -> core vs core -> DMZ likely need
  different default trust postures)
- relation to existing access-control layers (cube/access.zenki,
  per-zenka access.cmd.usr.cube, see [[feedback-access-grant-scope]],
  [[feedback-buffer-access-control]]) — command-relay's mapping table
  is presumably a NEW layer above/alongside these, not a replacement
- whether this is a single generic zenka with a configurable mapping
  table (config-driven), or whether each relay instance needs its own
  start-file-defined mapping (more explicit, less dynamic)
- relation to [[topic-hybrid-namespace-routing]]'s connection-type
  family (`HYBRID-CONNECTION-TYPE-ROUTING.md`) — a relay-zenki
  registering a tunnel/route was already one of that doc's three
  motivating cases; command-relay may be the concrete zenka that
  needs the `tunnel`/`route` connection type once that's built
```

## as a gateway adapter [ user 2026-10-09 ]

first read as the gateway zenka of
`data/md/design/NESTED-CUBE-NETWORK-SEGMENTATION.md` -- superseded the same
day by the decision below : the outer cube itself is the gateway
[ `ext-cube` ]. command-relay stays the optional mapping adapter between
outer and core cube, as a separate process. when used :

- direction : mappings are per direction [ outer -> core \ core -> outer ],
  the two sides carry different default trust
- access : the mapping is the relay's own layer ; behind it the core
  cube's access.zenki matches the full chain -- needs
  `data/tasks/needs-rewrite/base-has-access-source-sid-matching.md`
- tunnelling [ hop collapse ] and forensic logging as in the design doc
- the route chain shows `usr.cube.ext-cube.<source>` either way
- precedent : `cube-13` is a parallel cube network [ own address
  `protocol-7.network.zulum` ] and `zulum` already holds sessions to both
  cubes with per-side access lists -- command-relay adds the mapping between
  the two sides

## decision : ext-cube = the outer cube itself [ user 2026-10-09 ]

- the outer cube is the gateway : a cube instance serving the dmz segment
  [ its own public `ip.tcp` listener ] that connects to the core cube as
  `ext-cube`. remote clients dial it directly -- no accepting zenka in front
  [ it would duplicate cube's handshake \ link upgrade \ sessions ]. one
  hop fewer than a separate gateway process : chosen for performance
- the dmz segment can grow : zenki handling incoming users [ sessions,
  per-user state, rate limits, `authorization-buffer`, forensic watchers,
  later httpd \ httpsd ] talk through the outer cube without the core cube.
  minimal set-up = the outer cube alone
- command-relay becomes an OPTIONAL adapter between outer and core cube for
  paranoid set-ups [ a separate mapping process ], added later
- `external` stays outgoing only : it holds this host's link credentials and
  open links to other hosts, kept out of the process parsing unauthenticated
  input. each host : one way out [ external ], one way in [ outer cube ]
- the outer cube needs its OWN server key, signed by host-root [ `.dlg` ] so
  existing host pins hold ; the core cube's key never enters it

## status

requirement noted, not yet designed in detail or dispatched. revisit
when either DMZ-style external exposure becomes an actual near-term
need, or when [[topic-hybrid-namespace-routing]]'s connection-type
work progresses far enough that this zenka becomes its natural first
concrete consumer.

#,,,.,.,.,...,,,,,.,,,,..,,..,,,,,...,,,,,,,.,..,,...,...,.,.,,.,,,..,,..,,,,,
#UK6CE66XOZ6CWTOOFIXQMAXPDQAZJNDRM4BRXDMUR2U5X7S6KJZISDRKIFAUV44SADE5ZHLO2B37Y
#\\\|4F3HXCZ2PLLVK6FTTWM6D4OCCF6SSU3A2D7QAGSKXYMTR5FACDX \ / AMOS7 \ YOURUM ::
#\[7]QND5DY7A34OONFTUNGAL2HNAYBR6E5M262ZECYEUVJTPFTCQHGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
