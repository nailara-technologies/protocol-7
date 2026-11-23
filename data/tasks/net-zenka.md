# net zenka : the network managed by protocol-7, standing on a plain debian base

status : brief [ owner 2026-11-23 ] -- not dispatched. replaces systemd-networkd \ resolved in
p7-host-build installs [ data/tasks/host-build.md ] ; ties into the network \ phone boot of
data/tasks/recovery-partition.md and data/tasks/n7fs-logical-trees-and-mount.md.

## two layers [ dual use ]

1. the base, works without protocol-7 : ifupdown [ /etc/network/interfaces ] with dhcpcd as
   the dhcp client [ wired, wlan through wpa_supplicant, ipv6 ]. the machine is online in the
   rescue system, before the first p7-install and when protocol-7 does not start.
   isc-dhcp-client is end of life [ 2022 ] -- not used.
2. the net zenka, on top : control and integration. when it is down the network keeps
   running ; only the integration pauses.

## client side

- dhcpcd events through a hook script [ lease, link up \ down, dns servers ] into the zenka
- dns : /etc/resolv.conf points to 127.0.0.1 once nameserv runs its cache-local resolver
  [ data/tasks/4ZW-nameserv-cache.md ] ; the net zenka hands the dhcp dns servers to nameserv
  as upstreams instead of a fixed list. without nameserv : dhcpcd writes resolv.conf itself
- wlan through the wpa_supplicant control socket : scan, connect, saved networks from the
  vault [ never in a plain file ]
- interfaces and mac addresses to discover [ broadcast interfaces ] and to the power zenka
  [ wake on lan : the mac known from the first boot on ]
- commands : net.status, net.interfaces, net.wlan-scan, net.wlan-connect, net.leases

## server side [ owner : dhcpd with the bootp plans ]

- an optional dhcp \ bootp server for the lan : addresses for known hosts [ mac -> name from
  nodes \ discover ], and network boot of the rescue system [ pxe : dhcp options, tftp or
  http boot ] -- the 'every holder is a recovery point' and phone \ network boot plans
- implementation : first a managed daemon [ dnsmasq or kea -- isc-dhcp-server is end of life ],
  configured by the zenka ; a zenka-native dhcp \ bootp server later if it pays off
- fail closed : serves only on interfaces named in the config, never by default ; a second
  dhcp server found on the segment stops it with a clear report

## p7-host-build

- net.backend = ifupdown [ default ] | networkd | none ; ifupdown writes interfaces +
  dhcpcd ; networkd stays possible but is not the default ; systemd-resolved not installed

## protocol-7 owns the network state [ owner 2026-11-23 ]

the zenka does not only watch : it is the place that knows what the network is FOR and what
it should be -- so it changes it when needed and restores it afterwards.

- a known-good state per host [ interfaces, addresses, routes, dns, wlan profile, firewall
  later ] recorded by the zenka, versioned [ the previous states kept ], stored with the host
  configuration in n7fs [ the recovery stick and a rebuild read it ]
- dynamic changes with a reason and a way back : a temporary change [ a vpn exit, a test
  segment, a pxe service window, a degraded link ] is applied with its reason and an end
  condition ; when it ends or the zenka restarts, the recorded state comes back
- restore on drift : a change made outside the zenka is reported ; restoring it is a command,
  automatic only where the host config says so [ warn, do not silently fight the admin ]
- the base layer stays independent : when the zenka is down, ifupdown + dhcpcd keep the last
  plain configuration running -- the zenka writes that plain configuration as its fallback

## nodes \ power \ discover [ pieces 5 + 5b, 2026-11-23 ]

- roaming hosts : a laptop plugs into other switches \ docks \ wlans -- what worked before is
  a GROUP of observations, each tied to a network as seen from here
- network fingerprint [ netinfo.local_networks, shared by net \ nodes \ power ] :
  '<local iface>,<subnet>,<gateway mac or ->' -- the gateway mac [ arp table, default route
  gateway on that iface ] is the strongest same-lan hint
- nodes keeps per node a short history [ nodes.ifaces, node-ifaces.state ] : network, remote
  iface, mac, ip, last seen, times seen. a different network is a new entry, never an
  overwrite ; entries age out [ 13 days, newest 13 kept ]. nodes.node-macs <host> :
  '<network> <iface> <mac> <ip> <seen> <count>' lines, newest first, + 'trust <state>'
