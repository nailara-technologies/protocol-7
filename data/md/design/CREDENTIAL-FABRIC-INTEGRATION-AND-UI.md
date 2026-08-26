# credential fabric — integration plan + management ui design

## scope and intent

three infrastructure zenki landed independently and have not been wired
together end to end:

- `credential_fabric.*` [ 17 modules ] — slot registry, tier-1 twofish/c25519
  encrypted store, detached key-holder child, rotation strm, auth-relay
- `transport.*` [ 14 modules ] — priority list + passive quality + probe timer,
  yaml profiles per destination, per-entry credential refs
- `proxy.*` [ 19 modules ] — http/connect proxy at 127.0.0.1:8118, template
  selector, site-yaml fallback, transport+auth guards as stubs

the proxy zenka already calls `transport.select` and `credential_fabric.resolve`
through thin alias modules, but no realistic test exercises the full path,
no transport profile is seeded with real credential slot refs, and no ui
exists for users to inspect or operate on stored credentials.

this document covers two related efforts:

1. **integration + test plan** for the three zenki working as one system
2. **credential management ui design** built on the ascii frame template
   system, replacing the read-only `p7.keys list` view as the only window
   into credential state

see the per-effort task files in `data/tasks/`:

- `credential-fabric-wiring.md` — concrete integration code changes
- `credential-fabric-integration-test.md` — end-to-end test harness + scenarios
- `credential-fabric-ui-frames.md` — frame templates + read-only browser
- `credential-fabric-ui-interactive.md` — selection, actions, dialogs

---

## part 1 — integration of the three zenki

### current wiring

[ what is already in place ]

```
proxy.handler.request
    ↓
proxy.selector.match  →  template name
    ↓
proxy.auth.lookup     →  credential_fabric.resolve  →  (registry → tier-1 store)
    ↓
proxy.transport.select →  transport.select          →  (profile → handle)
    ↓
proxy.template.resolve →  passthrough | generic.html
```

both stub modules (`proxy.auth.lookup`, `proxy.transport.select`) already
delegate to the real implementations. but:

- the proxy initialises the request context hash with `transport.type='direct'`
  before transport selection runs. nothing later reads the chosen transport
  back into the context.
- `proxy.handler.passthrough` opens its own outbound socket via
  `clients.http.request` without consulting the transport handle.
- the registry seeded by `credential_fabric.register` is empty on a fresh
  install — no slot exists for the proxy to resolve, so `proxy.auth.lookup`
  always returns `{ has_session => FALSE }`.
- transport profiles in `data/yaml/transport/profiles/` either do not exist
  or use placeholder credential refs (`atom.udt-psk`) for which no slot was
  ever registered.

### natural integration points

[ where work is required ]

**(a) outbound socket creation must go through the transport handle.**
`proxy.handler.connection` and any passthrough handler currently call
`clients.http.request` directly. that bypasses `transport.select`. the
transport handle returned by `transport.select` is the connected socket
(or a socks5-proxied client). the proxy must use that socket for the
outbound leg of every request, including connect tunnels.

minimum change: pass `context->{transport}{handle}` into the outbound
client and have it skip its own connect when a pre-connected socket is
present. one shared helper `proxy.outbound.connect_or_use` that consults
the context first, falls back to a direct connect with the chosen
transport type as a tag, keeps both paths uniform.

**(b) credential resolution must happen at two distinct points.**

- *per-request, by domain*: `proxy.auth.lookup` already does this for slot
  `session.$domain`. it needs to also try `api.$domain` and the
  domain-yaml-declared slot name. the proxy never sees secrets — only the
  `inject_header` directive returned from `_perform_auth`.
- *per-transport, by profile entry*: each transport profile entry that has
  a `credential:` ref must resolve at connect time. for `psk` and
  `tls-client-cert` types this is mandatory before the handle is usable.
  `transport.handle.udt-tunnel` and `transport.handle.hysteria-socks5`
  currently take credential as a stub.

**(c) rotation events must flush proxy + transport caches.**
the proxy's template selector caches zenka assertion results and the
transport selector caches per-destination profiles. both must subscribe
to `credential.rotated.<slot>` strm and invalidate matching entries. the
fabric's `credential_fabric.handler.rotation_strm` push already exists —
only the subscribers do not.

