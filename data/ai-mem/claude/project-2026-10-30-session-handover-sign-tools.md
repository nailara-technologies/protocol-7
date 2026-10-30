---
name: project-2026-10-30-session-handover-sign-tools
description: START HERE 2026-10-30 night 2 [ last 9d2fd7907 ] : mcp sign \ commit tools in use, sign-agent deny path fixed, p7-sign-run reuses a sane pending bump, coding restart releases its old claims [ NOT live-checked ] ; next : live check, p7-commit-plan bugs, then jobsite sync
metadata:
  type: project
---

**landed [ d66960790 .. 9d2fd7907 ]**

- guide + memory : git workflow = p7_sign -> p7_commit_prepare -> p7_commit
  [[reference-mcp-sign-commit-workflow]] ; kimi default K3.1 low
- b6eeccbc2 sign agent : deny reason read raw [ arrows no longer echo ^[[D ]
  ; the screen clears after a denial
- 06b4a2ce0 p7-sign-run : a denied \ aborted run's version bump is reused
  when sane [ 3 files differ, counter HEAD + 1, same version, nothing else
  changed ] ; already-valid requested paths are staged ; a slash-less path
  not in src/ is refused up front [ kimi ]
- 9d2fd7907 models : claims record owner coding instance + target backend ;
  coding sends cube.models.coding-online at startup [ source_zenka_sid
  alias ] ; models releases the previous instance's coding.* claims [ kimi,
  target check added in review ]

**next**

1. LIVE CHECK 9d2fd7907 [ stubs could not cover it ] : cube reload config
   [ new alias ], restart models, restart coding between tasks -> models
   log 'coding instance .. online, released N claims'. pri needs the same
   after a pull
2. p7-commit-plan bugs :
   - with explicit paths [ p7_sign plan=true ] only format-code is found ;
     module adds are missed -> no sub-list \ dep-graph \ whitelist. without
     paths it finds them, but only once new files are STAGED [ untracked
     ones are invisible ]
   - 'dep-graph -affected-zenki' header line read as zenka 'Name' [ listed
     as cfg/zenki/Name/subroutines.load-early, nothing written ]
3. then the jobsite \ ui sync topic [[project-2026-10-30-session-handover-night-brake]]

**how to work**

- new modules : git add them BEFORE p7_sign, run `bin/dev/p7-commit-plan
  -apply` without paths until bug 2.1 is fixed, never hand-edit
  subroutines.load-early [ owner denied that : use gen-sub-whitelist ]
- regenerated files lose their footer : sign them, incl. the BINARY
  module-dependency-graph.txz [ a text tail check misses its footer ]
- unsigned top-level files [ AI-COLLABORATION-GUIDE.md ] : stage by hand
- descr lines <= 55 chars [ pre-commit hook ]

#,,,.,,..,.,.,,..,,.,,..,,,..,.,,,,.,,,,.,..,,..,,...,...,...,,,.,,,.,..,,.,.,
#3CWT4KW5CHI723SDYP43AJTBHTKYJ2HZ64XZBNNYOIVLNS3L4RCXPGEAEEGGWKHCUL3HBAYOUN7ZM
#\\\|EASUMRQTBNXQ6HHQQ6MEIJPILJQP5RD6C4ZBQHX7KMJFGJR4VT3 \ / AMOS7 \ YOURUM ::
#\[7]HPRACKDLO7CGBLKA467Q3CE2SXDN4OADRT5EXYBBHR5HJWQKIQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
