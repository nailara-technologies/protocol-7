---
name: project-2026-10-29-session-handover-commit-manager
description: START HERE 2026-10-29 [ evening, last 18d2a1363, pushed ] : sign agent finished [ content binding, clickable y\n\d prompt, ctrl-r restart with signature gate ], commits now go p7_sign -> p7_commit_prepare -> p7_commit [ ZA2 slices 1-3 ], dep-graph -affected-zenki ; next : kimi takes stale-message redraft or RCM
metadata:
  type: project
---

**where things stand [ 2026-10-29 evening, after
[[project-2026-10-29-session-handover-signing-agent-kimi-cli]] ]**

## how a commit works now [ use it ]

1. `p7_sign( paths, op, plan )` -- returns a job id at once ; start
   `bin/dev/p7-sign-wait <job>` as a BACKGROUND command, its exit is the
   notification [ an mcp job notifies nobody ]. phases : planning \
   versioning \ preparing \ awaiting-approval \ signing \ approved \ denied
   [ decoded reason ] \ aborted [ report ]. `op` new \ amend \
   amend-message \ reset picks the update-version mode ; `plan=true` runs
   bin/dev/p7-commit-plan -apply [ sub-lists, dep-graph doc, zenka
   whitelists -- first live -apply run still to watch ]
2. `p7_commit_prepare( message, op )` -- the commit-msg hook checks the
   form at prepare [ title, one-line max 100, '- ' body ] ; binds a
   staged-diff checksum
3. `p7_commit( id )` detached, `p7-sign-wait <commit id>` waits ; a staged
   change after prepare = `stale`
4. `git push hub base` [ the remote is 'hub', there is no 'origin' ]

the user approves in the p7-sign-agent terminal [ < [a]pprove > <
[d]iff > < [r]eject >, keys or clicks ]. the user restarts the mcp
server [ /mcp ] after every change to bin/mcp-server-p7 -- ask before the
sign run that needs it.

## landed today [ base, pushed ]

- HX4 : approval binds CONTENTS [ chksum + len per file at RUN, re-read
  at SIGN and after the answer ], endline-state restore in the agent strip,
  wire version `p7-sign-agent:002`, format-code -r [ up to 3 passes ] +
  `-c -report` gate + update-amos-versions inside update-signatures :agent:
- agent UI : AMOS7::TERM confirm_key [ clickable labels, pulsing [ ],
  reason on deny, diff on the alternate screen via core.pager ], progress
  bar per file, idle screen, hidden cursor, ctrl-r restart without the
  passphrase [ -key-fd pipe ; unsigned code asks with its diff ]
- ZA2 slices 1-3 : p7_sign \ p7-sign-run, p7_commit_* \ p7-commit,
  p7-commit-plan [ kimi wrote it, reviewed ] ; design
  data/md/design/COMMIT-MANAGER.md lists what landed
- 2SL : `dep-graph -affected-zenki=<sub|ns>` [ one scan, ~45 s, works with
  zenki down ] + `p7-sourcecode affected-zenki` ; found work's stale list
- format-code : one-line string chains split at whitespace are rejoined
  [ deliberate splits inside words \ markers stay ]

## next

- kimi : stale-message redraft for p7_commit [ local model ] OR RCM [ the
  user-writable inline C objects in ~/.7/inline-code, outside every
  signature ] -- claude writes the spec and reviews
- ZA2 open : work.console.commit -- extend or retire
- todos to know : ZA2, RCM

## lessons [ new today ]

- `qw| a b |` in a hash or call is TWO words : `qw| op => begin |`,
  `qw| agent exit |`, `qw| run closed |` broke silently -- quote multi-word
  values
- a test that copies the code's assumption proves nothing [ the 5-byte
  sign-buffer tail was wrong in agent AND test ] ; check against real data
  [ footer BMW over 5000+ real files caught the endline state ]
- edit after a checksum is taken = refused [ content_changed ] : finish
  edits before p7_sign
- format-code exits 0 on errors ; `-c -report` exits 1 when anything
  needs action
- src log lines use <[base.str.os_err]> [ feedback-os-err-for-console-logs ]

#,,,.,..,,...,..,,,,,,,,,,,.,,.,,,,.,,,,.,,,,,..,,...,...,...,.,.,,,.,.,,,.,,,
#BCT6UE6EDP5JIORVAFSVXWDLTDALBD357UXAX775I7AYBCDJXC4AJ3JGS7C4A5STE3XBA3XHTQUM2
#\\\|MEEIB7VXLN5RSGSGC4LOZBHNJ24D4I7XXZ2SWICZPOZRHIBYWCP \ / AMOS7 \ YOURUM ::
#\[7]Y6JFTXIMBRNPNRCEVBDKUDKO45IP2QCD3OXKC4Q3RDZ2HHM2VYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
