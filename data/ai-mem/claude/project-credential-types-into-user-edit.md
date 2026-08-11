---
name: project-credential-types-into-user-edit
description: "2026-08-12 user direction: transfer real credential types (external sites, android app accounts, host passwords) into protocol-7 via the user-edit/users mechanisms as they're built -- makes editor.control's 'masked' field type load-bearing, and needs credentials.cmd.add's closed type whitelist extended"
metadata:
  type: project
---

**Per user, 2026-08-12** (stated while approving user-edit phase 3
slice 2): they want to use the mechanisms being built here early rather
than after the fact, and specifically to "soon transfer different
credential types into the existing protocol-7 system" — named cases:

1. **external sites** — already covered by the `web-session` type
2. **android application accounts** — NO existing type
3. **host passwords** — NO existing type (`ssh-key` is a key, not a
   password)

## what already exists — do NOT rebuild

Two mature zenki, both real, neither a stub:

- **`credentials`** — `cmd.add` / `cmd.list` / `cmd.authorize` /
  `cmd.request_session`, `load`/`save`, `read_archive`/
  `write_archive_file`, `pack_format.archive`/`unpack_format.
  archive_payload`, `spawn_web_session`, `audit`, plus
  `handler.session_cleanup`. Encrypted at rest via the archive format.
  Per-credential authorized-zenki list.
- **`cred-mesh`** — `cmd.resolve`/`approve`/`rotate`/`list-slots`/
  `subscribe_rotation`/`ui-show`, `encrypt`/`decrypt`,
  `key_holder.parent`/`.child`, `handler.rotation_strm`/
  `auth-relay-reply`/`route_reply`, `register`. See
  [[topic-credential-fabric-proxy-transport]].
- `modules/credential.resolve` (singular) also exists, separate from
  both.

## concrete blocker found 2026-08-12

`credentials.cmd.add` validates against a **closed type whitelist**:

```perl
my %valid_types
    = map { $ARG => 1 } qw| web-session api-key smtp imap ssh-key |;
```

so 2 of the 3 named cases are rejected outright today. Extending this
list is the smallest concrete first step — but check first whether the
type string is merely validated or also drives storage/handling
behaviour downstream (`credentials.load`/`save`,
`spawn_web_session`, cred-mesh slot shape), since a new type may need
more than a whitelist entry.

## why this lands on user-edit

`credentials.cmd.add` currently collects the secret with a **blocking**
`AMOS7::TERM::read_password_single` terminal prompt. That is precisely
what user-edit's form is meant to replace: an event-driven console where
keyboard input and network replies share one loop.

This makes `editor.control.*`'s **`masked` field type load-bearing** —
it is currently interface-only, `editor.control.create` hard-rejects
every type except `freeform_line`:

```perl
return undef if $type ne qw| freeform_line |;    ## only type implemented
```

JUE's `field_types_needed` blocker asked exactly the right question
("check at design time whether any target setting is enum- or
secret-shaped") and the answer is now YES, secret-shaped, via this
direction. **How to apply:** build phase 3's input loop so a masked
field is an additive change — the render side must take the display
string from a per-field accessor rather than assuming
`editor.control.get_value` is what gets drawn, or masking means
rewriting `render_form`/`render_field` rather than extending them.

Also reconcile, not yet examined: `cred-mesh.cmd.ui-show` is an
EXISTING credential UI with live nshell integration (`nshell.shell_loop`
tracks `cred-mesh_ui_active`/`_pending`/`_session` state for it). Decide
whether user-edit's form subsumes it, renders it, or stays separate
before building a second credential UI in parallel.

## the concrete first target — a not-yet-installed host

Also per user, same conversation: a **still-uninstalled host is waiting
to become a protocol-7 desktop**, and both its `taeki` AND `root`
accounts need to be p7-managed. This is almost certainly the same
machine already recorded in `users-zenka.yaml`'s v7-managed-lifecycle
note — the currently-uninstalled fanless desktop node (16GB RAM, 1TB
SSD) named there as the concrete case for an always-on `users` zenka
override rather than the on-demand default.

That makes it the first real end-to-end exercise of this whole stack,
not a hypothetical: a fresh node whose two host accounts are created and
managed through `users` + `credentials` from the start, rather than
being adopted after a manual install. Notable consequences to think
through before it happens:

- **`root` is a managed account too** — host-password credentials for a
  privileged account, so the authorized-zenki list and cred-mesh slot
  model matter more here than for an ordinary user record.
- bootstrapping order: the node needs enough of protocol-7 running to
  reach `users`/`credentials` before those accounts exist, so decide
  what is seeded at install time vs. what is set through user-edit
  afterwards.
- this is the node that would carry the always-on `users` override
  (unset `start.on-demand` in its own `zenka-startup.v7`, or list it in
  that node's `start-set-up.base`) — already supported by the existing
  v7 lifecycle mechanism, no new code.
- it is also the natural first real test of `users.remote-get`/
  `remote-fetch` against a genuinely separate peer rather than the
  loopback self-test that landed in e4185e78b — see
  [[project-users-zenka-unblocks-cross-host-testing]].

Unresolved and deliberately open: whether credential records live in
`users` zenka's `host-system/` payload at all, or stay entirely in
`credentials`/`cred-mesh` with user-edit only acting as their editing
front-end. The latter looks far more likely given the encryption-at-rest
and rotation machinery already in place — do not move secrets into
`host-system/` YAML without deciding this explicitly.

#,,,.,...,..,,,,,,,.,,,,,,,,,,.,,,..,,..,,,.,,..,,...,...,..,,..,,.,.,,,,,,.,,
#E5Z77G7BZXNQ6CYQSMRFEUEHJWY67G35RT3ZI4JOALRRNMNJLCAY23ZTLFY7QTCJFK5HQIAZYRH32
#\\\|H3Z4PB6LRFQZ4U33WCXHXP6WYRSUDJXHP5DZLOB4CTHU6CSWX4B \ / AMOS7 \ YOURUM ::
#\[7]5OYBUE6G3V6Y3QI45KCENWVNZ3VEYJ567MUSO6XLGLHDM7GOGSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
