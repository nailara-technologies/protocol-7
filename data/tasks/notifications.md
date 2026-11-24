## notifications : notify, ticker and menu wired to the events, the coding zenka and the runs

owner direction 2026-11-24 : the pieces work, they need wiring.

### what exists

- notify [ dunst ] : notify.info \ warn \ message \ loves -- bin/dev/p7-sign-run already sends
  notify.loves on a sign request
- ticker : events, read-file-notify, current_content, dismiss, monitors \ profiles -- the place
  for PERSISTENT status lines
- protocol-7-menu : pending-question-add \ -answer \ -open, input-choice \ input-text \
  input-password, menu-update-notify -- interactive options ; the pending questions ARE the
  open-decisions queue of data/tasks/claude-zenka.md [ coding zenka item 1 builds on them, no
  second copy ]

### wiring

- one notification action plugin in the events zenka [ plugin.events.action.notify : level,
  text ] so any bucket entry, signal or parked task can notify ; signals worth a popup by default :
  claude.run.done \ kimi.run.done [ state=failed loud, ok quiet ], usage.threshold [ 75 \ 90 ],
  usage.window.reset, a sign request \ approval \ commit, a place \ placement end
- ticker status lines kept current from events : running dispatches with elapsed time, the
  pending sign, usage pace [ the usage.plan pace line ], placement progress ; a line goes when
  its thing ends [ dismiss ]
- menu : the pending questions from coding.ask with choices [ input-choice ] ; answering raises
  decision.answered ; entries for the common actions [ relay on \ off, pause a run, usage.plan,
  handover ]
- levels and quiet hours : one config [ which signal -> popup \ ticker \ menu \ nothing ], a
  do-not-disturb switch like the relay switch [ timed, nothing lost : the ticker \ menu keep it ]

### audio : non-aggressive cues [ owner 2026-11-24 ]

bin/warning-sound plays data/sounds/amos7/yourum.warning.ogg through mpv with
-audio-pitch-correction=no and passes extra mpv options on -- the speed is the expression :

- `-speed=0.24` [ no pitch correction ] : so subtle it lets one sleep through it or react to it
  alike -- the default for "something finished" at night
- profiles instead of raw options : soft [ 0.24 ], aware [ e.g. 0.5 ], alert [ 1.0 ], each with
  its volume ; a signal \ level maps to a profile in the same config as the popups
- one sample, many meanings by speed first ; new samples only where speed is not enough
- the sample loops cleanly [ cut from psytrance tracks ] : an alarm mode loops it [ mpv
  --loop-file=inf, the profile's speed ] until the user reacts -- the X idle time [ xscreensaver
  extension, as xprintidle ] drops below its value at the start = mouse or key -> stop [ mpv ipc
  `quit` or TERM ]. watched by the X-11 zenka through base.interval ; optional escalation [ soft,
  then a step faster \ louder after some minutes ], always a maximum length
- the wsl host cannot see the idle time [ windows holds the input ] : alarm mode runs on an X host
  [ azurum, the rpi panel, the native linux main host later ]
- quiet hours pick soft or nothing ; repeated cues for one event are rate-limited [ base.interval ]
- the host that plays : the desktop today [ the wsl pulse path underruns : the custom pulse server,
  or another host ] ; azurum or the rpi panel later [ data/tasks/display-hosts.md ]

### open

- popups only on the desktop host ; azurum \ the rpi panel get the ticker \ menu form
- the relay [ chat as the session relay ] and notify share the same switch semantics -- one
  helper for both

#,,,,,..,,,,,,,,.,.,.,,..,.,.,...,..,,,,.,,..,..,,...,...,...,,.,,..,,.,.,.,,,
#F4TQKDOU7OHUIXZJTW6BKNJIQEM5XBYT6IBEDAI76RE7PO46FSCZR6FN7VACJWMTVVU744YSYFCIG
#\\\|YNJEMQ6YW377QTNAXJESYEH75CDMFNTCXJKBHCU4MRLBA3O2F33 \ / AMOS7 \ YOURUM ::
#\[7]4DIZWZZLNLXJRIPWU5NM3KTP2EJIHHBQAU5ZJ77QKYWYFMCSFKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
