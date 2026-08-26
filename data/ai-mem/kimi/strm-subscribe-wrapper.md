# base.strm.subscribe — generic offline-safe STRM subscription wrapper (2026-07-19)

implemented `data/tasks/strm-generic-subscribe-wrapper.md` (archived in
`data/tasks/completed/`, full verification log there).

## what exists now

six modules, mirroring `base.zenka.push` layout + `zenka.push`
namespace-swap convention:

- `src/base.strm.subscribe` — entry: validation, registry,
  defer-or-attempt
- `src/base.strm.subscribe.attempt` — single route-send attempt
- `src/base.strm.subscribe.wait-online` — v7.notify_online wait with
  push-shaped 2**n backoff (60s cap, waiting_no/last_attempt gating)
- `src/base.strm.subscribe.reply-handler` — TRUE=subscribed,
  `client not present`=offline wait, else definitive error (no blind retry)
- `src/base.strm.subscribe.reply-handler.notify-online` — TRUE
  resubscribes immediately, FALSE backs off increasingly
- `src/base.strm.subscribe.pre_init` — swap to `strm.subscribe`

## usage (from any zenka's init_code)

```perl
<[strm.subscribe]>->({
    'publisher' => 'cred-mesh',
    'command'   => 'subscribe_rotation',
    'args'      => [ qw| * | ],     ## publisher-specific, optional
    'handler'   => 'cred-rotated',  ## bare suffix, dots rejected
    'start'     => 0,               ## :start: publisher via notify_online
});
```

sends `<publisher>.<command>` with args `<args..> <system.zenka.name>.<handler>`.
subscriber identity always comes from `<system.zenka.name>`, never a
caller string — the confused-deputy shape from
`cred-mesh-subscribe-handler-reflection.md` is unconstructable here.
defers via `<system.callbacks.initialized>` when own session isn't up;
no fixed-delay timers anywhere.

## gotchas learned this session

- `<a.b.c>` data keys split on EVERY dot: `<base.strm.subscribe.registry>`
  is `$data{'base'}{'strm'}{'subscribe'}{'registry'}` — not
  `$data{'base'}{'strm.subscribe'}{'registry'}`.
- `p7c <zenka>.eval-code` takes raw Perl (`$code{...}`, `$data{...}`),
  NOT `<[...]>`/`<...>` syntax — transformation happens only at module
  load.
- runtime module loading: `$code{'base.load_runtime_modules'}->(@mods)`
  bypasses the whitelist; auto-creates `cfg/zenki/<z>/source/<mod>`
  marker files as a side effect (cleaned up for proxy after the test).
- `devmod.cmd.eval-code` evals with `use warnings FATAL` — snippets must
  be warning-clean.
- new module files left UNSIGNED deliberately (never stub-sign); sign
  with `bin/Protocol-7 sourcecode update-signatures <paths>` (interactive
  key password — not possible in afk sessions).
- adopting the wrapper in a zenka needs `bin/dev/gen-sub-whitelist <zenka>`
  or the pre_init swap never runs at startup (module compiles dormant).

## verified live (proxy × cred-mesh, production call sites untouched)

validation rejections, fresh subscribe (`*:proxy` in cred-mesh),
idempotent repeat, distinct-slot subscribe, offline wait
(`waiting_no=5` while cred-mesh stopped), auto-resubscribe on
`v7.start cred-mesh`, real rotation event reached `proxy.cred-rotated`.

## still open (by design, flagged in the task file)

publisher-restart re-affirm: `<base.strm.subscribe.registry>` entries
persist after success so a future hook (e.g. on `command route
collapsed` over a pending subscribe route) can re-issue attempts.

#,,,,,,..,.,,,,,.,,.,,,.,,,..,..,,..,,.,,,,..,..,,...,...,...,,,.,.,,,,..,...,
#2OVIOE4ZHJXY6G6W2SLITG4EZKILBVK56QKFLTGMMI3QQE36ESPPL2XGGQQV4OIQPLVIYSSVO6MC4
#\\\|KXJBPTYSTKVZOKNGPHVGZZ5DLI5GA54U3FEQKV6UKY344D7NE2H \ / AMOS7 \ YOURUM ::
#\[7]QISUIW7EBQGMCRRE3LE4C2RIGDJZEC4B3YV5Q72BRVPXZFGDD6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
