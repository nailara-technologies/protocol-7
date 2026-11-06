---
name: session-handover-lock-mode
description: 2026-11-01 [ last c3b01c609 ] : login-screen live on srv-16 end to end + lock mode s2a live and glitchless ; session programs, assets, base.gtk.style
metadata:
  type: project
---

**landed 2026-10-31 \ 11-01** [ pushed hub ; srv-16 at c3b01c609 ; srv-U F V A NOT deployed ]

- login chain live on srv-16 : greeter -> root helper -> session as the user -> logout back.
  fixes on the way : File::stat lists [ CORE::stat ], SI 'localuser\0<user>', x11.display retry,
  cube source_zenka prefix for caller identity, v7 own zenka.* subs load UNPREFIXED
  [ zenka.cmd.start_once, zenka.end-handler.* ], exec-external really drops privs
  [ English + POSIX setuid\setgid, egid string ; root targets exempt from the group-0 check ]
- session programs : v7-zenki.cfg.login_session_zenki [ srv-16 : compton tint2 jgmenu ],
  exec_args + exec_usr <session-user> in start.cfg, bare system exec_bin found in /usr/bin
- p7-deps assets: [ AMOS7::deps::assets ] : themes, white-rabbit font, highlight theme, x-cursor-theme
  Chameleon-DarkSkyBlue-Regular
- base.gtk.style : one gtk3 style at priority 600 [ greeter, lock, protocol-7-menu dialogs ]
- lock mode s2a [ kimi-built, reviewed ] : Ctrl+Esc -> p7c login-screen.lock ; seat grab with
  retries ; fade 1.7s to opacity 0.995 [ NEVER 1 : compton --unredir-if-possible flickers ] ;
  blank_delay 1.2 \ input_delay 24 \ fade_out 3.6 of the PANEL only, cursor hidden, then dpms ;
  verify-only helper frame [ no grant ] ; greeter restart returns locked [ login-session-state ]
- gotchas : Glib::Source->remove is a CLASS method [ function form dies ] ; base.logs one-arg
  now complains ; one sign job at a time [ parallel jobs abort, agent crashed once ] ;
  descr lines <= 55 chars ; tests stub Glib -> live-test anything gtk

**next** : design LOGIN-SCREEN-ZENKA.md section 9 : s2b layer stack + snapshot + root
SubstructureNotify watch, s2c idle \ blank \ dpms policy [ fade timed to blank ], backlight module
+ brightness keys ; cursor hidden while typing ; X-11 under its own user ; session restarts
despite restart.disabled ; swap_subs replay after reload source ; deploy to servers [ first
live pull-git on the new exec-external code ].

#,,,.,,.,,.,,,...,,.,,,,,,,,,,.,,,.,,,,,,,,..,..,,...,..,,..,,..,,...,,.,,...,
#2YHIEM5HB36QCTJ3SZTLM6HOCXZYPUS3NJ5EOT2LXWRMRLDIAYJNP74YMZYM73KVNGKPJK265F5NK
#\\\|323Q3NXM5ZIPEDXDXWFSFHUWYTW2AIDGE5XZLW43SONKNSZDIKW \ / AMOS7 \ YOURUM ::
#\[7]AUO4FD6LVGBNSY4H22RJ2NJ2DKFEDKNWIIMCYWHI5T67LXIMI6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
