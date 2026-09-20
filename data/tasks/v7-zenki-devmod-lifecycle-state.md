# v7-zenki-owned devmod enablement state, explicitly clearable

not started, idea capture only [ 2026-09-20, owner design conversation,
follow-up to [[devcmd-namespace-wildcard-permissions]] ]. that doc scopes
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

## open, not yet investigated

- exact per-instance state storage: `v7-zenki`'s own instance-tracking
  data structures [ `<v7-zenki.zenka.instance>` per `src/v7-zenki.zenka.
  cmd.devmod-enable` ] seem like the natural place, but not confirmed.
- exact `command_aliases` self-correlation mechanism `v7-zenki.
  restart_own-zenka` uses — read that command before implementing, don't
  re-invent the pattern.
- access control on `v7-zenki.devmod-clear` itself, especially the
  cross-zenka `[zenka]` parameter form — who's allowed to force-clear
  someone else's state is itself an access.cmd.usr decision.
- whether removing `devmod` from `modules.load` on zenki like `coding`
  is a separate follow-up commit/decision from building this mechanism,
  or bundled — probably separate, since the mechanism needs to exist and
  be trusted before any default-load config gets pulled.

## related

- [[devcmd-namespace-wildcard-permissions]] — `data/tasks/devcmd-
  namespace-wildcard-permissions.md`, the permission-mask side of this
  same devmod-hardening effort, implemented 2026-09-20.

#,,,.,,.,,..,,.,.,,.,,,..,.,.,,,.,.,,,,,.,,.,,..,,...,...,..,,.,,,...,,,,,,,.,
#VOQQBYOZDN6Z65LH6M657SWQT653UZNI2HUHDIGXXI33H4TAUIWFWGPZR5ESLSZFZE6SLUMXZN3ZW
#\\\|EJJWHEWOVPQRESLS4WPNAITTXRORP6PVHTWEFR6TPYEYS5UHEZP \ / AMOS7 \ YOURUM ::
#\[7]PWMTF7FVLSK7PRLZ55JEQ6YJC5L6GBDKSEMAGAXSRX6X3TWOAGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
