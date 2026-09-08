## [:< ##

# name  = task: cred-mesh has no way to input a real credential value
# descr = register only writes slot metadata; the only path that writes a
#         real secret (rotate) always auto-generates one -- there is no
#         way, anywhere, for a user to type in or edit an actual value

## context

found 2026-09-08 while reviewing `data/tasks/credential-fabric-ui-
interactive.md` for archiving. that task (selection, rotate/revoke/grant/
approve, the vault-edit UX pass) is done and landed, but going through its
scope surfaced a more basic gap underneath all of it, confirmed by reading
the actual code rather than assumed:

- `src/cred-mesh.register` (`args: { slot, owner, type, storage, rotate,
  sensitivity }`) never accepts or stores a secret value at all — it only
  writes slot metadata to `<cred-mesh.registry>` / `registry.yaml`. a freshly
  registered slot has no credential material behind it whatsoever.
- `src/cred-mesh.rotate` (`args: { slot, new_value, reason }`) is the ONLY
  code path anywhere that writes real secret bytes, via
  `<[cred-mesh.store.local]>->('write', $slot, $new_value)`. it requires
  `new_value` to be non-empty (`return ... if not length $new_value`), so
  it's mechanically capable of storing an arbitrary value.
- but `src/cred-mesh.ui.interactive.action`'s `rotate` verb — the only UI
  entry point that ever calls `cred-mesh.rotate` — always synthesizes
  `new_value` itself via `Crypt::Misc::random_bytes(32)` (falling back to a
  timestamp on failure). there is no prompt, no free-text input step, no
  way for a human to supply a specific value through this path.
- the only place a real, user-chosen value has ever entered this system:
  `bin/dev/cred-mesh-test.d/helper-seed-fabric.pl`, a dev/test seeding
  script that calls the underlying functions directly, bypassing every UI
  and access-control layer this task's sibling built. not a production
  path, not discoverable by an actual operator.

practical consequence: today there is no way for someone running this
system to put a REAL, already-issued credential (an API key from a
third-party service, a bearer token they were handed, etc.) into the
fabric at all. the entire interactive UI built in `credential-fabric-ui-
interactive.md` operates only on values the system invented for itself.

## scope

1. **a way to set an explicit value at registration time.** either extend
   `cred-mesh.register`'s params with an optional `value`, or (probably
   cleaner, keeps register purely about metadata) require a follow-up call
   into whatever the new "set value" primitive turns out to be, immediately
   after registering an empty slot. decide which shape fits the existing
   `owner`/`storage`/`sensitivity` validation pattern already in `register`
   before building either.
2. **a UI action distinct from `rotate`** — rotate's whole semantic is
   "replace with a fresh generated value, notify subscribers"; entering a
   known value for the first time, or overwriting one with a specific
   value, is a different operation and should probably be a different key
   binding (`vault-edit`'s key-verb table currently has `j/k/r/x/g/a/?/o`
   free — `n` for "new/enter value" or `e` for "edit value" both read
   naturally, pick based on what doesn't collide with anything else added
   since this file was written).
3. **the prompt itself needs no-echo input**, same as the still-blocked
   phase-3 unlock dialog in the sibling task — a credential value is
   exactly the kind of thing that shouldn't render in cleartext or scroll
   into a terminal's own scrollback. reuse whatever no-echo mechanism phase
   3 ends up building (`cred-mesh.ui.interactive.unlock_dialog`'s
   `input_mode = 'no_echo'` state, if that lands first) rather than
   inventing a second one — check landing order and share the mechanism
   either direction.
4. **never log the value**, same hard rule phase 3's task already states
   for the unlock phrase — applies identically here and deserves the same
   explicit reminder in whatever module gets written, not left implicit.
5. **whether this needs to also cover EDITING an existing slot's stored
   value** (not just filling an empty one) — same underlying
   `cred-mesh.store.local` write, so likely the same new primitive/UI
   action serves both "slot has never had a value" and "operator wants to
   replace this one with a specific value they already have," as opposed
   to rotate's "generate me a new random one." confirm this reads right to
   whoever picks this up rather than assuming — an "edit" framing and a
   "rotate to a chosen value" framing could plausibly want different
   confirmation UX (e.g. showing what's being overwritten) even if the
   underlying write call is identical.

## relation to the blocked phase 3 (key-holder unlock)

genuinely independent of the fabric-secret encryption migration phase 3 is
blocked on — this gap exists regardless of whether the fabric's OWN
at-rest secret is encrypted, since it's about how a credential value gets
into `cred-mesh.store.local` in the first place, not about protecting
cred-mesh's own storage key. could land before, after, or alongside phase
3 with no ordering dependency, other than the no-echo-input-mechanism
reuse noted in scope item 3 above.

## what NOT to do

- do not fold this into `rotate` by adding an optional "use this specific
  value instead of generating one" param — conflates two different user
  intents (system-generated rotation vs operator-supplied value) behind
  one action, and rotate's existing subscriber-notification semantics may
  not even be right for a first-time value entry. keep them distinct
  actions even if they end up sharing a low-level write call.
- do not add the `#,,..` signature stub to any new file — the human signs
  new files separately (per this project's own established convention,
  also stated in the sibling task file).

## validation

- register a slot with no value, confirm the new entry action lets a real
  value be typed/pasted in (no-echo), confirm `cred-mesh.resolve` returns
  it afterward.
- confirm the typed value never appears in any log line, buffer, or
  terminal scrollback outside the masked input itself.
- confirm the same action (or a clearly-labeled sibling) can overwrite an
  existing slot's value, distinct from `rotate`'s random-generation
  behavior.

#,,..,.,,,...,,,,,,,.,..,,...,.,.,,..,,,.,.,,,..,,...,...,,,.,...,,,,,.,,,,..,
#DCZGGZP2YU7CTESOAEPPYL3PIDNJ4FLVBYAV7V5DKKPJC5XU7RST2OJTRN3M63PR4MR2TFPS2HUR2
#\\\|SOQP64CTWSSWV76GTAYZI2STSWAJYOFYN4WTYE2NGL5H3LD7HTZ \ / AMOS7 \ YOURUM ::
#\[7]RRKM4ZXGSTIZRB2GA5ZLYGDNZVUP26AJGH53EUD4LDX3T6N7UUDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