**(d) auth-relay flow needs an actual approval surface.**
`credential_fabric.request-authorization` currently routes to
`web-browser.dialog.show` which does not exist. the **primary** path
should instead route to `protocol-7-menu.cmd.input-text` (or
`input-password` for high-sensitivity payloads) — a styled, modal,
top-level gtk3 dialog already implemented by the `protocol-7-menu`
zenka. it pops independent of whichever browser triggered the request,
so the relay works for any proxied client.

both `input-text` and `input-password` are gated behind
`<protocol-7-menu.init-graphical>` and return
`{ mode => 'false', data => 'graphical mode not enabled' }` on headless
hosts. the relay handler must read `mode` and fall back when the
graphical path is unavailable:

```
credential_fabric.request-authorization
    ↓ route-send → protocol-7-menu.cmd.input-text|input-password
        reply.mode == 'true'  → user-typed payload → continue
        reply.mode == 'false' && data =~ 'graphical mode not enabled'
                              → file-based pending queue + console fallback
                                ( p7c credential_fabric.approve <req_id> ... )
        reply.mode == 'false' && data == 'input cancelled'
                              → propagate failure to proxy, drop pending
```

the console fallback is exactly the 407-style flow originally proposed,
demoted to secondary. it stays in the codebase for ssh and headless
operation. on a normal desktop session the user sees a centered modal
dialog the moment a credential is requested.

cross-zenka reachability is the open question — `cmd.*` modules must be
routed via cube as `protocol-7-menu.cmd.input-text` (or whatever cube
registers them as — confirm during wiring; no existing zenka currently
calls these as routed commands, this is the first cross-zenka consumer).
the cube `access.zenki` entry for `credential_fabric → protocol-7-menu`
needs an explicit grant.

modal blocking: while one dialog is open the protocol-7-menu zenka
services only the gtk event pump (via `event.once`). a second relay
request arriving while the first is pending will queue at cube and
fire once the first dialog closes. acceptable for credential prompts;
documented here so it doesn't surprise the implementer.

### what to build

1. one helper module — `proxy.outbound.connect_or_use` — that the
   passthrough handlers funnel through.
2. registry-seeding configuration — a yaml file `var/credential_fabric/
   seed.yaml` parsed once at first init that calls `register` for each
   listed slot. this is how the test scenarios get reproducible state.
3. transport profile examples — `data/yaml/transport/profiles/default.yaml`
   and `data/yaml/transport/profiles/atom.yaml` — both real enough to
   exercise. the atom profile is the motivating high-loss case.
4. rotation subscribers — two thin handlers,
   `proxy.handler.cred_rotated` and `transport.handler.cred_rotated`,
   that flush their respective caches by slot.
5. `credential_fabric.approve` command + `credential_fabric.handler.
   auth-relay-reply` linkage to surface user approval back into the
   pending entry without web-browser.dialog.show.

### test scenarios

each scenario is reproducible from a fresh `var/` and a seeded fabric:

1. **proxy → direct-tcp + low-sensitivity api-key**
   `weather` registers `openweathermap.api-key`. proxy intercepts a GET
   to api.openweathermap.org. selector picks `generic.proxy`. fabric
   returns `inject_header X-API-Key`. transport selects `direct-tcp`.
   outbound request carries the injected header. response flows back.

2. **proxy → hysteria-socks5 + bearer-token**
   same flow but destination matches the `atom` profile so transport
   selects `hysteria-socks5`. credential type is `bearer-token`.

3. **transport degradation under load**
   inject failures into `transport.handle.direct-tcp` via a test hook;
   confirm `transport.demote` fires, probe timer runs, `transport.promote`
   restores once the hook is cleared. proxy never sees the swap — it
   keeps getting completed requests.

4. **rotation invalidation**
   call `credential_fabric.rotate` on an active slot; confirm both
   proxy and transport caches flush; subsequent request fetches the new
   value.

