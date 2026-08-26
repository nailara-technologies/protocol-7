## [:< ##

# name  = task: soft vs. hard dependency distinction in the v7 dependency system
# descr = the zenka dependency graph only knows one relationship kind today:
#         if a dependency isn't ok, every dependent gets forcibly restarted.
#         there is no way to declare "I depend on this being available when
#         I need it, but don't tear me down just because it's briefly gone."

## context

found 2026-08-26 while fixing the `coding`/`models` on-demand deadlock (see
`data/ai-mem/claude/` session notes and commit `a40e31e96`, "dependency:
generic resolve hook for self-healing unmet dependencies").

after that fix landed, live-testing turned up a second, related gap:
manually stopping `models` (on-demand, `coding`'s declared dependency)
forcibly restarts `coding` too. idle-shutdown of `models` was suspected but
not yet confirmed to behave the same way -- worth checking as part of this
task, since the code path that causes it doesn't obviously exclude that
case (see "the actual mechanism" below).

immediate pragmatic fix already applied: `cfg/zenki/coding/start.cfg`'s
`dependencies` line no longer lists `models` at all. `coding.init_code`
already contacts `models` via `cube.models.discover` through the normal
async reply-handler pattern (`coding.handler.models_discover_reply`), which
goes through cube's own on-demand routing
(`base.handler.command.route_to_target`'s ondemand branch) -- that alone
auto-starts `models` on first contact, no declared dependency needed, and
tolerates `models` taking a moment to spin up since the reply is already
async. Dropping the dependency removes today's specific hard-coupling
without losing the "models gets started when actually needed" property.

that fix is sufficient for `coding`/`models`, but it sidesteps the
underlying gap rather than closing it. any FUTURE pair of zenki where one
genuinely needs to be told about the other at config-declaration time (for
the pre-start dependency-ok gate / cascade-start behavior), but should
NOT be forcibly restarted just because that other zenka blips, hits the
same wall.

## the actual mechanism (traced, not guessed)

`src/v7.handler.zenka_status`, the reverse-dependency block (~lines 458-479
as of the commit above):

```perl
if (    $status ne qw| online |
    and $status ne qw| extbin |
    and $status ne qw| starting |
    and ( $old_status eq qw| online | or $old_status eq qw| extbin | ) ) {

    # shutdown instances with unresolved dependencies
    foreach my $dep_id ( <[dependency.get_reverse]>->($object_id) ) {
        next if <[dependency.ok]>->($dep_id);
        map {
            <[zenka.instance.restart]>->($ARG)
                if not exists <v7.zenka.instance>->{$ARG}->{'stopping'}
                and not <v7.zenka.instance>
                ->{$ARG}->{'dependency_exempt'}->{$zenka_name}
            } @{
            <[zenka.instance.get_ids]>->(
                <dependency.object>->{$dep_id}->{'zenka_id'}
            )
            };
    }
}
```

whenever a zenka's status transitions away from online/extbin (for ANY
reason -- crash, manual stop, idle-term), this walks every OTHER zenka that
declared a dependency on it (`dependency.get_reverse`) and unconditionally
calls `zenka.instance.restart` on each. there is already a per-instance
`dependency_exempt` escape hatch (`<v7.zenka.instance>->{$id}
->{'dependency_exempt'}->{$zenka_name}`), which hints the author was aware
this needed finer control at some point, but nothing in `v7.set_up_zenka_
dependencies` or the `dependencies = a b c` config-string parser ever
populates it -- it's a plumbed-in but currently-dead knob, not a working
opt-out.

separately worth confirming empirically as part of this task: does
`v7.zenka.instance.stop`'s idle-term path (which forces status to
`shutdown`, see `data/ai-mem/claude/` notes on commit `3f386f6de2d`) hit
this same block? the condition checks `$status ne 'starting'` etc. using
whatever status was passed to `v7.handler.zenka_status` BEFORE the
shutdown-flag override later in the same function -- so on a quick read it
looks like idle-term SHOULD also trigger the cascade, contradicting the
"idle shutdown likely does not" assumption raised live. don't assume either
way -- reproduce it (`models`' own on-demand idle timeout is 1800s per its
`start.cfg`, long enough that this needs either a temporary short timeout
or triggering the underlying status transition directly for a fast test).

## design sketch (not committed to -- validate during implementation)

extend the dependency declaration itself with a kind, defaulting to today's
behavior so nothing existing changes silently:

- config syntax: something like `dependencies = cube models:soft` (a
  per-name suffix, parsed in `v7.set_up_zenka_dependencies` alongside the
  existing `type.name` dotted-object-reference syntax already handled
  there) -- or a separate `dependencies.soft = ...` config line if mixing
  suffix syntax into the existing space-separated list gets awkward
  against the dotted-object-reference case. pick whichever reads better
  once you're looking at real config files side by side.
- storage: `<dependency.chain>->{$object_id}` is currently a flat arrayref
  of dependency object ids (`base.dependency.add`). a "kind" needs
  somewhere to live per edge -- either upgrade chain entries from bare ids
  to `{ id => ..., kind => 'hard'|'soft' }` (touches `base.dependency.ok`,
  `.get_missing`, `.get_reverse`, `.add` -- every consumer of the arrayref
  shape), or keep the chain flat and add a parallel
  `<dependency.chain.kind>->{$object_id}->{$dep_id} = 'soft'` side-table
  (smaller blast radius, doesn't change the existing arrayref shape any
  other code already iterates). lean toward the side-table unless the
  merged-shape refactor turns out cleaner in practice.
- consulted only in the reverse-dependency cascade block above: skip
  `zenka.instance.restart` for a dependent whose edge to the now-unhealthy
  dependency is `soft`. `dependency.ok`'s own forward check (does MY
  dependency chain resolve) and the new resolve-hook from `a40e31e96` are
  unaffected either way -- a soft dependency still gets the same "try to
  cascade-start it on failure" treatment, it just doesn't forcibly restart
  the DEPENDENT side when the dependency degrades.
