# task: credential_fabric — register console `.cmd.` modules + grant console access

## dispatch
read `data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md` first —
specifically the section "new — no console/admin user can call ANY
credential_fabric command" (around line 451) and open-issues table row
**#12** (p0). that doc is a manual verification report against the
landed credential-fabric wiring. its blocking findings (#1-#3, the
`subscribe_rotation` wildcard bug, and the hardcoded `var/
credential_fabric/` paths) were already fixed and committed
(`3349352df`, `353f5f39f`) — **this task is the structural spec/access
gap that remains**, independent of those boot-time fixes.

## problem
confirmed live: NO console/admin user (not even `taeki` /
`:unix:<admin-user>`) can call any `credential_fabric` command. running
`p7c credential_fabric.resolve/.rotate/.approve` returns "command not
known or no permission". two compounding issues:

1. **no `.list` introspection command exists at all.** the zenka ships
   16 modules, none named `*.list` / `*.cmd.list`. `p7c
   credential_fabric.list` only returns the generic cube-provided
   `buffers` namespace.
   **naming note: do NOT call it `credential_fabric.cmd.list`** — that
   collides with `base.cmd.list` (a generic, widely-relied-on row-limit/
   prefix/suffix listing command every zenka inherits). pick a distinct
   name, e.g. `credential_fabric.cmd.list-slots` or `.slots` — your
   call, just avoid the collision and document why in the module's
   `# descr`.

2. **no access grant exists for any console/admin user.**
   `cube/access.zenki` grants `credential_fabric.resolve` /
   `.request-authorization` / `.subscribe_rotation` to `proxy` and
   `transport` (cross-zenka, infrastructure-to-infrastructure only),
   and `.register`/`.resolve` to `weather`/`jobsite`/`web-browser`. the
   `access.cmd.usr.*` wildcard (line 6) covers only generic cube
   commands (`commands clear heart drain ...`) — nothing
   credential_fabric-specific. **no entry anywhere grants a console/
   admin user access to `.resolve`, `.rotate`, `.approve`, or any
   introspection command.**
   worth noting: `credential_fabric.cmd.approve` already exists
   (landed to make console approval possible) but was *never wired
   into the permission system* — it's equally unreachable.

## changes

1. **create `.cmd.` console wrapper modules**, modeled directly on
   `modules/credential_fabric.cmd.approve` (positional `$call->{'args'}`
   parsing via `split qr|\s+|, $args_str, 2`, NOT hashref params — the
   internal subs it bridges to expect hashrefs):
   - `credential_fabric.cmd.resolve` — wraps `<[credential_fabric.
     resolve]>`, takes a slot name as its single positional arg, builds
     `{ slot => $slot, context => {} }`
   - `credential_fabric.cmd.rotate` — wraps `<[credential_fabric.
     rotate]>`, takes `<slot> <new_value> [reason]` positionally
     (3-way split, reason optional, default `manual` — match the
     internal sub's own default), builds the params hashref
   - a new **list/introspection command** (see naming note above) that
     enumerates `<credential_fabric.registry>` slots — return enough to
     be useful at a glance (slot name, owner, type, sensitivity,
     storage, last-rotated) without leaking secret material; follow
     `base.cmd.list`'s `{ mode => 'size', data => $string }` return
     convention if it formats a table, or plain `{ mode => true, data
     => \%summary }` if it returns structured data — your call, but
     check how other `.cmd.` list-style commands in the codebase format
     their replies and be consistent
   read `modules/credential_fabric.resolve` and `modules/
   credential_fabric.rotate` carefully for their exact param shapes,
   return-value `mode`/`data` conventions, and error strings — your
   wrappers must surface those faithfully, not swallow or reshape them

2. **wire console/admin access** in `cfg/zenki/cube/
   access.zenki`:
   - grant whichever admin user(s) exist there already (search for
     `taeki` / `:unix:` patterns — if none exist for credential_fabric,
     determine the right grant point: a dedicated `access.cmd.usr.
     <admin-user>` line, or extending `access.cmd.usr.*`) access to:
     `credential_fabric.resolve`, `.rotate`, `.approve`, and the new
     list command
   - model the line format on the existing `access.cmd.usr.proxy` /
     `access.cmd.usr.transport` / `access.cmd.usr.weather` blocks
     immediately above/below in the same file
   - do NOT grant `.register` or `.subscribe_rotation` to console users
     — those are infrastructure-to-infrastructure registration APIs,
     not operator commands (the findings doc doesn't ask for them and
     granting them widens the credential-write surface unnecessarily)

3. **`subroutine.white-list`** — add the new `.cmd.` module names to
   `cfg/zenki/credential_fabric/subroutine.white-list`
   following its existing alphabetical-ish grouping (grep for
   `credential_fabric.cmd.approve` to find where it currently sits)

## constraints
- model the new `.cmd.` wrappers closely on `cmd.approve` — same
  positional-arg parsing idiom, same `<[base.logs]>` usage pattern,
  same `## [ note: cube strips '.cmd.' segment ... ]` awareness if
  relevant
- do not touch signatures, lowercase comments / `[ word ]` bracket
  annotations, `base.logs` (not `base.log`), `TRUE`/`FALSE` constants
- if you can exercise the live system, confirm `p7c credential_fabric.
  <list-cmd-name>`, `p7c credential_fabric.resolve <slot>`, `p7c
  credential_fabric.rotate <slot> <value>` now return real data/errors
  instead of "no perm" — record what you see, including any remaining
  permission gaps
- if you cannot exercise the live system, say so plainly and note which
  parts are unverified

## acceptance
- `credential_fabric.cmd.resolve`, `credential_fabric.cmd.rotate`, and
  a non-colliding list/introspection `.cmd.` module exist, modeled on
  `cmd.approve`'s calling convention
- `cube/access.zenki` grants a console/admin user access to `.resolve`,
  `.rotate`, `.approve`, and the new list command
- `subroutine.white-list` updated
- acceptance items #1 (`list`), #4 (`rotate`), #5 (`approve`) from the
  findings doc are walkable from a `p7c` console session as an admin
  user (verified live, or explicitly marked unverified with reason)

#,,,,,.,,,,..,.,,,,,,,,..,,,,,,,.,,,,,,,,,,,.,..,,...,...,..,,.,,,,..,,,.,...,
#VETOTLRYU5ODNYSTXYAJOIND5D4GXQCD5M5TVBIN2UK5QXZUWPZEXI4CWFHZMSBPTFT5JSA6DS7H2
#\\\|RVSBT3CI5Z7OOX4VAUILRGN4D5BI3FKMBE7RUG72IQ262PBSVXS \ / AMOS7 \ YOURUM ::
#\[7]FHR6MGTFLSZFXJGMD3Y5Q5W54ZL3MT3SVCN6XPSGVQS7CABO5ADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