5. **on-demand auth relay (graphical primary path)**
   intercept a request to a domain with no slot. fabric calls
   `request-authorization` which routes to `protocol-7-menu.cmd.
   input-text` (or `input-password` for high-sensitivity). gtk dialog
   pops, user types payload, hits enter. pending entry resolved,
   original request retried, succeeds. **prereq**: an x11/wayland
   session with the protocol-7-menu zenka graphical mode enabled.

6. **on-demand auth relay (console fallback)**
   same flow on a headless host where `<protocol-7-menu.init-graphical>`
   is false. fabric receives `{ mode => 'false', data => 'graphical mode
   not enabled' }`, writes pending entry to file + log, proxy returns
   407 with `req_id`. user runs `p7c credential_fabric.approve <req_id>
   <payload>`. completion identical to scenario 5.

### open questions to flag

- *transport handle lifetime*: `transport.select` returns a handle —
  is it pooled or per-request? the existing modules do not say. a
  pooled handle is needed for tcp keepalive, but pooling complicates
  graceful degradation (the demoted transport's open sockets must be
  drained, not killed).
- *passthrough streaming*: `clients.http.request` accumulates the full
  body before reply. real proxy traffic includes large files and
  long-poll streams. the wiring above does not solve streaming — it
  inherits whatever the underlying client supports. true streaming is
  a separate effort.
- *who owns `proxy.auth.lookup`*: the proxy zenka or the fabric? today
  it lives in the proxy and calls into the fabric, which is fine, but
  the per-domain → slot mapping is policy that belongs to the fabric.
  consider moving the mapping rules into `credential_fabric.resolve`
  itself, leaving `proxy.auth.lookup` as a one-line passthrough.

---

## part 2 — credential management ui

### why a new ui

`p7.keys list` (src/keys.console.list) is the only surface today
for any kind of credential state. it lists c25519 keypairs and
hostkeys — useful for the keys zenka, useless for the credential
fabric whose state is:

- the slot registry (slot, owner, type, sensitivity, storage tier,
  rotation policy, last-rotated ntime)
- the tier-1 store (encrypted blobs, content-addressed)
- rotation subscribers (which zenki listen for which slot strm)
- pending auth-relay requests (req_id, domain, ntime, status)
- the key-holder child process (running / not running, key-locked /
  unlocked, decrypt-phrase prompt state)

the user needs to: browse and search this state, trigger rotation,
grant or revoke per-zenka access, approve pending auth relays,
optionally unlock the key-holder with a decrypt phrase, and see the
fabric's overall health at a glance.

### design principles

- **read first, act later**: phase 1 of the ui is read-only. users
  inspect; nothing changes. that ships before any interactive
  selection model.
- **frames as the unit of view**: each panel of the ui is a single
  ascii.frame template with named slots. the slot block content is
  produced by a fabric query, no exceptions. this means every panel
  is renderable as text, html, and (eventually) gtk via the existing
  `ascii.frame.render.*` adapters with no per-panel code change.
- **composition over branching**: rather than one big "credential
  manager" view with mode flags, define small frames (registry-row,
  registry-detail, rotation-history, auth-relay-pending, key-holder-
  status) and compose them into views.
- **selection is a context-provider concern, not a frame feature**:
  the highlight/focus state is held in `<credential_fabric.ui.focus>`
  and rendered as colorisation, not as a new ascii.frame primitive.
  this avoids forcing ascii.frame to grow a focus-cell concept.

### the data model the ui exposes

```
fabric overview         summary counts (slots, owners, sensitivities)
slot registry           list with sortable columns
slot detail             one slot's full metadata + history
rotation log            recent rotations, who triggered, ntime, result
auth-relay queue        pending user-approval requests
key-holder status       child process pid, lock state, last activity
access map              which zenki can call which fabric commands
```

each of these has a corresponding query helper in the fabric
(`credential_fabric.ui.*`) returning structured data that the ui then
renders into the appropriate frame.

### frame templates required

new files under `data/yaml/ascii-frames/credential-fabric/`:

