---
name: feedback-route-send-command-format
description: route-send uses bare zenka.command; cube.X-11.xxx prefix is for send.local only
metadata: 
  node_type: memory
  type: feedback
  originSessionId: eec99c76-3a6c-4a57-abb3-72c98c78bcdd
---

`protocol-7.route-send` command strings must NOT have the `cube.` prefix:
- **correct**: `'command' => 'X-11.wait_visible'` in route-send
- **wrong**: `'command' => 'cube.X-11.wait_visible'` in route-send → cube says "no perm"

**Why:** cube's access.zenki entries are checked without the `cube.` prefix. Using `cube.X-11.xxx` in route-send makes cube see the whole string as the command name, which doesn't match the access entry `X-11.xxx`.

`cube.X-11.xxx` format is only correct for `protocol-7.command.send.local` (fire-and-forget), where `cube.` is the implicit destination and `X-11.xxx` is the routed command.

**How to apply:**
- `protocol-7.route-send` (with or without reply handler): use `X-11.wait_visible`, `v7-zenki.notify_online`, `window-place.coords` — bare `zenka.command`
- `protocol-7.command.send.local`: use `cube.X-11.set_geometry` — `cube.` prefix required

`protocol-7.route-send` is a thin wrapper around `send.local` that prepends parent_route hops, so the command string semantics are the same. The distinction is purely the `cube.` prefix behavior.

#,,,,,.,,,,.,,,,.,,,,,,.,,,.,,,.,,.,,,.,,,,.,,..,,...,...,.,.,...,,,.,,,,,..,,
#5ZHYFDVZF5QQEEF5URYPMU6TQFGNTQLEZNXL4R6UI6FAFXKB63K2VNJCQW6CJVGOJ455XD3UH2XYQ
#\\\|4FKTP7VFRV7UMERWV3P4D6CHIGRAIC7X3PXK24URCAM76T2IKUA \ / AMOS7 \ YOURUM ::
#\[7]LVZDP3XFATBWRDVVRVD2P54X34V5SP2JSRN33IKXJWMNRDUJBSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
