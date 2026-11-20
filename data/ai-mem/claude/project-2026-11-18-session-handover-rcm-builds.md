---
name: session-handover-rcm-builds
description: 2026-11-18 handover : RCM builds, 4ZW wired, base.interval helper [ WEQ step 1 ], -core-subs fixed, UDT 5UR ; next first timer conversion
metadata:
  type: project
---

2026-11-18, started at 99 % \ 7d right before the claude reset. builds on [[session-handover-todo-cleanup]].

done :
- c236fa2cc : AMOS7::INLINE reproducible builds [ namespace keyed on source chksum, -ffile-prefix-map, --build-id=none, toolchain key as 3rd dir name part ] ; WY5 page ceiling configurable [ real fix was 9605c8647, cap = 4 pages x 25 ]
- f19723b81 : race-free builds [ per-object lock O_NOFOLLOW + owner, 120 s wait then pure perl, 0700 build dir, publish by rename, stale build dirs swept ]
- f7ecf3084 : 4ZW nameserv[cache] \ [cache-local] wired by kimi [ by_subname, loopback only ] ; format-code stub hook only answers own uses + lib-path/pm requires [ an empty stub broke Net::DNS's optional probe ] ; todo ZA2 5WI 4CJ closed -> K3E 2BI
- floor perl ~/.local/perl-5.32.1 now has Net::DNS

- e77f44f82 cde2c095b : todos 5UR [ UDT under the external link, high ; discover heartbeat pairs ] + WEQ [ shared interval helper, owner rhythm rules ] ; 4ZW upstream follow-up [ measure, cross-check, forward over link, server recursion ]
- 762377185 2c590c1d0 : base.interval.next + base.interval.rhythm.non-linear \ golden-blink [ WEQ step 1, built by claude_dispatch sonnet, reviewed ] ; 13 filter via base.assert.harmony ; CLAUDE.md + CONVENTIONS.yaml timer line ; test 35 pass. src modules compile on demand : no zenka.v7 edits needed
- e3d1a6838 : Protocol-7 -core-subs lists all 78 core subs [ trailing comment after '{', one-line subs ], styled no match
- kimi hit its 7d limit mid WEQ inventory [ nothing written ] : resume session_b986c2e8-537f-40b8-8209-bf5ee2f74ace after its reset

next :
- WEQ step 2 : convert a first simple timer onto base.interval.next [ site-yaml.fetch.backoff or the huggingface linear retry ] ; discover + dpms stay hand-tuned
- WEQ step 3 : kimi sweep after its reset [ resume the session above, then convert ]
- RCM : call-driven pure perl -> compiled upgrade in process, compiler time limit + host build cap, pre-build at install, prune old 2-part cache dirs
- 4ZW : live start ; on servers the authoritative wildcard :53 bind likely blocks a 127.0.0.1:53 cache instance ; owner to pick upstreams [ default 1.1.1.1 9.9.9.9 ]
- WY5 : close after a live rescan shows skips
- a sign run aborts when update-amos-versions bumps a modified .pm not in the run : include every modified signed file

#,,..,,.,,,..,..,,,,.,,,,,...,,,.,...,..,,..,,..,,...,...,.,.,,.,,,,.,,.,,...,
#HRBJ65AFF5H6CQ36WEOTCJC4Z6VO73CZFAHMQWPXN7CNYHWFQTXFBKZRTEDMVP6XG4QY3T6QPPDEA
#\\\|SJVFG7454LADAKTGEMJEUHI3VTY5Q66D2JA5ZLMP5YDEJJB74SJ \ / AMOS7 \ YOURUM ::
#\[7]5HW27DY56K2SCH3INEIORLLJMT54EVKVGJANOF7UK7FOFGCWL4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
