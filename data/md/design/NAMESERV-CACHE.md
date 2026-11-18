# nameserv forwarding cache

## scope

`nameserv[cache]` is the server profile and `nameserv[cache-local]` is the
linux desktop profile. both reuse the nameserv packet parser, reply builder,
udp listener, and tcp connection handling. neither profile performs recursive
resolution or changes `resolv.conf`.

the profiles are selected with:

```
v7-zenki.start nameserv[cache]
v7-zenki.start nameserv[cache-local]
```

their settings live under `nameserv.cfg.by_subname` in
`cfg/zenki/nameserv/zenka.v7`. both bind udp and tcp port 53 to `127.0.0.1`
and `::1`. the upstream list is a space-separated p7 config value. host-local
overrides belong in the usual nameserv host config.

## client boundary

cache service is limited to `127.0.0.0/8`, `::1`, and ipv4-mapped loopback.
`nameserv.cache.client_allowed` checks the numeric peer address in code. both
the udp query path and every framed tcp query enforce it independently of the
bind configuration. other clients receive the existing authoritative `REFUSED`
answer and cause no cache lookup or upstream traffic.

the default unnamed nameserv instance remains authoritative with cache mode
disabled. a cache instance answers authoritative names from its own zone
directory and forwards only recursive queries outside those zones.

## cache behavior

entries are keyed by lower-case question name, type, and class. a hit returns
a fresh packet with the client's transaction id and question casing. record
ttls decrease with entry age and expire at the lowest applicable ttl.

positive entries honor answer and authority ttls up to `max_ttl`. negative
answers follow rfc 2308: the lower of the soa ttl and minimum field is used,
capped by `max_negative_ttl`. negative answers without an soa are not cached.
truncated replies, `SERVFAIL`, `REFUSED`, and zero-ttl answers are not cached.

the entry count is bounded by `max_entries`; entries nearing expiry are evicted
first. simultaneous misses for one question share one upstream exchange while
retaining separate client ids and delivery callbacks.

## upstream exchange

each attempt uses a connected non-blocking `IO::Socket::IP` socket on the zenka
event loop. `base.prng.bytes` supplies both the 16-bit transaction id and an
ephemeral source port in the range 49152 through 65535. the original question,
class, and edns data are preserved while `rd` is set for the upstream.

udp replies must arrive from the selected upstream address and port and match
the pending transaction id and complete question. malformed or mismatched
datagrams are dropped without completing or advancing the attempt. timeout or
socket failure selects the next configured upstream; exhaustion produces
`SERVFAIL` for every waiter.

a valid udp reply with `tc` set is not cached or delivered. the same upstream
is retried over non-blocking tcp with a fresh prng-selected source port and
transaction id. tcp connect, framed writes, and framed reads remain on the
same timeout and reply-validation path.

## verification

`bin/test-scripts/test-nameserv-cache.pl` compiles the real modules and uses
stub upstream sockets on high loopback ports. it covers hits, ttl aging and
expiry, rfc 2308 negative caching and its cap, bounded eviction, loopback
refusal on udp and tcp, mismatched-id dropping, upstream fallback, in-flight
coalescing, and tcp retry after truncation. no live zenka or system resolver
configuration is used.

#,,,,,,,,,..,,,,,,.,.,.,.,.,.,,..,,,,,,,.,,,.,..,,...,...,...,.,,,,.,,,,,,,..,
#4RIBRS7AI7FUSW52G7UUHCBOLKCJBZUEXOLTWZ6OJ777TQVQ3UIYXYYVTIKPUFUU4KCWLWGZTYD5C
#\\\|JN2SKYAPEKMVWY4APPHWBSPLBAOECUH5V7PJCEERZJHM22J2MJ6 \ / AMOS7 \ YOURUM ::
#\[7]ZK3BZDYLO4XEOIVOYGDVANNTAQMCDS5ZE6YC25HSCFNY7HCYE2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
