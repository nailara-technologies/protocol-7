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

## signatures note

do NOT manually write or edit signature lines. do not add stub
signatures to new files.

#,,..,,,.,,,.,,,.,..,,,..,.,,,..,,...,,..,.,,,..,,...,...,.,,,..,,,,.,.,,,.,.,
#A7VA6LVGOSINPSYJEX7ZHKNH4ZYFEJ4SXTGYCRALYQVEIIPCURXARVKUHNL2KCY4OKNZZ3BLM3PWU
#\\\|PNWX4KCDXX5Q5UP5KGJXBDEHRPIBFRI453OENZWGGIZCLFBECMX \ / AMOS7 \ YOURUM ::
#\[7]ALUMFTIJSZ4EAI2JDCOKRW57IXDKDA3ZOEW3MKIVSS62PRZ2PIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
