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

## status

requirement noted, not yet designed in detail or dispatched. revisit
when either DMZ-style external exposure becomes an actual near-term
need, or when [[topic-hybrid-namespace-routing]]'s connection-type
work progresses far enough that this zenka becomes its natural first
concrete consumer.

#,,,.,,..,,,,,,,.,...,..,,,,,,...,,.,,.,,,,,.,..,,...,...,,.,,,.,,,.,,,,.,.,.,
#7COJWJEVTGX7ILWQJPDBCZ7J2JFVZSZ4P7RVXJBCHVDTKBGMBMEZHRYOHAYIHUQYUVMJHUYAMKVFK
#\\\|BJBME6QL3QCAJ3Q7ECK7KR4TE54EBBFCQL2LRENGBKV6KMYQF7W \ / AMOS7 \ YOURUM ::
#\[7]Z2MSSP2GITFCTPAZYBUXDZ6VYISRDFRKT6N2FRWJWDVQ2YSYBKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
