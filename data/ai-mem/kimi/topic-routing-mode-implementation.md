# routing_mode implementation — session lessons (July 2026)

task: data/tasks/zenka-name-routing-modes.md — configurable bare-name
routing modes + `-next` admin override family + strm duplicate-slot guard.

## live combined console

- combined zenka console: `/dev/shm/.7/STDOUT/NIW7OAQ` (symlink:
  `/var/run/.7/STDOUT/NIW7OAQ`). when network runs as root it is
  `-rw------- root` — NOT readable as taeki. fallback: read the per-zenka
  ring buffer instead: `p7c <zenka>.list buffers` /
  `p7c <zenka>.show-buffer zenka | grep ...` (works for cube too:
  `p7c show-buffer zenka`).

## sprintf( qw| multi-word |, ... ) bug class [ critical, recurring ]

`sprintf`'s prototype `($@)` forces its first argument into SCALAR context.
a multi-word `qw()` list in scalar context collapses to its LAST element.
`sprintf( qw| cube.set-routing-mode %s %s |, $name, $mode )` silently
becomes `sprintf( '%s', $name, $mode )` — args after the first dropped.
single-word `sprintf( qw| %s[%s] |, ... )` is fine [ existing style ].
rule: any sprintf format with SPACES must be a quoted string, never qw.
also: args do NOT belong in the command string for
`protocol-7.command.send.local` — its `^([^\.]+)\.(...)$` regex rejects
spaces; pass them via `'call_args' => { 'args' => ... }` [ drain-instance
pattern ].

## swapped-family call sites + reload semantics [ critical ]

- `v7.zenka.*` is swapped to `zenka.*` at runtime [ modules/v7.zenka.pre_init ].
  calling `<[v7.zenka.new_sub]>` at runtime = undef-sub crash. call sites must
  use the short form `<[zenka.new_sub]>`. the WHITELIST keeps the long
  filename-based name [ correct ].
- `v7.reload source` does NOT re-apply the swap: recompiled `v7.zenka.*`
  modules stay inactive under their runtime `zenka.*` key. after changing a
  swapped-family module, use `v7.reload all` [ re-runs pre_init ].
- an undef-sub call inside `v7.init_start_setup` [ runs from v7.init_code ]
  is FATAL: `module 'v7'-init not successful` → v7 gives up → tears down
  the ENTIRE network. guard init-path calls with
  `<[base.code.call_expected]>->( <[base.mod.exists]>->(qw| v7 |), ... )`.

## network run/start context

- the network runs as ROOT: `configuration/zenki/cube/start` does
  `[root.drop_privs:<system.amos-zenka-user>]` → exits when non-root.
  v7 as taeki also fails on `/dev/shm/.7/STDOUT` perms [ protocol-7 750 ].
  start = `bin/Protocol-7 v7` as root [ systemd unit points at
  /usr/local/protocol-7, NOT the dev repo ]. sudo needs a password;
  no setuid helpers. if the network dies as taeki, you cannot restart it.
- `p7c` = one fresh session per invocation [ unix-taeki reconnects each
  call ]. session-scoped state [ e.g. pending_routing_override ] is NOT
  observable across p7c calls — verify via `show-buffer` log lines instead.

## implementation notes [ what landed ]

- resolver: `base.zenki.resolve_routing_sids` [ shared by
  route_to_target + send.local ]; composes AFTER the initialized/drain
  filter. default absent-key mode = contact-oldest.
- `<v7.start_setup.zenki.config>` exists ONLY in the v7 process — cube
  cannot read it. bridge: v7 pushes to cube-side `<cube.zenki.routing_mode>`
  via `cube.set-routing-mode` [ on zenka online in v7.handler.zenka_status,
  on v7.init_start_setup re-parse, on v7.callback.connect_to_cube ].
- in every zenka the upstream cube session is registered as user 'cube'
  [ base.net.connect ] — `cube.<cmd>` from a zenka = "send <cmd> to cube";
  inside cube itself `cube.<cmd>` is NOT routable [ no user 'cube' ].
- admin override: one session slot `pending_routing_override`, 13s
  auto-expiry timer [ cube.handler.routing_override_expire ], :keep:
  refreshes on application. p7c sessions close instantly so expiry
  early-returns silently [ by design ].
- whitelist regen: `./bin/dev/gen-sub-whitelist` [ all ] — 116 files, all
  gained base.zenki.resolve_routing_sids; runtime ignores signatures,
  human re-signs before commit.

#,,..,,..,,.,,,,,,...,,,.,,,,,.,.,.,.,,,,,,..,..,,...,...,...,.,,,,,.,,,.,...,
#Z4Y4TRJQRILWWZA462PRA6DCILPRSORBDUCOZ6DAN5BMADVEIUMI7JG6VVVIQRNM3RBO2WBF2THDO
#\\\|EFZEAQBU3JTISQACVCN7SODX6AZNXAFX5MUWN4NOWT6VOEBB5MC \ / AMOS7 \ YOURUM ::
#\[7]Y4I3MVOZ6V2DFMKUXJILFUDFGOSDBFSVSVTT6CP2QY5RE36J6SDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