- `overview.yaml` — top-level summary frame, separator-stretch idiom
- `registry-list.yaml` — block slot for the slot list, column-aligned
- `registry-detail.yaml` — single-slot detail card
- `rotation-log.yaml` — block slot for rotation events
- `auth-relay-queue.yaml` — block slot for pending relays
- `key-holder-status.yaml` — single-line status + lock state
- `approve-prompt.yaml` — single-line input prompt
- `unlock-prompt.yaml` — single-line decrypt-phrase prompt (no echo)

every template uses the `.:[ ]::[ label ]:.` separator-stretch idiom
matching the project convention.

### the visual style

mockup (overview composed of three frames stacked):

```
.:[ ]:::::::::::::::::::::::::::[ credential fabric ]:.
:  slots: 7      owners: 3       relays pending: 1     :
:  key-holder: running   locked: no    rotated: 2h ago :
:.....................................................:

.:[ slots ]:::::::::::::::::::::::::::::::::::[ 7/7 ]:.
:  slot                    owner       type   sens.   :
:  openweathermap.api-key  weather     api    low     :
:  stepstone.session       jobsite     cook   medium  :
:  atom.udt-psk            transport   psk    high    :
:  atom.hysteria-auth      transport   bear   high    :
:  github.pat              credfab     api    high    :
:  session.example.com     credfab     cook   medium  :
:  identity.master         credfab     opaq   high    :
:.....................................................:

.:[ auth relays ]::::::::::::::::::::::::::[ pending ]:.
:  r-2k4p  evil-tracker.com   12s ago    [approve]    :
:.....................................................:
```

selection state is colorisation only (current row inverted or teal-on-
background, project convention). a single keystroke `e` from the
nshell wrapper moves down the slot list and re-renders.

### how it is built

the ui is **not a new zenka**. it lives inside the credential_fabric
zenka as `src/credential_fabric.ui.*`, with three layers:

1. **query layer** — `credential_fabric.ui.query.{overview,slots,
   slot_detail,rotation_log,auth_relay,key_holder,access_map}` —
   pure reads against `<credential_fabric.*>` state, return structured
   hashrefs. no rendering.

2. **render layer** — `credential_fabric.ui.render.<frame_name>` —
   each one loads its template via `ascii.frame.load`, fills slots
   from the corresponding query, returns the rendered string. one
   render module per frame template. minimal logic — slot fill only.

3. **dispatch layer** — `credential_fabric.ui.show` (the entry
   command) takes a view name (`overview`, `slots`, `slot <name>`,
   `relays`, `holder`) and composes the right render modules in the
   right order. this is what `p7c credential_fabric.ui.show` exposes.

interactive selection wraps the same render layer:

4. **selection layer** — `credential_fabric.ui.interactive.{up,down,
   select,refresh}` — mutates `<credential_fabric.ui.focus>`, calls
   the render layer, prints the rerendered frame. selection is
   per-session so it can live in `<session.X.ui_focus>` instead of
   global state.

### actions

once a slot is focused, the user can trigger:

- `r` / `rotate` → call `credential_fabric.rotate`
- `e` / `edit`   → not phase 1; phase 2 brings up an editor frame
- `x` / `revoke` → mark slot disabled, prevents future resolve
- `g` / `grant`  → grant access to a zenka; opens approve-prompt
                   frame with a zenka name slot
- `?` / `detail` → switch the bottom panel to registry-detail

for the auth-relay queue, focused row + `a` triggers
`credential_fabric.approve <req_id>`. the approve-prompt frame
collects the credential payload (api-key, password, etc.) which is
sent to the fabric in a single command. for sensitive types the
payload goes via the unlock-prompt frame (no echo) and the
plaintext is passed to the key-holder over its existing pipe — never
held in the ui zenka's memory.

### key-holder dialog integration

the key-holder child currently auto-generates its c25519 secret on
first run and stores it unencrypted in `var/credential_fabric/
fabric.secret`. the design says this secret should itself be
twofish-encrypted with a user-provided decrypt phrase. the fabric
must prompt for that phrase on first start and on key-holder restart.

**primary path — protocol-7-menu gtk dialog:**

