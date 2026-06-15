---
name: topic-credential-fabric-proxy-transport
description: credential_fabric/proxy/transport zenki — proxy HTTP round-trip WORKING (200 OK verified 2026-06-09); boot/UI fixes through b27ebb655; live traffic verification COMPLETE
metadata: 
  node_type: memory
  type: project
  originSessionId: 540d7622-310e-4b0f-8485-ccf9ab5cebcd
---

Three infrastructure zenki (credential_fabric, proxy, transport) landed
their initial wiring in `21f4edfa5`, but a manual verification pass
(`data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md`, commit
`c336ce62c`) found none of them could actually boot. Session 2026-06-08
dispatched fixes via kimi (`kimi_dispatch`, task files now in
`data/tasks/completed/`) and committed the result as `3349352df`.

See [[topic-ui-show-security-levels]] for the follow-on UI-show
security-level work (steps 1-5 landed 2026-06-13 as `36d605896`,
credential_fabric slot names/metadata now gated by ui-show security
level; step 6, generic key-based level authorization, is open and
deferred to a dedicated session).

**Fixed and committed:**
- proxy: `$proxy` bareword compile error in `proxy.handler.accept`,
  `proxy.selector.load` cwd-relative path failure, `httpd.status_codes`
  load-order in `modules.load`, `max_concurrency = 1` (was racing 3
  simultaneous instances on `127.0.0.1:8118` bind)
- credential_fabric: `cube/access.zenki` granted *prefixed* command names
  (`credential_fabric.resolve`) to the cube-side check, but routed
  commands arrive *prefix-stripped* (`resolve`) — see [[base-prefix-
  stripped]]. Fixed `access.cmd.usr.cube` to use plain names + added
  admin grants. Console can now call `.approve`/`.resolve`/`.rotate`
  without "no perm" errors.
- transport: scaffolded the entire missing config dir (`start`,
  `zenka-startup.v7`, `subroutine.white-list`, `access.zenki`, dep
  manifests), fixed `AF_INET()`/`SOCK_DGRAM()` bareword compile error in
  `transport.handle.udt-tunnel:57` (needs `()` under `strict subs` — see
  precedent `SOCK_STREAM()` in `proxy.listen`/`clients.http.request`),
  fixed `init_code` return-value semantics (see [[init-code-return-
  values]]), and **renamed `<external.transports>` → `<transport.
  registry>`** across all 11 `transport.*` modules.

**The `<external.transports>` rename — a real trap, worth remembering:**
`transport.init_code` borrowed the namespace name `<external.transports>`
from `external.init_code` ("initialize generic transport registry for
external plugins"). This LOOKED like a cross-zenka dependency (and
produced "external.init_code not loaded" boot failures), but per-zenka
isolation means `<external.transports>` inside `transport` and inside
`external` are two completely separate hashes — borrowing the name
bought nothing and created a spurious, *unsafe* apparent dependency
(loading the real `external.init_code` would have scheduled live orbital
auto-connect timers — see `external.init_code:44-72` — wildly
inappropriate inside `transport`). The fix was to seed the registry
locally (`<external.transports> //= {}`) and then rename the namespace
to its own (`<transport.registry>`) once the safety analysis confirmed
none of `transport`'s actual usage (`profiles`/`quality`/`demoted`/
`active`/`stats.connections_ok`) depended on anything `external.init_code`
uniquely provides.

**Fixed 2026-06-09 — proxy HTTP round-trip now WORKING (200 OK verified):**
- `proxy.listen`: data=>$sock watcher fix + FD_CLOEXEC on listen socket
- `proxy.init_code`: listen guard + stale socket cleanup on startup
- `proxy.handler.connection`: async auth + half-close race fix
- `proxy.auth.lookup`: async route-send to credential_fabric
- `proxy.handler.auth_lookup_reply`: new module
- `proxy.handler.post_auth`: new module
- `proxy.transport.select`: guard for missing transport.select
- `proxy.template.generic`: site-yaml.cmd.fetch → site-yaml.fetch
- `proxy.template.passthrough`: `<$var>` → `<[$var]>` dispatch fix
- `proxy.handler.accept`: store watcher handle
- `proxy.client.close`: cancel watchers before close
- `cube/access.zenki`: added site-yaml.fetch for proxy

**Known remaining issue:** stale listen socket from a prior run held by
root process (v7?) causes ~50% connection timeouts; clears on full P7
restart. FD_CLOEXEC on the new socket prevents recurrence after first
clean restart.

