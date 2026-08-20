---
name: auth-client-namespace-split
description: auth.* split into auth.* (server) / auth.client.* (client) + new base.code.exists/call_expected/call_optional/base.mod.exists primitives; undef-subs cleanup in progress across zenki
metadata:
  type: project
  originSessionId: 5c95ba04-6293-4ece-a4ae-455aa1095528
  modified: 2026-07-20T09:57:41.477Z
---

Landed in `b674ecd80` (registry/is_vision fixes) and `ae6b1f79b` (undef-sub
detection overhaul + auth.client split), both on `base`.

## new primitives (src/base.code.*, base.mod.exists)
- `base.code.exists(name)` — %code presence check via dynamic key, exempt
  from the reference scanner (scanner only matches literal-quoted
  `$code{'name'}`, not `$code{$var}`). Replaces raw
  `exists $code{'literal.name'}` guards, which the scanner flags anyway.
- `base.code.call_expected(condition, name, @args)` — call only if
  condition true; if condition true but sub still missing, logs a real
  error (loud) — for cases where reachability genuinely guarantees
  presence (e.g. `<[base.mod.exists]>->('v7')` before `v7.teardown`).
- `base.code.call_optional(name, @args)` — call if present, silent skip
  if not — for genuinely best-effort/optional integrations, no
  expectation either way.
- `base.mod.exists(name)` — checks `<base.p7_mod.loaded>->{$name}`
  (ground truth of which namespaces this zenka actually loaded), replaces
  ad-hoc identity proxies like `<system.zenka.name> eq 'v7'`.

## undef-subs buffer + console_report toggle
`base.referenced_subroutines.clear_from_disk` now clears entries by real
`%code` definition (`clear_found`, i.e. `defined $code{$ARG}` — true for
both a real compile and a deferred stub) instead of mere file-existence
on disk, which was silently masking genuinely unresolvable cross-namespace
calls. Findings go into a new `undef-subs` buffer (always populated,
cleared each `source`/`all` reload) — query any time via
`show-buffer undef-subs` / `list buffers`. Console/log output and the
`reinit source [ warning ]` reload-status line are both gated behind
`<base.referenced_subroutines.console_report>` (default off, via
`base.cfg_bool`) so unrelated zenki stay quiet; buffer population is
unconditional regardless of the flag.

## auth.* split
`auth.*` was a mix of server-side (incoming-connection) and client-side
(outgoing-connection) code, all compiled into every zenka that loaded bare
`auth` (~97 zenki). Split:
- **`auth.*` (server, unchanged)**: `auth_list`, `auth_select`,
  `pwd.success`, `zenka.cmd.session-key`, `callback.cap-neg.*` (5 files,
  dynamically dispatched via `sprintf('auth.callback.cap-neg.%s-%s', ...)`
  in `base.handler.auth` — left untouched deliberately, too risky to
  rename given the dynamic dispatch). Only loaded by zenki that also load
  `cube` itself, or bind the `protocol-7` wire protocol directly — found
  by grepping `<[base.protocol.bind]>->(...,'protocol-7')` calls across
  all modules (not just start-file directives; `cube`'s bind is
  programmatic in `cube.post_init`, not a `[base.protocol.bind:...]`
  directive). Final list: `cube`, `cube-13` (loads cube modules),
  `universal` (binds protocol-7 directly, `auth.supported_methods=unix`).
- **`auth.client.*` (new)**: `unix.authenticate`, `zenka.authenticate`,
  `zenka.process_auth_reply`, `zenka.init_code` (this last one has zero
  callers anywhere — dead/unwired, moved as-is, not worth chasing).
  ~94 client-only zenki's `modules.load` changed `auth` → `auth.client`;
  the 3 server-mode zenki get `auth auth.client` (both).
- `base.net.connect`'s `sprintf('auth.%s.authenticate', $type_str)`
  dynamic dispatch had to be updated in lockstep (missed on first pass,
  broke nshell's cube connection until caught).

## coding / nshell namespace additions
Both now load bare `ascii` (not `ascii.frame` — everything under `ascii.*`
is currently `ascii.frame.*` anyway; bare token is prefix-matched by the
loader and future-proofs against namespace expansion, same pattern as
`crypt.C25519`/`models.conversation` as multi-segment load tokens) and
`format.yaml` (needed by `ascii.frame.load`'s `format.yaml.load_file`
call, only surfaced after adding `ascii`).
`ui.cmd.ui-show`/`ui.render.tree` remain deliberately backend-agnostic
(`ui.render.fallback`/`ui.fields.fallback` already exist as fallback
paths) — did NOT merge `ui.*` into `ascii.*`; only `coding`/`nshell` opted
into rich ascii-frame rendering, everyone else keeps the eval-wrapped
graceful degradation.

## p7-log.buffer.local_logfile_write move
Moved out of `base.*` (compiled into every zenka) into `p7-log.*` (only
the p7-log zenka needs it — its only caller, `base.buffer.add_line`,
already gated the call behind `<system.zenka.name> eq 'p7-log'`). Same
"generic-namespace-holding-specific-code" smell as the auth split, just
one file.

## status / next steps
- `nshell`: 19 → 7 remaining (`source.*`×3 fine/policy-gated,
  `crypt.C25519.*`×4 all traced to unwired `nshell.tofu_validate_pubkey`
  — **open decision**: finish wiring TOFU pubkey pinning for nshell's own
  outbound connections, or remove the dead scaffolding).
- `cube`: down to 5 (`ascii.frame.*`×2 fine/eval-wrapped,
  `source.*`×3 fine/policy-gated).
- `coding`: 26, mostly optional-plugin/storage-backend clusters
  (`storage.9p.*`/`plan-9.protocol.codec.*`, `plugin.storage.*`,
  `channels.memory-sync.*`, `valued.*`, `format.json.*`) — same
  "not activated, not a crash risk" shape as `source.*`, not yet swept.
- Remaining ~90 other `auth.client.*` zenki not yet individually checked
  for their own `undef-subs` profiles.
- See [[feedback-undef-sub-scanner-verification]] for the methodology
  used throughout, and [[feedback-ncode-tools]] for a tooling caveat hit
  during the `auth.client` config sweep.

#,,.,,.,.,.,,,,,.,,..,,,,,..,,,,.,..,,,,,,.,.,..,,...,...,,,.,,,.,..,,.,,,...,
#55OR4YDILFTHCTEK5KHPJNRR33VZ2V5NOOWVD4A664H7ZVJLD5MZFRP2JZO62P4RYLPYE3MHDNP7Q
#\\\|73Q3U3WWFHPN7VVXG2Q7W6XOPEUNSEUID6ZRHGB2QOY4F5AX7NL \ / AMOS7 \ YOURUM ::
#\[7]TK47GVATBX7OJL4OFJHIXUXWUEQBIOUHP6GOBSLOAX57EB53OQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
