# N7FS stage 5 : placement, receipts, under-replicated list

2026-11-10. follows `N7FS-SEALED-REPLICAS.md` section 5 and `N7FS-SEALING.md`.
this note fixes the first, integer-target part. calculated placement, erasure
coding and holder-to-holder relays stay later.

## what exists

- `seal` writes one root's nodes to one holder, `holder-check` samples one
  holder, `seal-recover` reads one holder
- categories carry `copies`, `priority`, `want` and `foreign-work`, stored
  but not acted on
- nothing knows how many holders keep a node

## holders

a holder is registered on the home host, never in the repo, because entries
name real hosts :

```
n7fs holder add <name> <spec> -role durable|intake -domain <label>
    [ -owned ] [ -quota <size> ] [ -reserve <size> ]
n7fs holder list
n7fs holder remove <name>
```

- stored as one signed record per change under `<host-dir>/holders/`, signed
  by the host key, latest wins, history kept
- `domain` is a failure domain label. hosts at one provider share one, and
  an owned machine has its own
- `-owned` marks hardware the owner controls. it is the only thing that
  allows a category with `foreign-work no` to send node keys there later ;
  sealed blobs may go anywhere
- `quota` caps what n7fs places there, `reserve` is space it never touches

## what counts as a copy

a node counts on a holder only when that holder's current head maps it, its
blob exists with the right size, and a receipt for that holder is fresh :

- **receipt** : the result of a `holder-check`, signed by the host key, with
  time, holder, head version, blob count and sampled chunks. fresh means
  younger than a set age [ default 7 days ]
- an intake holder counts zero, as the design's safety rule 1 says
- several holders in one failure domain count as one copy toward the target

## commands

```
n7fs placement <disk> -root-key <key>        report only
n7fs place <disk> -root-key <key> [ -dry-run ]  seal what is missing
```

`placement` opens every registered holder's head and map with the root, joins
them with the disk's categories and prints, per category : target copies,
nodes and bytes at each count, and the under-replicated list with the bytes
missing. it never changes anything. `status` shows the under-replicated total.

`place` seals each under-replicated node to holders chosen in this order :
a domain not yet holding it, then owned before foreign, then most free quota.
it never goes below another node's target to make room, and what cannot be
placed stays listed. it uses packs and the existing commit rules.

## draining and moving [ stage 5 part 2, first part ]

`holder-drain <disk> <name>` removes from one holder's map every node whose
counted copies in other failure domains still meet its target without it, in
one commit, together with every tree that named a removed node. nothing that
would fall below its target is touched ; the rest is reported as kept. a copy
counts only with a fresh receipt, so a holder that was just filled does not
yet allow a drain. bytes stay until `holder-gc`.

`place -exclude <name>` and `placement -exclude <name>` read that holder but
do not count it, so a move is :

```
holder add <new> ... ; place -exclude <old> ; holder-check <new>
holder-drain <old> ; holder-gc <old> -only-root -delete
```

## not in this part

deletes on holders [ home-signed ], moving between holders, eviction from
intake, holder-to-holder copying, calculated placement, erasure coding.

## as built [ 2026-11-10 ]

- the registry is the vault note `n7fs holders`, json, one entry per holder
  with spec, role, domain, owned, quota and reserve. the vault keeps earlier
  versions. one vault unlock per command serves the root and the registry
- `holder-check` writes a receipt to `<host-dir>/receipts/`, named by a
  checksum of the holder, signed by the host key. it counts for 7 days and
  only for the same root
- `placement` opens each holder's head and map with the root. a holder
  counts when it is durable, reachable, has a head and a fresh receipt ;
  copies count once per failure domain. it updates a holder's pin as any
  read does, and changes nothing else
- `place` plans per node : domains not yet holding it, owned holders first,
  then most quota left, never past a quota. it seals each holder's share
  with packs, and a holder that receives any file of a tree also receives
  that tree, so it can recover it by name. new copies count after the next
  `holder-check`
- `reserve` is enforced : `place` reads free space with one `df` on the
  holder and never fills past the reserve ; unknown free space places
  nothing there. the size of a node is its local content size, not its
  sealed size
- `-bwlimit <size>` caps uploads to ssh holders per second, for links that
  fail under sustained load

## holder filters [ 2026-11-11 ]

```
holder add <name> <spec> ... [ -categories <a,b> ] [ -min-priority <n> ]
```

`place` puts a node on a holder only when one of the node's categories is in
the holder's list [ when it has one ] and its priority is at least the
holder's lowest. a holder without either takes every category. for small
off-site holders that should carry only what matters most, while the large
ones take everything. what the filters exclude stays in the under-replicated
list, never dropped. `holder list` shows them.

## receipts bind a head version [ 2026-11-11 ]

a receipt counts only while the holder's head is the version it checked, so
copies committed after it [ place, relay ] wait for the next `holder-check`,
as described above. relays and intake draining : `N7FS-INTAKE.md`.

## owner decisions [ 2026-11-10 ]

1. the holder registry lives in the vault, as a note entry titled
   `n7fs holders`, so it survives a total loss together with the root
2. a receipt counts for 7 days ; lower later with better connectivity
3. targets stay `default` 1 and `incoming` 2 for now, likely higher once the
   laptops join
4. rented servers can sit at more than one provider and region. a provider
   is one control domain, a region its own failure domain. which hosts are
   where stays in the vault registry, never in this repository

#,,,,,...,...,,,.,,..,,..,..,,,..,,,.,..,,.,,,..,,...,...,.,.,.,,,...,.,,,..,,
#4QYNUKFICLAV3HGYAKZ6ZBN5IXE27CY2RAUJGQV7KCZJ55UX3HDKLAVQH23DMXMNN4KKCLJ7I6GES
#\\\|WW6L7PG6LZA2NO7ETYLHO6DUNCELM5ZK2BTJ5YHCX3RG7IU5WEB \ / AMOS7 \ YOURUM ::
#\[7]DEAVL567JCCUXFU7WU2VCVUSDUXGYHRZLGRBWY4544SDWCZWHADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