**Fixed and committed 2026-06-08 (`353f5f39f`, kimi `cf799057` + follow-up
via `kimi_continue`), across 9 `credential_fabric.*` modules:**
- `subscribe_rotation` wildcard (`*`) bug — fixed with `$slot ne qw| * |`
  guard bypassing the registry-existence check; wildcard bucket that
  `handler.rotation_strm` reads from is now unblocked
- ~9 hardcoded `var/credential_fabric/...` path occurrences (init_code,
  store.local, key_holder.child, register, rotate, seed_registry,
  handler.auth-relay-reply) migrated to `file.zenka_dir.write/load/
  unlink_file/data_path` — paths now resolve to the zenka's own
  `/var/protocol-7/credential_fabric/` instead of cwd. NOTE: this also
  makes `<credential_fabric.cfg.store_dir/registry_file/audit_log>`
  config vars dead (paths now inlined as relative strings) — harmless,
  pre-existing pattern issue, not worth a follow-up
- `credential_fabric.cmd.approve` argument-parsing — was expecting a
  hashref (`$call->{'args'}` shifted as `$params->{'req_id'}`) but real
  callers (p7c, jobsite.cmd.approve) pass positional `"req_id payload"`
  strings; rewritten to `split qr|\s+|, $args_str, 2`
- regression caught mid-fix: kimi's first pass on `store.local` write
  path dropped atomic temp-file+rename semantics (direct
  `file.zenka_dir.write` unlinks-then-writes non-atomically — risky for
  encrypted credential blobs); follow-up `kimi_continue` restored
  atomic write-temp→rename→cleanup-on-failure, fully routed through
  `file.zenka_dir.*`

**Done (unsigned/uncommitted) 2026-06-08 — task `data/tasks/
credential-fabric-console-cmd-access.md`:** dispatched via
`claude_dispatch` (outer session `f870d68f-5996-4ada-83ee-
54a80deeb531`, PID 2503034). The session itself **hung for ~50min**
on a `coding_summarize`/review-summarization call that the local 9B
coding zenka rejected with `initial prompt overflow: estimated 22294
tokens exceeds n_ctx=22000` (task `7277779` — failed+resolved on the
coding-zenka side, but the outer session's poll loop only treats
"completed" as terminal and blocked forever burning near-zero CPU);
killed manually. **However the actual implementation work it produced
on disk was complete and reviewed-clean** (Claude reviewed directly
since the session never self-reported):
- `credential_fabric.cmd.resolve`/`.cmd.rotate`/`.cmd.list-slots` —
  positional `$call->{'args'}`+`split` parsing matching `cmd.approve`
  (the bug class just fixed is NOT reintroduced), bridge correctly to
  hashref-based internal subs, no fake signature stubs, perl -c clean
- `list-slots` avoids the `base.cmd.list` collision; formats a slot
  table (name/owner/type/sensitivity/storage/rotated) without leaking
  secret material
