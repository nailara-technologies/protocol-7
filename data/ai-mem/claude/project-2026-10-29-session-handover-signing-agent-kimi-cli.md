---
name: project-2026-10-29-session-handover-signing-agent-kimi-cli
description: START HERE 2026-10-29 [ last 40c0fbc6f, tree clean ] : HX4 slice 1 committed but NOT for use [ approval binds paths, not contents -- the follow-up is next ], kimi dispatch moved to the current kimi cli with 'thinking' low|high|max, sign \ verify run as a chunk pool [ 2:18 -> 1:45 ], release AMOS7-v6.48.9, profile 'extended'. a resumed claude session keeps the OLD mcp tool schema -- start a NEW conversation to get 'thinking' + k3.1
metadata:
  type: project
---

**where things stand [ 2026-10-29, after the azurum day -- see
[[project-2026-10-28-clean-bare-host-install-azurum]] ]**

## next, in order

1. **HX4 follow-up** [ high, todo HX4 ] : `bin/p7-sign-agent` approves a
   list of PATHS at RUN and signs whatever is on disk at SIGN for up to an
   hour idle -> a same-uid process [ the coding models run as taeki ] can
   change an approved file and still get it signed. fix : RUN carries a
   body checksum per file, the prompt approves those, SIGN refuses a
   mismatch ; the window ends with the run. should-fix in the same round :
   stdin approval only behind an explicit test flag, constrain the 5 free
   bytes `(.{5})` at the end of the signed buffer, real zeroing in
   `secret_wipe` [ reuse the editor's deterministic wipes ]. commit
   a32c7d0c0 says 'NOT for use yet'. dispatch as a NESTED, token-light
   kimi run [ todo RXG note ] with `thinking` chosen on purpose.
2. a live `update-signatures :agent:` run against the real tree, once 1
   is in [ the client never ran inside the zenka before 2026-10-29 ;
   SOCK_STREAM() + three join( qw| |, .. ) fixed in review ].

## landed this session [ base, pushed ]

- release AMOS7-v6.48.9 [ tag ] : the clean bare-host install milestone
- profile `protocol7-extended` -> `extended` ; minimal now holds the boot
  crypto, lzma, Inline::C + gcc, Const::Fast, File::Which
- sign \ verify : workers per cpu split [ verify_workers_per_cpu 1,
  sign_workers_per_cpu 2 -- 8 cores \ 16 threads here ], size-balanced
  chunks run as a pool [ 480-file bench 2:18 -> 2:07 -> 1:45 ]
- route history [ 9a9459835 ] for 'reply to unknown route id'
- kimi dispatch on `~/.kimi-code/bin/kimi` [ 40c0fbc6f ] : `-p`, `-S`
  resume, `thinking` low|high|max via KIMI_MODEL_THINKING_EFFORT [ medium
  is rejected by the provider ], aliases k3.1 \ k3.1-fast ; a resumed
  session now runs unattended [ legacy idled after a client attached ]
- designs : VERSION-BRANCHES.md [ supersession by name, per-release keys,
  re-signing as the hand-over gate, distributed re-sign ],
  PEER-FLIGHT-RECORDER.md [ peer-held encrypted logs, self-repair
  asymmetry ], HOST-SETUP.md 'records' [ usr.<user>.cfg.hosts.., prefix
  stripping per layer ]
- todos : 7GU [ pirateface model source ], 3CQ [ host-edit records ], PBS
  [ temp keys + history, signed ends ], QHC [ terminal graphing ], HX4,
  OLM [ idea intake ], 7SE [ reproducible inference ], RXG [ done, notes ]

## lessons

- a RESUMED claude session keeps the mcp tool schema it started with --
  `/mcp` reconnect and a shell restart did not refresh it ; a new
  conversation does
- resuming a large kimi session re-sends its whole context per step
  [ ~340k tokens ; the HX4 slice cost 11 % of kimi's week ] -> fresh
  dispatches with short briefs for follow-ups
- the sign run stages an agent's unreviewed files too -- unstage before
  committing [ [[amend-env-and-unsigned-files-staging]] ] ; and
  `.deps/profiles.yaml` is unsigned, the sign run never stages it
- the hook refuses a one-line message over 100 chars : title + body

## still open from 2026-10-28

azurum : route-history verdict pending ; discover peers [ this dev host is
WSL2 behind nat -- `networkingMode=mirrored` or a native host ; owner root
for trust ] ; nodes orbital-p7ref log spam ; `p7-deps help` drops `\`.

#,,.,,,,.,,..,,,.,,.,,,.,,..,,.,.,..,,,..,...,..,,...,...,.,.,,,.,...,,,.,,.,,
#TZUBV5TPYMFJVIUWHMZXFG744WL2D4RIQ66FZZVYWOKGBNCPLBXIX7LVI5VIAMEIU6M42EOTH2MK4
#\\\|RTJB33A3C7DZKHOUUEECW2ZEYER5T2NB2NF4ICA2L2QCEMMSI3N \ / AMOS7 \ YOURUM ::
#\[7]SOCGFCKOVOHVXZN2XX34OZTXZHPME3TUF63WKUER7DIGPTTIUSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
