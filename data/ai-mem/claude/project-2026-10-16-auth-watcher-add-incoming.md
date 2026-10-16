---
name: project-2026-10-16-auth-watcher-add-incoming
description: START HERE -- session 2026-10-16 day [ after the deps-service handover ] : taeki remote auth LIVE on all 4 servers, cube re-reads authorized keys via inotify [ 9a62a05d8 ], dep-graph plugin scoping [ 954 subs off eager lists ], p7-keys add-incoming [ 01b150d3d, 716313a79 ] ; OPEN : push+pull 716313a79 + live incident test on pri, unit update pri\atom, 4ZW
metadata:
  type: project
---

follows [[project-2026-10-16-session-handover-deps-service-p7r]].

## why taeki auth failed all night [ not keys vanishing ]

- my hand-written ssh block used `install -d .../incoming` : creates the
  missing PARENT `remote-keys/` as root:root 0755 -> `p7-keys authorize`
  [ as protocol-7 ] could not mkdir `authorized/` ; a root retry made
  `authorized/` root 0700.
- cube read `authorized/<zenka>/` only at start-up + reinit. `reload
  plugins` = base.reload_plugins = recompile only, NEVER runs init_code ->
  no re-read. `reload init` does. [ logs : 0 removals in 3 days. ]
- fixed by hand on all 4 [ chown, authorize as protocol-7, reload init ].
  `::: <host> ..` works everywhere.

## landed

- 9a62a05d8 : `plugin.auth.auth-keypair.watch-authorized` -- self-expanding
  inotify [ deepest existing parent, never above home ; re-scan after every
  re-read ; IN_IGNORED \ MOVE_SELF -> fall back ], 1 s debounce handler,
  armed in cube zenka.v7 after the start-up load + on reinit, gated on
  auth.supported_methods having auth-keypair. LIVE : pri fallback test
  [ mv authorized/cube aside 1->0, back 0->1, watch moved down again ].
- same commit : bin/dev/dep-graph parses `plugins.load` [ full subtree ] ;
  namespace-only plugin rule = depth-1 `plugin.<ns>.<x>` + static calls.
  -954 eager subs, httpd gained plugin.web.auth. user's goal : any code
  spared per zenka = memory + start time. dynamic-name targets [ storage
  extract_* ] compile on demand. plugin.external.udt = prepared next
  transport, not loaded yet.
- 01b150d3d [ kimi k2.8, ~2 % of its 7d -- user : very effective ; my
  review found the gid-strictness break, invented 'unsigned' footers, a
  non-idempotent repeat ] : `p7-keys add-incoming <user> <key|file|->
  [<zenka>]`, keys.owned_dir [ owner decides, a deliberate group like
  protocol-7:taeki stays ], keys.authorize_link shared with authorize.
- 716313a79 [ NOT pushed at writing ] : live root test on pri found the
  repeat path skipped the ownership walk -> walk first, then answer
  [ third arg allow_same ] ; keys.root_registry_note. 50 checks.
- `USER=protocol-7 p7-keys ..` as root selects cube's registry
  [ key_vars reads $ENV{USER} ] -- plain root = /root/.n [ a test tree
  there on pri was removed with the user's ok ].
- README : service commands, p-7-r usage + pin, `::` \ `:::` + ssh config,
  authorizing a remote user.

## open

- push 716313a79, pull on all 4 [ p7-keys only : no teardown ], live
  incident test on pri : chown root authorized/ -> `USER=protocol-7 p7-keys
  add-incoming taeki <pin file> cube` -> expect 'fixed ownership'.
- unit differs on pri + atom : `bin/p7-deps install-service` [ user's call ].
- 4ZW live, legacy install script, set-up rename, sys-deps probes [ see
  the handover above ].
- atom [ 964 MB, 1 vCPU ] : memory pressure critical on every teardown ;
  letsencr start timed out once, retry fine.

#,,.,,,.,,.,,,,,,,,..,,,,,,.,,.,,,.,.,,,,,...,..,,...,...,..,,,,,,,,,,,,.,,.,,
#HYPZKJDZLXJ4DPDTUX7G5NAJ5VSSJL72JRFZIE2ODMJYEJIQOIPYJZILTNE5GED4VZ3IILW4U5A5Y
#\\\|2V3FQDD3OPWVF7GNBH6QNY4CVZZLSMTEIZUDR3S3DD7YJL22KXD \ / AMOS7 \ YOURUM ::
#\[7]MQYODXT6DZROQO6BDPC4XYSCW2TQPU2OIEOWM6QNVYQJW6SIHQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
