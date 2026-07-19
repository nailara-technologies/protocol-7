# security: subscribe-as-callback-command is a reflection vector

## found 2026-07-18, during cred-mesh-rotation-subscription-cross-zenka.md

not a direct bug in the current cred-mesh code (nothing exploits it today),
but a general design vulnerability the project already has a convention
against — flagging for deliberate triage, not urgent, not blocking other
work.

## the vulnerability

`cred-mesh.subscribe_rotation` (`modules/cred-mesh.subscribe_rotation`)
takes a caller-supplied `handler` string and stores it verbatim:

```perl
my $handler = $params->{'handler'} // '';
...
push $subs->@*, $handler;
```

`cred-mesh.handler.rotation_strm` (`modules/cred-mesh.handler.rotation_strm`)
later fires that stored string directly as a `route-send` command target:

```perl
foreach my $handler (@combined) {
    <[protocol-7.route-send]>->(
        {   'command'   => $handler,
            'call_args' => { 'args' => $event_b32 },
        }
    );
}
```

`route-send` executes with **cred-mesh's own** outbound identity/
permissions — not the original subscriber's. So any zenka with access to
`cred-mesh.subscribe_rotation` (currently `proxy` and `transport`, per
`configuration/zenki/cube/access.zenki`) could subscribe with
`handler => 'system.host-poweroff'` (or any other command cred-mesh's own
zenka identity happens to be authorized for) instead of a legitimate
`zenka.cred-rotated`-shaped callback, and get it invoked for free on the
next credential rotation. Classic confused-deputy / reflection: the
subscriber controls *what* gets called, but the relay (cred-mesh) supplies
the *permission* to call it.

**This is very likely what caused the "self-referential permission check"
mystery** documented and now resolved in
`cred-mesh-rotation-subscription-cross-zenka.md` — a stored `handler`
value of `cred-mesh.subscribe_rotation` itself, almost certainly from an
earlier manual `eval-code` test, got fired back at cred-mesh on the next
rotation. Harmless in that instance only because cube correctly had no
grant for cred-mesh to call that command on itself — a *different* stored
value could have been genuinely dangerous.

## why this matters generally, not just for cred-mesh

this is exactly the vector the project's STRM-subscription convention
exists to avoid: a subscriber should declare a pre-registered, validated
channel identity, never hand the publisher an arbitrary command string to
execute with the publisher's own authority. any other `subscribe_*`-shaped
API in this codebase that stores a caller-supplied string and later fires
it as a `route-send`/`command` target has the same class of exposure —
worth an audit, not just a cred-mesh-specific patch.

## suggested direction (not yet designed)

the project already has an established safe pattern for exactly this
shape of problem — a variable list of targets to notify, without letting
any of them dictate what gets executed. see
`modules/content.cmd.update` / `modules/content.update.send_notifications`
/ `modules/rss.ticker.send_update`:

- `<update.notify_zenki>` (which zenki to notify) is variable, even
  dynamically configurable
- `<update.notify_command>` (what to call on each of them, e.g. hardcoded
  default `'playlist-update'`) is **fixed** — sourced from local
  configuration, never taken verbatim from a remote caller's request
- the command sent is always `"cube.$target_zenka.$fixed_suffix"` — the
  suffix never varies per-caller

`cred-mesh.subscribe_rotation` violates this by letting the remote caller
supply *both* the target identity and the command suffix in one
unvalidated string. The fix should bring it in line with the existing
pattern rather than invent a new scheme:

- keep the subscriber *list* variable (that's the whole point — different
  zenki subscribe at different times), but stop trusting the caller-
  supplied `handler` string as the literal command to fire