- local interface roles : lan \ external \ unknown. host config net.role.<iface> =
  lan|external [ /etc/protocol-7/host-config/net.cfg, read only when trusted ] ; without one
  the default route iface is external, the rest unknown. shown in net.interfaces and
  net.roles. external is never used to wake or fall back, even when a stale observation
  points there -- a lan on the default route iface needs net.role.<iface> = lan
- power.wake <host> [ iface ] sends IN PARALLEL, ONLY from observations :
  1. every observation on a network we are on now [ exact fingerprint, not external ]
  2. every earlier network whose subnet we are on now [ another dock \ gateway ]
  both tiers go out in the FIRST round at once, each to its subnet-directed broadcast [ one
  packet per mac + broadcast ] ; then power.cfg.wake_repeats repeat rounds [ default 3 ]
  against packet loss on the wake-fallback rhythm [ base.interval.next ], stopped early when
  the newest current observation answers a ping. a try whose local iface is gone or turned
  external is skipped. never an all-interface fallback, never 255.255.255.255.
  no match : 'last seen on <network> [ <when> ], not reachable from here' + the group.
  a packet only for trust pinned [ else the mac + power.add-wol-device line ]. registered
  wol devices wake only through their attached, non-external iface
- connecting to an awake node [ later, not built ] : staggered start [ happy eyeballs ] --
  one attempt per candidate path [ remote iface \ local network, the wake order ], started a
  few hundred ms apart, not after a timeout ; the first that AUTHENTICATES wins [ a tcp
  connect alone is not enough ], the others are closed at once ; the winning path is
  recorded for the TX-interface mapping
- arp \ neighbour awareness [ later ] :
  - static arp entries for observed macs on a lan network : wake by unicast to the last ip
    [ through switches that drop broadcasts ], set and removed by the net zenka
  - the neighbour table [ ip neigh \ /proc/net/arp, both families ] as a discovery source :
    macs seen on the lan add awareness [ hosts that do not run discover, a laptop arriving
    before its first announcement ] and feed the observations
- net : BOUND \ REBOOT \ CARRIER [ + 6 ] -> discover.reset-broadcast-timer [ config key
  network.cfg.discover_announce_cmd ] : this host re-announces on the new network at once
- goal : TX interface mapping -- for each remote interface the LOCAL interface \ network it
  is reachable on, so sender and receiver talk on the same network [ and power wakes over
  the right card ]. todo :
  - discover : record the local receiving interface per announcement [ IP_PKTINFO \
    recvmsg ; s_read sees no destination today ] ; the fingerprint's local iface is derived
    from the subnet until then
  - discover.host_details returns the FIRST entry for a name and nodes asks once per online
    period : a multi-interface host adds one observation per period. needs a details form
    returning every entry of a host
  - ipv6 : fingerprints and wake are ipv4 only
  - interface type [ wired \ wlan ] of a remote iface : announce it


## dhcp dns by network role [ owner 2026-11-23 ]

net hands dhcp dns servers to nameserv [ nameserv.set-upstreams dhcp:<iface> ]. a dhcp server
on a foreign network must not silently become the resolver :

- lan role : the dhcp dns servers are used as upstreams [ after the static ones ]
- external \ unknown role : the servers are recorded and shown [ net.leases, nameserv.upstreams
  marked 'held' ], not used ; the owner approves them per network fingerprint [ remembered ]
- never without dns : protocol-7 keeps a working resolver path [ static upstreams, the
  nameserv cache ] whatever a network offers, so holding back a dhcp server costs nothing
- selective use : a held server can still be used for the network's own names only [ e.g. a
  company lan : *.corp.example and its reverse zones over their dns, everything else over
  ours ] -- per network a list of domains routed to its dns ; the domain from the lease
  [ domain= ] is the suggested first entry, never applied without approval
- the data is always collected [ servers, domain, network fingerprint ] : it feeds the
  awareness of where the host is, also when nothing of it is used

#,,,.,.,.,,,.,...,,..,,,,,.,.,..,,..,,.,,,.,.,..,,...,...,,..,,.,,,,,,.,.,,,,,
#AQ2X5KNP35IYX44KUFZA45PR23TDHZWMD7CIOL6IY5HFMBLRDWIJ75SANNQ53JELKZ3ZX52E4UAC6
#\\\|KVGXQ3V7OTMTBND2YJN256WC7XPXUR7FLRXP36IAXP3QWLENM33 \ / AMOS7 \ YOURUM ::
#\[7]NWMJC3D47PGXKC2W4LTVRWVN45GF3IQJC52L4WGUR7GP47IGJ2BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
