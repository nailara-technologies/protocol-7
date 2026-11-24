## display hosts : the beamer, the touch panel, playback and dashboards across hosts

owner idea 2026-11-24.

### why

video playback on the wsl host fails through its pulse audio path [ underruns ] ; a small host
wired to the beamer only does display work : video playback, dashboards [ usage.plan, n7fs
status, zenka views ], slides. slower than a desktop, enough for that kind of work.

### option a : azurum, the beamer as a second screen [ owner 2026-11-24 ]

azurum [ intel alder lake-n uhd ] has three outputs : HDMI-A-1 in use, HDMI-A-2 and DP-1 free.
hardware decode h264 \ hevc \ av1 [ va-api ] -- more than a pi 4. the rescue data and the n7fs
disk are local there : playback without streaming. it stays the n7fs \ placement host, a video
beside that costs little on the igpu. the beamer as its own X screen or an xrandr output.

### option b : a raspberry pi 4

### screen layout [ owner 2026-11-24 ]

| screen | today | planned |
|---|---|---|
| large curved | desktop, primary | azurum primary [ when azurum is the working host ] ; the desktop as now otherwise |
| small fhd | -- | desktop ; second input : the rpi |
| beamer | -- | azurum, second screen [ HDMI-A-2 \ DP-1 ] |
| touch panel | -- | the rpi [ until the main host runs native linux : windows cannot read the panel ] |

- the touch panel on the rpi serves development [ touch input for the ui zenki ] and control in
  general
- main host off : azurum does the playback on the beamer, the rpi touch panel controls it
  [ play \ pause \ seek \ next, dashboards ] through p7c \ p-7-r to azurum's zenki
- the rpi then is a control surface first, a display host second [ option b above ]
- the touch panel on a rotatable arm : turned 90 degrees it is a portrait console or web-page
  display -- the rotation follows it [ xrandr --rotate and the touch matrix together, or an
  orientation the ui zenki pick up ] ; landscape for playback control, portrait for a console,
  logs, usage.plan, a long page
- worth it [ owner ] : holistic interactive dashboard modes made for each format -- a mode is
  laid out for its orientation and size, not a landscape page squeezed ; touch is the input, the
  zenki \ events feed it live [ usage pace, n7fs placement, runs, parked tasks ]

### shape

- a protocol-7 host [ arm : data/tasks/arm-awareness-p7-deps-install-x11.md ] with X-11 \ mpv
  zenki, connected to the beamer exclusively [ hdmi ], audio on the pi itself [ no pulse relay ]
- playback routed to it : a command on any host [ e.g. `<pi>.play <path|url>` ] streams the file
  from where it lives [ n7fs get, an http range from httpd, or sshfs ] -- the pi needs no copy
- dashboards : a full-screen view that cycles or follows events [ the events zenka can switch it ]
- control from the desktop or a phone through p7c \ p-7-r

### open

- which zenki run there [ the X-11 + mpv path of the desktop, or a lighter one ]
- hardware decode on the pi 4 [ h264 yes, hevc 1080p limited ] : the player picks a fitting
  stream or transcodes on a stronger host
- the custom pulse server for the wsl stays a separate fix

#,,..,,,,,,,.,,,.,.,,,,,,,..,,...,...,,,.,.,.,..,,...,...,,..,,,.,,..,.,,,,.,,
#AMHEHX2E77443WEQXPUQJHS24TCLOL5OS5BZDNSNWAIVLOALZWDP3D2YLTQ4RYWXK6WWOXTZMZKAQ
#\\\|QQ5LUKSAUUXPWQGLLOCYADPPMEXRB76J5C24QUTS52IJS2D4XHU \ / AMOS7 \ YOURUM ::
#\[7]ATYJSQLETHJ252TFGVSFY435WRTCNBP6OJXC2E7TYZ5U4KYTBECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
