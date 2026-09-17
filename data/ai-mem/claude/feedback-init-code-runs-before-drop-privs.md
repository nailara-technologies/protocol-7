---
name: init-code-runs-before-drop-privs
description: init_code executes during init_modules, BEFORE root.drop_privs -- code there that touches $ENV{HOME}/$UID-dependent paths silently resolves under the pre-drop launching user, not the zenka's real target user
metadata:
  node_type: memory
  type: feedback
---

Confirmed live 2026-09-17, `usage` zenka: a timer armed from
`plugin.usage.kimi.init_code` (`event.add_timer`, `after => 0`) read
the wrong credential directory on its first real fire — `ENOENT`, a
**path** problem, not a permission one. The callback itself runs fine
post-drop (the event loop that dispatches any timer literally cannot
start before `[zenka.loop]`, which is always after `[root.drop_privs]`
in a `.v7` file's directive order — ruled that out mechanically before
finding the real cause). The actual bug: `init_code` itself runs during
`[init_modules]`, which is **before** `[root.drop_privs]` — so anything
`init_code` does synchronously (not deferred to a later callback) that
depends on `$ENV{HOME}`/`getpwuid($UID)` resolves under the *pre-drop
launching user* (a system/service account, not the zenka's real target
user like `taeki`), even though the timer it merely *arms* fires later,
correctly, post-drop.

**How to apply**: any zenka work that needs to run genuinely post-drop
— reading/writing under the real user's home directory, anything
user-identity-sensitive — must NOT live directly in `init_code`, even
if it's just "registering" something for later (the registration
itself may be fine, but don't do the real work synchronously in
`init_code`, and don't assume a `event.add_timer` call *inside*
`init_code` protects you either, unless the callback itself re-derives
everything fresh at fire time with zero values captured/closed-over
from the `init_code` call site).

**The clean fix pattern** (already established elsewhere, don't
reinvent): add an explicit post-drop callback directive in the `.v7`
file itself, placed after `[root.drop_privs]` and `[base.net.connect]`
— same pattern the `universal` zenka already uses (`[universal.startup]`,
called in that exact position). A new `src/<zenka>.startup`-style module
does the real first-time work.

**Reload vs first-boot, the direct signal** (per user, corrects an
initial `<system.zenka.initialized>`-based inference this memory
originally proposed): `base.init_modules` (`:51-58,68`) passes an
explicit `$reinit` boolean as `init_code`'s *first argument* —
`my $reinit = shift;` — computed by tracking
`<base.modules.initialized>->{$real_m_name}->{$init_mode}` per
module+phase. FALSE the first time any module's `init_code` runs,
TRUE on every subsequent reload. Use this directly (`if ($reinit) {
...re-arm... }`) rather than inferring first-boot-vs-reload from any
other state flag — it's the real signal already being passed, not
something to reconstruct.

**Full working pattern, both pieces together**: the post-drop
`.v7`-callback module does the unconditional first arm (storing
whatever timer/handle it creates somewhere reachable, e.g. on a
provider hash); `init_code` itself only re-arms `if ($reinit)`,
cancelling the previously-stored handle first so a reload never
leaves two timers running. See `src/usage.startup` +
`plugin.usage.kimi.init_code`/`plugin.usage.claude.init_code` for the
landed reference implementation (commit `bdbe66706`).

related: [[init-code-return-values]] — a different `base.init_modules`
gotcha (return-value semantics, not execution timing), same general
area of the codebase worth knowing together.

#,,,,,,..,...,.,.,,,,,.,,..,.,,,,.,,.,,,.,.,.,,,,,..,,...,...,.,,,,,.,.,.,.,,,

#,,,.,,,,,,,,,.,,,,..,..,,,..,..,,,,,,.,.,,,,,..,,...,...,...,.,,,..,,...,.,.,
#6KBURIBMVRJNWYNJKDHQIUZLPX5QP5HS2RHNHVICDF3AEHCWDRVQPE4PBHOLQJVXOGJGUQS6UK2K2
#\\\|57CXWS6HSU5KZ7CRMKZYJX3NSXKXIGOJSEGE5M3HCG7NUDYJ3LU \ / AMOS7 \ YOURUM ::
#\[7]75HUBMWNTDFB4WSEYPCMNT54NQTZMSEOIEKCZUU3HDEEBCMIHGAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
