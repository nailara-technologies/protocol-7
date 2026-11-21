# input and window forwarding : one keyboard \ mouse across hosts, single remote windows

status : brief, not dispatched [ owner 2026-11-21 ]. builds on
data/md/design/HEADLESS-X11-AND-HOST-ADMINISTRATION.md [ auto-xvfb, odd display numbers by
role, xvnc as an X-11 mode, ssh as the boundary ], the X-11 zenka [ multi-server, window
and pointer commands ], screen-setup [ monitor layout model ], window-place.
full desktop forwarding [ xvnc sessions ] stays its own feature in that design doc.

## part a : input forwarding [ synergy-like ]

- one layout over several hosts : screen-setup's layout model holds the monitors of
  more than one host ; it knows which screen edge leads to which host
- crossing an edge hands input over : capture on the active host through xinput2 raw
  events, a local grab while another host is active [ no double action ]
- injection on the target through its X-11 zenka with xtest
- keysyms, not keycodes : hosts may have different keyboard layouts
- shared clipboard [ text first ] between the joined hosts
- one fixed escape key that always returns input to the local host [ e.g. the
  thinkpad blue key, configurable ; see desktop-ui-surfaces.md ]
- transport : a direct authenticated, encrypted link between the two X-11 zenki, not a
  route through cube per event [ latency ] -- the udt work applies here

## part b : single window forwarding

- the application runs on the remote host in its own virtual display [ auto-xvfb, an odd
  display number per forwarded application ], started by the remote X-11 zenka
- only that window travels : its contents [ damage regions, xdamage \ xcomposite on the
  virtual display ] go to the local host, which shows them in a normal local window
  [ placed by window-place, themed frame, title marked as remote ]
- input into that local window is injected into the remote one [ the part a path,
  scoped to that window ]
- resize locally -> randr resize of the remote virtual display, so the app relayouts
- encoding staged : changed tiles losslessly compressed first ; a video codec later
  for fast-changing content [ playback, games ]
- spice as a simplification where vms or whole displays are involved [ owner
  2026-11-21 ] : multi-monitor, audio, clipboard, usb redirection, an html5 client
  [ spice-html5 -- the web renderer path ], and xspice exposes an X server through
  spice [ one more X-11 mode ]. it forwards whole displays, not single windows [ xpra
  stays the single-window tool ] ; it runs inside our encrypted, padded link like
  every other stream. natural fits : the sandboxed work vms of
  work-and-private-contexts.md and full desktop forwarding
- the counterpart to forwarding pixels : send the APPLICATION to the client instead
  [ owner 2026-11-21 ] -- js \ wasm running in the browser, as a javascript amiga
  emulator runs a whole system client-side. only state changes and inputs travel, or
  nothing [ offline ] ; little bandwidth, needs a capable client and code allowed to
  run there [ signed, served through the httpd signed-files path ]. for zenki a third
  renderer beside gtk and the web renderer : the client gets the render logic once
  and then only the zenka's state stream. references : TAWS [ the amiga workbench
  rebuilt as a web desktop, in the browser since 2001 -- a whole desktop ui written for
  the browser, not emulated ] ; data/md/design/WEB-BROWSER-VIEW-STACK.md [ the n-view
  stack in the amiga screen-pull model ]