- derive the command suffix from a small fixed/known set (e.g. always
  literally `cred-rotated`, matching the existing `proxy.cred-rotated`/
  `transport.cred-rotated` convention already in use), and derive the
  *target zenka name* from the authenticated source of the subscribe
  request itself (whatever cube/`base.handler.command` already knows the
  caller's zenka identity to be), not from a string the caller typed into
  the `handler` argument
- concretely: store `$src_zenka_name` (from the request's own routing
  metadata, not `$params->{'handler'}`) in `rotation_subscribers`, and at
  notify time construct `"$src_zenka_name.cred-rotated"` the same way
  `content.update.send_notifications` constructs
  `"cube.$ARG.$update_cmd"` — variable target, fixed suffix
- longer term, fold this into whatever generic STRM subscribe-wrapper
  infrastructure comes out of `strm-generic-subscribe-wrapper.md` — this
  variable-target/fixed-suffix shape belongs at that shared layer so every
  future STRM subscription gets it for free, not reimplemented per
  subscriber type

## dispatch scope (2026-07-19)

ready to dispatch as a narrow, cred-mesh-only fix — not the wider
`subscribe_*`-shaped audit (that's a real follow-up, but a separate task
once this pattern is proven here first). the two current subscribers are
`proxy.handler.subscribe_rotation_deferred` and
`transport.handler.subscribe_rotation_deferred`
(`configuration/zenki/cube/access.zenki` grants both `cred-mesh` access) —
both call `cred-mesh.subscribe_rotation` with
`handler => "$self.cred-rotated"`-shaped strings today, so the fixed
`cred-rotated` suffix this doc proposes matches their existing behavior
exactly; nothing about their call site needs to change, only
`cred-mesh.subscribe_rotation`/`cred-mesh.handler.rotation_strm`
(`modules/cred-mesh.subscribe_rotation`,
`modules/cred-mesh.handler.rotation_strm` — read both in full, they're
short) and whatever test coverage exists for
`cred-mesh-rotation-subscription-cross-zenka.md`'s three earlier bug fixes
(don't regress those).

**Caller-identity mechanism — confirmed, not an open question.** cube can
de-anonymize the caller's zenka name (and, separately, its session id) for
specific commands via `configuration/zenki/cube/command_aliases`:
`setup.aliases.source_zenka` (name only) / `setup.aliases.source_zenka_sid`
(name + sid) list commands that get the caller's authenticated identity
prepended as leading space-separated token(s) of `$call->{'args'}` before
the module runs — the module itself never supplies or controls this
prefix, cube does. Confirmed precedent, same security shape as this fix:
`modules/credentials.cmd.request_session` (listed under `source_zenka`) —
its own comment says it outright: `## SOURCE_ZENKA alias prepends the
caller's identity as the first token ##`, then
`my ($zenka_name, $cred_name) = split(m|\s+|, $args, 2)`. Other consumers:
`modules/tile.cmd.get_geometry`, `modules/v7.zenka.cmd.restart_own-zenka`
(uses the `_sid` variant: `split(m| |, $call->{'args'}, 3)` → zenka + sid
+ rest).

The routed command is **`cred-mesh.cmd.subscribe_rotation`**
(`modules/cred-mesh.cmd.subscribe_rotation`) — not
`cred-mesh.subscribe_rotation` itself, which is an internal function that
thin wrapper calls with a `{slot, handler}` hashref after parsing
`$call->{'args'}` as `"<slot> <handler>"`. It is **not currently listed**
in `command_aliases`. The fix is concretely:

1. add `cred-mesh.cmd.subscribe_rotation` to `setup.aliases.source_zenka`
   in `configuration/zenki/cube/command_aliases` (name only needed, not
   `_sid` — nothing here needs the session id, only the zenka identity)
2. in `cred-mesh.cmd.subscribe_rotation`, parse the now-3-token args as
   `<source_zenka> <slot> <handler>` (mirror
   `credentials.cmd.request_session`'s parse shape) — keep receiving
   `handler` for backward compatibility/logging if useful, but no longer
   trust it as the thing that gets fired later
3. change `cred-mesh.subscribe_rotation`'s contract from
   `{slot, handler}` to `{slot, source_zenka}` (or keep `handler` as a
   deprecated/ignored param, implementer's call), storing
   `$source_zenka` in `rotation_subscribers` instead of the caller-
   supplied string
4. in `cred-mesh.handler.rotation_strm`, construct the fired command as
   `"$source_zenka.cred-rotated"` (fixed suffix) at notify time, rather
   than firing the stored string directly — matches the
   `content.update.send_notifications` variable-target/fixed-suffix shape
   the original doc pointed at, now with a verified-not-guessed source

verify live (not just by reading) that the alias actually prepends the
token in the shape assumed here — the existing subscribers
(`proxy.handler.subscribe_rotation_deferred`,
`transport.handler.subscribe_rotation_deferred`) will need their
`route-send` call sites re-tested end to end after this change, since
their `args` string shape changes from cube's alias injection.

## follow-up, not in scope here

`strm-generic-subscribe-wrapper.md` (filed the same session) designs the
generic offline-safe/restart-clean subscription wrapper this fix's
variable-target/fixed-suffix pattern should eventually be folded into.
That doc's own scope note already says retrofitting cred-mesh onto it
later is a cleanup, not a prerequisite for this fix — the two are
independent and can be dispatched in either order or in parallel.

## signatures note

do NOT manually write or edit signature lines. do not add stub
signatures to new files.

#,,.,,.,,,.,.,...,.,,,,,,,.,.,...,.,,,,,.,.,.,..,,...,...,..,,,,,,...,,..,,.,,
#3S6XJIXK6A775GHE3HXAMFTJEGKLSR6Y7GD4WU6ABDWZCWYAPH6HBNKF3OSWIRQK2JWE76NOMB2KC
#\\\|LJ4CZBC4GVUV4IRK5MOGERCK54T6BC52JBFSTPN63KG4MOCO6HE \ / AMOS7 \ YOURUM ::
#\[7]KXSVNV75BDEUHNVKOKGQISANTJSFLVPK5EGKZXUUXIXJYX6HFSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