- default (no suffix / no soft declaration) must stay `hard` -- every
  existing `dependencies = ...` line in every zenka's `start.cfg` keeps
  today's behavior unchanged unless a zenka explicitly opts a specific
  dependency into `soft`.

## why this isn't urgent

`coding`/`models` itself is already fixed by the config change above. this
task is about the general capability for the next pair of zenki that hits
the same shape -- worth having, not worth interrupting other work for.

## validation

- confirm (or refute) the idle-term cascade question above with a real
  reproduction, before designing further -- it changes how much of a
  problem this actually is in practice today.
- unit-level: a fake `hard`-declared pair still restarts the dependent on
  simulated failure (regression guard); a fake `soft`-declared pair does
  not restart the dependent on the same simulated failure, but the
  resolve-hook from `a40e31e96` still fires for the soft edge.
- live: reproduce the original `coding`/`models` shape with a throwaway
  soft-declared pair of on-demand zenki, confirm stopping the dependency
  no longer restarts the dependent, and that the dependent still recovers
  contact once the dependency comes back (same mechanism validated live
  today: reload + resolve hook cascade-start).

#,,,,,...,,,.,..,,,.,,,..,...,,.,,.,.,..,,,.,,..,,...,...,...,.,.,,..,.,.,.,.,
#EGMPS3K7U5GHRUIBF44AH2WV2RNA2J4RY6WL4ZHFYHLLY7SOH3W2Z4DPJ4GA6PUYGOSNGEV5QMIOY
#\\\|TW26FC3NCTIBMTX5S6ASEOSVPNRP3S3VPV5QD4PGNCTXZXZOU6E \ / AMOS7 \ YOURUM ::
#\[7]L2RNEDWH34J4OLPEP4ZPCFV5RVMSD6HG5KMCOX5LJWBKBDZOJSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
