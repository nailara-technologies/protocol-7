# v7-zenki-owned devmod enablement state, explicitly clearable

implemented 2026-09-20 [ same day, see "decided / implemented"
below ]; original design conversation captured in git history.
follow-up to [[devcmd-namespace-wildcard-permissions]]. that doc scopes
WHO can reach devmod commands once loaded [ the `access.devcmd.usr.*`
mask axis ]; this doc is about WHETHER devmod gets loaded by default at
all — a separate, standing-attack-surface question.

## why this exists

some zenki [ e.g. `coding` ] load `devmod` by default via their static
`modules.load` list, purely for development convenience. `devmod` exposes
fairly open primitives [ `exec-sub`, `eval-code` ] — that should not need
to be a default-on surface. a static `modules.load` entry is inherited
wholesale by remote/production deployments too, even for a zenka that
isn't started there by default yet — on-demand start-up would still let
e.g. `coding.eval-code` complete the moment it does start. remembering
"devmod was enabled" as an implicit, silently-sticky-forever default
across restarts would itself be counter-productive for a security-
relevant flag — the persistence has to be paired with explicit clear
points, not just assumed safe because it's convenient.

## the proposal

`v7-zenki` [ the zenka lifecycle manager ] becomes aware of devmod-
enabled state **per zenka instance**, and re-enables devmod automatically
when that instance restarts — covering the "convenience" use case
`modules.load` currently serves. this removes the need to list `devmod`
in any zenka's static `modules.load` at all: default is off, and a zenka
that had it explicitly turned on keeps having it on across restarts,
until explicitly cleared.

state must be explicitly clearable, never just ambiently remembered:

- new `v7-zenki.devmod-clear` command, shaped like the existing
  `v7-zenki.restart_own-zenka` [ same self-correlation mechanism — use
  `cfg/zenki/cube/command_aliases` to resolve the calling zenka's cube
  session id, so a zenka can be identified/authenticated as itself when
  clearing its own state ].
- `devmod.cmd.unload-devmod` should itself call `v7-zenki.devmod-clear`
  [ for its own instance ] as part of unloading — so an explicit unload
  doesn't get silently undone by the next restart's auto-re-enable.
- a zenka `stop` command should also clear the flag.
- **`v7-zenki.devmod-clear` takes an optional `[zenka|instance]`
  parameter** [ added 2026-09-20, refined same day — `zenka` alone was
  the first cut, widened to also allow narrowing to a specific instance
  ], letting a privileged caller clear the flag for a DIFFERENT
  zenka/instance, not only as self, and narrow to exactly one instance
  when a zenka name resolves to several. mirror `v7-zenki.zenka.cmd.
  devmod-enable`'s existing param handling for this — it already accepts
  either a bare numeric instance id or a zenka name/pattern resolved via
  `<[v7-zenki.zenka-instances.get-ids]>->($param_str)`, same shape
  reused here rather than inventing new resolution logic. owner's stated
  reasoning for allowing cross-instance targeting at all: this only ever
  increases security [ ability to force-clear someone else's remembered
  devmod state ], never decreases it, so it's safe and worth designing
  in from the start rather than adding later.

## relation to devcmd-namespace-wildcard-permissions

