# user conversion : uid \ gid \ home base

starting point for a future conversion zenka. one manual run so far :
azurum, 2026-10-31, user taeki 1000:1000 /home/taeki -> 5007:5007
/users/taeki. profiles later decide what is acceptable per case
[ fresh install vs a lived-in desktop vs a server ].

## preconditions

- nothing may run as the user : `usermod` refuses otherwise
  - the user's own logins [ ssh, console ] -- ask the owner to log out
  - `systemctl stop user@<old uid>` [ systemd --user : pipewire,
    wireplumber, gnome-keyring, dbus ]
  - protocol-7 zenki running as the user [ on azurum X-11 ran as taeki ]
    -> `systemctl stop Protocol-7`
  - check : `pgrep -u <user> -a` is empty
- the target uid \ gid are free : `getent passwd <uid>`, `getent group <gid>`
- grep host configs for the old home path [ /etc/protocol-7, /etc/ssh,
  /etc/systemd ] -- protocol-7 auth is by user name [ unix-<user> ], not
  uid

## steps

1. `mkdir -p /users`
2. `groupmod -g <gid> <user>`
3. `usermod -u <uid> -d /users/<user> -m <user>`
   - moves the home, re-owns its files to the new uid
   - does NOT re-own files whose GROUP is the old gid : the home itself
     stayed gid 1000
4. re-own everything still on the old ids, outside the moved home too :
   `find / -xdev \( -uid <old> -o -gid <old> \)` -- on azurum :
   `/var/protocol-7/X-11`, `cfg/zenki/X-11/deps/*` in the tree, the home
   dir group. map uid and gid separately [ chown -h old->new per field ]
   - read-only mounts show up [ an installer iso auto-mounted under
     /media/<user> ] : unmount, do not chown
   - skip build debris [ /root/.cpanm ]
5. apparmor : profiles match `@{HOMEDIRS}` [ default /home/ ] ->
   `/etc/apparmor.d/tunables/home.d/users` : `@{HOMEDIRS}+=/users/`,
   `systemctl reload apparmor` [ firefox has a profile ]
6. new users : `DHOME=/users` in `/etc/adduser.conf` [ FIRST_UID \
   LAST_UID ranges : later, owner choice ]
7. `systemctl start Protocol-7`, check the zenki that run as the user
   [ `ps -o user,uid,cmd` ]

## not covered yet

- systemd `ProtectHome=` covers /home /root /run/user only : /users is
  not hidden by it [ hardening gap, nothing breaks ]
- snap \ flatpak assume /home [ not used here ]
- ssh : authorized_keys moves with the home, nothing to do
- crontabs, mail spools, /var/lib entries keyed by name : none on azurum

## rollback [ owner : part of the first zenka slice, not later ]

- the rollback COMMAND ships with the conversion itself and must work on a
  PARTIAL conversion [ interrupted after any step, crash, power loss ]
- journal first : before a step changes anything, record its intent and
  the old state [ old uid \ gid, old home, each path with its old owner
  and group ] in a root-owned journal, synced to disk ; mark the step
  done only after it completed
- rollback reads the journal backwards and undoes only what is recorded
  as started : a step started but not marked done is checked against the
  live state [ e.g. home already moved or not ] before undoing
- each undo is idempotent [ a second rollback run after a crashed first
  one is safe ]
- per-path re-owning is journalled per path [ or in fsynced batches ] so
  a half-done chown pass can be reversed exactly
- the journal stays after a finished conversion until the owner drops it

#,,..,,..,.,.,..,,...,,,.,...,.,,,..,,...,...,..,,...,...,,.,,,,,,,,,,.,,,.,,,
#IDEIMDBAYUJMMHSX5GQM2VYNWGVGS4IXPKNIOKCIYYETAU5Q6CGL3WFHBXOK32IUS437C67ZTTSLO
#\\\|NPWWQS6BADPY43PVAF3WBKOG7RMNXSAVMERNFQHPSQU4QT5RBNK \ / AMOS7 \ YOURUM ::
#\[7]OFJFIKTKRV5UOJACEQCFELUFB3FTC76GXPRD7MJN4V47JTD2GWCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
