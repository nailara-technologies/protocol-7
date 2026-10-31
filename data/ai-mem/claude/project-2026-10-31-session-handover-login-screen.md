---
name: session-handover-login-screen
description: 2026-10-31 later [ last b70c9d6cc ] : authorization slice 1, devmod safe\rw, desktop base + openbox-n rebase, native login-screen zenka LIVE on azurum [ greeter renders, real login untested ]
metadata:
  type: project
---

**landed 2026-10-31** [ pushed hub ; srv-U F V A at 0ab62b75f ; azurum at b70c9d6cc ]

- 10c523648 authorization zenka [ NOT auth.* : `.cmd.` modules load as bare
  commands into every zenka loading the namespace -- auth.cmd.list would
  override base.cmd.list ] : key-submit \ pending \ inspect \ approve,
  key-arrive for discover only. approve = owner sig over host-root id +
  entry ; authorization.owner.public_key unset -> all refused [ owner key
  choice still open ]. tofu : authorized link must resolve to the
  CONNECTING KEY [ not a path : test-auth-keypair links straight to a key
  file, osf-cache self link uses it ]
- 861aa1272 + 83fa60ea7 + 0ab62b75f devmod : devmod-enable = SAFE [ NUM51 ],
  devmod-enable-rw = full [ NUM53 ], devmod-disable [ 50 ], -unload-unsafe
  [ 52 ] ; cfg/devmod-commands = the one safe list ; dump-env unsafe.
  cube acks with own name + sid 0 [ cube.v7-zenki... is unknown inside cube ]
  ; live-tested srv-U
- f12be9814 data/configs/desktop/photonic [ @HOME@ templated ] + bin/p7-desktop
  status \ diff \ install [ -force, .bak ] \ pull ; profile photonic-desktop
- 5524476ca + b70c9d6cc login-screen zenka [ design LOGIN-SCREEN-ZENKA.md ] :
  Gtk3 greeter on X-11 :13, root crypt helper bin/login-screen-auth, single
  -use grant -> v7 starts login-screen-session[<user>] as the user.
  review fixed : dummy-hash password granted inadmissible accounts ; plain
  v7-zenki.start of the session bypassed the password [ now needs the
  admitted mark from xauth_reply ]. live fixes : stub whitelist [ run
  bin/dev/gen-sub-whitelist <zenka> for every NEW zenka ], map-in-sprintf,
  X-11 zenka.v7 had no [load_host_config]
- openbox.taeki.xml merged [ owner bindings : A-Return terminal, C-Return
  rofi run, A-D \ A-A \ A-S \ A-Shift-S \ A-W \ A-Q ] ; bin/desktop/fox-*
- X11-Desktop profile now : xorg xinit libinput xfonts-base xephyr
  xserver-xorg-legacy [ + Xwrapper needs_root_rights = yes on the host ],
  Glib::Event via cpan [ libglib-perl does NOT ship it ]

**azurum** : gdm + GNOME purged [ owner : no display managers ] ; overlays
v7-zenki.cfg load.start_setup = desktop-login, X-11.cfg mode xorg,
login-screen.cfg allow = taeki. the dist-upgrade autoremove purged Xorg
[ was only a GNOME dep ] -> profiles fixed. openbox 3.7-n deb from
openbox-n master [ rebased on Mikachu 2026, old master = master-2018,
bundle /data/backup/openbox-n-rebase-2026.bundle ]

**next** : owner tests a real login on azurum [ openbox + compton as taeki,
logout -> greeter ] ; one 'undefined value as subroutine reference' at
login-screen zenka.v7 statement 006 seen once -- check ; root-only grant
tests ; lock mode [ also replaces the lost lock-fade : fade + backlight ] ;
photonic autostart cleanup [ ~/bin scripts, compton line -> compton zenka ]
; thermal k live fit r2 0.74 at last check ; owner key choice for approvals

#,,,,,,.,,,.,,,..,.,,,,.,,.,,,,,,,...,,,.,...,..,,...,...,,,.,,..,...,.,,,,,.,
#ERM7PFD27L7VUOIOT6FWGL3IYHUA3PG5DT5XHEUYQCDXUT2V7H2VN6CSSCPV43OEN2ZGIVM2XRQ5Q
#\\\|C5EAXUMQAEL6WWOO4PD5FO5PLVRETGBP3BMZE5DWI54ZCDHW2NK \ / AMOS7 \ YOURUM ::
#\[7]EETHDUUH2NTF6IFYRVXD3NPNAP5KNJYC7AJ4QPRH3UH7SBB6PSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
