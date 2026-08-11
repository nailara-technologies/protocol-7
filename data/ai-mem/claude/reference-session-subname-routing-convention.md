---
name: reference-session-subname-routing-convention
description: "'<name>[<subname>]' session routing — primary name is ALWAYS the authenticated identity, subname is a routing label that must never touch authorization; decided 2026-08-12 against the inverse form, with the runtime-mutability argument as the clincher"
metadata:
  type: reference
---

## the form

`<name>[<subname>]` — e.g. `mpv[audio]` (zenka auth), `taeki[user-edit]`
(unix auth). Max subname length 18 (`base.regex`'s `MAX_SUBNAME`).

Lets several sessions sharing one authenticated name be addressed
individually. Without it, cube routes by uname and two consoles running
as the same unix user are indistinguishable — `p7c <user>.<cmd>` reaches
whichever matched first.

## the rule

**Primary = the authenticated identity. Subname = which instance of it.**

- zenka auth → primary is the zenka (`mpv[audio]`)
- unix auth → primary is the unix user (`taeki[user-edit]`)

**The subname must NEVER take part in an authorization decision.** It is
split off before the `auth.setup.usr` lookup and before every access
check, so all authorization keeps seeing the bare name. `base.has_access`
takes the bare user and has no subname involvement at all. A future edit
that moves the split later would silently break this property.

## why NOT the inverse (`user-edit[taeki]`)

Considered and rejected 2026-08-12 — the user raised it as their original
idea, then agreed against it. It is not merely stylistic:

1. **The primary would not be an authenticated name.** Unix auth proves
   "this peer really is UID taeki" against the socket UID; `user-edit`
   proves nothing, there is no key behind it.
2. **Access control would lose per-user granularity.** `access.cmd.usr.
   cube` grants are looked up by the primary name (`base.has_access`), so
   the grant would attach to `user-edit` — every user running that console
   shares one grant, and "taeki may, jane may not" becomes unexpressible.
   Sharper on a multi-user node than on a single-user one.
3. **It would conflict with `mpv[audio]`**, whereas the chosen order makes
   one rule cover both auth types.
4. **DECISIVE, per user: subnames are (meant to be) runtime-mutable, users
   are not.** Changing a session's user needs `devmod.cmd.switch-user` —
   devmod is development-only and normally disabled. So the volatile half
   of the identity belongs in the slot that can actually change.
   **Qualification found 2026-08-12, see the deferral section below: today
   that mutability is LOCAL ONLY.** The argument still holds — and the fix
   direction strengthens it — but do not assume a subname change is
   currently visible to routing.

**The grouping axis the inverse form was after** (enumerate all
`user-edit` consoles across users, rather than all of taeki's sessions) is
still obtainable without changing identity: index the subname
independently on the read side, e.g. a `list subnames :user-edit` form.
That is a read index, not an identity change, so authorization is
untouched. Do that if application-grouping ever matters, rather than
flipping the order.

## what already exists — do not rebuild

- `base.regex` : `subname`, `usr_subn`, `usr_subn_str`, MAX_SUBNAME=18
- `base.handler.command.route_to_target` : parses the inline form in a
  route path and strips `[subname]` off the target
- `cube.cmd.select`, `cube.cmd.idle-next`/`oldest-next`,
  `v7.zenka.cmd.stop` : already match instances by subname
- `list subnames <name>` : defined TWICE — session-keyed in base.init_code,
  instance-keyed in v7.init_code ; which you get depends on who answers
- `plugin.auth.zenka` + `plugin.auth.unix` : both accept the wire form
- `base.session.split_subname` / `base.session.set_subname` : the shared
  pair, extracted 2026-08-12 so the two plugins do not each carry a copy
- `base.session.check.close` : releases the per-user registration that
  `set_subname` creates — **the session write and the per-user counter must
  stay paired**, which is why `set_subname` is one module
- `v7.start <zenka>[<subname>]` : starts a named instance

## changing a subname is DELIBERATELY not implemented

Not an oversight to be tidied up — **per user 2026-08-12, subname change
synchronization was specifically left out, pending thinking through the
security implications and the round-trip complexity of doing it
correctly.** Treat the absence as a decision with open questions behind
it, not a gap to fill. Read the rest of this section before proposing to
build it.

**THREE** separate registries hold a subname, in three different
processes, and would need to agree. Per user: "both zenki need the data —
cube for routing and v7 for restarting." They are independently
load-bearing, not duplicates of each other.

1. **the zenka's own view** — `<system.zenka.subname>`, in ITS process.
   `base.cmd.subname` (a GETTER, there is no setter) reports this one.
2. **cube's ROUTING registry** — `$data{'session'}{$id}{'subname'}` plus
   the `$data{'user'}{$u}{'subname'}{$s}` counter, in CUBE's process,
   keyed per SESSION. This is what `base.handler.command.route_to_target`
   and `cube.cmd.select`/`idle-next`/`oldest-next`/`group-next` consult.
3. **v7's LIFECYCLE registry** — `<v7.zenka.instance>->{$iid}{'subname'}`,
   in V7's process, keyed per INSTANCE. Used by `v7.zenka.cmd.stop`,
   `v7.instance_count` (hence max_concurrency) and `v7.start
   <zenka>[<subname>]`.

`list subnames` is defined TWICE and resolves differently depending on
which zenka answers: `base.init_code:171` is session-keyed (column header
`session`), `v7.init_code:208` is keyed on `v7.zenka.instance` (header
`instance`). Same command name, different registry — do not read one and
conclude anything about the other.

**History, per user 2026-08-12 — and do not mis-read it:** what was added
late for convenience is the `list subnames` COMMAND in `base.init_code`,
not the underlying data. Only v7 had such a listing for a long time; cube
already held the subname per session (auth writes it, routing reads it),
so surfacing it cost nothing. **Cube's data is load-bearing for routing
and always was** — it is not a derived convenience copy of v7's, and the
two cannot be collapsed into one.

Cube's copy is written **only at auth time**, by `plugin.auth.zenka` /
`plugin.auth.unix` via `base.session.set_subname`. Verified 2026-08-12:
**there is no cube-side subname setter at all** — every cube module
mentioning subname (`select`, `idle-next`, `oldest-next`, `group-next`,
`routing_override.arm`) only reads or matches it.

So `mpv.cmd.change-subname`, the only mutator that exists, sets
`<system.zenka.subname>` and stops there. After calling it the getter
reports the new name while routing still uses the old one, until that
zenka reconnects and re-authenticates.

**What would have to be resolved FIRST — these are the reasons it was
deferred, not a checklist to work through mechanically:**

0. **Security.** A subname is the routing selector: whoever can change one
   can redirect where commands land, or make a session answer to a name
   another session previously held. So a change command needs its own
   authorization story — who may rename what, whether a rename can take
   over an existing subname, and whether a renamed session inherits
   anything addressed to the old name. Note the subname is deliberately
   OUTSIDE authorization today (it never reaches `base.has_access`); a
   careless change command is exactly how it would slip back in.
1. **Round-trip complexity.** Three processes must agree, and the change
   originates in the one that is neither of the two registries that
   matter. Decide what happens if cube accepts and v7 does not, or if the
   zenka dies mid-rename — i.e. whether this is best-effort or needs to be
   atomic, and what a partial result looks like.
2. decide which registry is AUTHORITATIVE — everything below depends on
   it, and it is a real decision rather than an obvious default.
3. a cube-side setter that re-registers the session: decrement the old
   per-user counter, increment the new — i.e. the inverse-plus-forward of
   `base.session.set_subname` / `base.session.check.close`, which is why
   it belongs beside them.
4. a v7-side equivalent for `<v7.zenka.instance>`, or v7 must be told to
   re-read. Skipping this desynchronises `v7.zenka.cmd.stop` and
   `v7.instance_count` — so max_concurrency could miscount and a stop
   command could target the wrong instance.
5. a generic `base.cmd.change-subname` that sets the local view and drives
   (2) and (3), leaving zenka-specific side effects (mpv's playlist
   reload) to a hook — `mpv.cmd.change-subname` then shrinks to that hook,
   the same consolidation the split/set pair just went through.
6. decide whether a change may collide with an existing subname under the
   same user, and what happens to in-flight routes addressed to the old
   name.

**Config-file caveat:** `[subname]` cannot be written literally into a
zenka `start` file — `[...]` there is command-invocation syntax. Build the
`<user>[<subname>]` string in the zenka's `init_code` and reference that
key from `system.auth-user` instead (see `user-edit.init_code`'s
`<user-edit.auth_name>`).

Landed in `d0848477b`; live-verified both paths — `mpv[audio]` (pre-existing
zenka auth, unaffected by the refactor) and `taeki[user-edit]` addressed via
`p7c 'taeki[user-edit].char-add'`, with the subname released on exit.

#,,,.,.,.,,.,,,.,,...,,.,,..,,..,,..,,,.,,.,.,..,,...,...,,.,,..,,,.,,..,,...,
#IOWDTJGMEM6FXELT2ENCGDCH4J7VZLC3A6GVD47TK2M7CJY6CCJKKMEHXDGV62S75EK4AONKG3YCA
#\\\|K573JP5FSMABDBKNMRPC6N6WONZSYF6CFSF2QVNKUF5MF54VBLP \ / AMOS7 \ YOURUM ::
#\[7]IQFXCW6OLRTQSDFYWL2UHVN3VP6OTDEGQDJE66E5YRDUGWZ4VECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
