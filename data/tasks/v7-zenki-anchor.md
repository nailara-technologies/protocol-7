# v7 : a root process above v7-zenki [ name proposed 2026-11-26, `<anchor>` below = v7 ]

status : DESIGN DRAFT 2026-11-26 -- nothing implemented ; name, wrapper form and the feature set
are open. the aim is an improvement, not a fix that only adds overhead.

## why

2026-11-26 : the desktop v7-zenki [ pid 229, root ] spun at 100 % cpu for ~2 h [ 125 min cpu ].
the kernel stack was empty, signal 53 [ devmod ] and TERM had no effect -- perl defers signals
until the current op ends : one long op, most likely a backtracking regex on some input. its
log had already stopped ~20 h earlier [ 14:30, right after starting the on-demand kimi zenka ]
while it kept working [ cube logged its session keys until ~10:40 ].

nothing noticed either phase, and nothing could act : every zenka, cube and notify included, is
a CHILD of v7-zenki. cube can only drop the connection, which needs v7-zenki's event loop to
notice ; a stuck loop notices nothing. only kernel-handled signals reach such a process
[ KILL, STOP ]. so the only clean place for supervision is above v7-zenki, as root.

## the shape

1. `<anchor>` is the systemd unit's MAIN process, v7-zenki its child. systemd sees only the
   anchor, whose pid never changes -- a v7-zenki restart is invisible to systemd [ a sibling
   would make systemd start a second v7-zenki, or kill the cgroup with KillMode=control-group ].
   without systemd the same : `<anchor>` started by hand or an init script.
2. minimal : no module system, no plugins, no event loop of its own beyond the pulse wait ;
   small enough to review in one sitting. it never runs code that could hang like v7-zenki did.
3. everything loaded at start, nothing at crisis time : no require, no config re-read ; argv
   plus at most one small native file read once. a stall often comes with memory pressure.
   target well below a zenka [ v7-zenki : 54 MB rss ] -- core perl only, or c.
4. pulse : a pipe v7-zenki -> anchor, written from v7-zenki's EVENT LOOP on a
   <[base.interval.next]> rhythm. a missed pulse means the loop is stuck, not merely busy.
5. evidence before action, without exec where possible : /proc/<pid>/{status,stat,wchan,
   syscall}, cpu over a few seconds -- written straight to a file in the zenka var dir. gdb
   [ `-batch -ex bt` ] only last, with a timeout, failure recorded [ a big process under
   pressure ].
6. recovery : TERM, wait, KILL, then start v7-zenki again [ plain fork + exec, argv and env
   kept from the first start ]. v7-zenki gains "restart myself" = ask the anchor.
7. reporting : after a recovery the NEW v7-zenki reads the evidence file and sends notify --
   nothing has to send while the tree is down.
8. who watches the anchor : systemd if present, otherwise its simplicity.

## start, compared to a regular zenka

| | regular zenka | `<anchor>` |
|---|---|---|
| started by | v7-zenki [ `bin/Protocol-7 <name>` ] | the unit \ by hand -- first |
| config | zenka.v7, modules, overlays | argv + one small native file, once |
| identity | keys, cube auth, access lists | none : no network, no cube |
| user | drops privileges after init | stays root |
| logging | buffer -> p7-log | its own file, written directly |
| watched by | v7-zenki heartbeat | systemd \ nothing |
| installed by | v7-zenki [ like p7c ] | `p7-deps install-service` [ must exist before v7-zenki ] |

today's unit [ installed ] : `ExecStart=bin/Protocol-7 v7-zenki -c -v`, `Restart=always`,
`RestartPreventExitStatus=76`, `KillMode=mixed`, `TimeoutStopSec=30`. with the anchor :
- ExecStart becomes the anchor, which starts `bin/Protocol-7 v7-zenki -c -v`
- Restart=always and the 76 rule stay and now apply to the anchor : a deliberate v7-zenki
  exit 76 makes the anchor exit 76 -- today's behaviour kept
