---
name: never-overwrite-other-users-files
description: a set-up script for another unix user [ protocol-7 ] must append and check, never tee \ > into its ~/.ssh or ~/.n files -- 2026-11-26 broke the external zulum link
metadata:
  type: feedback
---

2026-11-26 : events-pull-keys.sh wrote ~protocol-7/.ssh/config and known_hosts with `tee`
[ replace, not append ]. known_hosts held zulum.v7.ax for the external zenka's ssh-w link
[ /var/protocol-7/host-edit/hosts/zulum.json ] -> host key gone -> ssh refused under
BatchMode -> `auth-keypair : network error [ nothing read ]`, link zulum down for ~an hour.
repaired by appending the caller's trusted zulum.v7.ax line [ p7-ssh-repair.sh pattern ].

**Why:** I could not read that directory [ protocol-7 0700 ] and assumed it was empty ; its
files belonged to running links. a file I cannot see is not a file that does not exist.

**How to apply:** in any script for another user's home : `-e` check first ; append with
`grep -qxF || tee -a` ; for ssh use a separate `Include`-d file or a `Host` block added only if
missing ; print the before state. when a link breaks right after such a change, suspect the
change first [ zulum's cube showed NO attempts -> ssh, not auth ]. related : the link records
choose ssh-w by default when they carry an `ssh` target [ src/link.supervisor.connect ].

#,,.,,.,,,,,,,...,,..,,..,.,,,.,,,,..,.,.,,.,,..,,...,...,,,.,..,,,,.,,.,,...,
#YGQ2LUFJW2S5E6OXDGQW4IY3BWKPUODU2JLQTCHDYZWS6LRBLX6NT5PVX3DBUAWKHLI66OF5RNBXO
#\\\|R6YAKI2JBJJOWPVF422M3HRVOA4XHGGMRSVYXKJMFLXDYIF4KY5 \ / AMOS7 \ YOURUM ::
#\[7]5BMM6VJXEP744V3ZDFEGJQ7I7TLYULOVGKVMQ33GLGP6OJTKSMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
