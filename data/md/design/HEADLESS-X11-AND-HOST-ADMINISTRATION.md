# headless X-11 sessions, console hardening and host administration

status : design, nothing implemented yet [ 2026-11-05 ]. related :
`data/md/design/LOGIN-SCREEN-ZENKA.md`,
`data/md/concepts/CONCEPT-CONTEXT-AWARE-LOG-MANAGEMENT.md`,
`data/md/concepts/CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md`, the todo
item on concurrent v7-zenki runs.

## 1. auto-xvfb : a virtual display as a fulfilled dependency

### what exists

- `X-11.mode` knows `xvfb` ; `X-11.init_code` accepts instance suffixes
  [ `xvfb-0001` ].
- `auto-xephyr` [ `X-11.init_code` ] : xorg running -> xephyr, else xorg.
- `X-11.helper.alloc_xvfb_display` : a free, harmonically true display number
  above :99 for extra xvfb servers of the host-mode X-11 zenka.
- `X-11.callback.object.xvfb_resource_available` : dependency callback, size
  limit 4096 and `MemAvailable` >= framebuffer + 128 MB.
- `X-11.dev.dimensions_xvfb` : the only size source, a fixed default.

the parallel xvfb servers of the host-mode X-11 zenka are extra displays of
one instance. a test start is a different case : a complete zenka set of its
own, with its own X-11 zenka owning its display.

### mode decision

