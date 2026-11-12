---
name: project-2026-10-30-nameserv-zone-delegation-plan
description: plan : delegate the registrar zones to our own nameserv, which keeps host + acme records dynamically ; zones not current yet [ 2026-10-30 ]
metadata:
  type: project
---

owner plan [ 2026-10-30 ] : switch the nameserver delegation of the
project zones from the registrar [ inwx ] to our own nameserv
[ dn0000 dn0110 dn1110 : 3 servers, each under a v7.ax and a
protocol-7.network name ], and let nameserv keep the records
dynamically [ host names, renames, acme challenges ].

**Why:** per-name registrar records [ _acme-challenge CNAME + acme.<d>
NS ] do not scale : srv-U [ its current name, the former one is the old
one ] never got them, so its dns-01 enrollment failed -- dropped as no
longer practical. delegated zones would make that automatic.

**How to apply:** the zones in nameserv do NOT represent the current
state yet -- reconcile them with the registrar zones BEFORE any
delegation switch [ a switch on stale zones takes the names offline ].
until then : pri letsencr = dns-01 via nameserv alias [ acme.<domain> ],
other hosts = default http-01. details of the zulum diagnosis :
[[project-2026-10-30-session-handover-jobsite-replica]]

**blocked on this [ owner 2026-11-06 ] :** the zulum set-up on pri waits :
no more per-subdomain acme entries at the registrar ; it continues once our
dns mirrors the current set-up and is primary.

**registrar snapshot 2026-10-30 :** `/data/backup/dns/registrar-zones/2026-10-30/`
[ v7.ax protocol-7.network <personal-zone>, raw paste + zone files ]. ESSENTIAL :
mail for @taeki.v7.ax -- served today as taeki CNAME v7.ax -> v7.ax MX 13
mail.v7.ax [ the extra taeki MX record is invalid next to the CNAME and
never served ]. any switch must keep that chain [ or replace it with
A + AAAA + own MX ] -- verify `dig MX taeki.v7.ax` against the new
servers BEFORE changing the delegation. also : protocol-7.network has its
MX on a name '13' [ apex has none ], <personal-zone> acme.jobsite lists
dn1110.protocol-7.network twice, srv-U's former name = old name.

**end state [ owner 2026-10-30 ] :** zenki map the mail + dns set-up
functionally, then RETIRE atom, its postfix and inwx as zone master
[ inwx stays registrar only ]. functional reference = the two snapshots :
dns `/data/backup/dns/registrar-zones/2026-10-30/`, mail
`/data/backup/mail/atom/2026-10-30/` [ README : postfix only, local
delivery to taeki, catch-alls, 4 external forwards, snakeoil tls ].
a replacement is done when it reproduces every mapping there [ @taeki.v7.ax
first ]. atom main.cf : mydestination lines end in '\' [ not a postfix
continuation -- stray '\' destinations, harmless ] -- moot once retired.

**reproducibility [ owner 2026-10-30, next essential logic ] :** the
zenki replacement must be REBUILDABLE from tracked config, not hand-set
on a host [ atom's postfix \ inwx's zones are exactly the hand-set state
being retired ]. a fresh host + the repo + its host-config overlay +
secrets from the key store -> the same served dns answers and the same
mail mappings. personal data [ real addresses, external forward targets ]
stays out of the repo [ /data/<project>-data/ or host-config ], the
structure goes in. test it the way the snapshots define it : rebuild,
then diff served answers [ dig ] and mappings against the snapshots.

**state 2026-11-12 :** srv-U nameserv holds ONLY acme.* subzones [ 8 ], no parent zone.
owner decided : zone sources live in /etc/protocol-7/nameserv/ [ host config, not the repo ] ;
recreatability later via an N7FS host-config tree. gaps found in nameserv.answer before it
can serve a parent zone : no CNAME answer for other types [ breaks MX taeki.v7.ax ], no
wildcard '*', no SOA in authority on NXDOMAIN \ NODATA, empty non-terminals [ us.v7.ax ]
answer NXDOMAIN ; no zone-source import [ ensure-zone is acme.-only ]. per-record ttl
and longest-suffix zone match exist already.

#,,.,,,.,,,,,,...,.,,,,..,...,..,,..,,..,,,,,,..,,...,...,..,,,,,,..,,...,..,,
#XLXDZKG56NMZPDGZAFQ7MNPKAPTFWDVGNU57AMKJHMKPIBC5TUL43KEZN6S4PL5RVVHAIK6WCH5N6
#\\\|VNMYY4DXJDTO26VU4FRLMKYOYX6HT4VKY2OB7ZGW2J23TITAEKH \ / AMOS7 \ YOURUM ::
#\[7]GSLOI2YPWNHTWFOSQOMAMTNRUDTXMKHIWWT4HRL4UAQZ4IBJUMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
