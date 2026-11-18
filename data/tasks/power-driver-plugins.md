# power zenka : driver plugins, optional deps, pin on first successful use

status : brief, not dispatched [ 2026-11-18 ]

## goal

the `power` zenka becomes a generic device switch with driver plugins. today it
is hard-wired to gembird sockets [ `power.dev_obj` builds `Device::Gembird`,
`power.set_states` \ `power.cmd.get_states` hard-code 4 sockets and the status
codes 17 \ 18 \ 65 ]. drivers wanted now :

- `gembird` : the current code, moved into a plugin, kept for when devices return
- `wol` : wake on lan [ magic packet, udp broadcast port 9 ] ; off \ state through p7
  on the host itself [ suspend \ poweroff, `power.host_reachable` ]. MAC and the
  P0-P3 priority stay in the nodes zenka [ CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md,
  "nodes zenka and wake-on-lan" ] : nodes decides when, power decides how
- `casio-rs232` : casio XJ-V2 beamer, later stage [ protocol to verify against the
  casio XJ-V RS-232C command spec : believed 19200 8N1, `(PWR1)` `(PWR0)` `(PWR?)` ]

## driver interface

plugin modules `power.plugin.<driver>.<call>` :

- `open` : `( $device_cfg )` -> handle or undef + reason ; loads the driver's perl
  module here, never at zenka start
- `outlets` : `( $handle )` -> count of switchable outlets [ gembird 4, wol 1, casio 1 ]
- `set` : `( $handle, \@states )` [ 1 on, 0 off, undef skip ] -> new states or undef
- `get` : `( $handle )` -> states [ 1 \ 0 \ undef unknown ]
- `info` : optional, `( $handle )` -> hash [ model, light source hours.. ]

the device config gains `driver = <name>` ; a device without one is `gembird`, so
existing configs keep working. `power.dev_obj` \ `power.set_states` \
`power.cmd.get_states` dispatch by driver ; the `cmd.*` interface stays the same
[ power-x11 keeps working unchanged ]. `on` \ `off` take 1..outlets, not 1..4.

power-x11 [ gtk window, functional state unknown ] assumes gembird shape too :
`power-x11.handler.show_all` parses `show_all` rows as `id mac ip s1 s2 s3 s4`,
`power-x11.cmd.set_states` demands 4 states, `power-x11.open_window` builds 4 switches
[ `1 .. 4` twice ] and derives a label from the mac. stage 1 keeps the `show_all` row
format for gembird devices so power-x11 does not break ; any command or row format
change in a later stage updates power-x11 in the same commit [ remap, outlets per row,
`-` for a missing mac ] -- never break it knowingly. a ui bug sweep is separate work.
optical refresh [ owner idea ] : re-render the look with the invoke zenka + qwen in the
same composition [ logo today : data/gfx/logos/power-x11/pms-lan.png ] ; render parts
[ header, device row, switch on \ off ] not one fixed picture, so rows \ outlets per
driver stay dynamic ; dark theme. style [ owner ] : modern blacklight | network, one
style for every element ; best after stage 2, together with the outlets-per-row change.

new `power.cmd.drivers` : each driver, module present yes \ no, devices using it,
pinned yes \ no.

## optional deps

- remove `command_line_modules = Device::Gembird` from `cfg/zenki/power/start.cfg`
- remove the gembird autoload from `power.init_code` ; check `Net::Oping` and
  `Net::Libdnet::Arp` too [ gembird mac pattern \ reachability : move them into the
  driver that needs them, or keep only what the core really uses ]
- `cfg/zenki/power/deps/p-mod/Device__Gembird` leaves the required deps ; new
  optional profile `power-gembird` in profiles.yaml
- a missing module : only that device reports it, once, with the hint
  `bin/p7-deps install power-gembird` ; other devices \ drivers keep working ;
  no warnings at start ; never install silently
- `wol` needs core modules only ; casio via `POSIX::Termios` + sysopen if it works
  with the usb-serial adapter [ no extra module ]

## pin on first successful use

new shared helper `base.deps.pin_first_use` : `( $profile )`, usable by any zenka
with optional drivers.

- opt-in per host [ e.g. `deps.pin_on_first_use = yes`, default off ] ; off : log
  once with the matching install command
- pin only after the first SUCCESSFUL use : a device opened AND one `get` \ `set`
  returned valid states. a module that loads but finds no device, or a driver whose
  open aborts, does not pin
- records through `AMOS7::deps::tracked::record` [ type profile, source the zenka ] ;
  recorded profiles are reinstalled \ verified after `bin/p7-deps dist-upgrade`
- once per profile per host : check `recorded_profiles` first
- store permissions : `chown_to_user` sets 0775 \ 0664 to the runtime user -- VERIFY
  the power zenka user can write after drop_privs ; if not, route the record through
  v7-zenki
- `bin/p7-deps unpin <profile>` removes the record, nothing else

## stages

1. gembird into a plugin + driver dispatch + optional deps [ no behaviour change ]
2. `wol` driver + `base.deps.pin_first_use` + `power.cmd.drivers`
3. `casio-rs232` driver [ after the protocol is verified, on the always-on host ]
4. later : x11 coupling -- an x11 output maps to a power device [ e.g. `HDMI-1 -> beamer:1` ] ;
   x11 reports dpms \ idle \ output connect, power switches. x11 holds no drivers of
   its own : one display-power hook calling power.* , so every power driver works for
   displays [ rs232 beamer, smart plug monitor, later DDC\CI through its own driver ]

## rules for the implementer

- house style : lowercase comments, `[ ]` not `( )` in comments
- new timers through `<[base.interval.next]>`, no literal intervals
- internal checksums BMW \ AMOS, no sha ; no json for hand-editable files
  [ open question : power config is json today via set-up.json -- leave as is in stage 1 ]
- a new command needs its zenka.v7 list + gen-sub-whitelist entry
- syntax check with `bin/format-code -c <files>`, never plain perl -c
- do not touch files outside this task

#,,..,...,,..,.,.,,,.,..,,,.,,,..,,.,,..,,..,,..,,...,...,.,,,..,,,.,,,,.,...,
#W2HVGLA4QV2WYIDDOL5JCEK5IEVWUYUG3VM4VHDWLIDGAMRUNBP24D7S2HC3Q6P3UELZTN7SNYFLI
#\\\|JUH5BD2RKHLQEPU57PSFS4T3DABPYZSSUYM56YF7WPAKKWH42D3 \ / AMOS7 \ YOURUM ::
#\[7]PIQUYGT6VQ75BLCGHF3QRPJ3L35UVTLU5KZIGCEVEGGC734YAABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
