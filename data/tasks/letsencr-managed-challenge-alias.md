# letsencr : managed dns-01 challenge alias in our own zones

owner 2026-11-18. trigger : a new host under our own zone enrollment failed with
NXDOMAIN -- the parent zone moved from the registrar to our
nameserv, and the `_acme-challenge.<host>` CNAME had to be added by hand
[ the hand zone source ].

## today

- letsencr.child.acme.challenge_name : `_acme-challenge.<alias>`, alias from
  letsencr.dns.challenge_alias pairs or `<prefix>.<domain>` [ prefix 'acme' ]
- nameserv.cmd.ensure-zone : creates `acme.<domain>` [ prefix-guarded ]
- nameserv.cmd.add-txt \ remove-txt : the challenge TXT inside it
- the parent's CNAME `_acme-challenge.<domain> -> _acme-challenge.acme.<domain>.`
  is nobody's job -- the registrar used to carry it

## build

1. nameserv.cmd.ensure-challenge-alias <domain> [ :remove: ]
   - acts only when the PARENT zone of <domain> is held by this nameserv
     [ longest matching zone in <nameserv.zones>, never an acme.* zone ] ;
     otherwise answers 'not ours' [ mode false, no change ]
   - ensures acme.<domain> [ reuse ensure-zone ] and adds ONE signed record
     `_acme-challenge.<domain> CNAME _acme-challenge.acme.<domain>.` [ ttl 3000,
     like the hand line ] into the parent zone -- through the same record
     write path as add-record, so the existing sync replicates it
   - idempotent : present -> no change ; a different CNAME at that name ->
     refused, reported [ never overwrite a hand record ]
   - :remove: : drops the CNAME [ tombstone, the sync's normal removal ] and
     the acme.<domain> zone [ remove-zone ] -- only records it manages, never
     a hand-written one [ a record from the zone source stays ]
   - records it writes are marked managed [ find how records carry a writer \
     source today ; show-zone shows the mark ]
2. access : letsencr may call ensure-challenge-alias ; the command itself only
   writes `_acme-challenge.*` CNAMEs into zones it holds. add it to the
   nameserv zenka.v7 command list, gen-sub-whitelist, and cube access for
   letsencr [ see memory : new-task-command-three-lists ]
3. letsencr : before every dns-01 enrollment call ensure-challenge-alias
   <domain> ; 'not ours' -> today's path [ registrar api, inwx \ cloudflare ].
   skip domains listed in letsencr.dns.unmanaged_alias_zones [ opt-out,
   default empty ]
4. cleanup : when letsencr revokes a certificate or the vhost is deleted
   [ httpd.cmd.del-vhost ], call ensure-challenge-alias <domain> :remove: --
   also a periodic sweep is NOT part of this task
5. httpd.cmd.add-vhost : the new vhost dir takes the group of its parent dir
   [ /var/httpd is httpd:httpsd 0750 ; today it gets httpd -> httpsd can't
   read, fixed by hand ]

## constraints

- no sha, no json internal ; p7 config style ; style per CLAUDE.md
- new timers \ retries : base.interval.next
- do not touch the hand zone source file ; the hand-added line stays
- tests : a stub zone set [ parent held \ not held \ hand CNAME present \
  foreign CNAME ] for ensure-challenge-alias incl. :remove: ; add-vhost group
- floor perl 5.32, bin/format-code -c

## live check after landing

- a fresh name under our own zone : request-certificate alone works
- names in registrar zones still go the registrar way

#,,..,,..,.,.,.,,,.,,,,,,,.,,,.,,,...,.,.,.,.,..,,...,...,...,..,,.,.,...,,,.,
#YXYXNSCVIMHMVH7HW4OPQV7L5VM4HWEND23UEBYU7PIBUKWYDVBV7EFHPTCI7UXRPAXYH7MM2WQDU
#\\\|ZZXAG6LV4NF6DXBOAD346B5KM2HIZV7TAEFUHA2HPDEPCZ3AGRO \ / AMOS7 \ YOURUM ::
#\[7]RT6OKHDHWNMJGTE54BBYC56Q3PC5J3BL6RJR2HN2GCAKDKIKPOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