that doc's `access.devcmd.usr.*` axis and this doc's load-state gate are
complementary, not overlapping: even with devmod loaded [ this doc's
concern ], a user still needs a devcmd mask entry to reach anything [ that
doc's concern ]. tightening this doc's default-off posture reduces the
standing attack surface independent of the permission-mask question —
worth doing even if a zenka's devcmd masks are already tight.

## decided / implemented

implemented 2026-09-20, same day as the design conversation. records
the decisions as decided, with the concrete mechanics traced from code.

### 1. per-instance state storage [ settled ]

`<v7-zenki.zenka.instance>->{$instance_id}->{'devmod_enabled'} = TRUE`
— in v7-zenki's own in-memory instance hash, no new store. verified:
`v7-zenki.zenka.instance.restart` never recreates the instance, the
same hash [ and instance_id ] is reused across a restart, and
`v7-zenki.zenka.start` records the new child pid into that same hash.
deliberately NOT persisted: a security-relevant flag must not survive
v7-zenki's own restart, only a managed zenka's restart.

### 2. self-correlation mechanism [ settled ]

exactly the `restart_own-zenka` pattern, no reinvention:
`v7-zenki.devmod-clear` was added to `setup.aliases.source_zenka_sid`
in `cfg/zenki/cube/command_aliases`. cube then injects
`<source_zenka> <source_sid>` as the first two args [ prepended
before any user args, `src/base.handler.command` alias handling ],
and the no-param form resolves the caller's own instance by scanning
`<v7-zenki.zenka.instance>` for a matching `cube_sid`.

### 3. write side — devmod-enable [ settled ]

`src/v7-zenki.zenka.cmd.devmod-enable` now sets
`$instance->{'devmod_enabled'} = TRUE` for every instance it
successfully signaled [ kill returned a count ]. this is the single
write both the clear command and the restart hook depend on.

### 4. auto re-enable on restart [ settled — hook point corrected ]

the doc's guess of `v7-zenki.handler.restart-timeout` was wrong: that
handler is the restart FAILURE path only [ watchdog → status `error` ].
the actual "respawned and confirmed alive" point is
`src/v7-zenki.handler.instance_verification` — the console verification
handshake that is the one place an instance transitions to `online`,
with the new pid already recorded. the hook lives there: if
`devmod_enabled` is set on the instance, SIGNUM53 is sent to the new
`process.id` right after the `online` transition. fresh starts are
naturally excluded [ a fresh instance gets a brand-new hash with no
flag ], so no restart-detection heuristic is needed. extbin instances
never pass verification and cannot load the perl devmod module anyway
— out of scope by construction.

### 5. v7-zenki.devmod-clear [ settled ]

new `src/v7-zenki.zenka.cmd.devmod-clear`. the first two args are
the injected source zenka + sid [ validated as numeric, same as
restart_own-zenka ]; the remainder, if any, is resolved EXACTLY like
devmod-enable's param loop [ numeric instance id → direct hash lookup,
else `<[v7-zenki.zenka-instances.get-ids]>->($param_str)` after the
same `usr` regex gate ]. no remainder → self-target via the injected
cube sid. clearing is `delete $instance->{'devmod_enabled'}` — clear
is NOT unload: the module stays loaded in the running process until
it is restarted or explicitly unloaded; the flag only governs whether
a FUTURE restart re-enables it.

### 6. unload-devmod self-clear [ settled — grant landed ]

`src/devmod.cmd.unload-devmod`'s success branch [ after the purge is
confirmed and masks are recompiled ] now sends
`cube.v7-zenki.devmod-clear` via `<[protocol-7.command.send.local]>`,
the established cross-zenka idiom [ same shape as
`httpsd.self_restart` ]. `v7-zenki.devmod-clear` was added to
`access.cmd.usr.*` [ the catch-all mask, `cfg/zenki/cube/access.zenki`
line 28, right next to `v7-zenki.restart_own-zenka` which already
lives there ] once point 7's in-command admin gate landed — safe for
every zenka to reach, since the gate means self-clear is all any
non-admin caller can ever do with it, regardless of what params it's
given.

### 7. access control on devmod-clear [ revised — in-command gate added ]

original decision [ no in-command gate, mask-layer-only ] turned out to
be fragile: it silently relied on "only admin-wildcard users can reach
this command at all" staying true forever. but point 6's own follow-up
[ granting `coding` a self-clear `access.cmd.usr.*` entry ] would hand
that same grant to the FREE-FORM `[zenka|instance]` parameter too,
since the command didn't distinguish self-target calls from explicit-
target calls once you can reach it — a grant meant only to let `coding`
clear its own state would incidentally let it clear anyone's.