- applications for a platform the device can no longer run [ owner 2026-11-21 ] :
  e.g. android apps that need a newer android than an older phone gets. they run on a
  server or the home machine in an android environment [ waydroid, an emulator,
  android-x86 in a vm ] and the phone shows the screen and sends touches back, as if
  local. limits : apps with hardware \ attestation checks [ banking, some streaming ]
  may refuse an emulator ; camera, sensors and location must be forwarded explicitly
  [ each its own opt-in, in the user's context ] or are absent.
  the security gain is general : the phone runs only one small, checked viewport
  client and no third-party code ; apps run sandboxed on the user's own machines,
  each in its context with only the mapped access [ the work vm model ]. a lost phone
  holds no app data, a malicious app cannot reach the phone. what remains is the
  viewport itself [ screen and input while in use -- the overlapping trust of
  work-and-private-contexts.md ], a far smaller surface than a phone full of apps
- a capable phone can also be a full node : a local linux vm with native protocol-7
  [ android's virtualization framework where the device has it, else termux \ proot
  or a postmarketos install ] -- offline capable, a native presence and position
  source, a small holder for a few context-encrypted trees ; heavy work runs remote,
  light work local, by the same load signals [ battery included ]
- one native but very generic android app assists the viewport : it shows the view,
  passes touch and keys, and exposes the phone hardware [ camera, location, sensors,
  notifications, vibration ] as channels the user approves one by one. it speaks the
  protocol-7 wire protocol to the local vm and to remote nodes alike ; being generic,
  it needs no application-specific updates -- new features come from the zenki
- a first stage may use an existing tool [ xpra ] as one more X-11 mode, the way the
  design doc takes xvnc for full desktops -- own transport later, same commands

## part c : moving applications -- re-hosting and remote hibernation [ owner 2026-11-21 ]

three levels, cheapest first :

1. move the view : an application in its own virtual display [ part b ] is detached
   and re-attached on another host ; it keeps running where it is [ xpra already does
   this -- nearly free once xpra is an X-11 mode ]
2. move or hibernate the process : checkpoint the application TOGETHER with its own
   virtual display [ criu : checkpoint \ restore in userspace ; the X state lives in
   that display, so the pair is self-contained ] -- frozen to an image, resumed later
   or on another host. limits : open network connections, devices and gpu contexts do
   not survive ; the restore target needs compatible libraries [ same system profile ]
3. zenki move themselves : their state is serialisable by design ; a zenka hands its
   state over and starts on the target host -- the cleanest path for our own
   applications

by application type :

- applications made of zenki : headless zenki move their state [ level 3 ] ; ui zenki
  carry no state of their own beyond the view and re-render on the target from the
  moved state -- the application moves as its parts, each where it fits best.
  the renderer is exchangeable : the same zenka state can be shown by a gtk window, a
  web renderer in a browser, or forwarded from an xvfb session on a server -- a
  device without X still reaches the application through the web renderer, while the
  zenki themselves keep running wherever they are
- classical applications whose state is exactly reproducible : instead of a memory
  image, record what produces the state -- the document plus its history [ undo
  stack, the inputs or commands that led there ] -- and replay it on the target. the
  web-browser zenka already does this for pages [ replay-record, state-play,
  waypoints ]. smaller than a checkpoint, independent of library versions, and the
  history comes along instead of being lost
- everything else : a checkpoint of the application with its display [ level 2 ]

- the image is private data : encrypted with the user's context key, stored and
  placed through n7fs [ a holder can keep a hibernated session ], never readable on
  the way
- hibernate \ resume fits presence : sessions can be parked when the user leaves a
  host and resumed where they arrive [ the prepared-and-locked session above ]

## presence : where the user is reachable [ owner 2026-11-21 ]

- the active input host is where the user is : a stronger signal than logged in or
  unlocked. the X-11 zenki publish it as a presence state [ host, since when ]
- consumers follow it : notifications, pending questions of protocol-7-menu, the
  content \ mpv playlist, alerts -- shown on the host that has the input
- presence is known to the owner's own zenki only, never published beyond them ; an
  outside observer of the padded steady stream learns that a forwarding session
  exists between two hosts, not whether the user is active or what is typed
- without forwarding, the local input activity of a host gives the same state
- external zenki never see presence : they talk to the home ring zenki first, which
  decide what reaches the user and where. what the home ring drops or rejects stays
  silent -- no delivery receipt, no 'not reachable' answer that would itself reveal
  presence or absence
- shared availability is the home ring's choice, never a leak : it may arrange an
  availability stream for chosen contacts and a bounded purpose -- e.g. around a
  planned meeting, or a likely later chat session. scoped [ which contacts, which
  window of time, which detail : 'available \ busy' rather than host or activity ],
  expiring by itself, revocable, and derived from presence by the home ring -- the
  raw presence state never leaves it

## meet-up : shared position for a planned meeting [ owner 2026-11-21 ]

- on the way to a meeting, the participants' mobile devices can see each other : an
  availability stream [ above ] with position as its detail level, arranged by each
  home ring for exactly that meeting
- mutual and bounded : only the participants, only from a start [ e.g. departure ]
  until the meeting begins or a time limit, ending by itself ; each participant can
  leave at any moment
- precision grows with closeness : a coarse area while far apart, exact only near the
  meeting point -- nobody's route home or elsewhere is ever shared
- auto-guide : the zenki compare positions and estimated arrival times and suggest
  how to meet efficiently -- a better meeting point when one is delayed, who waits
  where, an earlier catch-up on a shared route ; suggestions only, each person decides
- positions travel end-to-end between the home rings of the participants [ encrypted,
  padded like the input stream ], never through a third-party location service ;
  nothing is kept after the meeting except what a participant chooses to keep

### delay notices for non-friend meetings [ owner 2026-11-21 ]

- for meetings with people who get no position at all [ business, appointments ] :
  the home ring sends them only accurate delay estimates -- 'arriving about 12 minutes
  late', updated when the estimate changes by more than a threshold
- works through gaps in coverage : the mobile device hands the home ring its plan
  before it goes dark [ route, transport, the last position and time ] ; the home ring
  keeps estimating from that plan [ timetables, typical travel times ] and keeps the
  partner informed while the device is unreachable ; the device corrects it on return
- the partner sees a delay and an arrival time, never a route, position or the reason
  unless the user adds one ; the user can review or stop notices at any time
- the partner is reached the way they already use [ mail, their own zenki if they have
  them ] -- no account or app needed on their side
- an 'approaching the building' notice : one message when the user is a few minutes
  away [ geofence around the meeting address, set by the user's own device ] -- the
  partner can come down, open the door or prepare the room. one notice, no position,
  only when the user enabled it for that meeting
- the same for friends at home : 'arriving home' to a friend waiting for an agreed
  evening chat -- they have time to get a coffee and sit down at their workstation.
  same rules : chosen friends, that occasion only, one notice, no position
- the user's own working zenki are recipients too : 'arriving home' \ 'at the desk in
  about 15 minutes' switches them from collecting to presenting -- a research zenka
  stops scanning and compiles its report, jobsite finishes its assessments, the coding
  zenka warms its inference servers, mail \ n7fs summaries are gathered, the desktop
  prepares the first view -- and there is time to decide WHICH desktop it will be :
  the one the user is expected to sit at [ arrival direction, time of day, habit,
  the reports waiting ], fully prepared before they arrive [ screens on, layout,
  the windows placed by window-place, inference warm ] ; the others stay asleep.
  with secure sessions the desktop can be at a friend's place, and theirs at yours
  when they come over : a guest session on the host's screen, the guest's own zenki
  behind it [ window forwarding, part b ], nothing of the guest stored on the host.
  partial views fit as well : a prepared media library for the evening, shared
  read-only for that visit [ the lan media path of token-lease-and-lan-media.md ],
  ending with the visit.
  prepared but locked : everything is prepared ENCRYPTED -- reports, the media list,
  window contents, warm caches -- and only unlocked in place when the user actually
  sits down and types the session passphrase [ the approval ladder of
  WEB-UI-USER-LOGIN.md ]. until then the prepared desktop holds nothing readable in
  detail : a host that is never used, or used by someone else, never had the
  plaintext. an unused preparation expires and is wiped
  each zenka declares what it does on the signal ; the
  signal carries only the expected arrival time, never a position
- a remote meeting approaching while the user shows no presence yet [ no input on any
  host since the night ] : first the user's own devices try to wake them, escalating
  gently [ alarm, then louder, on the host or phone they are nearest to ] ; only if
  that fails and the user enabled it for that meeting, the partners get a short
  'joining a few minutes late' -- never the reason, never 'no presence'. the user can
  cancel the notice in the first seconds after waking

### discovery : public for organisations, private for people [ owner 2026-11-21 ]

- an organisation or group may publish that it supports these notices, publicly and by
  its own choice : a dns record of its domain [ nameserv serves our zones ], a
  well-known url on its site, its public zenka key. a visitor's zenki check it before
  an appointment and use the notices without anyone asking -- 'are they on it too'
  answers itself
- people are found only with their agreement : no public entry ; a discovery request
  that reaches their home ring correctly is still unanswered by default -- the zenki
  reply only where the owner agreed [ per requester or per group of requesters ].
  no reply is the normal case, so 'not using it' and 'not wanting to be found' look
  the same from outside
- the requester waits a short, fixed timeout -- long enough that a consenting home ring
  has answered for sure -- then treats silence as 'not found'. the home ring answers
  consenting requests itself, whether or not the user's devices are online, so the
  answer time reveals nothing about presence
- graded answers for agreed requesters : instead of silence the home ring may answer a
  friend 'not present right now' [ or 'available later', 'busy' ] -- the level per
  requester is the owner's choice, the default stays silence. the answer comes from
  the home ring at the same timing either way, so a friend learns only what the owner
  allowed

## security

- only between hosts with pinned keys ; never on by default ; each pairing confirmed
  once by the owner
- keyboard input carries passwords : part a only over the encrypted link, never
  logged, never routed through other hosts
- the stream is encrypted AND padded [ owner 2026-11-21 ] : input events go out in
  fixed-size frames, and while input is forwarded the link sends at a steady rhythm
  with cover frames in between -- packet sizes and timing must not show single key
  presses or the typing rhythm [ the keystroke timing side channel ; openssh 9.5
  added obfuscation for the same reason ]. window frames are padded to size buckets
- udt on the lan too : lower latency than tcp for the input path and the window
  stream, the same encryption and padding on every network
- a forwarded window runs with the rights of its remote user, nothing more ; listening
  on localhost \ the link only, never a public port

## stages

1. part b with xpra as an X-11 mode : start one remote application, show its window
   locally, close cleanly
2. part a between two hosts on one lan : edge crossing, xtest injection, escape key
3. shared clipboard ; keyboard layout handling
4. own window transport [ tiles ], input scoped to the forwarded window
5. video encoding for fast content ; multi-host layouts

## rules

- p7 config style, no json ; BMW \ AMOS checksums, no sha ; perl floor 5.32
- timers \ retries through <[base.interval.next]> ; the event loop never blocks
- no host names, addresses or personal data in repo files

#,,..,,.,,.,.,...,..,,.,,,,.,,.,.,,..,.,.,...,..,,...,...,,.,,,,.,...,.,.,,,.,
#JBLQXY3KLOQLZC7EL5WYUKNG2HYTUQHZ5W2JBQQKZOJ3NRDGJNPSK5C27N3IPXHFAUKDEDCZVHXSI
#\\\|2AWYKAM4UUS377DSDRY3Q6H5NYEXOJ2YMCZERZ7MPEFYWC3E3PE \ / AMOS7 \ YOURUM ::
#\[7]3SNCFJTUM6YY5SHNPAK7FDHP7XZFPEJPN7XIAGB2GHTI6MZLZ4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
