---
name: session-handover-rcm-builds
description: 2026-11-18 handover : RCM reproducible + race-free inline builds, 4ZW cache instances wired, format-code stub fix, todo split
metadata:
  type: project
---

2026-11-18, started at 99 % \ 7d right before the claude reset. builds on [[session-handover-todo-cleanup]].

done :
- 23fa83f56 : AMOS7::INLINE reproducible builds [ namespace keyed on source chksum, -ffile-prefix-map, --build-id=none, toolchain key as 3rd dir name part ] ; WY5 page ceiling configurable [ real fix was a3c7781aa, cap = 4 pages x 25 ]
- 1b058602c : race-free builds [ per-object lock O_NOFOLLOW + owner, 120 s wait then pure perl, 0700 build dir, publish by rename, stale build dirs swept ]
- 5c6afa117 : 4ZW nameserv[cache] \ [cache-local] wired by kimi [ by_subname, loopback only ] ; format-code stub hook only answers own uses + lib-path/pm requires [ an empty stub broke Net::DNS's optional probe ] ; todo ZA2 5WI 4CJ closed -> K3E 2BI
- floor perl ~/.local/perl-5.32.1 now has Net::DNS

next :
- RCM : call-driven pure perl -> compiled upgrade in process, compiler time limit + host build cap, pre-build at install, prune old 2-part cache dirs
- 4ZW : live start ; on servers the authoritative wildcard :53 bind likely blocks a 127.0.0.1:53 cache instance ; owner to pick upstreams [ default 1.1.1.1 9.9.9.9 ]
- WY5 : close after a live rescan shows skips
- a sign run aborts when update-amos-versions bumps a modified .pm not in the run : include every modified signed file

#,,..,...,,.,,,,,,..,,...,,,,,...,...,,.,,.,.,..,,...,...,..,,...,,,,,..,,..,,
#YQ3QGT6QCXJHO4ZY2HSDTYO3HJNARPF3BVGFHQXATOPEE2EH7LZRX6VQNENCOU2HWBKF7YVIPFSO4
#\\\|YJJDV3EQOGHULEMD7HHOOKWDCJXNPQ3ER63APDTIE52HN7II2FH \ / AMOS7 \ YOURUM ::
#\[7]JRVKIP3TSHJPAWZ7AWH3V7CU7K7YASG7ALICZT75TIT5FBP7UMBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
