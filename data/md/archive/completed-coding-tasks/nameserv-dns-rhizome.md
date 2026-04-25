## [:< ##

# name  = [ kimi-task ] nameserv-dns-rhizome
# descr = add DNS TXT/SRV record publishing for orbital P7REF node discovery
#         implementing the DNS rhizome spec for public discoverability

## objective

extend the nameserv zenka to publish Protocol-7 node discovery records in DNS
TXT and SRV format, making nodes discoverable via standard DNS from anywhere on
the internet. this is the public-facing complement to the LAN multicast discovery
already implemented in the discover zenka.

## background

the DNS_RHIZOME spec (data/md/documentation/DNS_RHIZOME_ROADMAP.md and
data/asc/what-AI-thinks/markdown-form/protocol7/specs/DNS_RHIZOME.md) defines:

TXT record format:
  _protocol7._tcp.<domain>. TTL IN TXT "v=proto7 vm=<name> p7ref=<P7REF> ..."

SRV record format:
  _protocol7._tcp.<domain>. TTL IN SRV <priority> <weight> <port> <hostname>.

the nameserv zenka already has: set-record, get-record, zone.save, zones.load,
start_listener (UDP DNS server). it needs commands to publish node orbital data
as DNS records automatically.

## modules to create

### nameserv.cmd.publish-node
- command: publish-node <domain> [port] [ttl]
- retrieves orbital P7REF from <nodes.orbital.current_p7ref> via route-send
- retrieves node name from <system.zenka.name> or config
- retrieves local IP from <nodes.orbital.local_ip> (set by nodes.orbital.init_code)
- constructs TXT record: "v=proto7 vm=<name> p7ref=<P7REF> harmonic=384615"
- constructs SRV record pointing to hostname:port
- calls nameserv.cmd.set-record for both TXT and SRV
- calls nameserv.zone.save to persist
- logs at level 2: "published node <name> as _protocol7._tcp.<domain>"
- returns { mode => true, data => "published TXT + SRV for <domain>" }

### nameserv.cmd.discover-nodes
- command: discover-nodes <domain>
- performs DNS TXT lookup for _protocol7._tcp.<domain>
- uses Net::DNS::Resolver (already loaded in nameserv.init_code)
- parses returned TXT records for v=proto7 prefix
- extracts p7ref field from each matching record
- stores results in <nameserv.discovered>->{$domain} = [ { name, p7ref, ... } ]
- logs at level 2 for each discovered node
- returns formatted list of discovered nodes

### nameserv.orbital.auto_publish
- called from a repeating timer (interval 777, repeat TRUE)
- checks if <nameserv.cfg.auto_publish_domain> is configured
- if so, calls publish-node automatically to keep record fresh
- updates TTL to match the timer interval
- this keeps the DNS record current as the orbital P7REF changes every 13s
  (note: DNS TTL can be longer than orbital update interval — just refresh
   the record periodically, not every 13 seconds)

### nameserv.handler.p7ref_lookup
- handles incoming DNS queries for _protocol7._tcp records
- extends existing nameserv.handler.query to recognise _protocol7._tcp pattern
- returns both TXT and SRV records when available in the zone
- allows external nodes to discover us via standard DNS query

## modules to modify

### nameserv.init_code
- add: <nameserv.discovered> //= {}
- add: <nameserv.cfg.auto_publish_domain> //= undef
- add timer setup for nameserv.orbital.auto_publish IF domain configured:
  if defined <nameserv.cfg.auto_publish_domain>:
    <[event.add_timer]>->({ interval => 777, repeat => TRUE,
                            handler => 'nameserv.orbital.auto_publish' })

## existing infrastructure to use

- Net::DNS, Net::DNS::Packet, Net::DNS::RR — already loaded in nameserv.init_code
- nameserv.cmd.set-record — existing, use to store the records
- nameserv.zone.save — existing, use to persist after publishing
- nameserv.zone.lookup — existing, use in handler
- <nodes.orbital.current_p7ref> and <nodes.orbital.local_ip> from nodes zenka
- <[protocol-7.route-send]> to reach nodes zenka for orbital data

## style reference

read data/yaml/docs/protocol-7-coding-style.md before writing any code —
it contains essential P7 module conventions that prevent common mistakes.

## CRITICAL notes

- $ARG not $_ throughout
- lowercase comments only
- timer syntax: { 'interval' => 777, 'repeat' => TRUE }
- route-send returns count not reply — use reply handler for async data
- Net::DNS::Resolver->new for outbound queries (discover-nodes command)
- the existing nameserv UDP listener handles inbound queries
- do NOT add fake signature stubs

## signatures note

do NOT add, verify, or modify AMOS7 signatures. leave new files clean.

## deliverables

1. modules/nameserv.cmd.publish-node
2. modules/nameserv.cmd.discover-nodes
3. modules/nameserv.orbital.auto_publish
4. modules/nameserv.handler.p7ref_lookup
5. modified modules/nameserv.init_code (add discovered hash + timer)

#,,,,,..,,,.,,,.,,...,...,,,.,.,,,,,.,.,.,,,,,..,,...,...,.,.,,,,,,..,.,,,,..,
#O374UISYHI3O7DVT4RHNUJQ5BB64OAP6JTUU6AT3DBVRSCSNSTWWCK6ONK2O7B5KWFLE74ZBQNPGG
#\\\|EG2T4T2KIQBO4JG7TYZBTWM554JGP54UDS3G6NMCXVETMRMAQBM \ / AMOS7 \ YOURUM ::
#\[7]YBFV2LEVFLV4TYEWBSKDRY45MP76ZZA7V2AGDNM5GLCANJB672DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
