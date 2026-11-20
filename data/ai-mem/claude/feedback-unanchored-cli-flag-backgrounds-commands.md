---
name: unanchored-cli-flag-backgrounds-commands
description: bin/Protocol-7 matched -B unanchored, so any argument containing -B [ a file name ] daemonized a console command ; a silent sign abort with an empty report = check for backgrounding first
metadata:
  type: feedback
---

2026-11-17 : four p7_sign runs aborted with "signed 0", empty report, run_id null, 2 seconds after
start. cause : bin/Protocol-7 tested every argv entry with `qw| -B(K?) |` [ unanchored ] ; the file
name TRANSPORT-MARK-BITS.md contains "-B", so `sourcecode update-signatures` backgrounded itself,
closed STDOUT and the sign runner read EOF. fixed in ade49a75f [ `m|^-B(K?)$|` ].

**Why:** restarting the sign agent and retrying cost three rounds ; the agent was never the problem.
**How to apply:** when a console command or sign run ends silently, run it with `-v` placed AFTER
the zenka name [ see [[p7-cli-argv-and-console-command-gotchas]] ] and look for "backgrounding
current process". after an aborted sign run with version bump, reset the three version files to
HEAD before retrying [ the tool refuses a half-done bump ].

#,,..,..,,.,,,.,.,...,.,.,,,.,.,.,.,.,,.,,,,.,..,,...,...,..,,,,.,,.,,.,,,,.,,
#CHQKVR4EMRT2HA3HV6ZH7VQUD36664OWXV5N4KGMVWFCQIFCB5LCN4CWSHIU6O2ESRHMJTWZNIMXI
#\\\|FOPVBN7SFGJHUT6SDM5AC4DLUY6ZLDQZERIBGO5VBYF2UA5X3SN \ / AMOS7 \ YOURUM ::
#\[7]B2JLYOPLDFWTOLQMXM6ZC2TBZTWLBXNMQPWAFDDO7ULPNOIF5EBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
