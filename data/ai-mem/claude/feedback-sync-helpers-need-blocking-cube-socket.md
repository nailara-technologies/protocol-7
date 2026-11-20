---
name: feedback-sync-helpers-need-blocking-cube-socket
description: never switch a shared socket's blocking mode for the event loop's sake -- synchronous helpers read it ; make the one event-driven write non-blocking [ send MSG_DONTWAIT ]
metadata:
  type: feedback
---

2026-11-04 : 5567aa7fa set the cube socket non-blocking after auth ; deployed to pri, every restarted
zenka then failed start-up [ base.get_session_id whoami read got EAGAIN -> exit 0110 ]. ~10 more helpers
[ base.X-11.*, web-browser.calc_zoom_level, login-screen.xauth_setup ] write and read the cube handle
synchronously. fixed in 9220834b9 : base.s_write 5th param -> send( MSG_DONTWAIT ) on sockets, only
base.handler.write passes it.

**Why:** a handle's mode is shared state ; checking only the auth handshake missed the other readers.
**How to apply:** before changing a handle's mode, grep every `<$fh>` \ readline \ sysread on it
[ `grep -rn "<\$cube_fh>\|readline(\$cube_fh)"` ] ; prefer a per-call flag. test a zenka RESTART locally
before deploying, not just a running one.

#,,..,...,...,,,.,.,.,.,.,.,.,..,,,.,,,,.,...,..,,...,...,,..,...,.,,,..,,.,,,
#YHQ3P7ZL2NGUBMDLOIJ3HHUVE3DSJMJ5MA3RFXNVTMNFL7TOHF27JBW53WFTLYXJRBNIA3QOBV5KQ
#\\\|UOVNOTWO2TGQ6VFNRDRHUHU3FMLCSXWWSSAPYDCBA2LOBRHHY6Q \ / AMOS7 \ YOURUM ::
#\[7]4YBZRVMZUJDAU4M2KSHI7LKN7XJWPKTAN754LHLU7UKDSCBCKOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