fixed in-command: the explicit [ cross-instance ] targeting branch now
checks the caller's identity against `<system.admin-user>` [ both the
plain and `unix-` prefixed forms, matching `base.access.special-user-
map`'s own `<admin-user>`/`<unix-admin>` handling ] BEFORE resolving
any target params, and refuses otherwise. critically this is checked
against `$source_zenka` — the identity cube itself injected via the
`source_zenka_sid` alias set-up, never anything caller-supplied — same
trust boundary as the unix-auth identity-bypass fix earlier this
session: verify the kernel/cube-verified value, not a self-reported
one. self-target [ no params ] is unaffected and stays available to any
zenka that can reach the command at all. this makes the point 6 follow-
up grant safe to add later: `coding` gains the ability to clear its OWN
devmod state, never anyone else's, regardless of what params it passes.

## open, not yet investigated

- ~~removing `devmod` from `modules.load` on zenki like `coding`~~ —
  done 2026-09-20, `cfg/zenki/coding/zenka.v7`, commit `13eb78690`.
  live-tested end to end by the owner: enable -> restart -> still
  enabled; devmod-clear -> restart -> stays disabled. both directions
  confirmed working against the real running zenka, not just read.
- a zenka `stop` command clearing the flag [ proposal bullet ] was
  not built this pass — flagged as worth revisiting once the
  stop/offline → later-start instance-hash reuse semantics are
  traced.

## security property : v7-zenki itself is not a valid devmod-enable target

confirmed 2026-09-20, not something this pass built -- an existing
structural fact worth documenting rather than leaving as tribal
knowledge. `devmod` does not appear in `cfg/zenki/v7-zenki/zenka.v7`'s
own `modules.load`, and v7-zenki never adds itself to
`<v7-zenki.zenka.instance>` -- that table only ever holds the CHILD
zenki it manages. `v7-zenki.zenka.cmd.devmod-enable`'s target
resolution [ numeric instance id, or a name resolved via
`<[v7-zenki.zenka-instances.get-ids]>` ] is looked up in that same
table, so there is no instance id that ever resolves to v7-zenki's own
process. over the network -- even as `<admin-user>` -- there is no
command path that loads devmod, and therefore `exec-sub`/`eval-code`,
into whatever elevated-privilege process v7-zenki is [ it manages
`[root.drop_privs:<user>]` for the zenki it spawns, plausibly retaining
root itself ].

**scope of this property, precisely:** this holds ONLY against someone
who has network/command-level access alone. `pkill -53 v7-zenki` [ or
`kill -53 <pid>` ] delivers SIGNUM53 directly via the kernel and is
handled by `src/base.sig_NUM53` identically to a network-originated
signal -- it never passes through `base.has_access` or any
access.*.usr mask, because it isn't a Protocol-7 command at all. local
root, or the same unix user v7-zenki runs as, can always bypass every
layer built this session this way. this is not a gap in the feature --
no userspace access-control system can defend against the OS-level
privilege its own process runs under -- but it means "cannot escalate
to root over the network alone" is the precise claim, not "cannot
escalate to root."

## related

- [[devcmd-namespace-wildcard-permissions]] — `data/tasks/completed/devcmd-
  namespace-wildcard-permissions.md`, the permission-mask side of this
  same devmod-hardening effort, implemented 2026-09-20.

#,,..,,.,,.,.,..,,.,.,,.,,.,.,.,.,.,.,.,.,.,,,..,,...,..,,.,,,.,.,,,.,,,,,.,,,
#Q7LQFX6POQIVQ6SX3HOKIZTOH3Z3ILAUNZ7EYTAPE7X5Y2TOBJXIKDMIEZ5E3QQ3THIMMWNJPZUAW
#\\\|D7HPWDIRAX24GTFGIBU2VYQM6ACQK4GD7JZPPO3WOGYA47XCR3T \ / AMOS7 \ YOURUM ::
#\[7]N63HP7EX2KIBCDZQNPKFWVF5GR66MQ5EL2JSH5RSDUWVQHO4TIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
