---
name: buffer access control vision
description: per-buffer-name access control as a future extension to the existing zenka access system
type: project
originSessionId: c33109d4-ce45-4735-8bfd-83170d636715
---
Buffer names as an access control dimension — deferred until the buffer system
has enough consumers that the right configuration location becomes obvious.

**Why:** `radio.show-buffer radio-jingle` gives access to any named buffer via
one generic command. As more zenki expose sensitive buffers (crash logs, auth
events, etc.), per-buffer ACL becomes necessary alongside the command whitelist.

**Proposed shape:** `access.buffers = radio-jingle radio-stream` in zenka access
config, checked in the show-buffer handler alongside the existing command ACL.
Generic buffer command stays, but the buffer name is validated against the
allowed list for the requesting session.

**Implementation sketch:**
- `base.has_access( $session, $name, $type )` — `$type` defaults to `'command'`,
  optionally `'buffer'`; routes to the right section of the parsed access config
- `base.parser.access_conf` already parses access config — extend to recognise a
  `[buffers]` section (or `buffers:` key) for explicit buffer ACLs when needed
- `buffer:` internal prefix (e.g. `buffer:radio-jingle` in access conf) only if
  buffer names ever collide with command names — unlikely given naming conventions,
  so skip until a real collision appears
- `base.cmd.commands` / `base.cmd.list` pattern: same `has_access` call, just with
  `$type = 'buffer'` in the show-buffer handler

**Access modes (per zenka config):**
- `command` (default): buffer access mirrors the corresponding command's access —
  zero extra config, reuses existing whitelists
- `explicit`: `access.buffers = radio-jingle radio-stream` independent of command ACL
- `open`: no filtering for any authenticated session

**How to apply:** revisit when 3+ zenki expose buffers via show-buffer and the
config location feels natural. Don't force it earlier.

#,,.,,.,.,.,.,,..,,,,,.,.,,.,,.,.,,..,,.,,,,,,..,,...,...,...,.,.,,,,,..,,,.,,
#DVV5MYYKFWANKQAAOXRQ5FHV3CEFMYHURBAOFNPTWMALSWB257BAQHTGDIL3P2W7OHII5CDKNGPQS
#\\\|HA57KVQDSU7AA3EHWSYOTQEZD5MLMMEUF6RYBYQZTRRUYZRAMIN \ / AMOS7 \ YOURUM ::
#\[7]DBSDEFNWIM3MIXPRQ7P4SBOSRH6FSFBMRWSFY4N6DIBNJLZHLAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
