---
name: cube.cmd.* modules receive call_args with 'session_id', not 'sid'
description: cube.cmd handlers are invoked with $call_args — session key is session_id; reading $param->{'sid'} silently produces undef and FALSE returns
type: feedback
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
cube.cmd.* modules are invoked at base.handler.command:1290 as:

    $code{ <base.cmd>->{$cmd} }->( $call_args )

`$call_args` is built at base.handler.command:376-378 with keys:

    command_id, session_id, args, reply_id, cmd (+ unalias)

It does **not** have `sid` or `args_list` keys.

## the trap

Several cube.cmd.* modules were written assuming `sid` / `args_list`:

- `cube.cmd.set-capability`           — had `$param->{'sid'}`            [ fixed 2026-04-18 ]
- `cube.cmd.declare-strm-size-timeout` — had `$param->{'sid'}` + `args_list` [ fixed 2026-04-18 ]

Both failures silent: `$sid` becomes undef → callee returns FALSE due to
`exists $data{'session'}{undef}` being false → caller translates to
`FALSE capability update failed`. No log at default verbosity. Looks like
the capability handler rejected the value even though it was never reached.

## how to apply

- When writing a new cube.cmd.* module: read `$call_args->{'session_id'}`
  and `$call_args->{'args'}`. Do **not** use `sid` / `args_list`.
- Cross-check with cube.cmd.select which uses `$ARG[0]->{'session_id'}` and
  cube.cmd.select-strm-mode which uses `$call->{'session_id'}` — those are
  the correct shapes.
- When a capability / set-capability dispatch mysteriously returns FALSE
  with no cap-neg log line: check the param-key names in the cube.cmd
  wrapper before suspecting the cap-neg handler itself.

## related: auth response ordering for test clients

A client doing `select unix\nauth unix-$user\n` receives **two** reply
lines: `TRUE continue` (for select) and `AUTH_TRUE =)` (for auth).
Consuming only one before sending the next command leaves an orphan line
in the stream and aliases every subsequent response to the wrong send.
Read one line per command, not a loop that bails on the first TRUE.

#,,.,,,,.,,..,,..,,.,,.,.,.,.,.,.,,..,..,,.,,,..,,...,...,,.,,,,,,,..,...,,,,,
#4CG7T6PQDZRDNZR5HXLJFLMKNJJMNXN42KHYG3R3NUKJMVMC34Q3NL3QYFUYQS3U52OUEJ6ZV2YM6
#\\\|NR2IKFLVYEPQCLB4VHD327HEUYOL2LCNWOPLWBEBFM6SWPFBIVR \ / AMOS7 \ YOURUM ::
#\[7]L2ME4DN7KYMYD7LUUV5O7OXSY4MDHVP2K3OZDA4H62SFW5EUNIBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
