# coding : policy store and safe action queue

status : IDEA 2026-11-28 -- owner agreed on the shape ; nothing built.

## why

standing permissions and policies are spread over CLAUDE.md, ~100 memory
files and the conversation. every session re-derives them by reading ;
'for now' ones go stale unnoticed. and before any restart \ reload a model
has to find out itself whether it is safe [ a render running, a sign run
pending, a lease held ] and weigh the impact. the coding zenka can keep
both current, in parallel, for every model [ claude, kimi, a local or a
joining external one ].

## policy store

- one record per policy : scope [ project, host, command, data class ],
  conditions [ context : 'restart without asking, not while a render
  runs' ], validity [ permanent, until revoked, until <date>, 'for now'
  with a review point -- it returns as a question, never goes stale
  silently ], source [ who granted it, when, why ]
- queried, not re-read : `coding.policy may <action> [ <scope> ]` answers
  yes \ no \ ask, with the record [ source, date, the why ]
- fail-closed data classes [ credentials, health, exact location,
  finances ] are policies no context condition overrides
- changes : proposed with a reason, approved by the owner, recorded ;
  repeatedly accepted kinds may become pre-approved [ never judgement or
  character ]
- first contents [ from memory and CLAUDE.md ] : push base freely, no
  force push \ rewrite without the owner ; root ssh to the servers ;
  remote restarts \ reloads without a per-step ask [ name them ] ; never
  print a config file whole ; multiuser off for now [ review ] ; kimi
  never touches files it did not change ; no edit while its sign run is
  pending ; never DELETE a v7 model entry

## safe action queue

- `coding.queue-action <action> [ notify=<target> ]` : eg. a zenka restart.
  the zenka waits until safe, runs it, notifies when done [ or why not ]
- safety conditions per action, kept by the zenka : no render \ gpu lease
  in use, no pending sign run on the files, no commit in progress, no
  place \ drill running, the owner's appointments [ events reminders ]
- the policy store decides whether the action needs the owner at all ;
  the queue only ever runs what a policy allows
- a queued action shows in coding.handover until it ran ; it can be
  dropped ; a wait past a limit notifies instead of running late

## rules for the implementer

no sha, no json internally ; native p7 config style ; lowercase comments
with [ ] brackets ; perl floor 5.32 ; new commands need their zenka.v7
list, whitelist and access entries ; timers via base.interval.next ; no
commit, no sign, no reload ; never touch files you did not change.

#,,,,,...,.,,,.,.,.,,,..,,,..,,.,,.,.,..,,,.,,..,,...,..,,...,...,..,,,..,...,
#AZ6KYW4BNYO4LMHFYF65U3EOUNEOA6JNZ5ZYEHT4U756AHVXOMXJDGWN26JJGS2SRWMA4HAEH7WBE
#\\\|6MZ7MW372WP2DJCH3CZW2WV2U3VPELB4NQNRVIZQV3EFGKXWJBO \ / AMOS7 \ YOURUM ::
#\[7]4A5XCB7BNI5PQZCTMIMQEWUCHVEE7WIMFUR6GSLDAXFYABD7KGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
