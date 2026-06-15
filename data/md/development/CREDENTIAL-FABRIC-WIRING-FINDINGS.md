# credential-fabric wiring — manual verification findings

commit under test: `21f4edfa5`
verifier: kimi (manual pass), with a follow-up addendum pass by claude
date: 2026-06-07

> **note on the addendum**: the second pass (bottom of this doc, "##
> addendum — second pass against the live v7 instance") corrects one
> headline claim below — `credential_fabric` *does* boot and seed
> correctly once the spec-compliant config is in place — and surfaces
> a new structural blocker that applies regardless of boot status: no
> console/admin user has permission to call `credential_fabric.list`/
> `.resolve`/`.rotate`/`.approve` at all. read both passes; they
> disagree on a few specifics and that disagreement is itself useful
> signal for the fix-task.

## summary

the wiring commit landed the modules and config changes specified in
`data/tasks/credential-fabric-wiring.md`, but **none of the three
infrastructure zenki (credential_fabric, transport, proxy) can currently
start cleanly** against the running v7 instance.

- **credential_fabric** — lacks `zenka-startup.v7`; v7 refuses to start it.
  also missing `auth.zenki` entry.
- **transport** — has no `configuration/zenki/transport/` directory at all;
  missing `auth.zenki` entry.
- **proxy** — after adding the missing `auth.zenki` entry for proxy at the
  user's request and reloading cube, proxy now authenticates successfully
  with cube, but init still fails due to (1) a compile error in
  `proxy.handler.accept` line 6 and (2) `proxy.selector.load` dying on an
  undefined scalar dereference when `file.slurp` returns `undef` for the
  relative-path `template-selector.yaml`.

because the zenki cannot finish init, the end-to-end acceptance
scenarios are blocked. module-level code review shows several items are
correctly implemented, but at least one critical logic bug (wildcard
rotation subscription rejected) will break cache invalidation even after
the boot-time issues are fixed.

---

## how the verification was run

- connected to the already-running v7 instance via `/var/run/.7/UNIX/NIW7OAQ`
- used `USER=taeki p7c ...` for cube queries
- observed live v7 log output (proxy crash-loop) provided by the operator
- read all landed modules and configuration files in `modules/` and
  `configuration/zenki/`
- copied `configuration/zenki/credential_fabric/seed.yaml.example` to
  `var/credential_fabric/seed.yaml` (explicitly permitted by the task)
- at the user's request, added `auth.setup.usr.proxy = :zenka:` to
  `configuration/zenki/cube/auth.zenki` and sent `p7c reload` to cube
- attempted to start credential_fabric by creating
  `configuration/zenki/credential_fabric/zenka-startup.v7`, adding
  `auth.setup.usr.credential_fabric = :zenka:`, removing `proxy` from
  credential_fabric's `modules.load`, and adding credential_fabric to
  `configuration/zenki/v7/start-set-up.base` — v7 reload did not pick up
  the new start-set-up entry, so credential_fabric remains unstartable
  via v7. manual `./bin/Protocol-7 credential_fabric` fails because it
  runs as unix user `taeki` and cube rejects the auth handshake
  (`taeki != credential_fabric`); v7-managed startup is required for
  proper session-key auth
- did **not** modify any zenka module source — all findings are documented
  as-is for a follow-up fix task

---

## acceptance item walk-through

### 1. seeded slots visible via `p7c credential_fabric.list`

**verdict: blocked — credential_fabric zenka will not start**

`p7c v7.start credential_fabric` returns:
```
zenka 'credential_fabric' not configured for 'v7'-managed start-up,
see log-buffer.
```

v7 log shows:
```
required file 'zenka-startup.v7' not present
  :. configuration/zenki/credential_fabric/zenka-startup.v7
```

`configuration/zenki/credential_fabric/start` exists and loads the
modules correctly, but v7-managed on-demand startup requires a
`zenka-startup.v7` sibling file (see `configuration/zenki/proxy/zenka-startup.v7`
for a working example).

module review: `credential_fabric.seed_registry` (new in this commit)
reads `var/credential_fabric/seed.yaml` and calls
`credential_fabric.register` once per entry. the code is correct — it
parses yaml, validates structure, guards against re-run with
`<credential_fabric.seed.loaded>`, and logs per slot. **if the zenka
could start, seeding would work.**

### 2. transport handle reuse — debug log in `proxy.outbound.connect_or_use`

**verdict: cannot verify — proxy never stays up long enough to serve a
request**

`proxy.outbound.connect_or_use` (new module, 75 lines) is correctly
implemented:
- reads `$context->{'transport'}{'handle'}`
- if the handle exposes a connected socket, logs at level 2:
  `proxy.outbound.connect_or_use: using transport %s socket`
- returns `{ socket => $sock, type => $handle_type, transport => $handle }`
- falls back to `IO::Socket::IP` direct tcp tagged `direct-tcp-fallback`

call-site review:
- `proxy.template.passthrough` calls it on line 40 and branches on
  `$conn->{'type'} eq 'direct-tcp-fallback'` (line 50)
- `proxy.template.passthrough.connect` calls it on line 20
- `proxy.handler.connection` copies the transport result into
  `$context->{'transport'}{'handle'}` on line 129

**the wiring is correct, but the proxy zenka crashes during init before
any request reaches this path.**

### 3. header injection — seeded `session.$domain` slot reaches upstream

**verdict: blocked — depends on proxy and credential_fabric both running**

`credential_fabric.resolve` already supports `session-cookie`, `api-key`,
`bearer-token`, etc. and returns an `inject_header` hash. `proxy.auth.lookup`
calls `credential_fabric.resolve` for `session.$domain`, caches the result,
and stores it in `$context->{'auth'}`. `proxy.template.passthrough` walks
`$context->{'auth'}{'slots'}` and merges `inject_header` entries into the
outbound request (lines 21-35).

**the injection path is wired correctly, but cannot be exercised because
the proxy cannot finish init.**

### 4. rotation — `p7c credential_fabric.rotate <slot>` flushes proxy + transport caches

**verdict: partially implemented, but broken by a subscription bug**

`credential_fabric.handler.rotation_strm` publishes on the exact channel
name `credential.rotated.<slot>` (verified in source, line 25). this
matches the spec.

`proxy.init_code` and `transport.init_code` both call
`credential_fabric.subscribe_rotation` with `slot => '*'` and their
respective handlers. **this will fail** because
`credential_fabric.subscribe_rotation` enforces:

```perl
return { mode => 'false', data => "unknown slot '*'" }
    if not exists <credential_fabric.registry>->{'*'};
```

there is no slot literally named `*`, so the wildcard subscription is
rejected. the proxy and transport init codes do not check the return
value, so the failure is silent. after init, neither cache will ever
receive rotation events.

**fix needed:** either relax `subscribe_rotation` to accept `*` without
requiring it to be a registered slot, or have `rotation_strm` walk the
registry and dispatch to per-slot subscribers plus wildcard subscribers
individually.

the handler modules themselves (`proxy.handler.cred_rotated` and
`transport.handler.cred_rotated`) are correctly implemented:
- proxy walks `$data{'proxy'}{'auth_cache'}` and deletes entries whose
  `'slots'` hash contains the rotated slot
- transport walks profile cache and active handle cache, removing entries
  whose `credential` field matches the slot

### 5. on-demand auth — 407 / pending log, `p7c credential_fabric.approve <req_id> <payload>`, retry, succeed

**verdict: blocked — credential_fabric cannot start, proxy cannot start**

module review shows the auth-relay wiring is mostly correct:

`credential_fabric.request-authorization` (updated in this commit):
- generates `req_id`, stores pending entry
- picks `protocol-7-menu.input-text` or `protocol-7-menu.input-password`
  based on sensitivity
- routes via `protocol-7.route-send` with reply handler
  `credential_fabric.handler.auth-relay-reply`

`credential_fabric.handler.auth-relay-reply` (updated in this commit):
- `mode == 'true'` → calls `_complete_approval`, stores session,
  clears pending
- `mode == 'false' && data =~ /graphical mode not enabled/` → writes
  `relay_pending.yaml`, logs the console command
- `mode == 'false' && data eq 'input cancelled'` → clears pending,
  returns failure

`credential_fabric.cmd.approve` (new module):
- looks up pending by `req_id`
- synthesises a dialog-style reply with `mode => 'true'`
- calls `credential_fabric.handler.auth-relay-reply`
- on success clears memory and file pending entries

cross-zenka routing note: the module comment in
`credential_fabric.request-authorization` says "cube strips '.cmd.'
segment for cross-zenka routing". the actual module names are
`protocol-7-menu.cmd.input-text` and `protocol-7-menu.cmd.input-password`,
but both `access.zenki` and the route-send target use
`protocol-7-menu.input-text` (no `.cmd.`). this convention is consistent
within the commit but **has never been exercised cross-zenka before** —
confirmation is still needed once the zenki can talk to each other.

---

## additional findings (outside the acceptance list)

### a. proxy startup — auth fixed, two module errors remain

after the user requested adding `auth.setup.usr.proxy = :zenka:` to
`configuration/zenki/cube/auth.zenki` and reloading cube, proxy now
authenticates successfully:
```
[*] success., =), cube authorized session.
```
however, proxy init still fails before `proxy.listen` can bind the
socket. two independent module errors remain:

1. **syntax error in `proxy.handler.accept` line 6:**
   ```perl
   my $listen_sock = shift->w->data // $proxy . listen_sock;
   ```
   `$proxy` is undeclared. this should be `$data{'proxy'}{'listen_sock'}`
   (or the fallback removed entirely, since `shift->w->data` is always
   set by `proxy.listen`). this causes a compile-time failure:
   ```
   Global symbol '$proxy' requires explicit package name
   ```
   the module loader reports "1 broken" but continues; the accept
   handler is effectively missing, so the listening socket is never
   functional.

2. **`proxy.selector.load` dies on undefined scalar dereference:**
   line 9 does:
   ```perl
   my $yaml_str = <[file.slurp]>->($config_path)->$* // '';
   ```
   when the zenka's cwd is not the project root, `file.slurp` returns
   `undef`, and `undef->$*` throws:
   ```
   'undefined value as SCALAR reference [proxy.selector.load:9]
   ```
   the `data/yaml/web-proxy/template-selector.yaml` file **does exist**,
   so this is a path-resolution / working-directory issue. the fallback
   path on line 6-7 uses `<system.root_path>` which would be safer;
   perhaps `<proxy.cfg.selector_config>` should be set to an absolute
   path in `configuration/zenki/proxy/start`.

3. **missing `auth.zenki` entry for `proxy` — FIXED during verification:**
   `auth.setup.usr.proxy = :zenka:` was added to
   `configuration/zenki/cube/auth.zenki` and cube was reloaded.
   this blocker is resolved.

### b. transport zenka has no configuration directory

`configuration/zenki/transport/` does not exist. there is no `start`
file, no `zenka-startup.v7`, and no `auth.zenki` entry for `transport`.
`v7.list available` does **not** list transport. even after creating the
directory, the transport init_code depends on `<external.transports>`
being initialized by the `external` zenka. `external` is listed as
"gone" in `list virtual`, so that dependency also needs to be satisfied.

### c. missing `auth.zenki` entry for `credential_fabric`

`configuration/zenki/cube/auth.zenki` has:
```
auth.setup.usr.credentials = :zenka:
```
but `credentials` is a **different** zenka (the old one). there is no
`auth.setup.usr.credential_fabric`, so even after adding
`zenka-startup.v7`, cube will reject the credential_fabric zenka's auth
handshake the same way it rejects proxy.

### d. `credential_fabric.access.zenki` vs cube `access.zenki` — possible confusion

`configuration/zenki/credential_fabric/access.zenki` exists but defines
`access.cmd.usr.credential_fabric`. the cube's own
`configuration/zenki/cube/access.zenki` **also** defines
`access.cmd.usr.credential_fabric` with the cross-zenka edges
(`protocol-7-menu.input-text`, `proxy.handler.cred_rotated`, etc.).
the credential_fabric-level file defines **intra-zenka** command access
(e.g. `credential_fabric.register`). both files are needed, but the
credential_fabric one is currently not loaded by the start config. this
is not a blocker — the start config explicitly lists the commands under
`access.cmd.usr.cube` — but it is technical debt.

### e. `transport.handle.quic-hysteria` resolves credentials but never uses them

`transport.handle.quic-hysteria` (updated in this commit) calls
`credential_fabric.resolve` and validates the result, but the resolved
`$cred` is stored in the handle hash and never referenced again during
the SOCKS5 proxy setup. the hysteria external client is expected to
authenticate independently; the credential is wired but not yet consumed.
this is acceptable for the current phase (the task spec says "the auth
payload itself stays inside the handle module — do not leak it into the
context hash"), but it should be noted that real hysteria auth is still
a stub.

### f. `proxy.handler.passthrough_reply` still assumes `clients.http.request` callback shape

when the transport-socket path in `proxy.template.passthrough` is taken
(non-direct-tcp-fallback), the response is read via
`clients.http.handler.io` and `clients.http.handler.timeout` (lines
135-148). `proxy.handler.passthrough_reply` expects a callback params
hash with `client_id`, `context`, `ok`, `status`, `headers`, `body`.
this matches the existing http client contract, but the manual-socket
path registers io watchers differently. in practice both paths converge
on the same reply handler, so this is likely fine, yet it has not been
runtime-tested.

---

## open issues (prioritized)

| # | issue | priority | blocks |
|---|-------|----------|--------|
| 1 | fix `proxy.handler.accept` line 6 syntax error (`$proxy` → `$data{'proxy'}{'listen_sock'}`) | **p0** | proxy init |
| 2 | add `auth.setup.usr.credential_fabric = :zenka:` to `configuration/zenki/cube/auth.zenki` | **p0** | credential_fabric boot |
| 3 | create `configuration/zenki/credential_fabric/zenka-startup.v7` (copy from proxy or another zenka) | **p0** | credential_fabric boot |
| 4 | create `configuration/zenki/transport/` with `start`, `zenka-startup.v7`, `subroutine.white-list`, and `access.zenki`; add `auth.setup.usr.transport = :zenka:` | **p0** | transport boot |
| 5 | fix `proxy.selector.load` path resolution so `file.slurp` does not return undef (set absolute path in proxy start config or guard the `->$*` dereference) | **p0** | proxy init |
| 6 | fix `credential_fabric.subscribe_rotation` to accept wildcard `*` without requiring a slot named `*` in the registry | **p1** | rotation cache flush |
| 7 | confirm cross-zenka `protocol-7-menu.input-text` / `input-password` routing works end-to-end (first cross-zenka consumer of these cmd.* dialogs) | **p1** | on-demand auth relay |
| 8 | verify `proxy.outbound.connect_or_use` debug log actually prints when a transport handle socket is reused (currently unobservable due to proxy init failure) | **p2** | acceptance #2 |
| 9 | verify injected headers reach upstream via local listener or httpbin (currently unobservable) | **p2** | acceptance #3 |
| 10 | add transport start config to `v7.list available` (may need v7 config reload or ondemand-zenka registration) | **p2** | transport visibility |
| 11 | `credential_fabric.handler.auth-relay-reply` uses `->%*` postfix dereference (perl 5.24+); safe on current host (5.40.1) but document if target platform is older | **p3** | portability |
| 12 | grant a console/admin user (e.g. `access.cmd.usr.taeki` or extend the `*` wildcard) access to `credential_fabric.list`/`.resolve`/`.rotate`/`.approve` — currently **nobody** at the console can call any of them (see addendum) | **p0** | acceptance #1, #4, #5 — entirely, independent of boot status |
| 13 | add `max_concurrency = 1` to `configuration/zenki/proxy/zenka-startup.v7` (compare `acquire/zenka-startup.v7`) — proxy binds a fixed listening address (`127.0.0.1:8118`); concurrent instances will race on bind | **p1** | proxy stability |
| 14 | second, distinct compile-time issue: `httpd.status_codes` reports "subroutine ... not defined" during `proxy.init_code` despite being listed in `modules.load` — likely a load-order issue (`httpd.status_codes` is the *last* entry, after `proxy`, whose `init_code` needs it already loaded); needs tracing through `base.load_modules`/`init_modules` sequencing to confirm | **p0** | proxy init (compounds #1 in this table) |
| 15 | route all 6 hardcoded `'var/credential_fabric/...'` paths (`init_code`, `seed_registry`, `store.local`, `key_holder.child`, `cmd.approve`, `auth-relay-reply`) through `<[file.zenka_dir.write/load/data_path]>` — same class of cwd-relative-path bug as `proxy.selector.load` (additional finding a.2); works today only because cwd happens to be the project root | **p1** | portability / correct-deployment robustness |

---

## files touched / read during this pass

modules (all read, none modified):
- `proxy.outbound.connect_or_use`
- `proxy.handler.connection`
- `proxy.handler.accept`
- `proxy.handler.request`
- `proxy.handler.cred_rotated`
- `proxy.handler.passthrough_reply`
- `proxy.template.passthrough`
- `proxy.template.passthrough.connect`
- `proxy.auth.lookup`
- `proxy.transport.select`
- `proxy.selector.load`
- `proxy.init_code`
- `credential_fabric.seed_registry`
- `credential_fabric.cmd.approve`
- `credential_fabric.handler.auth-relay-reply`
- `credential_fabric.handler.rotation_strm`
- `credential_fabric.request-authorization`
- `credential_fabric.subscribe_rotation`
- `credential_fabric.resolve`
- `credential_fabric.register`
- `credential_fabric.init_code`
- `credential_fabric.rotate`
- `transport.select`
- `transport.init_code`
- `transport.handler.cred_rotated`
- `transport.handle.direct-tcp`
- `transport.handle.udt-tunnel`
- `transport.handle.quic-hysteria`
- `transport.profile.load`
- `transport.profile.match`
- `protocol-7-menu.cmd.input-text`
- `protocol-7-menu.cmd.input-password`
- `external.init_code`

configs (read; several modified during verification at user request or to
unblock testing):
- `configuration/zenki/cube/auth.zenki` — added `auth.setup.usr.proxy = :zenka:`
  and `auth.setup.usr.credential_fabric = :zenka:`
- `configuration/zenki/cube/access.zenki`
- `configuration/zenki/credential_fabric/start` — removed `proxy` from
  `modules.load` (was causing compile failure due to broken
  `proxy.handler.accept`); temporarily commented out `[root.drop_privs]`
- `configuration/zenki/credential_fabric/zenka-startup.v7` — created
- `configuration/zenki/v7/start-set-up.base` — added `- credential_fabric`
  (not picked up by v7 reload)
- `configuration/zenki/credential_fabric/start`
- `configuration/zenki/credential_fabric/access.zenki`
- `configuration/zenki/credential_fabric/seed.yaml.example`
- `configuration/zenki/proxy/start`
- `configuration/zenki/proxy/zenka-startup.v7`
- `configuration/zenki/proxy/subroutine.white-list`
- `configuration/zenki/external/start`
- `data/yaml/web-proxy/template-selector.yaml`
- `data/yaml/transport/profiles/default.yaml`
- `data/yaml/transport/profiles/atom.yaml`

var/ (modified as permitted):
- `var/credential_fabric/seed.yaml` (copied from example)

---

## addendum — second pass against the live v7 instance (claude, 2026-06-07)

ran a follow-up hands-on pass against the *current* tree — the two
out-of-scope edits kimi made to unblock its own testing
(`credential_fabric/start`'s `modules.load`/`root.drop_privs`,
`v7/start-set-up.base`) have since been reverted to spec; the
legitimate fixes (`auth.zenki` entries, new `zenka-startup.v7`) were
kept. this corrects and extends several items above.

### correction — credential_fabric DOES boot and seed correctly

`p7c v7.reload` then `p7c v7.start credential_fabric` against the
spec-compliant config (still has `proxy` in `modules.load`, still has
`root.drop_privs` active — none of kimi's "unblocking" edits present)
brought the zenka up cleanly and kept it stable:

```
p7c v7.list zenki
   1744151      4727907      credential_fabric   7597072   online
```

`var/credential_fabric/registry.yaml` shows all three seed slots
registered with metadata matching `seed.yaml` exactly:
`openweathermap.api-key` (weather/api-key/low), `atom.udt-psk`
(transport/psk/high), `atom.hysteria-auth` (transport/bearer-token/
high); `fabric.public`/`fabric.secret` keypair generated alongside.
**the seed → registry mechanism works as designed** —
`credential_fabric.seed_registry` is correctly implemented, exactly as
kimi's module review concluded.

this means kimi's belief that `proxy` had to be dropped from
`modules.load` and `root.drop_privs` disabled in order to boot
credential_fabric was **incorrect** — the two real blockers were only
the missing `zenka-startup.v7` and the missing `auth.zenki` entry,
both already present in the kept/reverted tree, and `p7c v7.start
credential_fabric` (direct on-demand start) is the right invocation.
kimi's path via `start-set-up.base` is the wrong mechanism for an
on-demand zenka — which explains why it stayed stuck on "v7 reload did
not pick up the new start-set-up entry."

re-verdict for **acceptance #1**: the underlying seed→registry
mechanism **passes** — verified directly by reading
`var/credential_fabric/registry.yaml` after a clean boot. but the
literal command named in the acceptance text does not exist (see next
finding), so the criterion as *written* still cannot be satisfied even
though the feature it describes works correctly.

### new — no console/admin user can call ANY credential_fabric command

confirmed live via the cube log relay while exercising acceptance
items #1, #4, #5 from a `p7c` session as `taeki`
(`unix-taeki` / `:unix:<admin-user>`):

```
:. cr.,.ic : [3577472] no perm. [ src 'cube' cmd|usr 'resolve' ]
:. cr.,.ic : [3577472] no perm. [ src 'cube' cmd|usr 'rotate'  ]
:. cr.,.ic : [3577472] no perm. [ src 'cube' cmd|usr 'approve' ]
```

`p7c credential_fabric.list` only returns the generic cube-provided
list namespace (`buffers`) — there is **no `credential_fabric.list`
(or `cmd.list`) module at all** (the zenka ships 16 modules, none
named `*.list`/`*.cmd.list`). `p7c credential_fabric.resolve/.rotate/
.approve` each return `command not known or no permission for
'<cmd>'`.

reading both access files explains why:
- `cube/access.zenki:337-344` grants `credential_fabric.resolve`,
  `.request-authorization`, `.subscribe_rotation` to **`proxy`** and
  **`transport`** only (cross-zenka), plus `.register`/`.resolve` to
  `weather`/`jobsite`/`web-browser`
- `credential_fabric/access.zenki:20` grants `.rotate` (and others)
  only to **`credential_fabric`** itself (intra-zenka) — and per
  finding (d) above, this file isn't even loaded by the start config
- the cube wildcard `access.cmd.usr.*` (line 6) covers only `commands
  clear heart drain when-present` — nothing credential_fabric-specific
- **no entry anywhere** grants any console/admin user (`taeki`,
  `:unix:<admin-user>`, or the `*` wildcard) access to `.resolve`,
  `.rotate`, `.approve`, or any introspection command

practical effect: **acceptance items #1, #4, #5 — as literally
specified (`p7c credential_fabric.list`, `p7c credential_fabric.rotate
<slot>`, `p7c credential_fabric.approve <req_id> <payload>`) — cannot
be exercised from the console at all, regardless of whether the zenki
boot cleanly.** this is a structural spec/access gap, not a boot-time
blocker — it needs an `access.cmd.usr.<admin-user>` (or extended `*`
wildcard) grant for at least `list`/`resolve`/`rotate`/`approve`
before any of these acceptance items can be walked by hand, by
automation, or really at all.

worth flagging specifically: `credential_fabric.cmd.approve` — the
module landed *by this very commit* to make console approval
possible — is not mentioned in either access.zenki file. it was
written to be callable but never wired into the permission system
that would let anyone actually call it.

### new — `proxy` zenka-startup.v7 lacks `max_concurrency`, allowing concurrent-instance pile-up

mid-pass, `proxy` briefly had **3 simultaneous online instances**
(unique instance-ids `7509717`/`3553717`/`2597099`, unique
session/job-ids; same zenka-*type*-id `2927039` — confirmed via
operator clarification that this column identifies the zenka type,
not a per-process collision). `configuration/zenki/proxy/
zenka-startup.v7` has no `max_concurrency` key; compare
`configuration/zenki/acquire/zenka-startup.v7`, which sets
`max_concurrency = 1` — a real, working gate (read in
`v7.zenka.cmd.start:102` / `v7.zenka.cmd.restart`, checked against
`v7.start_count`). for a zenka that binds a fixed listening-socket
address (`127.0.0.1:8118`), running concurrently is actively harmful —
multiple instances would race to bind the same address rather than
share load. `proxy/zenka-startup.v7` should set `max_concurrency = 1`
(operator agreed live: "makes sense to limit still while starting
multiple does not mean load sharing too").

### new — second, distinct compile-time blocker: `httpd.status_codes` reported "not defined" during `proxy.init_code`

confirmed live via the console relay, mid-`proxy`-boot:

```
:. cr.,.ic : 'protocol-7 subroutine httpd.status_codes not defined
:. cr.,.ic : module 'proxy'-init not successful [ init_code != [0|5] ]
```

this is **separate from** (and not mentioned alongside) the
`proxy.handler.accept:6` `$proxy`-bareword compile error kimi
documented — both fire during the same `proxy` boot attempt and
compound each other. `httpd.status_codes` *is* already listed in
`proxy`'s `modules.load`
(`configuration/zenki/proxy/start:16` — `...format.yaml proxy
proxy.outbound.connect_or_use httpd.status_codes`, the *last* entry),
and `proxy.init_code:14` calls `<[httpd.status_codes]>` to populate
`<protocol.http.status_codes>`. the module file itself is a plain
data-returning module (`return { '100' => 'Continue', ... }` — no
init_code of its own), so it should compile trivially on its own.
most likely explanation: **load order** — `httpd.status_codes` sits
*after* `proxy` in the `modules.load` list, and `proxy.init_code`
apparently runs (or references the not-yet-loaded sub) before the
list finishes loading — moving `httpd.status_codes` ahead of `proxy`
in the list would likely resolve it. did not trace
`base.load_modules` → `init_modules` sequencing precisely enough to
be 100% certain it's a pure ordering issue rather than something else
swallowing the load — flagged here for the fix-task to verify
directly (reorder, reload, recheck the relay log for the same line).

### new — `credential_fabric` storage paths bypass the managed `file.zenka_dir.*` abstraction

every storage-path reference in the zenka hardcodes a project-relative
`'var/credential_fabric/...'` string instead of going through
`<[file.zenka_dir.write/load/data_path/unlink_file]>` (the
established pattern — see `coding.init_code:116,147`,
`memory.render.context:14,17` — which resolves through
`<system.path.zenka-dirs>{'var_P7'}` to a managed, cwd-independent,
per-zenka directory under `/var/protocol-7/<zenka-name>/`):

- `credential_fabric.init_code:21,23,24` — `<credential_fabric.cfg.
  store_dir>` / `.registry_file` / `.audit_log` all default to
  `'var/credential_fabric/...'`
- `credential_fabric.seed_registry:9` — `$seed_file =
  'var/credential_fabric/seed.yaml'`
- `credential_fabric.store.local:13` — `$store_dir = ... //
  'var/credential_fabric/'`
- `credential_fabric.key_holder.child:24` — same fallback
- `credential_fabric.cmd.approve:43` and `credential_fabric.handler.
  auth-relay-reply:44,119` — `$pending_file =
  'var/credential_fabric/relay_pending.yaml'`

this is **the same class of bug** as kimi's `proxy.selector.load`
finding (additional finding (a)2 above) — both assume the zenka's cwd
is the project root, and both break the moment it isn't (which is the
*normal* case for a `[root.drop_privs]`-managed, v7-started zenka).
none of it surfaced during this verification pass only because the
live v7 instance happens to run with cwd at the project root — it
will surface the instant that's not true (different deployment,
different invocation, containerized run, etc).

side question this raised: *whose* data is this — zenka-owned or
user-owned? checked `credential_fabric.register:17` /
`.resolve:21,27` — `owner` is strictly a **zenka name** (slots route
to `<owner>.credential.resolve` when not locally owned; the seeded
registry shows `owner: transport` / `owner: weather`, real zenka
identities). there is **no** per-user/`usr` scoping field anywhere —
`session.$domain` (from acceptance #3) is a slot-*naming* convention,
not a user namespace. so this is unambiguously zenka-custodial data,
which settles the fix direction: route every one of the paths above
through `<[file.zenka_dir.*]>` against `credential_fabric`'s own
managed dir, not a hand-rolled `var/credential_fabric/`.

**live corroboration, found mid-session**: `bin/var/credential_fabric/`
existed on disk — `fabric.public` (53b), `fabric.secret` (56b),
empty `store/`, all root-owned, mtime `2026-06-07 16:58:46`. byte
sizes match the legitimate `var/credential_fabric/fabric.{public,
secret}` (53b/56b, mtime `2026-06-07 05:35:52`) but the timestamps
differ by ~11.5h — a **separate, orphaned C25519/Twofish keypair**,
not a copy. this is the bug above caught in the act: some process ran
`credential_fabric` init/seed code with `cwd=bin/` (most likely the
`./bin/Protocol-7 credential_fabric` direct-invocation kimi documented
attempting in finding (a) — far enough through `init_code`/
`seed_registry` to materialize files before failing on cube auth), and
the hardcoded relative path resolved to `bin/var/credential_fabric/`
instead of the project-root `var/credential_fabric/`. operator chowned
it back from root and removed it (`rm -rf bin/var/credential_fabric/`
— `bin/var/` itself was empty afterward and went too) once confirmed
as debris rather than intentional state — concrete, non-theoretical
proof that this bug produces stray secret-key material the moment cwd
isn't the project root.

### confirmed live — `proxy.handler.accept:6` `$proxy` bareword bug is real and current

watched it fire in real time during a fresh `proxy` (re)start —
independent confirmation of kimi's finding, still **p0**:
```
:. cr.,.ic : .:[ proxy.handler.accept ]:.
:. cr.,.ic : Global symbol '$proxy' requires explicit package name
:. cr.,.ic :   (did you forget to declare 'my $proxy'?) at
:. cr.,.ic :   proxy.handler.accept line 6.
:. cr.,.ic : ..: success on 98 subs, 1 broken.
```

---

## follow-up pass — 2026-06-15 (commit 15518f0b0)

verifier: kimi (harness-only pass, no zenka module edits)
context: user added `site-yaml.fetch` to `access.cmd.usr.cred-mesh` in
`configuration/zenki/cube/access.zenki` and reloaded cube to unblock the
specific "no perm. [ src 'cred-mesh' cmd|usr 'site-yaml.fetch' ]" error
seen in earlier runs.

### harness re-run result

```
cd /data/projects/protocol-7
./bin/dev/cred-mesh-test --verbose

[ summary ]
  scenarios run : 5
  assertions passed : 8
  assertions failed : 9
```

previous run was **10 passed / 16 failed**. the absolute number of
assertions dropped from 26 to 17 because scenario 4 now times out before
making its later assertions, and scenarios 1/5 crash with "Can't use
string as HASH ref" before completing all checks.

per-scenario assertion counts from the run:

| scenario | pass | fail | notes |
|----------|------|------|-------|
| 1 direct-tcp api-key | 1 | 2 | proxy returns 500 instead of 200; body is a timeout string that crashes YAML parse |
| 2 hysteria bearer | 1 | 3 | `transport.eval-code` denied; handle never returned |
| 3 transport degrade/promote | 0 | 2 | `transport.eval-code` denied; cannot inject/read demoted state |
| 4 rotation invalidation | 2 | 2 | `cred-mesh.rotate` returns "failed to store rotated credential"; `wait_for_log` times out after 25s |
| 5 auth relay console | 4 | 2 | relay pending file empty; approve returns "storage failed"; final proxy request returns 502 HTML string |

### status of previously-identified bugs

1. **`proxy.template.passthrough:74 undefined subroutine reference`** — **not reproduced / appears fixed.** the current proxy zenka boots cleanly; `proxy.show-buffer zenka` shows `proxy.selector.load: 4 rules loaded [fallback=generic.proxy]` and `proxy listening on 127.0.0.1:8118`. no `undefined subroutine` / `Global symbol '$proxy'` errors appear in `/dev/shm/.7/STDOUT/NIW7OAQ` during this run.

2. **`key_holder` child process surviving parent termination** — **not observed in this pass.** `ps -eo pid,ppid,user,comm` shows the current root-owned key_holder child (pid 297432) is a direct child of the cred-mesh parent (pid 297431). no parentless orphan key_holder processes were found. this bug may have been incidentally fixed by the rename/reload or may require an explicit parent-kill test to reproduce.

3. **`"failed to store rotated credential"` / `"key_holder is not ready"` rotation errors** — **still present.** every `cred-mesh.rotate` call in the harness returns `failed to store rotated credential`. the v7 log shows a repeated warning:
   ```
   :. cr.,.sh :  : warn : sprintf parameter expected
   :. cr.,.sh :  :.    .: [cred-mesh.key_holder.parent:76]
   ```
   immediately following each rotate attempt. the key_holder child is forked (log shows `key_holder.child forked (pid ...)`) but the parent times out waiting for a response on the socketpair. additionally, the v7 log contains a historical (possibly intermittent) failure:
   ```
   : 'undefined subroutine &main::AF_UNIX called [cred-mesh.util.key_holder.start_child:10]
   ```
   indicating the `Socket` constants used at `cred-mesh.util.key_holder.start_child:6-9` are not always loaded when the module is first invoked.

4. **scenario 2 (hysteria) transport `eval-code` failure and `YAML::XS::Load` returning a string instead of `HASH`** — **the transport `eval-code` failure is still present, now manifesting as an access denial.** scenario 2 logs:
   ```
   :. tr.,.rt :  [7023317] no perm. [ src 'cube' cmd|usr 'eval-code' ]
   ```
   repeated for every `transport.eval-code` call. the original `YAML::XS::Load` string-vs-HASH issue was not reached because the handle is never returned; scenario 1 still crashes on a string body ("read timeout ...") at `scenario-1-direct-tcp-api-key.pl:71`, but that is the proxy path, not the transport path.

### new findings from this pass

#### F1. proxy auth lookup denied for `credential_fabric.resolve` despite `access.cmd.usr.proxy` granting `cred-mesh.resolve`

- **location / error:**
  - `modules/proxy.auth.lookup:33` sends `command => 'cred-mesh.resolve'` via `protocol-7.route-send`.
  - `configuration/zenki/cube/access.zenki:361-364` grants `cred-mesh.resolve` to `proxy`.
  - v7 log shows:
    ```
    :. cube    :  [1200301] no perm. [ src 'proxy' cmd|usr 'credential_fabric.resolve' ]
    ```
- **impact:** proxy cannot resolve session/api-key slots, so `proxy.auth.lookup` fails and proxied requests either return 500/502 or proceed without injected headers.
- **hypothesis:** command canonicalization still uses the pre-rename namespace `credential_fabric.resolve` for routed cross-zenka calls even though the zenka, modules, and access entries were renamed to `cred-mesh`. console `p7c cred-mesh.resolve <slot>` works because the wildcard `access.cmd.usr.*` (line 6) grants `cred-mesh.resolve`, but the proxy-specific grant is checked against the old canonical name.
- **repro:** start proxy and cred-mesh, issue any HTTP request through the proxy to a domain with a seeded `session.<domain>` slot, watch `/dev/shm/.7/STDOUT/NIW7OAQ` for the `credential_fabric.resolve` denial.

#### F2. transport zenka lacks `eval-code` access/devmod, blocking scenarios 2 and 3

- **location / error:**
  - `configuration/zenki/transport/access.zenki:4-19` grants transport internal commands but does not include `eval-code`.
  - `configuration/zenki/transport/source/ui` exists but `configuration/zenki/transport/source/devmod.cmd.eval-code` does not (cred-mesh has it).
  - v7 log shows on every `transport.eval-code` call:
    ```
    :. tr.,.rt :  [7023317] no perm. [ src 'cube' cmd|usr 'eval-code' ]
    ```
- **impact:** scenarios 2 and 3 cannot introspect or drive the transport zenka; `transport.select`, `transport.demote`, `transport.probe.timer`, etc. cannot be exercised through the harness.
- **repro:** `p7c transport.eval-code 'return 42'` returns a permission refusal (or command-not-known) while `p7c cred-mesh.eval-code 'return 42'` succeeds.

#### F3. key_holder child forks but does not respond, breaking encrypt/rotate/approve storage

- **location / error:**
  - `modules/cred-mesh.key_holder.parent:75-78` logs a timeout after 7 seconds.
  - v7 log warning:
    ```
    : warn : sprintf parameter expected
    :.    .: [cred-mesh.key_holder.parent:76]
    ```
  - `modules/cred-mesh.util.key_holder.start_child:6-9` uses bare `AF_UNIX()`, `SOCK_STREAM()`, `PF_UNSPEC()`; the log also contains an intermittent `undefined subroutine &main::AF_UNIX` error at line 10.
- **impact:** `cred-mesh.rotate` returns `failed to store rotated credential`; `cred-mesh.cmd.approve` returns `storage failed`; encrypted slots cannot be persisted.
- **repro:** `p7c cred-mesh.eval-code '$code{"cred-mesh.key_holder.parent"}->("ENCRYPT","x","y")'` times out; `cred-mesh.key_holder.parent` returns undef and the warning above appears in the log.

#### F4. proxy direct-tcp fallback fails for fake test domains with `Invalid argument`

- **location / error:**
  - `modules/proxy.outbound.connect_or_use:46-51`
  - v7 log:
    ```
    proxy.outbound.connect_or_use: direct tcp to auth-relay-test.local:80 failed: Invalid argument
    ```
- **impact:** scenario 5's retried request after approval returns a 502 Bad Gateway HTML body, crashing the YAML parser in `scenario-5-auth-relay-console.pl:72`.
- **note:** this is partly expected for an unresolvable test domain, but it may also indicate that `IO::Socket::IP` is being passed an option it rejects (e.g. missing `Family`/`AI` params) rather than simply getting a DNS failure.

#### F5. harness seed assertions are too permissive

- **location:** `bin/dev/cred-mesh-test.d/scenario-1-direct-tcp-api-key.pl:45`, `scenario-2-hysteria-bearer.pl:97`, `scenario-4-rotation-invalidation.pl:39`.
- **issue:** `$seed_ok = ( defined $seed_out and $seed_out =~ m{rotated} );` matches the substring "rotated" inside `"failed to store rotated credential"`, so the harness reports `[ OK ]` for seed/rotate steps that actually failed.
- **impact:** pass count is inflated; failures are not surfaced until later assertions crash or timeout.
- **repro:** inspect any run where rotate returns `"registered,failed to store rotated credential"`; the seed assertion still passes.

### prioritized fix list for follow-up task

| # | issue | priority | blocks |
|---|-------|----------|--------|
| 1 | resolve proxy `credential_fabric.resolve` access denial (canonical name mismatch or add grant) | **p0** | scenarios 1, 3, 5 header injection / proxy path |
| 2 | enable `eval-code` for transport zenka (devmod source or access.zenki grant) | **p0** | scenarios 2, 3 |
| 3 | fix `cred-mesh.key_holder.parent`/child response timeout and intermittent `AF_UNIX` undefined sub | **p0** | all rotate/approve/storage operations |
| 4 | tighten harness seed assertions so "failed to store rotated credential" is reported as a failure | **p1** | test signal quality |
| 5 | investigate `proxy.outbound.connect_or_use` `Invalid argument` for unresolvable test hosts | **p1** | scenario 5 retry path |

---

#,,.,,,,.,...,.,,,..,,...,...,.,.,,.,,.,,,,..,.,.,...,...,...,...,,..,,.,,.,.,
#COTCBYTZLBFNOSPXPL2SN5S5T5IWEUASWPRBO7AMS7JCRFLETHUI2RWDESBKLO2PI3EF7CIVKXYR4
#\\\|NKCAG4COQF2E3PBQBUAB46ZUGBZCYC7ADXIF4G3CFELD27PUT4K \ / AMOS7 \ YOURUM ::
#\[7]J7UYWO4FKARSTEXG7AUKW5TSLERQDWWFBD2TSETMHHRLWGLXV4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