- `cube/access.zenki` grants `credential_fabric.resolve`/`.rotate`/
  `.approve`/`.list-slots` to the admin wildcard using the *stripped*
  form — confirms [[feedback-cmd-segment-stripped]] (still needs a
  live end-to-end `p7c credential_fabric.resolve <slot>` test to fully
  close that memory's "verifying" status)
- `subroutine.white-list` updated with the 3 new module names
**Ready for your sign+stage+commit flow — not yet signed/committed.**

**Fixed and committed 2026-06-08 (`b27ebb655`) — key-holder liveness +
ascii-frame width drift:**
- **fork-before-drop_privs liveness false-negative (generalizable
  pattern, see [[feedback-fork-child-module-loading]] for the sibling
  module-loading trap)**: `credential_fabric.init_code` forks the
  key-holder child during `[init_modules]`, which runs BEFORE
  `[root.drop_privs:<system.amos-zenka-user>]` — so the child stays
  root-owned while the parent later runs unprivileged. Both liveness
  checks (`ui.query.key_holder`, `key_holder.parent`) used
  `kill(0,$pid)`, which reads `EPERM` (cross-uid signal denial) as
  "dead" — UI permanently showed `terminated`/`dead` for a live process,
  AND `key_holder.parent` would fork a fresh root child on EVERY
  operation (process leak). Fixed both call sites to
  `<[base.exists.sub-process]>->($pid)` — a `waitpid`-based check
  (`base.waitpid`/`base.exists.sub-process`) that depends only on the
  parent-child process relationship, not uid match. **General lesson:
  any liveness check on a child forked pre-drop_privs must use
  waitpid-based existence, never `kill(0,...)`.**
- renamed UI state `'dead'` → `'terminated'` (less presumptive about
  whether key material is still recoverable) — also added to
  `cmd.ui-show`'s colorisation status-word list
- **ascii.frame width drift (two compounding bugs)**: the key-holder-
  status frame rendered at inconsistent widths across rows. (1) the
  YAML mockup's bottom border had a hardcoded 62-dot fill, 10 chars
  wider than the frame's actual computed width — `render.border_line`'s
  elasticity model assumes `min` is a true minimum and produces an
  oversized line when `$fixed > $width` (slack clamps to 0, no
  shrinking); fixed the dot count in the source mockup. (2)
  `ascii.frame.render`'s `required_width` contribution from inline
  border slots used `$min_width + $val_len`, where `$min_width` only
  sums *anchor* lengths — it ignored fill runs (the `::::`/dots either
  side of the bracket), under-counting the line whenever the slot value
  is longer than its placeholder (`'running'` 7 chars overflowed where
  `'dead'` 4 chars happened to fit). **General fix** — now computes the
  border line's true fixed width (anchors + fill mins + slot value),
  mirroring `render.border_line`'s own `$fixed` formula; benefits any
  frame with state-driven inline border slots, not just this one. See
  [[topic-ascii-frame-system]] for the broader frame architecture (that
  memory's "DRC validator"/generic-mockup-type content looks stale/
  mismatched against the actual reverse-template-parser code — verify
  before relying on it).

**Fixed and committed 2026-06-13 (`898ac7156`) — live ui-show verification
+ ascii.frame width bugs:** v7 wasn't running credential_fabric (not
on-demand, no v7 always-on entry) — started manually via `v7.start
credential_fabric` (v7.list available shows it as a manual-start zenka).
With it live:
- `p7c credential_fabric.resolve/.rotate/.list-slots/.ui-show` all
  console-callable with `.cmd.` stripped, routed + permission-checked
  correctly, returned real data — closes [[feedback-cmd-segment-stripped]]
  verification fully (was "verifying" status)
- `ui.caller.security-level:28` warned 4x on every call
  (`<unix-AMOS-user> not defined` / `undef value in string eq`) because
  headless zenki like credential_fabric don't load `X11-vars` (only X11
  zenki like `osd-logo` do), so `<system.AMOS-user>` is legitimately
  undef. Fixed by passing the silent flag to
  `base.access.special-user-map` and guarding for undef.
- **ascii.frame width/padding bug (new, distinct from the b27ebb655
  fix)**: `credential_fabric.ui-show overview` rendered the frame at 88
  cols for an empty registry (mockup is 55). Root cause:
  `ascii.frame.parse`'s padding fallback measured trailing whitespace
  on the `{{SUMMARY...}}` content line as `rpad` (=42) — but that
  whitespace is mockup-only visual filler for a block/expand slot, not a
  real margin; `ascii.frame.render` then added that 42 *again* on top of
  the expanded content width. Fixed by skipping `{{NAME...}}\s*$` lines
  when computing rpad. A second bug: border lines with no inline slot
  (e.g. the static `[ credential fabric ]` title) didn't contribute their
  own fixed width to `required_width`, so after the first fix, content
  rows (48 cols) and border lines (55 cols, from anchors+fill mins) went
  *out of alignment*. Fixed by having every border line (not just
  slot-bearing ones) contribute `fixed - left_border - right_border` to
  `required_width`. Both frames (`overview` 55 cols, `auth-relay-queue`
  53 cols) now render self-consistent and match their mockups. General
  fix — affects all `ascii.frame.*` consumers (memory.render.*,
  ui.cmd.ui-show, etc.), not just credential_fabric.

**Still open:**
- on-demand auth (407/pending/approve flow) end-to-end not yet verified
- credential_fabric has no v7 always-on/on-demand registration — must be
  started manually (`v7.start credential_fabric`) each P7 restart until
  that's added

**2026-06-15 update — cred-mesh integration harness + key_holder fixes:**
- kimi built `bin/dev/cred-mesh-test` (orchestrator +
  `bin/dev/cred-mesh-test.d/lib/CredMeshTest.pm`, 5 scenario scripts) per
  `data/tasks/credential-fabric-integration-test.md`. Findings logged to
  `data/md/development/CREDENTIAL-FABRIC-WIRING-FINDINGS.md` (F1-F14).
  Current best: 10/21 assertions passing.
