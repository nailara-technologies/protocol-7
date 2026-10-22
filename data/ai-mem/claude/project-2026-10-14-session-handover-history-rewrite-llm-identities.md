---
name: project-2026-10-14-session-handover-history-rewrite-llm-identities
description: START HERE -- session 2026-10-13..14 handover [ last a7ebe55b2, pushed ] : third history rewrite [ one developer identity, llm metadata stripped, retired-domain committer harmonized ], llm identity hooks [ commit-msg \ post-commit \ pre-push ], pii-audit pattern file initialized, pre-rewrite backups archived + reviewed, console color fix
metadata:
  type: project
---

session 2026-10-13..14. follows [[project-2026-10-12-session-handover-dns-tcp-vault-notes]].

## landed [ all committed + pushed to hub base ]

- history rewritten a third time with `p7-work harmonize-emails outliers
  execute -vq` : every author \ committer is now the single developer
  identity [ incl. the retired `nailara.*` committer ], llm metadata
  stripped from all messages [ Co-Authored-By, Claude-Session,
  'Generated with', `[CLAUDE]` prefix ]. force-pushed base + all tags,
  hub == local verified, llm scan 0.
  - `3b001a740` : commit ids in tracked files rewritten with the
    composed original -> final map [ 30840 ids, 5703 files ]. map copy :
    `/mnt/ext-xfs-data/repository/protocol-7.harmonize-emails.2026-10-14.map`
  - scope is `-- --branches --tags` [ not --all ] ; refs/original backed up
    to refs/harmonize-backup/<time>/ by the tool [ deleted after gc here ]
  - github still serves ~5050 old-id commits via `refs/pull/2/head`
    [ 2025 copilot pr, no llm emails ] -- only github support can drop it
  - bundle recreated : `/mnt/ext-xfs-data/repository/bundle.protocol-7.base`
- `30638b5d6` `cfg/git/llm-metadata.patterns` = ONE shared list [ actions
  line \ prefix \ identity ], applied by `bin/dev/strip-llm-metadata`
  [ filter, -i in place, -s scan, -H harmonize HEAD ].
- `eac6f0883` hooks : post-commit re-authors an llm author \ committer to
  user.name \ user.email via commit-tree + update-ref [ no hooks run twice ;
  cloud commits import without a changed env ] ; pre-push refuses llm
  identities \ metadata in commits not yet on the remote [ first real run
  passed on the force-push ]. commit messages from claude sessions carry NO
  trailer lines [ the user's policy ; the hook would strip them anyway ].
- `1763315cf` pre-commit `:inlist:` signature check batched [ MAX_ARG_STRLEN ;
  'argument list too long' used to look like a signature failure ].
- `e989a3a49` console output color : bin/Protocol-7 sets the stderr color
  [ p7_fg_0002, orange ] ONCE at start-up, every log line ends in a reset
  -> with -v a console command's own output came out white. now re-set
  before the console handler and after each console log line while a
  console command runs [ on STDOUT -- see [[feedback-stderr-buffered-in-zenki]] ].
- `a7ebe55b2` diff-modified `// ''` fix, the only item worth importing from
  the pre-rewrite backups [ [[reference-pre-rewrite-backups-archive]] ].
- `base.log.console_minimum` [ work zenka.v7 ] raises console verbosity to 1
  after init so result lines show without -v.

## outside the repo

- pii-audit pattern file initialized : `/etc/protocol-7/pii-audit/patterns`
  [ 0700 dir \ 0600 file, owner taeki ] -- private domains + emails,
  categories email \ phone \ bank \ private key ; personal name \ live host \
  postal address \ assessment marker left as commented placeholders for the
  user to fill. bin/dev/pii-audit [ cloud-implemented 2026-10-13 ] reads it ;
  2 history hits [ an old export script, read-me/author ] left by choice.
- 9 `../p7.bak.*` directory copies archived and deleted [ 10 GB ] ;
  `p7.bak.10010` remnant is root \ httpd owned, identical to live -> user
  removes with sudo.

## open

- user fills the personal pii placeholder categories
- `sudo rm -rf /data/projects/p7.bak.10010` if not yet done
- nothing else pending from this session

#,,,.,...,.,,,,..,,,.,.,,,...,,,,,..,,...,...,..,,...,...,,,.,..,,,..,..,,.,,,
#3A63D2BI23XIA3TYGDJHACNPG5SOHW6UHV4O4VHBGRNSHCUYBTDNZQBNUXI3XR7IZ7SE6DPGPMKIS
#\\\|OSQZBZDBMSXREZU54JHDVOWRXB7C7ZRJPRSZEJSEGLVUO5QJIKP \ / AMOS7 \ YOURUM ::
#\[7]AGHEMZUXVZV6SIMEFOXENX6WZMN6Z5Y72B2K2FFO5MBUNKE7USCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
