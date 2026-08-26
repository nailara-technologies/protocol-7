## [:< ##

# name  = [ kimi-task ] discover-orbital-relay
# descr = extend discover zenka to broadcast + receive orbital P7REF addresses,
#         enabling instant satellite relay of local grid map fragments

## objective

extend the discover zenka to include orbital addresses in its mcast broadcast
packets, and to extract + relay grid map fragments when receiving packets from
other nodes. each node that receives an orbital broadcast becomes an instant
satellite relay into its own local neighbourhood.

## background

nodes.orbital.* (recently implemented) computes a time-derived P7REF for each
node: NODE:CHKSUM7:ADDR_B32, stored in <nodes.orbital.current_p7ref>.

the discover zenka broadcasts HOST packets via multicast. extending these packets
to include the orbital P7REF enables:
1. receiving nodes to store the sender's orbital address
2. receiving nodes to share their own grid map fragment back
3. cascade relay: A broadcasts → B receives → B relays A into B's neighbourhood

the relay cascade means the full local network discovers itself in O(hops) rounds
rather than requiring everyone to receive everyone's direct broadcast.

## modules to create

### discover.orbital.get_local_p7ref
- utility: retrieve <nodes.orbital.current_p7ref> via route-send to nodes zenka
- returns the current NODE:CHKSUM7:ADDR_B32 string
- if nodes.orbital not running, returns undef gracefully (don't crash)
- log at level 3 if unavailable

### discover.orbital.store_remote
- called when a HOST packet containing an orbital P7REF is received
- params: hostname, pkey (b32), p7ref string
- store in <discover.orbital.known>->{$pkey_L13} = { hostname, pkey, p7ref,
  timestamp }
- log at level 2: "orbital address received for $hostname: $p7ref"

### discover.cmd.list-orbital
- command handler: list all known orbital addresses
- uses existing list infrastructure pattern
- returns formatted table: hostname | pkey (first 7 chars) | p7ref | age

### discover.orbital.share_grid_fragment
- called after successfully processing an incoming HOST packet
- sends our known orbital addresses back to the sender as a reply
- format: simple text block, one "hostname p7ref" per line
- routes via protocol-7.route-send to the sender's session
- this is the relay gift: sharing our grid map fragment with the new contact

## modules to modify

### discover.format_discover_mcast_packet
- after formatting the existing payload, append orbital P7REF if available
- format as additional payload line: "p7ref <nodes.orbital.current_p7ref>"
- only append if <nodes.orbital.current_p7ref> is defined and non-empty
- the 6-space prefix convention must be maintained for payload lines

### discover.process_host_packet
- after existing HOST packet processing succeeds
- check if payload contains a "p7ref" line
- if found, extract the P7REF value and call discover.orbital.store_remote
- then call discover.orbital.share_grid_fragment with the sender's session info
- this triggers the relay cascade automatically on every HOST packet received

## existing infrastructure to use

- <nodes.orbital.current_p7ref> — the local orbital address (from nodes zenka)
- discover.process_host_packet — existing module, modify to extract p7ref line
- discover.format_discover_mcast_packet — existing module, modify to append p7ref
- <[protocol-7.route-send]> — for routing grid fragment reply back to sender
  use call_args => { args => $string }, NOT param => { hashref }
- <[chk-sum.bmw.L13-str]> — already used in process_host_packet for pkey_L13

## CRITICAL notes

- $ARG not $_ throughout
- lowercase comments only
- swap-boundary chk-sum: $code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}
- route-send returns count (0 or 1), NOT reply data — replies arrive async
- do NOT add fake signature stubs — leave files clean for signing system
- the 6-space prefix on mcast payload lines is significant — maintain exactly
- process_host_packet regex is strict — only add p7ref extraction AFTER the
  existing regex match succeeds, don't modify the match pattern itself

## signatures note

do NOT add, verify, or modify AMOS7 signatures. leave all new files without
signature footer. modified files will be re-signed automatically.

## deliverables

1. src/discover.orbital.get_local_p7ref
2. src/discover.orbital.store_remote
3. src/discover.cmd.list-orbital
4. src/discover.orbital.share_grid_fragment
5. modified src/discover.format_discover_mcast_packet (append p7ref line)
6. modified src/discover.process_host_packet (extract p7ref + trigger relay)

#,,.,,...,,,,,,,.,,,,,...,,..,...,,,.,.,.,,,.,..,,...,...,...,,,.,,,.,...,,.,,
#UBFYSIQNIU6LJCMXU6IFGSIE4J2G3WJOALVNEMAORC2GXPNV2RCF7IILYODXRFAK2ZZU3QDDQEXOW
#\\\|PQH2R2222SYF45MWUJ3F55K7FUQQJS3E2EYKPQ25RDTMPQN4M7A \ / AMOS7 \ YOURUM ::
#\[7]5RIWGWW5SNN3TH6Y52PBLMY26RBWY6XRDAIPJZQZOJL74LSYUWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
