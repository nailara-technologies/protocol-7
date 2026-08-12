---
name: feedback-bash-tool-http-proxy-contaminates-localhost-curl
description: Bash tool's shell env has an active http_proxy that silently breaks curl tests against 127.0.0.1 unless no_proxy=127.0.0.1 is set — always set it explicitly, don't copy a bare curl command from the user
metadata:
  type: feedback
---

The Bash tool's shell environment has `http_proxy=http://10.0.110.7:4040` set. A bare
`curl http://127.0.0.1/...` (no `no_proxy`) silently routes through that proxy instead of
hitting the local server directly, and gets back the proxy's own 404 — not an error from
Protocol-7's httpd at all. The failure looks exactly like a real connection/response
problem (wrong status, empty body, immediate close) with no indication a proxy was ever
involved unless `-v` output is read carefully for the `Uses proxy env variable http_proxy`
/ `Trying <proxy-ip>:<proxy-port>` lines instead of `Trying 127.0.0.1`.

**Why:** during a radio-zenka streaming investigation I copied the user's own test command
but dropped the `no_proxy=127.0.0.1` prefix they had included. Every "confirmed broken"
result I generated from that point (an empty internal registration hash, apparent
correlated cube routing errors) was actually just the proxy's 404, not the real httpd
handler running at all — a false trail that consumed a large fraction of the debugging
session chasing a routing bug that, once retested correctly, turned out not to exist. The
real bug (WSLg PulseAudio bridge down, breaking mpv's audio output init) was found only
after re-running the test with the proxy bypassed and getting a genuinely different result.

**How to apply:** any time a Bash-tool `curl`/network test targets `127.0.0.1` or
`localhost` in this environment, prefix it with `no_proxy=127.0.0.1` (or set `NO_PROXY`)
unconditionally — do not rely on copying the exact command the user pasted, since a
dropped or reordered env-var prefix is easy to miss and produces plausible-looking but
false evidence. When a local-server test result looks surprising, re-check with `-v`
that the connection actually went to `127.0.0.1`, not a proxy, before trusting it.

#,,,.,,,.,,..,,..,.,.,.,.,,.,,,.,,,.,,.,.,.,.,..,,...,...,,.,,.,.,.,,,,..,,.,,
#BCUBQM6VB4EKE5AVWF3MBUIXNK2DCRRM6QGM6IR5YSX2UTMAVVIEEVIDRNWL5MRNO7GODHTUY6WUI
#\\\|L4ZCQUU2FUKEZTJWR73MTOK4ANDZGGOGEED53LTLPWIRRN4JPI7 \ / AMOS7 \ YOURUM ::
#\[7]VEYYSX2EESWOYVQ5KZCFK6CL3NWLBXUAJB72D3DFLMGXTENWBEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