```
key-holder.parent calls start
    ↓
detects fabric.secret is encrypted (magic prefix)
    ↓
fabric route-sends → protocol-7-menu.cmd.input-password
                     args = 'credential fabric — decrypt phrase'
    ↓
gtk modal dialog pops (masked entry, project styling)
    ↓
user types phrase, hits enter (or escape to cancel)
    ↓
reply.data is the phrase string
    ↓
phrase sent to key-holder.child over the existing parent pipe
    ↓
child decrypts secret, derives keys, ready
```

this replaces the originally-proposed custom `unlock-prompt.yaml`
frame + nshell-side no-echo handler **for graphical sessions**. the
gtk dialog already does masked entry, gives platform-native focus
capture (no terminal echo race), and pops independent of whichever
shell or browser is in foreground.

**fallback path — custom unlock-prompt frame (headless / ssh):**

when the dialog reply is `{ mode => 'false', data => 'graphical mode
not enabled' }`, the fabric falls back to a tty prompt. this is the
custom `unlock-prompt.yaml` frame with `PHRASE_MASKED` slot rendering
`*` per character, paired with a one-shot nshell input handler that
sets `no_echo` mode for the duration of input. shape unchanged from
the original design — only the conditions under which it runs.

both paths converge on the same `credential_fabric.cmd.unlock`
command, which forwards the phrase to `key_holder.parent` over its
existing pipe. the phrase is wiped from memory the moment it crosses
the pipe.

**why both paths exist**: a single-binary credential fabric must
boot on headless servers, but on a desktop session the gtk dialog is
the obvious right answer. picking only one would force operators
into either ssh-only operation or hand-rolling x11 forwarding. the
fallback chain mirrors the auth-relay chain in part 1 — same
detection (`mode == 'false' && data =~ 'graphical mode not enabled'`),
same fallback discipline.

### what needs extending in foundational modules

[ what is "use as-is" vs "needs extension" vs "needs new" ]

- `ascii.frame.*` — **use as-is**. no new primitives needed for phase
  1. the frame compose / render / parse pipeline is sufficient.
  selection is colorisation in the slot-block content, not a frame
  feature.
- `context.provider.frame` — **use as-is**. the ui dispatch layer can
  call it for inline mockup frames during prototyping, then promote
  to named templates once stable.
- `protocol-7-menu.cmd.input-text` and `protocol-7-menu.cmd.input-
  password` — **use as-is** as the **primary** surfaces for auth-relay
  approval and key-holder phrase entry. these are existing gtk3
  modal dialogs with the project's dark-theme styling and masked
  entry; they require no edits. **wrinkles to confirm during
  wiring**: (a) cross-zenka reachability — `cmd.*` modules must be
  routable from credential_fabric via cube, and no other zenka
  currently invokes them as routed commands, so this is the first
  cross-zenka consumer; (b) headless detection via the `mode =>
  'false', data => 'graphical mode not enabled'` reply contract,
  triggering the console fallback; (c) modal blocking — while a
  dialog is open the protocol-7-menu zenka services only the gtk
  pump, so concurrent relay requests serialise. acceptable for
  credential prompts, and cube already queues. **phasing impact**:
  the gtk path replaces what was previously a phase-3 custom unlock
  flow with a phase-3a one-liner route-send, simplifying that phase
  significantly. the custom frame path stays for headless operation
  and becomes phase-3b.
- `pager.*` — **possible extension**. the slot list can grow long
  (hundreds of session slots for an active proxy user). the slot-
  registry render should use the pager buffer pattern if the list
  exceeds the terminal height. the existing `pager.buffer.page` and
  `pager.sort.multi-key` are reusable. **extension needed:** a
  `pager.source.fabric-slots` source registration that pages the
  registry by slot name. mechanical work; reuses
  `pager.source.register`.
- `vterm.*` — **not needed for phase 1**. the ui is single-pane,
  single-zenka. vterm becomes relevant if/when phase 3 ships a
  multi-pane fabric dashboard, but that is out of scope.
- `amos-term.*` — **not needed for phase 1**. cursor positioning
  for selection rendering can use plain ansi escape sequences
  (already used by `keys.console.list` colorising path). amos-term
  becomes relevant only when the ui owns a window inside an
  amos-term compositor session — also out of phase 1 scope.
