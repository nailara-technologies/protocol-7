# hybrid zenka start-up : one-shot console call or resident loop

## what this covers

how one zenka can serve as *both* a plain command-line front door
(`Protocol-7 zenki start debian`, run by an unprivileged user or by an
llm with no v7 access) and a resident, `v7-zenki` managed agent — and
how it avoids paying for the resident shape when it is only being
asked one question.

built and proven in the `zenki` zenka, deliberately: nothing depends
on that zenka's current shape, so it is a low blast-radius proving
ground. the eventual transplant of this pattern into `v7-zenki`
itself is a separate, later decision (see *open decisions* below).

## the three shapes a start file can have

```
configure      [load_modules] -> [init_modules] -> [base.call.console_command]
               one-shot only.  no loop, no cube, no privileges.

nshell         [load_modules] -> [init_modules] -> connect -> [zenka.loop]
               resident only.  every module loaded up front.

user-edit      [load_modules] -> [init_modules] -> connect ->
               [base.call.console_command]
               hybrid loop : no [zenka.loop] in the start file ; a
               console command that needs the event loop calls
               [init-done:TRUE] + [zenka.loop] itself, as its own last
               step, so 'commands' and 'describe' still print and exit
```

`zenki` extends `user-edit`'s hybrid-loop idea backwards past
`[load_modules]` — the *module set itself* becomes a function of the
invoked command, not a constant of the start file.

## the mechanism

three facts make it work, all pre-existing:

- **`<system.args>` is already populated before the start file runs.**
  `bin/Protocol-7` builds it from the residual `@ARGV` after the zenka
  name and the known option tokens have been removed. so the first
  word of the command line is knowable at config-parse time.
- **`base.load_modules` is callable at runtime**, from inside a module,
  with the subroutine whitelist still in force — the same code path a
  config-level `[load_modules:..]` takes. (`base.load_runtime_modules`
  is the whitelist-bypassing sibling, for loads that happen after
  start-up proper; `letsencr`, `image2html`, `vision-batch` and `work`
  all use it that way.) **no new loader primitive was needed.**
- **`base.init_modules` accepts a namespace list**, so the newly
  loaded namespaces' own `pre_init` / `init_code` / `post_init` hooks
  run in the ordinary single pass — provided the extra load happens
  *before* `[init_modules]`, which is why the call sits between the
  two in the start file.

the resulting start file:

```
zenki.cfg.modules.full        = auth.client net protocol io.unix ui
zenki.cfg.modules.resident    = <zenki.cfg.modules.full>
zenki.cfg.modules.cmd-default = <zenki.cfg.modules.full>

zenki.cfg.cmd-modules.start       = <zenki.cfg.modules.full>
zenki.cfg.cmd-modules.status      = -none-
zenki.cfg.cmd-modules.attach-logs = -none-
zenki.cfg.cmd-modules.commands    = -none-
zenki.cfg.cmd-modules.describe    = -none-

zenki.cfg.cmd-network.start       = yes

modules.load = zenki

[load_modules:<modules.load>]
[zenki.parent.select-modules]
[init_modules]
[zenki.parent.start-up]
```

the manifest lives in the config, not in code, because it is a
deployment decision: which commands a given installation considers
cheap is not a property of the source.

`zenki.parent.select-modules` records `<zenki.start-up.mode>` as
`one-shot` or `resident` and loads the matching namespace set.
`zenki.parent.start-up` then branches on that same key:

| | resident | one-shot |
|---|---|---|
| privileges | `root.drop_privs` when root, keep identity otherwise | never dropped |
| cube auth | `:zenka:`, injected key from `start.cfg` | `:unix:` under this zenka's own name |
| after init | inline command [if any], then `[zenka.loop]` | `base.call.console_command`, then exit |

`[zenka.loop]` never appears in the start file at all. the resident
branch calls it; a console command that needs to wait for a reply
calls `[init-done:TRUE]` + `[zenka.loop]` itself (`user-edit`
precedent) and its reply handler `Event::unloop()`s to hand control
back.

the resident branch also processes an inline command from
`<system.args>`, mirroring `v7-zenki`'s own start file
(`[v7-zenki.call_cmd:<system.args>]` right before its own
`[zenka.loop]`) — an unconditional-but-harmless-when-empty step so a
`v7-zenki`-managed instance can still act on a startup-supplied
command before settling into the loop. guarded, though, unlike
`v7-zenki.call_cmd`: `base.call.console_command` defaults an *empty*
command line to `commands` [ full listing ] rather than no-op'ing, so
calling it unconditionally here would reproduce the console-only-zenka
dump-and-restart-loop trap documented below, just triggered from the
resident side instead of via `start_via_v7`.

## why an unprivileged front door needs an `auth.zenki` entry

a standalone invocation has no cube-issued zenka key — that key is
injected through `start.cfg`'s `: zenka-init :` block, which only
exists when `v7-zenki` starts the zenka in `stdin-zenka` mode. so a
one-shot call must authenticate over the unix link instead.

