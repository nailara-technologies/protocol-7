# login-screen zenka : native x11 greeter and user session admission

status : slice 1 implementation. native authentication only ; no display
manager and no pam dependency. the web login designs remain separate :
`LOGIN-ADMISSION.md` and `WEB-UI-USER-LOGIN.md` govern browser tokens and
browser credentials, not local x11 sessions. names use `login-screen` for the
greeter, `login-screen-session` for the external per-user session process,
and `v7-zenki.login-session-start` for the narrow admission command.

## 1. goals and non-goals

- start xorg through the existing `X-11` zenka [ normally display `:13` ],
  then draw one native Gtk3 greeter on that display.
- every surface is dark before it is mapped : dark violet \ blue defaults,
  large readable type, no white gtk fallback, no splash or bright fade.
- only a small root child reads shadow and calls `crypt()`. the Gtk process
  drops privileges before connecting to cube or creating its window.
- successful authentication creates a short-lived, single-use root grant.
  `v7-zenki` consumes that grant and starts the session as the authenticated
  unix user, never as the generic desktop \ amos user.
- openbox uses `openbox.<user>.xml` ; compton follows ; the user's native
  autostart follows both. openbox exit, compositor failure, supervisor
  failure, and explicit session termination all lead back to the greeter.
- slice 1 is local console login. pam is a possible optional backend later,
  not a reason to put pam or shadow access in the greeter now.
- slice 1 is not a screen saver, lock screen, tty manager, display manager,
  remote login service, or browser credential store.

## 2. processes and privilege split

### X-11 and v7-zenki

`X-11[xorg]` owns xorg and its display connection. `v7-zenki` remains root and
is the only session launcher. the desktop start profile enables `X-11` and
`login-screen`, but not openbox, compton, or `login-screen-session` : those
only appear after admission.

### login-screen [ unprivileged after early init ]

early startup loads `login-screen.*`, creates the helper socketpair and root
grant directory, and forks `bin/login-screen-auth`. it then calls
`root.drop_privs` for `login-screen.greeter_user` [ default
`<system.amos-zenka-user>`, a service account, not the future session user ].
only after that drop does it connect to cube, obtain display and xauth data,
and initialize Gtk3.

the greeter owns :

- the user interface and its state machine ;
- the non-secret username and the transient password buffer ;
- one inherited, connected socket to its root helper ;
- its own 0600 xauthority file needed to draw ;
- no shadow, passwd policy, grant-directory, or root session-launch access.

a compromised greeter can ask v7 to start a session, but cannot satisfy the
root grant check without first authenticating. the cube grant is deliberately
not sufficient by itself.

### login-screen-auth [ root, minimal ]

the helper starts before the privilege drop and keeps only its end of the
connected socket. production mode requires euid 0 and fixed paths
`/etc/passwd`, `/etc/shadow`, and `/etc/shells`. it has no network socket,
config reload, shell execution, or command channel other than the framed
authentication request.

on success it writes a root-owned 0600 grant file below
`/var/run/.7/login-screen/grants`. the random 256-bit ticket names the file ;
the contents bind username, uid, and expiry. the helper returns only the
ticket, never the password hash or account details. a grant expires after 30
seconds and is unlinked by v7 on first use, including a launch that later
fails.

### login-screen-session [ authenticated user ]

v7 starts this external supervisor with `exec_usr_from_subname` after strict
validation. it runs with the authenticated user's real and effective uid,
primary and supplementary groups, home, and clean environment. its openbox,
compton, and autostart children inherit that identity.

the supervisor reads no shadow data and receives no password. it validates
that its uid and `USER` still name the same account, that `DISPLAY` is valid,
and that its xauthority file is user-owned 0600. it exits rather than falling
back to another user, display, or openbox config.

## 3. login flow

1. v7 starts xorg and then `login-screen`. X-11 writes a private 0600
   authority file before starting xorg with `-auth`, then authenticates its
   own connection and inserts `SI:localuser:<x11-user>` plus root before the
   display becomes ready. the greeter starts its root helper and drops privs.
2. the greeter resolves `DISPLAY` and asks X-11 for protocol name + cookie.
   it writes a private xauthority file before Gtk initialization. no cookie
   means no window and a startup error, not an insecure X connection. any
   failed setup statement ends the greeter before a window is mapped.
3. Gtk settings prefer the dark theme before any widget is realized. a
   fullscreen undecorated window, all widgets, and the complete CSS are built
   before `show_all`. the greeter enters `greeter` state.
4. submit validates username shape and password length locally. state moves
   to `authenticating` ; input and submit are disabled. the password goes in
   a length-prefixed binary frame over the inherited socket. it is never in
   argv, environment, cube traffic, logs, status text, or a file.
