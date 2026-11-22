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

#,,,,,.,,,.,,,...,,.,,,,,,...,..,,.,.,,..,.,.,..,,...,...,,,,,.,.,,.,,..,,...,
#7NIUGNSFZ7BFU36FTTBHR6TNOKIUS4YEJRYQESR33LZLAB3TOOPPWPQ75RX3NDBM2Z54R7W3CUYZQ
#\\\|YVXPIGVPOXJW5SIKJK7ZKTHFO5WMKRUPXLONOVJGK4ZLNIRNVQM \ / AMOS7 \ YOURUM ::
#\[7]VA5MYMQYR4LI64LOEYJK2HR2A7CWKWBK4CMBVCWUJSVTWYLWYEBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