- `menu-commands.*` — **not used**. the menu-commands module is for
  cross-zenka command menu mapping, not for in-frame selection.
  keep them separate to avoid coupling.

new modules needed:

- `credential_fabric.ui.show` (dispatch)
- `credential_fabric.ui.query.*` (8 query helpers)
- `credential_fabric.ui.render.*` (one per frame template)
- `credential_fabric.ui.interactive.*` (4 selection helpers, phase 2)
- `credential_fabric.cmd.approve` (auth-relay approval command)
- `credential_fabric.cmd.unlock` (key-holder unlock command)
- `pager.source.fabric-slots` (only if registry grows past a few
  pages — defer until needed)

### phasing

[ what ships first ]

**phase 1 — read-only browse** [ minimum viable ]
- 7 frame templates
- query layer
- render layer
- `credential_fabric.ui.show overview`
- `credential_fabric.ui.show slots`
- `credential_fabric.ui.show slot <name>`
- `credential_fabric.ui.show relays`
- `credential_fabric.ui.show holder`

**phase 2 — interactive selection + actions**
- selection layer
- `rotate` / `revoke` / `grant` actions
- `approve` flow for relays
- per-session focus state

**phase 3a — key-holder unlock via protocol-7-menu (graphical)**
- one route-send to `protocol-7-menu.cmd.input-password`
- forward phrase to `key_holder.parent` over existing pipe
- fabric.secret encryption magic header + decrypt logic in child
- restart-aware unlock (re-prompt on every restart)

**phase 3b — key-holder unlock fallback (headless)**
- `unlock-prompt.yaml` frame
- echo-suppressed nshell input handler
- mode-detection branch: trigger only when 3a returns
  `graphical mode not enabled`
- fabric.secret encryption migration (shared with 3a)

**phase 4 — multi-pane and html render** [ optional ]
- compose the four frames into one dashboard view
- `ascii.frame.render.html` adapter for web access
- vterm integration for amos-term-resident dashboard

---

## risks and uncertainties to flag

1. **auth-relay surface — gtk primary, console secondary, both
   need cross-zenka plumbing.** the primary path now routes to
   `protocol-7-menu.cmd.input-text` / `input-password`, both of
   which exist and work. but no existing zenka currently invokes
   them as routed commands — this is the first cross-zenka
   consumer of the protocol-7-menu gtk dialogs. confirm during
   wiring that (a) cube routes `protocol-7-menu.cmd.input-text`
   as expected, (b) `access.zenki` grants credential_fabric the
   right to call them. headless hosts need the console fallback;
   that path also remains untested until scenario 6 lands. the
   risk is no longer "no surface exists" — it is "two surfaces
   exist, neither has been driven cross-zenka yet."
2. **transport handle semantics are not pinned down.** before any
   real test wiring lands, the handle's lifetime (pooled vs. per-
   request), its socket type contract, and its cleanup story need
   to be specified. otherwise the integration tests will lock in
   whatever the first writer chose, and changing it later means
   rewriting them.
3. **the key-holder secret is currently stored unencrypted.** the
   ui design assumes the secret will be twofish-encrypted with a
   user phrase. that migration is real work (re-key existing
   stores, decide on a magic header for the encrypted form, write
   a one-time upgrade path). it is *not* covered by the ui task
   files — they assume the migration has happened or is concurrent.
   flag this before phase 3 starts.

#,,,.,,,.,...,,,,,.,,,..,,,,,,...,...,,..,,,.,..,,...,..,,.,.,.,.,,..,,.,,.,,,
#FWAP2LDFQDCA2EGXC55BACQBU5QX75I7R42GH54B6OYHUYF7GURRGP3KCUPCUAWMBKWR6CW2KVGXQ
#\\\|UQKSMUIBZ3PJQOYQAX5P4YCLS7E7X7TL3WNETUANBIKO7KVLNXL \ / AMOS7 \ YOURUM ::
#\[7]NNZLTBP2JNWMOX6PXNCAXTWQCX7QHPQAIVWLXC5XL3GQNC5OJ4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
