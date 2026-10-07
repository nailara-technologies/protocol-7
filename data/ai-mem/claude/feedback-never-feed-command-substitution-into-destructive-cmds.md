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

**follow-up 2026-10-05 afternoon** : the liveness sweep landed
[ `fa550b716`, every 7 s, dead tracked pids -> the normal SIGCHLD path,
child entry restored first so the instance restarts instead of being
deleted by process_zenka_end ]. live : 0 false positives over ~38 sweeps
on a healthy system ; a deliberate clean `v7-zenki.restart cube` did NOT
reproduce the incident [ always-on set restarted with new pids, ondemand
powershell left the list cleanly, sweep had nothing to do ]. user : the
cause was "something about the ondemand zenka state machine", maybe not
easily reproducible -- consistent with that night's victims [ invoke-web
vanished, powershell kept a dead pid ] and with the earlier ondemand
races [[topic-ondemand-starting-flag-race]] [ resolved by design, the
deleting line never found ] and [[project-ondemand-zenki-registry-wipe]].
if it recurs, the sweep's level-0 `: liveness :` line names the instance
\ zenka -- that is the evidence to start from.

**ON RECURRENCE -- investigate immediately, aim for a reproduction**
[ user, 2026-10-05 ]. trigger : any `: liveness :` line in the v7-zenki
log, or v7-zenki listing an instance `online` \ `restart` whose pid is
dead [ `v7-zenki.list children` + `/proc/<pid>` ]. open hypotheses, none
with evidence yet :
1. ondemand state machine timing [ user's first guess ; both victims were
   ondemand ; see the two ondemand memories above ]
2. `reload config` without the init phase clobbering runtime state
   [ [[feedback-config-reload-clobber]] ] -- checked : cube's ondemand
   registry `<zenki.virtual>` is declared in NO config file, so not via
   that path ; other keys unchecked
3. old callback \ code references assigned non-reload-safely [ a timer or
   watcher keeps running pre-reload code against new data ] -- earlier
   sweeps fixed such cases ; that night only cube was reloaded
   [ source x2, config x4 ], v7-zenki was not, so it would have to stem
   from an older reload
first steps : note the instance + zenka from the liveness line, grep the
on-disk zenka logs for `< reload config >` \ `< reload all >` \ reload
source markers before it, check whether a cube restart or an ondemand
idle shutdown preceded it, then try to replay that sequence on purpose.

4. **CONFIRMED mechanism 2026-10-07 [ likely the answer ]** : v7-zenki stopped catching SIGCHLD after any p7c \ p-7-r compile [ at start or on reload ] -- `$SIG{CHLD}` restore + a duplicate CLD alias watcher, see [[never-touch-sig-under-event-watcher]]. without SIGCHLD, ended zenki stay zombies and their instances keep dead pids -- exactly 'dead pids listed online' ; the liveness sweep [ fa550b716 ] then recovered them. fixed 07e19f5a2. on recurrence check SigCgt bit 16 of the v7-zenki pid FIRST.

#,,,,,,,.,,.,,.,.,.,.,.,,,,,.,.,.,,,.,.,.,,,.,..,,...,...,.,,,,,,,,,,,.,.,..,,
#PDQOQMGRVKPIBVXEGIZHRMP4JCZMFBGTL6UU3W5C6FJMPEM7ML7QBFQZPRFA5OCCUVIJBHUY64NN6
#\\\|H4E6SYB464D7MJKQLPYD2HASOMTFFKNEWVB5OFOXXWDQFNUDRDH \ / AMOS7 \ YOURUM ::
#\[7]UHJKZI6QWE5ATLW6SWVLDYPWBU6BNOWCTOEYYQJWVH3HOV7UG2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
