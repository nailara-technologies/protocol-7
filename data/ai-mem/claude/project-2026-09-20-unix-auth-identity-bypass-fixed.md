---
name: project-2026-09-20-unix-auth-identity-bypass-fixed
description: "CRITICAL, FIXED - plugin.auth.unix's unix-socket identity claim never actually verified the claimed alias against the real kernel-verified peer user, letting any local unix account impersonate any configured auth.setup.usr alias (including the admin/owner) just by setting $USER before invoking p7c"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e49f0ab-caa0-40aa-880e-624860973ca3
  modified: 2026-09-20T13:13:42.860Z
---

Found and fixed live, 2026-09-20, during an unrelated tangent (Kimi's
async-parity investigation hit a spurious `unix-kitten` auth failure,
which led to digging into why).

**The bug**: `src/plugin.auth.unix` resolves each unix-socket auth
request's claimed identity (e.g. `unix-root`) against
`auth.setup.usr.<alias>`'s configured allowed-user list, correctly
using `getpwuid($client_uid)` to get the REAL, kernel-verified
connecting username (`$client_uname`) -- but then never actually used
it in the authorization decision. The loop resolved each allowed-user
entry (a literal name or an `<admin-user>`/`<unix-admin>`/etc template
via `base.access.special-user-map`) and compared the resolved value
BACK AGAINST ITSELF (`$prefixed_user eq $allowed_user`) instead of
against `$client_uname`. For any plain (non-`unix-`-prefixed) allowed-
user entry, that comparison is trivially always true, so the loop
authorized as soon as ANY entry existed in the alias's allowed list --
regardless of who was actually connecting. `$client_uname` was
computed and used only in log lines, never in the real decision.

**Confirmed live, cross-account** (not a single-operator false alarm):
a genuinely separate, unrelated local unix account (`another@...`) ran
`USER=taeki p7c whoami` and was authenticated as `unix-taeki` --
cube's own log admitted it: `session authorized [another] as
'unix-taeki'`. Also separately confirmed `USER=root`/`USER=protocol-7`
from the real `taeki` account both succeeded pre-fix (spoofing the
`unix-root`/`unix-protocol-7` aliases, configured via
`auth.setup.usr.unix-root = :unix:root,protocol-7` in
`cfg/zenki/cube/auth.users`) despite `taeki` being neither account.
Root cause is code, not a config regression -- the config itself is
exactly as documented/intended, a legitimate per-alias allow-list of
real usernames.

**Fix**: both `$allowed_user` references in the comparison changed to
`$client_uname` (two spots: the early `next if` skip-gate and the
final `if` authorization check). Deliberately does NOT touch
`base.access.special-user-map` or the `unix-` prefix-stripping logic,
so `<admin-user>`/`<unix-admin>`/`<AMOS-user>`/`<unix-AMOS-user>`
templates still resolve and authorize exactly the real configured
account -- traced by hand against every case (plain literal match,
template-resolved match, legitimate real-account match, illegitimate
cross-account attempt) before applying.

**Deployment gotcha hit while verifying**: `reload source` deliberately
excludes `plugin.*` modules (see [[reference-...]] if this memory
exists, or `MEMORY-reference.md`'s config-reload-clobber pointer) --
the fix silently did NOT take effect on the first `reload source`
call; needed `reload plugins` (bare, sent directly to cube, no zenka
prefix -- this is cube's own auth plugin, not a worker zenka's).
Confirmed post-`reload plugins`: legitimate `p7c whoami` (real taeki)
still returns `unix-taeki`; `USER=root`/`USER=protocol-7`/`USER=kitten`
all now correctly rejected with "authentication not successful".

**Scope check before fixing** (per
[[feedback-security-fix-verify-both-code-paths-not-just-symptom]]'s
"enumerate all callers" discipline): `plugin.auth.unix` only fires for
unix-domain-socket link connections (early-gated on
`$data{handle}{...}{link} eq 'unix'`); `:zenka:` auth
(`plugin.auth.zenka`) and `:auth-keypair:` (Ed25519 signature auth) are
separate code paths that don't reference `client_uname`/`admin-user`
at all and are unaffected by this fix.

**Not yet done**: committing this fix (needs a fresh signed version
per the user's batch-commit convention, same as any other change);
`cube-13` shares this same `plugin.auth.unix` module and has its own
separate `auth.users` config file (`cfg/zenki/cube-13/auth.users`) --
not independently re-verified live this session, but the code fix
applies to it identically once cube-13 reloads its plugins.

#,,.,,...,...,...,,,.,.,.,,.,,.,.,,..,.,.,...,..,,...,.,.,.,.,.,,,,..,,,.,.,.,
#725SKLNIBXLFBBFTHVT73WMGJ7P6QQSJEOGB2DERXTVPR4WVWJKJ66N6D2ECS23WYF4XELARNVNE2
#\\\|FFC7WHDPUPXZQIKBDLPZEATGA2256JPLQHRFJJBDO6R73OW4RXD \ / AMOS7 \ YOURUM ::
#\[7]H3PDNZ7QPU6HR5WQNQXKG3PQJRXL7PUMHP7GCSGNOTTEQ4GLGYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