there are two ways to do that, and they are not equivalent:

- **as the invoking human** (`taeki[zenki]`) — `nshell` and
  `user-edit` do this. needs no cube config at all, because
  `cfg/zenki/cube/auth.users` already maps `<admin-user>` /
  `<unix-admin>`. but `cfg/zenki/cube/access.users` then grants that
  session `** ..*.**` — the front door inherits the admin's entire
  authority to relay one command.
- **as the zenka itself** (`zenki[taeki]`) — the `coding` /
  `amos-term` / `mpv` / `protocol-7-menu` precedent. needs
  `:unix:<unix-admin>` added alongside `:zenka:` in
  `cfg/zenki/cube/auth.zenki`, plus an `access.cmd.usr.<zenka>` grant
  in `cfg/zenki/cube/access.zenki`. the blast radius is then exactly
  that grant.

the second is correct for a front door and is what `zenki` uses:

```
auth.setup.usr.zenki  = :zenka:,:unix:<unix-admin>,:unix:<admin-user>
access.cmd.usr.zenki  = v7-zenki.start
```

the `[<unix-user>]` subname is a **routing label only** —
`plugin.auth.unix` splits it off before any authorization decision —
and exists so a short-lived front-door session stays addressable apart
from the resident instance of the same name.

a specific `access.cmd.usr.<name>` entry is **additive**, not a
replacement: `base.has_access` matches the user's own regex *or* the
`access.cmd.usr.*` baseline. so adding the grant above did not cost
`zenki` its baseline `heart` / `commands` /
`v7-zenki.notify_online` / `v7-zenki.restart_own-zenka` /
`v7-zenki.idle-term`.

what the `:unix:` clause *does* cost, today, is real and should be
stated plainly: `plugin.auth.unix` never compares the connecting
peer's unix user against the resolved allowed-user list (see *open
decisions*), so with a `:unix:` clause present **any** local unix user
can claim the `zenki` identity and reach `v7-zenki.start`. with
`:zenka:` alone, no unix peer could. the entry is nevertheless written
in the forward-compatible form — once the plugin does compare the
peer, `<unix-admin>` resolves to `unix-taeki` -> `taeki` and matches
correctly without another config change.

## what does *not* work without root

the original intent was that an unprivileged caller could bootstrap
`v7-zenki` itself via `system()` when the fleet is down. it cannot:
`cube` enforces its own root requirement, and `v7-zenki` drops
privileges for every zenka it starts. `zenki.parent.ensure_v7`
therefore does the honest thing — bootstraps via `system()` when
`$UID == 0`, and otherwise returns a `requires_root` error naming the
condition rather than failing obscurely. relaying to an
*already-running* fleet is fully root-independent, which is the case
that actually matters for a front door.

## a console-only zenka started as a managed zenka dumps its command list

this is the failure the hybrid shape exists to prevent, and it is
currently reachable for every console-only zenka in the tree.

`base.call.console_command` falls through to `commands` when given no
command. a `configure`-shaped start file ends in
`[base.call.console_command:<system.args>]` and nothing else — so when
`v7-zenki` starts such a zenka, `<system.args>` is empty (or the
stray `-v`, see *open decisions*), the zenka prints its **entire
console command table to the console**, exits, and `v7-zenki`
restart-loops it until it gives up:

```
. : <work>    : commands [pattern] ______ list [these] console commands ...
. : <work>    : commit <message> ________ LLM-friendly commit with auto-signing
   ... 25 more rows ...
: instance 7701720 ['work'] starting --> error
: : instance 7701720 [ work ] : start-retries : limitless :
: instance 7701720 ['work']    error --> shutdown
```

observed live for both `work` and `session` while testing the relay.

**there is no marker distinguishing the two kinds of zenka.**
`cfg/zenki/work/start.cfg` and `cfg/zenki/session/start.cfg` are
structurally identical to `cfg/zenki/radio/start.cfg` — `dependencies`,
`start.on-demand`, `restart.disabled`, and a full
`: v7-init :` / `: zenka-init :` `stdin-zenka` pair. across all 109
`start.cfg` files in the tree, no key expresses "this zenka can be run
as a managed instance". so `v7-zenki.zenka.cmd.start` accepts the name,
and the `zenki` front door has nothing to check either.

a textual check on the start file does **not** work as a substitute:
the discriminator would be "has no `[zenka.loop]`", and `zenki`'s own
start file no longer has one — its loop moved inside
`zenki.parent.start-up`. a hybrid zenka and a console-only zenka are
textually indistinguishable at the config level. that is precisely why
the marker has to be declared, not inferred.

two candidate fixes, neither taken here:

- **declare it.** a `start.cfg` key — `zenka.managed = yes|no`, or the
  inverse `console-only = 1` — read by `v7-zenki.zenka.cmd.start`
  (refuse with a clear reason) and, opportunistically, by the `zenki`
  front door (refuse before relaying). needs a `v7-zenki` change, so
  it is out of this sandbox's scope.
