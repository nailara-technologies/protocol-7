---
name: n7fs-host-migration-goal
description: 2026-11-08 owner goal for N7FS : host group sync, blind remote replicas, native linux desktop this month ; decisions and stage order in N7FS-SEALED-REPLICAS.md
metadata:
  type: project
---

goal [ owner 2026-11-08 ] : everything essential in N7FS and synced so the desktop can move to native linux [ target : this month ], the windows disk shrunk some time after, two laptops join the group later.

**Why:** the gpu fan warranty [ ~february ] is NOT a driver : a new fan costs under 30 eur, possibly only a connector.

**How to apply:** design and stage order are in data/md/design/N7FS-SEALED-REPLICAS.md. owner decisions :
- foreign-owned hosts never hold plaintext or keys, no mount there
- sealing suite twofish-ctr inside + chacha20-poly1305 outside ; AES dropped entirely, owner distrusts NIST
- the sealed map for plain nodes confirmed
- encryption and placement are per file category
- small hosts take part as intake \ cache and relay in the background ; placement is selective but redundancy aware
- C: still holds wanted files : they go through an incoming pool for assimilate, sorted in batches

long-horizon direction [ owner 2026-11-08 ] : hosters can read plain memory, so work drifts into deeper network layers as equally sized elements that reveal little alone ; gaining anything should need the whole group's bits at one time plus decoding the protocol. a compromised host is then mostly a theft of resources ; forensics stays vital meanwhile, spying on readable activity is the highest current risk.

resource economy : already written in read-me/documentation/dev/NRT.NRD.asc and data/md/design/RESOURCE-ECONOMY-DEMYSTIFICATION.md -- search those first. new 2026-11-08 [ owner ] : token resources follow the SAME logic as data, cold balances with latency growing by depth, warmed by activity [ spending returns them, swaps from free pools, net unwinding only ], funding reparented to a network-level virtual account when in shared interest, absolute fairness = all priorities accurately considered, per frame. unlike data copies, tokens are conserved. open : sybil against the per-account numeraire.

continues [[session-handover-n7fs-format3]].

#,,,,,.,.,,.,,..,,,,,,,,,,..,,,,.,..,,,,,,,..,..,,...,..,,,.,,...,,,.,,..,,,,,
#7TBSDSQXQBWSNDEKFTQ3ZFK2ZTO7M3VVDM7RMOYMY2UORA7MVX357AI5KJEOASONIIZOCPUDAZJMY
#\\\|TMU4EFOG3PKQRLQ26UITOLT6PEN6HXTPKSMIRB2PGQWH4HHNTXI \ / AMOS7 \ YOURUM ::
#\[7]LU5UWK3DCCZ7RMUXY57V76SDFRZ2IB4D6YTWJM7VMXJEUMXM3ICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
