# memory cap for zenka children : transient scope via v7-zenki

brief [ 2026-10-18 ]. layer 2 of data/tasks/coding-cpu-host-setup.md
[ llama-server under MemoryMax ] cannot use `systemd-run --user` on a
service host : no lingering user session, no XDG_RUNTIME_DIR in a zenka
started from the system unit. the systemd-sanctioned alternative needs
no user session and no unit change :

1. the coding zenka spawns llama-server as today [ unprivileged ] and
   registers it as its child [ v7-zenki.zenka.cmd.register_child ]
2. it asks v7-zenki to cap THAT child [ a narrow command : pid + role ]
3. v7-zenki [ root ] calls the system manager over the system bus :
   StartTransientUnit `llama-<pid>.scope`, PIDs = [ pid ], MemoryMax
4. systemd enforces the limit ; the scope ends with the process

the dbus zenka does not fit : it wraps the X11 SESSION bus as the AMOS
user ; StartTransientUnit on the system manager needs root.

## protection : no capping of foreign processes [ user ]

capping is a lever : capped low enough, any process dies -- a request
must never reach a process that is not the requester's own child. the
same validation the child registry already does [ register_child :
/proc start time as the pid-reuse guard, cmdline as the plausibility
check, both re-verified before any keep \ claim \ signal ] :

- the pid must be a REGISTERED child of the requesting zenka instance
  [ v7-zenki.child, recorded at register time -- not a live /proc parent
  lookup, which races with reparenting ]
- re-verified right before the call : the recorded /proc start time
  still matches [ pid not reused ], the cmdline still matches the
  registered role [ e.g. the configured llama-server binary ], the uid
  is the zenka user
- the VALUE comes from v7-zenki's own host config per role
  [ e.g. memory_cap.llama-server = 14G ], never from the request ; the
  request only names the role
- a cap BELOW current usage is accepted by the kernel and acts as a kill
  [ reclaim fails -- no swap -- the oom killer acts inside the cgroup ] :
  v7-zenki refuses a cap at or below the child's current memory use plus
  a margin, and the cap is meant to be set right after spawn, before
  the model is loaded [ user ]
- one scope per child ; a refused request changes nothing and is logged
  with the requester's instance id
- tests : a foreign pid, a reused pid [ start time differs ], a wrong
  cmdline, another zenka's child, a value in the request -- all refused

## two commands, ruled separately [ 2026-10-18 ]

parameter-based access rules do not exist yet [ access.zenki : "restrict
later [param based]" ], so the split is by COMMAND :

- `v7-zenki.cap-own-child <pid> <role>` -- for zenki. listed in
  cfg/zenki/cube/command_aliases `setup.aliases.source_zenka_sid` : cube
  forwards the caller's real session id, so v7-zenki knows WHICH instance
  asks [ unspoofable ] and checks the pid is that instance's registered
  child. no :force: here -- a zenka can already signal its own child ;
  a cap below current use is refused with the measured use in the reply
- `v7-zenki.memory-cap <pid> [ :force: ]` -- for admins, its own access
  rule [ users only, never zenki ]. :force: lifts ONLY the minimum check
  [ a cap below current use = a kill : warned in the reply and logged
  with who forced it ] ; the ownership checks [ registered child, start
  time, cmdline, uid ] stay -- force changes how much, never whom

## until built

pri runs layers 1 + 3 [ context cap, system zenka watchdog ] ; mem_max
stays out of its coding host.cfg [ the spawn then runs unscoped and logs
it ].

#,,..,.,,,,..,.,,,,..,.,,,,,.,,,.,,,,,...,,,,,..,,...,...,...,.,,,.,,,,,.,,.,,
#RWVSGCQ6RMOHZXHQQMNFPFRUB5BSYOEKJO234OSINPH27CBMCI47KNYOVMT72DUE3KBJYS4H5P5JA
#\\\|ZKWPYYZB4UB7NOBNZJ47RFFGA4SAGLK2U5XKDKNW54UA24ZXTIQ \ / AMOS7 \ YOURUM ::
#\[7]4P2EDGHPCGJH7Z3YAZKDOL7IBMETPZYI7SWTCLF3WIX5UILUJCDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
