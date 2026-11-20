---
name: project-2026-10-30-deferred-history-purge
description: deferred history purge [ owner 2026-10-30 ] : do ONE work purge-paths run together with the owner once there is more to purge -- dep-graph .txz [ untracked 8db4dfe6c ] + old data/gfx/backgrounds/ images when an improved set replaces them
metadata:
  type: project
---

- `./bin/Protocol-7 work purge-paths [execute] <paths>` [ dry run by default,
  git filter-repo, clean tree required ]
- queued : data/md/documentation/module-dependency-graph.txz [ 7 commits,
  ~666 KB, untracked since 8db4dfe6c, -txz makes it opt-in ]
- next candidate : data/gfx/backgrounds/ images, once replaced by a better set
- filter-repo only drops a remote named 'origin' -- this repo has none
  [ hub \ ext-bundle \ session-work ], nothing to re-add
- 2026-11-13 : also a CONTENT rewrite [ filter-repo --replace-text, not purge-paths ] :
  the per-service mail aliases + the mail name in data/ai-mem/claude/ [ removed from the
  tree 2026-11-13 ; list of the strings in /data/backup/mail/atom/MAIL-CHAIN-NOTES.md ] --
  they help guess external account addresses
- **Why:** a rewrite for 666 KB alone [ ~3665 new hashes ] was not worth it
- **How to apply:** do it WITH the owner, never alone ; bundle every path

#,,,,,,..,,,.,...,.,,,...,.,,,,,.,.,,,...,,.,,..,,...,...,...,...,,.,,.,,,,.,,
#CW7GGT3PKWBPNNXQNBVBKGJ4ONDPUH4JAAQOCGARYQ7JBLIBJ3HDTAXVEK7DISZMXMEXOCA3UXP4E
#\\\|EMRYNCACADZR4NJUY6B6H5AX5JVDZMYA6VDB4I655N776HVWUJW \ / AMOS7 \ YOURUM ::
#\[7]Y2CVNWUTLPVMUHDS2NQF5ZJX4RCPM26JIQOZDLMWV5RAH7SET2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
