---
name: feedback-v7-restart-stop-stale-zenka-registration
description: "v7.restart/v7.stop can leave a zenka's OLD process still connected to cube under the same zenka name -- cube then routes commands to whichever registration it prefers, which may be the stale one, silently testing dead code. p7c term-all <sid> (found via list subnames) is the reliable forced cleanup."
metadata:
  type: feedback
---

Hit repeatedly 2026-08-14 live-testing the `sessions` zenka's first
key-holding child (see [[vision-sessions-zenka-key-holding-children]]).
Neither `v7.restart <zenka>` nor `v7.stop <zenka>` reliably guaranteed a
single live instance — `p7c list subnames` sometimes showed TWO `sessions`
entries at once (an old one from a prior test cycle, still connected to
cube, alongside a freshly-spawned one), and `v7.stop <zenka>` sometimes
stopped the wrong one (`shutting down 1 zenka instance` — but the OLDER
one was still there afterward) or reported `there is no zenka matching
zenka running` while a stale instance was demonstrably still alive and
answering commands.

**Symptom this produces**: commands appear to succeed or fail in ways
that don't match the code just edited, because they're being routed to
the OLD process still running the PRE-edit source. Cost real time this
session before being diagnosed — confirmed via `ps -o pid,ppid,cmd -p
<pid>` cross-checked against `list subnames`'s session ids: the stale
process's PPID pointed at a long-dead v7 lineage (reparented to an
init/subreaper pid, not the current live v7), not the current running
`v7` process.

**Reliable fix**: `p7c list subnames | grep <zenka>` to get the session
id(s), then `p7c term-all <sid>` for each — this closes the cube
connection directly rather than going through v7's own (apparently
sometimes-stale) process-lifecycle bookkeeping. Confirmed this reliably
leaves zero stale processes, verified via `ps aux | grep <zenka>`
immediately after.

**How to apply**: before trusting a `v7.restart`/`v7.stop` result during
live iteration on a zenka's code, cross-check `list subnames` for
duplicate registrations and `ps -o pid,ppid` to confirm which process is
actually the current v7's child. If in doubt, `term-all` every matching
session id and let the zenka respawn on-demand fresh, rather than trusting
the restart/stop command's own success message.

[[vision-sessions-zenka-key-holding-children]]
[[feedback-stuck-zenka-recovery-v7-stop]]

#,,..,.,.,,,,,,..,,..,,,,,..,,,.,,,.,,,,,,,.,,..,,...,...,...,..,,,,.,,,,,,.,,
#2K3AVFFDZJ5EDTZPGIH3D2FVSIWZSBBAJME6GB42XYNUXOUDJMABW56R7ITRBOAFKHRVZ7PARPOEG
#\\\|SDNX6UF2A4MHFXO4JA2E7IQGWUURV5GU3ZHO4C7A7ZVIZIEXRVI \ / AMOS7 \ YOURUM ::
#\[7]XMTT3ORWR2RVZCL75OZZGQO5DT745EWW7G3Q6Z6BPXNG2GISIEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
