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
one mail chain [ CNAME + MX ] must survive every switch -- the
private notes /data/backup/mail/atom/MAIL-CHAIN-NOTES.md say which and how to
dig-check it BEFORE \ after changing a delegation. also : protocol-7.network has its
MX on a name '13' [ apex has none ], <personal-zone> acme.jobsite lists
dn1110.protocol-7.network twice, srv-U's former name = old name.

**end state [ owner 2026-10-30 ] :** zenki map the mail + dns set-up
functionally, then RETIRE atom, its postfix and inwx as zone master
[ inwx stays registrar only ]. functional reference = the two snapshots :
dns `/data/backup/dns/registrar-zones/2026-10-30/`, mail
`/data/backup/mail/atom/2026-10-30/` [ README : postfix only, local
delivery to the owner, catch-alls, 4 external forwards, snakeoil tls ].
a replacement is done when it reproduces every mapping there [ that mail
chain first ]. atom main.cf : mydestination lines end in '\' [ not a postfix
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
can serve a parent zone : no CNAME answer for other types [ broke the mail chain ], no
wildcard '*', no SOA in authority on NXDOMAIN \ NODATA, empty non-terminals [ us.v7.ax ]
answer NXDOMAIN ; no zone-source import [ ensure-zone is acme.-only ]. per-record ttl
and longest-suffix zone match exist already.

**roadmap [ owner 2026-11-12 ] :** dns first [ parent zones served + delegated ], then the
smtpd zenka [ suitable tls params, letsencr certs per mx host ], then move all work off
atom and retire it ; add two small hosts in two more us cities [ like delta ] : same or less
cost than atom, ~6x capacity, 3 locations. MX order : pri [ rename to zulum completes ]
primary, yourum second [ both non-us ], the us hosts as fallbacks [ connectivity first ].

**LIVE 2026-11-12 [ 0b77e807e ] :** the three parent zones are served by dn0000 \ dn0110 \
dn1110 [ apply-zone-source on srv-U, sources in /etc/protocol-7/nameserv/zones, sync grants
added on srv-V \ srv-A ]. dig compare vs the registrar : every record equal, the mail chain
and the private zone's MX names correct ; the only diffs = acme.* NS [ we answer from the
child zone, registrar refers -- expected ] and ~1/40 udp timeouts on both sides [ local
path ]. NOT delegated yet : owner switches at the registrar ; dn0000 glue was pending.
atom retire : private checklist /data/backup/mail/atom/ATOM-RETIRE-CHECKLIST.md [ accounts
still on the returned old domain -- move them before atom goes ].

**switch 1 [ 2026-11-12 ] :** the private zone is delegated to the six dn names [ glue for all
six ; INWX 'Master IP' left empty ; all .re tld servers switched ]. INWX still holds its old
copy : no record changes in that zone until 2026-11-13 evening [ old NS ttl 86400 ], then
DELETE the zone at INWX [ owner ]. next : one real mail on atom for the private zone, then
protocol-7.network, v7.ax last -- same INWX cleanup a day after each. sources on srv-U are
the master copies [ six NS in all three ].

**smtpd state [ 2026-11-12 ] :** the smtpd zenka [ 14 modules, on-demand ] is a mail PROCESSOR
only : inject \ parse \ classify \ route [ jobs -> jobsite, * -> mail.store ], archive.
missing for atom's job : smtp listener [ 25, esmtp, starttls, limits, anti-relay, recipient
check per DOMAIN only ], mailbox access, outbound + the 4 forwards. zones carry NO spf \ dkim \ dmarc TXT ;
atom postfix uses the snakeoil cert [ tls may ].
**catch-all decision [ owner 2026-11-13 ] :** smtpd keeps the existing catch-alls and never
rejects unknown local parts on them ; a block list per address. details : private notes
/data/backup/mail/atom/MAIL-CHAIN-NOTES.md.

**contabo ipv6 outage [ 2026-11-13 ] :** srv-U \ srv-A v6 dead in and out [ fe80::1 resolved,
no replies, no firewall drops ] -- dig with v6 glue waited ~9 s. srv-U came back by itself,
srv-A only after a panel restart. sporadic since install, also between our own hosts.
mtr after recovery : 25 % \ 55 % outbound loss from contabo's first hop [ AS51167 ],
inbound from delta clean. ticket sent [ german, with mtr ] ; mtr-tiny now on U \ A \ V.
on recurrence : capture ip -6 neigh + mtr -6 BEFORE any restart. glue \ zones stay as they are.

#,,..,,,.,,..,,.,,..,,,.,,.,.,,..,...,,.,,,,.,..,,...,...,..,,.,.,.,,,...,,..,
#EEFI6YZC2WRXZ2C6KEYGZ2XJ4MP24F7PWPGPD3EHZEFNYSVDB6MNQSNZKHP27W6IIZYTVIF53HSK4
#\\\|RZUZ4GXUA6NBEVVBWUV3NFFHVTCPWJSHR43AUKY2M4QDDZWNZJR \ / AMOS7 \ YOURUM ::
#\[7]753L46CYLPLTHRABQGBAM5R2HUCG3QAUZVS5OQXFVYFRKR3H7KDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
