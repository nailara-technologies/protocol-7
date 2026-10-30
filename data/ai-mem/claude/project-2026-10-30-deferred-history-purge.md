---
name: project-2026-10-30-deferred-history-purge
description: deferred history purge [ owner 2026-10-30 ] : do ONE work purge-paths run together with the owner once there is more to purge -- dep-graph .txz [ untracked aa9b29c3d ] + old data/gfx/backgrounds/ images when an improved set replaces them
metadata:
  type: project
---

- `./bin/Protocol-7 work purge-paths [execute] <paths>` [ dry run by default,
  git filter-repo, clean tree required ]
- queued : data/md/documentation/module-dependency-graph.txz [ 7 commits,
  ~666 KB, untracked since aa9b29c3d, -txz makes it opt-in ]
- next candidate : data/gfx/backgrounds/ images, once replaced by a better set
- filter-repo only drops a remote named 'origin' -- this repo has none
  [ hub \ ext-bundle \ session-work ], nothing to re-add
- **Why:** a rewrite for 666 KB alone [ ~3665 new hashes ] was not worth it
- **How to apply:** do it WITH the owner, never alone ; bundle every path

#,,..,.,.,,..,,..,.,.,.,,,.,,,..,,,.,,,,.,,..,..,,...,...,...,,.,,,,,,..,,,,.,
#M3IGRI5JXZKTETM5CZBLNG3A7RWTM6PEDLC4D6GF62D2YXJ4J5YMKDEKOKBHIDWP53TKEFSUAPH2G
#\\\|RM427BDNXOHOFQBWBKZ2NHCJ7UCPTAK4CA6L6F3KB74QKAETJAQ \ / AMOS7 \ YOURUM ::
#\[7]VDI64WG5FBB2RROGYPHKVAAGFI7KZQMWEY5ZHAIMC6IBYINX64DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
