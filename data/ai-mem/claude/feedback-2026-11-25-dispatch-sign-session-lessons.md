---
name: dispatch-sign-session-lessons-2026-11-25
description: lessons 2026-11-25 -- dispatched runs must not register as live sessions, never guess a session target, changed AMOS modules join the sign, /tmp is a small tmpfs, review every run
metadata:
  type: feedback
---

- a dispatched headless claude run starts its own mcp server with its own inbox socket : it
  registered as a live session and a reminder landed in it as a user turn. dispatched runs get
  P7_SESSION_REGISTER=no ; session-post \ reminders refuse to guess with several sessions.
  **Why:** a message meant for the owner's session can steer a running agent.
  **How to apply:** name the target [ to=session:<name> ] whenever more than one is registered.
- the sign tool aborts when changed AMOS7 modules [ data/lib-path/pm ] lie outside the set
  ["module version updated outside this run"] : sign them together. a crashed sign leaves only
  the version files staged ; a new sign runs on top of them.
- /tmp is a 12 G tmpfs with 1 M inodes : aborted n7fs tests left 980 k inodes and blocked every
  tool. tests that make many files run with TMPDIR on the large disk [ the dispatch template says so ].
- a dispatched run inherits P7_SESSION_REGISTER=no : its relay tests fail there, run them here.
- review catches what a run's own tests hide : fake p7c decoding base32 for every command,
  `sleep 0.5` without Time::HiRes = a busy loop, a cfg test under /tmp [ refused by design ].
- related : [[session-handover-relay-parking-notify]], [[one-pending-sign-at-a-time]]

#,,,,,,..,,.,,.,,,,,,,..,,..,,.,,,..,,.,.,,,,,..,,...,...,.,,,,.,,,,.,..,,...,
#ROBZTMFLNQ33MCCZO3NEA4TCVSQWHLITADGAW6M36PAN6XK6SHB45LJH2E46VNYEEACXTLBMK67KI
#\\\|3H4TXKGMLBI2OKG2U6EI2P6U4FVQSQ2J35UXNONAT2YVSOD7JQU \ / AMOS7 \ YOURUM ::
#\[7]NJA2UXZ56BMMNE47J3QPREWOZG5QIFSLDTUPE7MUMYGE5H2DB6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