- Landed 3 commits: `20012341c` (access.zenki grant of `site-yaml.fetch`
  to `access.cmd.usr.cred-mesh` + harness files), `bb3b20a36` (fixed two
  `<[base.s_warn]>->('single string')` calls in
  `modules/cred-mesh.key_holder.parent` → "sprintf parameter expected" —
  replaced with plain `warn 'msg <{C1}>';`, see
  [[feedback-s-warn-single-arg]]), `e32ffb386` (root-cause fix: added
  `->autoflush(1)` on both ends of the socketpair in
  `modules/cred-mesh.util.key_holder.start_child` after `binmode` — child's
  `print {$pipe}` responses were sitting unflushed, causing
  `cred-mesh.rotate`/`.encrypt` to always hit the 7s timeout = F3/F10,
  RESOLVED).
- **Stale-process lesson**: F1 (`proxy` denied `credential_fabric.resolve`)
  and F13 (`proxy.template.passthrough:74` undefined subroutine ref) were
  both false alarms — `proxy`/`cred-mesh` sessions were running 1-2 day old
  pre-rename/pre-fix code. `p7c v7.restart <zenka>` after landing fixes,
  before re-verification, resolved both with no code change needed.
- Remaining open items for next kimi round: scenario 1 header-injection
  (x-api-key not reaching upstream via `proxy.auth.lookup`/slot-matching),
  `transport.eval-code` access denial blocking scenarios 2/3 (F2, needs an
  access.zenki grant similar to the site-yaml.fetch fix), scenario 4
  cache-flush logs not observed during rotation, scenario 5 502 HTML
  handling (harness-side fix, not a zenka bug).

**2026-06-15 — scenario 1 header-injection LANDED via claude_dispatch
(opus):**
- Root cause of "injected x-api-key: got ''": `modules/cred-mesh.cmd.resolve`
  called `cred-mesh.resolve` with a hashref arg
  (`{slot=>$slot, context=>{}}`), which selects `$as_size_reply = FALSE`
  and returns the raw `{mode=>'true', data=>$auth_result_hashref, ...}`.
  `base.handler.command` then sent a stringified-hashref `TRUE` reply
  instead of a `SIZE`/YAML reply, so `proxy.handler.auth_lookup_reply`
  (which only handles `cmd eq 'size'`) silently fell through to an empty
  result. Fixed by calling `<[cred-mesh.resolve]>->($slot)` (string-arg
  form, selects `$as_size_reply=TRUE`). Committed `2882f7ad5`. Verified:
  scenario 1 went from 2/5 → 4/5 (only "no relay pending" still fails,
  pre-existing stale `/var/protocol-7/cred-mesh/relay_pending.yaml` from an
  old scenario-5 run, separate/lower-priority).
- Second fix landed same session, commit `6b535bf8a`: proxy zenka log was
  flooded with `no perm. [ src 'cube' cmd|usr 'handler.cred_rotated' ]` on
  every `cred-mesh.rotate` (via `cred-mesh.handler.rotation_strm` ->
  `proxy.handler.cred_rotated` notification, relayed by cube with
  `src='cube'`). Root cause: `base.parser.access_conf` compiles a bare `*`
  in an access mask to regex `[^\.]+` (no-dots-allowed), so it never
  matches dotted command names like `handler.cred_rotated`. Fixed by
  explicitly listing `handler.cred_rotated` in
  `configuration/zenki/proxy/start`'s `access.cmd.usr.cube` mask, ahead of
  the trailing `*`. Verified live: rotating `test.fixcheck` no longer logs
  "no perm".

**Open — intermittent race, scenario 1 still ~3/8 fails after both fixes
above:** when seeding BOTH `openweathermap.api-key` AND `session.<domain>`
slots (as scenario-1 does) and then immediately issuing the proxied
request, ~1/3 of runs return `status=500 / error="read timeout"` from the
LWP client (proxy never responds within 8s) instead of `status=200` with
`x-api-key` injected. A single-slot manual repro (`session.*` only, no
`openweathermap.api-key`) was reliably fast (0.1s). The `no perm` fix
above reduced but did NOT eliminate this race (3/8 failures after the fix,
vs failures also seen before it).

