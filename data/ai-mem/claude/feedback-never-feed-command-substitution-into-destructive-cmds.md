---
name: feedback-never-feed-command-substitution-into-destructive-cmds
description: 2026-10-05 -- `p7c v7-zenki.restart $(p7c v7-zenki.sid-lookup $EMPTY)` restarted CUBE [ the lookup's error text "expected numerical cube session id parameter" became the restart args, 'cube' matched a zenka name ] and killed the user's running invoke render ; validate every substituted value before a restart \ terminate \ stop, and the tools now refuse any unknown name
metadata:
  type: feedback
---

**what happened** [ 2026-10-05, osf-cache cross-host work ] : a shell
one-liner computed the main osf-cache sid with a fragile `grep -v -E
"^($P|$P2)$"` [ ugrep rejects the empty alternative -> empty result ],
then ran `p7c v7-zenki.restart $(p7c v7-zenki.sid-lookup $M)`. with `$M`
empty, sid-lookup printed its error to stdout ; the substitution handed
`expected numerical cube session id parameter` to restart, which takes a
space-separated name list, silently skipped the unknown words and
restarted **cube**. every zenka disconnected, the user's invoke render
[ which they had just restarted after an earlier interruption ] died.

**Why:** a p7c command's error text goes to stdout and looks like data to
`$( )` ; restart \ terminate accepted a mixed list and acted on the valid
names in it.

**How to apply:**
- never pass `$( p7c ... )` straight into `v7-zenki.restart` \
  `terminate` \ `stop` : capture it, check it matches `^\d+$` [ or the
  exact expected shape ], abort the script otherwise [ `set -e` does not
  help, p7c errors can exit 0 or print to stdout ]
- prefer one restart per explicit, already-printed id over pipelines
- ugrep is the system grep here : no empty alternatives in `-E` patterns
- tool fix landed the same day : `v7-zenki.zenka.cmd.restart` and
  `.terminate` refuse the WHOLE request if any name is unknown
  [ "nothing restarted" ] -- per [[feedback-tool-probe-empty-args-destructive-default]],
  the tool accepting a malformed list was the real bug
- the user had a long render running : ask before any restart that could
  touch shared zenki while their work runs

**aftermath, found ~7 h later** : the cube restart left v7-zenki's state
diverged from reality -- the zenki that lost their cube link exited
[ p7-log, all osf-cache instances, powershell ] but v7-zenki kept them
as `online` \ p7-log stuck in `restart` with DEAD pids, so no log files
were written, the always-on set never came back [ openbox, compton,
content, models -> dependents `waiting` ] and ondemand starts misbehaved
[ invoke-web restart stalled after `restart delay` ]. only a full
v7-zenki restart recovered it. check with `v7-zenki.list children` +
`kill -0` on the listed pids. real v7-zenki gaps, not yet fixed : no
liveness sweep of tracked pids, and `zenka.instance.restart` arms its
restart timeout only `if $dependencies_ok` [ likely stuck when cube is
down at that moment -- unconfirmed, the logs of that window are lost ].

#,,..,.,.,.,,,,,.,.,.,,.,,,..,,.,,,.,,,.,,.,.,..,,...,..,,.,.,...,.,,,..,,.,,,
#R357P6JL42TZ5ROXVHZ4ORK54DOZRB3EGVOLXSVS35OO5U7DDUCLCV4QPAZUR5Y6RPWPEAQ3MIUVO
#\\\|JOCSXXAFGI4FUKEC3VU4RD4KWKBGEBPL6QZRP4VDGZWFT6HKPOP \ / AMOS7 \ YOURUM ::
#\[7]YHK2BXPKCX6YWREMRXBAISY3HMKXIVOKDULUAC23OCZU6GIK3KDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