- **make the dump impossible.** `base.call.console_command` could
  decline to print the command table when
  `<system.start-up.stdin.read-init-code>` is TRUE and no command was
  given — a managed start never wants that listing. one line, fixes
  the whole class at once, but it is a `base.*` module affecting every
  zenka and should not be changed unilaterally.

the third option is to convert the console-only zenki to the hybrid
shape documented here, which is the real end state — `configure`,
`keys`, `work` and `session` are the obvious candidates.

## whitelist regeneration trap

`cfg/zenki/zenki/subroutines.load-early` is hand-maintained here, not
regenerated. its own header says
`bin/dev/gen-sub-whitelist zenki` — but that derives from
`modules.load`, which is now just `zenki`. regenerating would shrink
the whitelist to the domain module, pushing every
`auth.client net protocol io.unix ui` subroutine the *resident* path
loads onto the deferred-stub path and changing its compile timing.
either keep maintaining it by hand, or teach the generator about
`zenki.cfg.modules.full` first.

## measured

`zenki`, cold start, unprivileged, on this host:

| invocation | before | after |
|---|---|---|
| `zenki status` | 2.04 – 2.32 s (and then died on `drop_privs`) | 1.46 – 1.63 s |
| `zenki commands` | as above | 1.31 – 1.42 s |
| `zenki attach-logs cube` | as above | 1.30 – 1.45 s |
| `zenki start <name>` | never completed | 2.86 – 2.96 s |

roughly a third off the commands that need nothing but the domain
module. **`start` is a wash and that is expected**: it relays through
cube and waits for the reply in the event loop, so it needs
`auth.client net protocol io.unix ui` — the entire set — and now
additionally pays a real round trip it previously never made. the
saving is available only where the command genuinely needs less, and
the manifest is the honest place to say which those are.

note the floor: `bin/Protocol-7` reaching a bare `configure`-shaped
zenka already costs ~0.96 s here, and the loader opens *every*
`.cmd.` / `.console.` file in a loaded namespace for header metadata
regardless of the whitelist. so the win scales with namespaces
skipped, not with subroutines skipped.

## open decisions

- **transplanting into `v7-zenki`.** the pattern is the interesting
  half of what `v7-zenki` would need to be callable as a plain command
  without the fleet already running. deliberately not attempted here:
  `v7-zenki` is the live manager of every other zenka and the two
  changes should not land together.
- **renaming this zenka.** `zenki` collides with the pre-existing
  `zenki.*` shared-code namespace it itself loads — the same ambiguity
  class the `v7` -> `v7-zenki` rename resolved. left alone on purpose
  so the pattern above could be proven first.
- **`bin/Protocol-7`'s option filter drops only one of two adjacent
  flags.** its `s<(^| +)\-(..)( +|$)>< >g` consumes the separating
  space as part of each match, so the following `-flag` no longer sits
  at a boundary the pattern can match. a `v7-zenki` started zenka
  therefore arrives with `<system.args>` = `-v` rather than `''`.
  harmless until a managed zenka reads `<system.args>` — which this
  one does. worked around locally in `zenki.parent.select-modules`
  (leading option tokens are never console commands); the upstream fix
  belongs in `bin/Protocol-7` and is not in this sandbox's scope.
- **no "safe to manage" marker exists.** see *a console-only zenka
  started as a managed zenka dumps its command list* above — the two
  candidate fixes both reach outside this sandbox, so neither was
  taken. this is the highest-value follow-up of the three listed here,
  because the `zenki` front door now makes the trap reachable in one
  command by an unprivileged caller.
- **the non-root bootstrap.** see *what does not work without root*
  above. making the plain-user case genuinely bootstrap the fleet
  needs either a sudo path or a small root-side helper — a separate
  decision, not attempted here.
- **`plugin.auth.unix` never compares the peer's unix user.** its
  allowed-user loop resolves each `:unix:` token through
  `base.access.special-user-map` and then compares the result with the
  *token it came from*, not with `$client_uname` — a tautology for a
  literal name and always false for a `<template>` in first position.
  every hybrid zenka already depends on the current behaviour, so this
  is recorded, not changed.

#,,..,..,,,,.,,,,,..,,,.,,,.,,...,,.,,,.,,.,,,..,,...,...,..,,,,,,...,,.,,.,,,
#TPXXIJ37SIPNFQ7QNUWGUVYS5H2WNAROWQFSHUBDKF6ZVRLJM5ZDDZMXCIM7OQD3S36ISXEWQATNY
#\\\|SRUHDDEP6UWUDNYVBM5UPWYLYNNZKW36Y6ZS6VKYDPLU4MIUFRZ \ / AMOS7 \ YOURUM ::
#\[7]ZMBYZK2IVEAF4WA4F4DH6RJQRGJ7VN7FPJN42XNGMP7XTVE4NGBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