- stop : KillMode=mixed sends TERM to the anchor only ; it forwards to v7-zenki, waits, KILLs
  itself before TimeoutStopSec. teardown = restart stays [ owner's habit, never changed silently ]
- updating the anchor : execve of its new binary in place -- same pid, systemd sees nothing,
  v7-zenki stays its child ; child pid + pulse fd handed over through argv

## the entry layer

bin/protocol-7-gtk3 is an exec wrapper : zenka name from the symlink name [ protocol-7.<name> ,
v7-zenki.install_zenka_symlinks ], perl path from $Config{perlpath} [ no PATH under systemd ],
env set, then exec. the anchor reuses that entry layer but FORKS and stays. open :
1. a separate wrapper beside protocol-7-gtk3
2. one shared entry layer with two modes [ exec \ anchor ] -- no drift, gtk3 wrapper more involved

## beyond the fix -- candidates that make it an improvement

the anchor is the one process that survives everything below it. what only such a process can
do well :

- **socket handover** : the anchor opens and HOLDS the cube listening sockets [ unix + tcp ] and
  passes them down [ like systemd socket activation ]. a v7-zenki \ cube restart then loses no
  listening socket ; clients [ p7c, :::, links ] see a short delay, not "connection refused".
- **crash-loop protection with a safe mode** : a v7-zenki that keeps dying is restarted on a
  <[base.interval.next]>-style backoff, after N failures in a minimal set [ cube, p7-log, notify ]
  so the owner is told and can look, instead of a silent loop.
- **verified start** : the anchor checks the AMOS signatures of bin/Protocol-7 and the base
  sources before each [ re ]start and refuses a tampered tree -- the one point no zenka can
  bypass.
- **own restart history** : every start, exit reason, stall evidence, in one native journal --
  "what happened tonight" without assembling it from 30 zenka logs.
- **process hygiene** : oom_score_adj per layer [ anchor never, v7-zenki low, zenki normal ],
  limits, the clean environment -- set once, at the top.
- **in-place v7-zenki upgrade** : "restart myself" becomes a controlled handover [ new v7-zenki
  started, old one told to hand its children over or end them ] -- the basis for adoption.
- **adoption [ later, hard ]** : a new v7-zenki takes over the running zenki [ pids, sockets,
  cube sessions ] instead of a full restart.
- **log silence** [ not the anchor, the system zenka ] : a zenka that normally logs regularly
  and has gone quiet raises a signal -- would have caught 14:30 the same afternoon.

## open decisions [ owner ]

- the name : PROPOSED `v7` [ owner + claude 2026-11-26 ] -- process title plain `v7`, no host
  prefix [ it is the host's protocol-7 itself ; `pgrep -x v7` finds exactly one ] ; v7-zenki
  -- NOT settled [ owner ] : under a top `v7` the `v7-` prefix of v7-zenki is redundant.
  rejected : parent [ every process is one ; "parent zenka" means the forking zenka ],
  litter [ names the young, not the holder ]. earlier candidates : anchor, stem, hearth,
  ground, origin
- naming as ONE block [ owner 2026-11-26 ] : the top process [ v7 ], the zenki manager [ today
  v7-zenki ; `v7-` redundant under v7, plain `zenki` taken ] and the existing `zenki` zenka
  [ src/zenki.* , 17 modules ~2026-10-28 : zenki.parent.ensure_v7 \ ensure_cube \
  resolve_dependencies \ start_via_v7 -- "ensure the base, start with dependencies", partly
  the same role as the new top ]. open : does that role move into v7 + the manager [ the
  zenka goes, `zenki` is free ] or stay a client-side tool under its own name
  PROPOSED split [ owner + claude 2026-11-26 ] : `zenki` is too generic for a PROCESS [ the
  name of the whole kind ] but right for the user's CONSOLE COMMAND for the whole tree
  [ like git \ systemctl : `zenki status`, `zenki start weather`, `zenki logs cube` -- the
  zenka already has zenki.console.status \ start \ attach-logs ]. so : `v7` = root process,
  the manager = a resident process named for its ROLE [ still open : not `zenki`, no redundant
  `v7-` ], `zenki` = the console tool ; what it does that v7 \ the manager do better
  [ ensure the base, dependency start ] moves there.
  `litter` : a named group of zenki, mainly a TEAM sent roaming with a mission -- its own
  design in data/tasks/litter-roaming.md. needed from here : the litter record carries more
  than names [ parameters, roles, formation type, mission ] ; start-set-up.base = the base litter
- separate wrapper or shared entry layer
- perl [ core only ] or c
- `bin/Protocol-7 v7-zenki` started directly : always re-exec under the anchor, or allowed without
- which of the "beyond the fix" features belong to the first version
- the kill step : automatic after a long grace, or report only at first
- children on recovery : full restart [ today ] or adoption later

#,,,.,.,,,.,,,.,.,.,.,,.,,,,.,.,,,.,,,...,.,.,..,,...,...,..,,,,.,,,,,..,,,,,,
#IV5OTGTVQT7HMKNLKYNYK5JZXJUQVK5P6SMR6WKWT6QGQOYZZ4ZOELBGCKUHCOGGTHLX6U6FAGH6Y
#\\\|2FCNCJ5NU6ETOJTUSSQUQDRQ5Z6TRKWSCBI6Q5W4ZCDA5LISOO3 \ / AMOS7 \ YOURUM ::
#\[7]ON52AYDZFQIKKDKHY5RN5TOHO26JGDXHVXOOLBNONKMYP5YSHGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