Also re-observed **F13's exact error string** —
`undefined value as subroutine reference [proxy.template.passthrough:74`
(now `:75` after a line shifted) `] [EV:[pid] input buffer]` — repeatedly
in **cred-mesh's** zenka log (not proxy's), across many timestamps spanning
before/during/after this session's restarts. `p7c proxy.list-subs
clients.http.request` confirms `clients.http.request` IS compiled in
proxy. cred-mesh's `modules.load` includes `proxy` (so
`proxy.template.passthrough` is compiled into cred-mesh's `%code` too) but
NOT `clients.http`/`clients.https` — so if cred-mesh ever locally executes
`proxy.template.passthrough` (mechanism unclear — `proxy.handler.cred_rotated`
itself doesn't call it), `<[clients.http.request]>` would be undef in
cred-mesh's context, producing exactly this error. F13 was previously
dismissed as a stale-process false alarm, but it has now recurred
post-restart — **may be a real, separate bug**: something is routing/
executing `proxy.template.passthrough` inside the `cred-mesh` zenka. Needs
investigation: how/why would cred-mesh ever invoke a `proxy.*` module
locally — check `cred-mesh`'s `subroutine.white-list` (it includes
`proxy.handler.cred_rotated` per cred-mesh's whitelist line 336 — was this
copied wholesale from proxy's whitelist, and does cube ever route a
`proxy.handler.cred_rotated`-addressed message to **cred-mesh** instead of
**proxy** because cred-mesh's whitelist also matches it?). This may also be
the root cause of the 3/8 race above (the "EV input buffer" exception could
be killing/corrupting an in-flight event handler mid-request).

**Next:** dispatch a focused opus session for the cred-mesh/`proxy.template.
passthrough` cross-execution mystery + the 3/8 race — these are likely the
same bug. Budget note: previous opus dispatch (session
`6c88ecdb-0616-475c-ac85-a7c64effeb44`) hit the $3 max_budget mid-investigation
after finding the `no perm`/`*` regex root cause but before testing; a fresh
dispatch with a higher budget (e.g. $5) and the cred-mesh-whitelist lead
above should make faster progress.

**RESOLVED 2026-06-15 (claude_dispatch opus, session
`73005c88-feb7-4856-8e0f-2e2b66842a82`):** the two bugs above WERE the same
bug. `modules/proxy.init_code` runs `<[proxy.listen]>` (binds the
SO_REUSEPORT listener on port 8118) unconditionally for ANY zenka that
loads the `proxy` module namespace — and `cred-mesh`'s `modules.load`
includes `proxy` (for `cred-mesh.subscribe_rotation`'s
`proxy.handler.cred_rotated` side effect). So **cred-mesh was ALSO binding
a duplicate listener on 8118**, and the kernel round-robins SO_REUSEPORT
connections across both listeners. ~1/3 of proxied requests landed in
cred-mesh's event loop, which ran `proxy.handler.connection` ->
`proxy.template.passthrough` correctly up to the `direct-tcp-fallback`
branch, then died on `<[clients.http.request]>` (undef in cred-mesh's
`%code` — `clients.http`/`clients.https` aren't in cred-mesh's
`modules.load`) — the exact `proxy.template.passthrough:75` error, and the
client-side request just hung until the 8s LWP timeout.

Fix: `modules/proxy.init_code` now guards both `<[proxy.listen]>` and the
stale-listen-socket cleanup block with
`my $is_proxy_zenka = (<system.zenka.name> // '') eq qw| proxy |;` — only
the zenka actually named `proxy` binds/owns the listen socket.
`cred-mesh.subscribe_rotation` registration is unaffected (no listener
needed for that). Repro loop: **8/8 status=200** (was ~5/8).
`proxy.template.passthrough` error no longer appears in cred-mesh's log
after triggering rotations. Full scenario-1 re-run 2-3x: stable 4/5 (only
the pre-existing unrelated "no relay pending" assertion still fails).
Change is unstaged in `modules/proxy.init_code` — review and commit.

#,,,,,,,.,,,.,.,.,.,.,.,,,,.,,.,.,,,,,,.,,,,,,..,,...,...,...,,..,,..,,.,,,,.,
#T7VFK4O35YFJ4GK43HD6XJ4XQJTVBTH7HYAPXCLUESA4CL7DEWHX347VL4LKLC4VCY26JV2GJJRX2
#\\\|PP54TBXZSQK5CEEPQ4SMTZ2ICHH3ALVOQB6BRN3UQUYQ4RERHRI \ / AMOS7 \ YOURUM ::
#\[7]QXHGT2FJVG5VRSZESQHLTIFOFAMVWSGUNTHNU6UFX5EWEOAMQ4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
