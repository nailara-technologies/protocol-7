---
name: feedback-sync-helpers-need-blocking-cube-socket
description: never switch a shared socket's blocking mode for the event loop's sake -- synchronous helpers read it ; make the one event-driven write non-blocking [ send MSG_DONTWAIT ]
metadata:
  type: feedback
---

2026-11-04 : 0fd160c6a set the cube socket non-blocking after auth ; deployed to pri, every restarted
zenka then failed start-up [ base.get_session_id whoami read got EAGAIN -> exit 0110 ]. ~10 more helpers
[ base.X-11.*, web-browser.calc_zoom_level, login-screen.xauth_setup ] write and read the cube handle
synchronously. fixed in 70a02805e : base.s_write 5th param -> send( MSG_DONTWAIT ) on sockets, only
base.handler.write passes it.

**Why:** a handle's mode is shared state ; checking only the auth handshake missed the other readers.
**How to apply:** before changing a handle's mode, grep every `<$fh>` \ readline \ sysread on it
[ `grep -rn "<\$cube_fh>\|readline(\$cube_fh)"` ] ; prefer a per-call flag. test a zenka RESTART locally
before deploying, not just a running one.

#,,..,...,..,,..,,,.,,,,.,,,.,,..,,,,,,..,..,,..,,...,...,.,,,,.,,.,,,,.,,...,
#X4HII27DIVR5D6HK3T7ZVWJB5BQM3IM5SHOMOBT6TDAJZBCOAPB57RW72KEAGYATMACRARWENXYVS
#\\\|OG35HSEWEWKUECI7V36ZUFCGZC7LXDHDG546ZNHENMMSW3BHREC \ / AMOS7 \ YOURUM ::
#\[7]UQT7HT3A2ZBG5HPT5M4X5AJRDYLDAGPPJOXB7O62UNYWCCQKZ4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