| situation | mode |
|---|---|
| host-mode X session already running from `/usr/local/protocol-7`, this is another instance [ development path, non-root ] | xvfb |
| server without a display, an X-11 client zenka is wanted | xvfb [ or xvnc, section 2 ] |
| deliberate headless test of code changes | xvfb, even with a display present |
| real console, no X running, first instance | xorg [ today's rule ] |

the first row needs the concurrent v7-zenki work : an instance must know it is
not the primary one.

when an X-11 client zenka starts and no display is reachable, the X-11 zenka
starts in xvfb mode on demand, runs the resource callback first, and the
clients get its display. too little memory : a clear refusal, not a crash.

### screen size

resolved in this order :

1. each X-11 client zenka declares a minimum and a preferred size in its
   config [ the commented `-screen` weather lines are this, by hand ] ;
2. the server size is the largest declared need of the zenki starting ;
3. headless test mode copies the host-mode size [ `X-11.host_mode.min_size`
   or the live root size ], so layouts are tested at the real size ;
4. fallback : `X-11.dev.dimensions_xvfb`.

xvfb allocates its framebuffer at the `-screen` size ; randr only shrinks
within it, growing needs a restart. that is the same open todo as in
`X-11.cmd.set_screen_size` for xephyr : one shared restart-on-resize path.
allocating the largest declared size up front avoids most restarts, and the
resource callback already prices it in.

### display numbers : even \ odd by role

- even : host mode and parent sessions [ including the host-mode X-11 zenka's
  extra xvfb displays ; :0 is even ] ;
- odd : child sessions [ test sets, admin sessions ].

`alloc_xvfb_display` gets the parity as one more condition in its existing
generate -> check -> retry loop. the role comes from one config value, later
from the concurrent v7-zenki socket layout.

this separates the groups without a registry. within one group two instances
can still pick the same number : xvfb refuses to start when
`/tmp/.X<n>-lock` exists, and the X-11 zenka treats that refusal as one more
failed candidate and draws again. `-displayfd` is not used : it cannot honour
the parity.

## 2. graphical admin sessions on servers

### display source

- **provider console** : the provider's vnc shows the real console, a tty
  when no X runs. the X-11 zenka in xorg mode on the provider's virtual
  graphics device makes it graphical. this is host mode on a server. it is
  the out-of-band recovery path : opt-in per host, and the tty must come up
  when X fails [ section 3 ].
- **virtual display** : xvnc [ preferred ], xvfb, xnest or xephyr, reached
  through an ssh tunnel, on an odd display number. xvnc is a virtual X server
  and a vnc server in one process and follows the viewer's window size through
  randr : the viewer decides the size, no size logic needed. it becomes one
  more X-11 mode beside xvfb, with the same resource check.

listen on localhost only, never a public port. the ssh link is the boundary,
the vnc password is not. `::: <alias>` could open the tunnel and start the
session in one step. virtual display first : it reuses section 1 and is
testable headless.

### layers above the display

1. **entry** : the login-screen zenka as greeter. on the provider console it
   is the only barrier in front of a session.
2. **session profile** : a fullscreen admin zenka without window manager [ the
   lightest, one surface ] or an openbox session of flexible size with a list
   of what it starts [ gkrellm, amos-term with nshell, the menu ; compton off
   by default, compositing over vnc only costs bandwidth ].
3. **user profile** : an admin user with a server profile : which monitoring
   starts, what may be installed without asking [ only packages of named
   `p7-deps` profiles ], how long such installs and session state are kept.

### deployment

the v7-zenki start set `remote-server-lowram` [ chosen below
`v7-zenki.cfg.lowram_mb`, 3072 MB ] starts only what `zenki.enabled` and
`zenki.on-demand` list. leaving the graphical zenki off both lists makes them
opt-in there without new code.

| | `remote-server` | `remote-server-lowram` |
|---|---|---|
| virtual admin session | on demand, starts on connect | by hand, or opt-in per host in `/etc/protocol-7/host-config/v7-zenki.cfg` |
| provider-console X | opt-in per host | opt-in per host |

on a small host the cost is the zenki, not the framebuffer : about 90 MB each,
X-11 + login-screen + openbox + terminal + gkrellm is about 400 .. 500 MB. the
admission check adds up the zenki of the session profile and refuses with a
reason when they do not fit. the natural low-ram profile is the fullscreen
admin zenka.

## 3. console hardening

### vt switching

switching from X to a tty is a bypass only when X was started from a logged-in
tty [ `startx` ] : back on that vt, kill X, the shell waits. the X-11 zenka
starts X under v7-zenki, so other vts show a getty with its own login.

- `DontZap` always : ctrl+alt+backspace never kills X under a lock. xorg
  handles these keys before any grab, the s2a grabs do not cover them.
- start-time check : X must not be a child of a logged-in vt session. if it
  is, warn, and keep vt switching blocked while the lock or greeter shows.

| state | vt switching |
|---|---|
| greeter showing, no login attempts | locked |
| session running, healthy | locked |
| repeated failed logins [ threshold, e.g. 3 ] | on + security log entry |
| any sign of failure | on + security log entry |

signs of failure : login-screen cannot reach its auth backend ; login-screen
or X-11 misses a heartbeat or restarts ; its event loop stalls ; X fails to
start or restarts several times in a row.

blocking at runtime removes the vt-switch keys from the live keymap [ xkb ].
restoring needs a working X. a hung X cannot release the vt, so the last
fallback is outside X : v7-zenki ends an unresponsive X server, the console
returns to text mode ; after repeated failed starts it stops trying and leaves
the tty up [ like a15de54fd : an error exit ends, no loop ]. if X hangs
completely only ssh or sysrq remain : the tty fallback covers a misbehaving
session, not a dead X server.

the entry : time, reason, vt, display, and the source of the attempts where
known [ on the provider console : `console` ].

### intended capabilities and outputs

nothing of the appliance tty handling survived. writes to
`/proc/sysrq-trigger` [ `v7-zenki.cmd.host-reboot`, `system-poweroff` ] work
regardless of `kernel.sysrq`, which only governs the keyboard.

| capability \ output | intended |
|---|---|
| keyboard sysrq [ `kernel.sysrq` ] | explicit mask : unraw \ sak [ escape from a hung X ], sync, read-only remount, reboot. no memory or process dumps, no signals to all processes |
| ctrl+alt+del | masked, or set per host on purpose |
| kernel messages on the console | redirected to the log vt, or errors only |
| `dmesg` for non-root | `dmesg_restrict = 1`, explicit |
| gettys | explicit vt plan, not logind `NAutoVTs` |
| failed console logins | `pam_faillock` with lockout, into the security log |
| rescue \ emergency shell | checked : a locked root account must not give a free shell |
| bootloader | grub password or editing lock : on the provider console the largest hole [ `init=/bin/sh` ] |

### vt plan

- tty1 : getty, recovery ;
- tty7 : X with the login-screen ;
- tty12 : read-only zenka console [ p7-log + kernel messages ], no input, no
  login [ the appliance mode ] ;
- more than six vts when a host's plan says so.

### login surface

the appliances hid the hostname : a clean minimal getty prompt, the same for
ssh, and `clear >/etc/motd` on every install. that writes the clear-screen
sequence `ESC[H ESC[2J ESC[3J` : every login wipes the screen and scrollback.
kept as is.

leaks a cleared motd does not cover :

1. `pam_motd` in `/etc/pam.d/sshd` and `/etc/pam.d/login` runs
   `/etc/update-motd.d/10-uname` on every login [ `uname -a` : hostname,
   kernel, arch ]. remove the dynamic `pam_motd` line, keep `noupdate` [ the
   cleared motd ].
2. agetty prints `<hostname> login:` by itself : `--nohostname` in a
   `getty@.service.d` drop-in, an intentional `/etc/issue` and `/etc/issue.net`.
3. sshd adds the debian package version to its first line : `DebianBanner no`,
   `Banner none`, `PrintMotd no`.
4. `PrintLastLog yes` stays : a login you did not make becomes visible.

state seen 2026-11-05 : motd cleared on two of four servers, `10-uname` and
`pam_motd` active on all, `/etc/issue` names the os on all.

the plan is tracked config and rebuildable. `check-console` [ beside
`bin/p7-deps check-service` ] reads the live state [ sysctls, gettys,
ctrl+alt+del target, pam stack, grub lock, console log level, login surface ],
compares it with the host's plan and names every difference. it changes
nothing ; applying is a separate step.

### backup and restore

- before the apply step writes a file, the original is stored xz-compressed
  with a manifest entry : path, owner, mode, checksum, time, plan step.
- only the first original per file counts : a restore goes back to the state
  before protocol-7 touched the host.
- one restore command, all or one path. it backs up the current version first
  [ a restore is reversible too ], asks when the file was edited after the
  apply, and syntax-checks pam and sshd files [ `sshd -t` ] so a restore
  cannot lock out.
- the docs and the audit name the backup and the restore command beside each
  change.

## 4. host administration log

### layout

```
/var/protocol-7/host-admin/       owner : host-admin [ rw ]
  log                             what was changed, with restore handles
  backup/ , backup/manifest       originals for restore

/var/protocol-7/forensics/        owner : forensics zenka
  security-log                    append-only : security events + admin log chain heads
```

`/var/protocol-7/<zenka>/` is the existing convention. `/var/log/protocol-7`
stays p7-log's alone : only p7-log edits there.

### administration log

- per host, root-only. entry : who [ zenka or tool, on behalf of whom ], what
  [ files with backup references, packages, services, sysctls ], why [ plan
  step and the detected context ], how to undo [ restore handle or `not
  reversible` ].
- hash-chained and signed.
- writers, in order : `p7-install` [ the first entry ], the console plan apply,
  later `p7-deps` installs, dist-upgrade, any zenka changing host configuration.
  a zenka that does not write yet is simply not covered.
- the report is a view : log + live audit [ what was changed, by whom, where
  the host drifted since ].
- the log is an exact inventory of the host's hardening, gaps included : never
  in the repo, through cube only to the authorized admin.

### writer and owner

- first version : v7-zenki [ root ] is the single writer ; zenki submit
  entries as a command, v7-zenki checks, appends, signs. one writer, so no race
  on the last entry. `p7-install` runs before any zenka and writes directly in
  the same format.
- later : a host-admin zenka [ network or hybrid, its own console interface,
  delegated as the host's admin, e.g. in a fully zenki-managed resource pool ]
  owns the directory rw. either it runs as root, or v7-zenki stays the root-side
  writer. the doc describes the writer as a role.
- delegation : host-root signs "this host-admin key may administer this host
  for this pool until revoked" [ like the cube `.dlg` ]. delegation and
  revocation are entries ; host-admin signs its own entries, verifiable back to
  host-root. every entry says where the decision came from : local, which pool
  controller, or the console.
- console mode works without network : read the report, restore, revoke the
  delegation. revoking is the local override when the pool misbehaves.
- remote reads and requests are cube commands : list the four grants up front
  [ cube access.users, cube access.zenki, external zenka.v7, the target's
  access.cmd.usr.cube ].
- `host-edit` [ remote host set-up ] triggers the remote's first entry through
  the `p7-install` run it starts, and is the natural place to read a remote
  report.

### automatic decisions

bolder automatic decisions for detected contexts are defensible when all
automated channels are clean and :

1. the detection is logged, not only the action ;
2. one-command undo exists before the action runs ;
3. anything irreversible or able to cut access [ data deletion, keys, network
   or sshd changes ] stays a question - in a pool to the pool's admin.

### security log

an owner with rw and its own key could rewrite the admin log and sign it again ;
a hash chain only proves self-consistency. the forensics zenka, as second
recipient, closes that :

| role | admin log | backups | security log |
|---|---|---|---|
| host-admin | rw [ appends, signs ] | rw [ restore ] | submits events |
| forensics zenka | read-only | read-only | sole writer, append-only |
| host-root | signs delegation and revocation | - | - |

- content : vt-switching events with reasons, failed console logins,
  delegations and revocations, audit breaks and drift, admin log chain heads.
  nothing is ever changed.
- append-only three ways : by protocol [ only the forensics zenka writes, it
  only appends ], by file system [ `chattr +a` ; a missing flag is a finding ],
  by chain [ hash-linked, signed, newest head also off the host where possible ].
  an undetected change needs all three broken.
- rotation : a closed segment ends with a signed final head and is
  xz-compressed whole ; the next file opens with that head. lossless only.

### relation to p7-log compaction

p7-log's age-based compaction is lossy by design ; it never applies to the
security log. its anomaly surfacing is the feed : what compaction cannot
compress and is security-relevant goes to the forensics zenka at full
resolution with its preserved parameters. later compaction of
`/var/log/protocol-7` cannot erase it.

| | `/var/log/protocol-7` [ p7-log ] | `/var/protocol-7/forensics/security-log` |
|---|---|---|
| edits | p7-log only | none, append-only |
| compression | lossy by age, anomalies kept | lossless xz of closed segments |
| content | all runtime output | security events, promoted anomalies, chain heads |
| retention | shrinks with age | complete |

## 5. order

1. auto-xvfb mode decision + even \ odd allocation [ testable headless ] ;
2. xvnc mode + ssh-tunnel admin session, fullscreen admin profile ;
3. administration log format + `p7-install` first entry ;
4. console plan : `check-console` audit first, then apply with backup \
   restore ;
5. security log + forensics anchoring ;
6. provider-console X with the vt-switching rules ;
7. host-admin zenka and delegation.

#,,,.,,..,..,,,,.,..,,.,,,...,...,.,.,..,,..,,..,,...,...,...,.,.,...,...,..,,
#QKB3K2HGQV4HNI3NBMHLINFJMW3YVRTGGQ3IB4YUSU6UBL6PWGS6MVXXEWBZJKJBIQAPN2RZPOTN2
#\\\|M3W3Y2UO2HQZSLNCPTEWA4VQQCK7C6RWWL7FJRP6P6RK5G6NETM \ / AMOS7 \ YOURUM ::
#\[7]737WFF3NVLSWCL2PKBOH5UZGODAPHP6JIQKXLGSN6HWKTF5FFQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