5. the helper enforces delay, account policy, and `crypt()` verification. all
   ordinary failures return the same `FAIL`. a delay returns `WAIT <secs>`.
   success returns `OK <ticket>` after the root grant is durable.
6. the greeter overwrites its password and request buffers, clears the entry,
   and sends `v7-zenki.login-session-start <user> <ticket>`. state moves to
   `starting` ; the window remains dark.
7. v7 authenticates the caller, validates and consumes the grant, re-checks
   uid >= 1000, fetches display + xauth itself, and writes a user-owned 0600
   xauthority file. it then inserts `SI:localuser:<user>` through the v7-only
   X-11 command. only after that grant succeeds does it start
   `login-screen-session[user]`.
8. once v7 reports the external session running, the greeter clears the
   ticket, hides its window, and enters `session`. the root stays dark.
9. openbox starts with the exact per-user config, compton starts next, then
   `$XDG_CONFIG_HOME/protocol-7/autostart` [ or
   `~/.config/protocol-7/autostart` ] runs when present and executable.
10. when the supervisor ends, v7's end handler revokes the session user's SI
    entry, removes its xauthority file, and calls
    `login-screen.session-ended`. the greeter discards any old form state,
    shows the dark window, and returns to `greeter`. the session itself is
    never automatically restarted.

## 4. authentication policy

### account admission

every condition below is required, and all refusals use the same external
failure :

- username matches `[a-z_][a-z0-9_-]{0,31}` [ no newline, slash, whitespace,
  option, path, or log injection ] ;
- explicit membership in `login-screen.auth.allow` ; empty or missing means
  deny everyone ;
- passwd record exists, uid >= 1000, and the shadow name matches exactly ;
- shell is absolute, executable, listed in `/etc/shells`, and is not a
  `nologin` or `false` binary ;
- shadow hash is non-empty and not locked with `!` or `*` ;
- account expiry day has not passed ; forced-change, expired password, and
  expired inactive grace periods are refused rather than starting a session ;
- the supplied password's `crypt( password, stored_hash )` matches in a
  fixed-length byte loop whose exit does not depend on the first difference.

unknown and inadmissible users run `crypt()` against a fixed dummy sha512
hash, so the common miss path also performs password work. error text never
says which policy item failed.

### password lifetime

requests have a small fixed upper bound [ 1024 octets ] and explicit lengths,
so whitespace and non-utf8 octets are not line protocol. helper and greeter
use raw io. mutable password and frame scalars are overwritten after use on
every reply path. perl can make internal copies, so this is best-effort
memory hygiene, not a claim of guaranteed erasure from every interpreter
buffer ; the design therefore also minimizes the number of consumers.

### abuse resistance

the helper keeps all counters centrally in root memory :

- per user : failures beyond the free threshold impose 1, 2, 4 .. second
  delays, capped at 60 seconds ;
- global : failures beyond a separate free threshold impose growing delays,
  capped at 30 seconds ;
- an attempt inside either delay gets `WAIT` before shadow access or crypt ;
- success resets that user's counter. global history decays instead of being
  cleared by one success, so rotating usernames does not reset the budget ;
- restart clears memory, but grants remain short-lived and single-use.

these are local-console delays, not permanent account lockout. there is no
unauthenticated disk write per failed attempt.

## 5. state machine

states :

- `init` : helper, privilege drop, cube, display, xauth, and Gtk setup ;
- `greeter` : form enabled, password empty, neutral status ;
- `authenticating` : one helper request in flight, form disabled ;
- `starting` : valid grant sent to v7, form disabled ;
- `session` : greeter hidden, external user session active ;
- `failed` : short generic error display, then `greeter` ;
- `shutdown` : password and ticket cleared, window destroyed, helper socket
  closed.

allowed transitions :

```
init -> greeter
init -> shutdown                 [ any setup error ]
greeter -> authenticating -> greeter
authenticating -> starting -> session
authenticating -> failed -> greeter
starting -> failed -> greeter   [ grant, xauth, or launch failure ]
session -> greeter              [ logout, clean end, crash ]
any -> shutdown
```

there is at most one authentication request and one user session. old replies
carry no authority after state has changed. a helper death is fatal to the
greeter so v7 recreates both halves ; it never becomes an unauthenticated
fallback.

## 6. theme and no-flash rules

`cfg/zenki/login-screen/theme.cfg` supplies :

- `font_family`, `font_size` [ default 32 px ], title and status sizes ;
- background, panel, text, muted text, accent, entry, and error colors ;
- `brightness` as a bounded multiplier applied to configured rgb colors ;
- padding and content width.

defaults use `#05040f` \ `#0b1024` backgrounds and muted violet \ blue text.
brightness never selects a theme with a light default. values are parsed and
clamped before CSS generation ; malformed colors fall back to the dark
constants, not gtk defaults.

the window uses the system visual [ no transparency dependency ], prefers the
dark Gtk theme, has no image or animation, and is shown only after CSS and
children are complete. hiding it for a session does not clear the root to
white. lock mode reuses the same renderer and palette.

## 7. failure modes

| failure | behavior |
|---|---|
| allow-list missing \ empty | every authentication fails |
| helper cannot start, dies, or replies badly | generic failure \ supervised greeter restart ; no session |
| malformed \ oversized frame | connection fails closed ; no crypt |
| shadow \ passwd \ shells unsafe or unreadable | affected request fails ; no fallback store |
| unknown, locked, expired, nologin, uid < 1000, not allowed | same `FAIL` as a wrong password |
| grant stale, wrong user, malformed, replayed | v7 refuses before xauth or process creation |
| no X cookie, bad display, xauthority write failure | no session launch ; return to login |
| per-user openbox config missing | supervisor exits before starting a partial desktop |
| openbox or compton exits | supervisor terminates remaining session children and exits |
| autostart missing | valid empty choice ; desktop continues |
| autostart fails | logged by session output ; desktop remains, later policy may change |
| session crash | v7 end handler restores the greeter ; no automatic session restart |
| greeter crash during a session | v7 restarts the greeter in `greeter` ; active-session reconciliation is slice 2 |

## 8. cube and configuration surface

`login-screen` receives only its required X-11 reads,
`v7-zenki.login-session-start`, and `v7-zenki.register_child`. v7 receives
`login-screen.session-ended` plus the two narrow X-11 session-user grant \
revoke commands. no wildcard is added for either side.
`cfg/zenki/cube/auth.zenki` authenticates `login-screen` as a zenka.

tracked auth config contains policy defaults and an empty allow-list. the
host must set real names in `/etc/protocol-7/host-config/login-screen.cfg`.
the example desktop profile is inert until that list and the per-user
openbox configuration exist.

`login-screen-session` is not a cube-connected zenka and needs no cube user.
its start config exists only so v7 can supervise the external process.

## 9. later lock-screen mode

lock mode is the same process and renderer, not a second locker :

- on lock, v7 records the already authenticated session user and switches the
  greeter from hidden `session` to visible `locked` ;
- the username is fixed to that session user ; no user switching and no new
  session grant is possible ;
- the root helper authenticates with mode `reauth`, requiring the returned
  identity to equal the locked uid. rate limits remain active ;
- success asks v7 for a fresh single-use unlock grant, then returns to hidden
  `session`. the existing session processes are never stopped and restarted ;
- failure stays locked. helper, xorg, or greeter failure must fail locked,
  never expose the desktop ;
- before implementing this mode, greeter crash recovery must reconcile the
  live session into `locked`, and input grabs \ focus \ multi-monitor coverage
  need real-host tests. until then slice 1 does not claim to be a secure
  screen saver.

## 10. slices

1. native greeter, root crypt helper with fixture-only test mode, root grant,
   v7 per-user supervisor launch, xauthority transfer, openbox + compton +
   native autostart, logout \ crash return, cube entries and fixture tests.
2. active-session reconciliation after greeter restart, asynchronous helper
   io in the Gtk loop, shutdown \ reboot controls with separate policy, and
   x11 focus \ grab hardening on a real test host.
3. lock \ reauth mode from section 9, including multi-monitor and crash tests.
4. optional pam backend behind the same helper protocol and account policy.
   crypt \ shadow remains the native default ; pam never moves into Gtk.
5. installer \ service hardening : dedicated greeter account, protected host
   config examples, persistent rate-limit policy if desired, and packaged
   session desktop entries.

## 11. verification boundary

slice 1 tests use temporary passwd, shadow, shells, grant, openbox, compton,
and autostart fixtures. helper fixture switches are refused in production
mode, and the test never reads the real `/etc/shadow`. no test starts or
restarts a zenka, touches a real host display, installs a setuid file, or
uses a real user session. real xorg, keyboard focus, actual logout, and
multi-monitor behavior remain explicit real-host validation steps.

#,,,.,.,,,,.,,,,.,,..,...,.,.,,,,,.,,,...,..,,..,,...,...,,..,.,.,...,..,,,..,
#FKMTN5TYCL2EN3IWBPIFYYD43CYKFQ5F2XYSJIU7XOTOCHNGQLUE5CPZMUHC57JK6PFICTMSWGNCM
#\\\|3FDO5VSUJG3KLPQXCIS3TDSOZLPRKNWWHRUO6SD7JARHSKAC7OA \ / AMOS7 \ YOURUM ::
#\[7]QH44SVO3GVQTYGFMAMMSH5WVK5ZZXHWFJ3L2UOOLZDVNC6M5CMCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
