# task: wire calc zenka into stdio multiplex emitter

## relation

follow-up to `data/tasks/completed/zenka-side-stdio-multiplex-emitter.md`
[ landed: `base.stdio_multiplex.connect`, `.emit_eout`, `.emit_str`,
`.emit_num` ]. that task's non-goals explicitly deferred "wiring an
existing zenka's actual stdout into emit_eout" as a separate follow-up
— this is that follow-up, using `calc` as the first real adopter so the
new emitter modules become exercised, functional code instead of
unused helpers.

## the gap

- nothing currently calls `<[base.stdio_multiplex.connect]>` for any
  zenka, so the connect/emit chain is dead code.
- `calc` is a small on-demand zenka with one command
  [ `calc.cmd.val`, in `src/calc.cmd.val` ] that computes a
  result string and a numeric value — a natural minimal case for
  `emit_eout` [ result text ] and `emit_num` [ result value ].

## scope

### opt in to multiplex [ `cfg/zenki/calc/start.cfg` ]

- add `stdio.multiplex = yes` as a top-level config line [ same level
  as `start.on-demand = 1`, `restart.disabled = 1`,
  `heartbeat.disabled = 1` ] — this is the line both v7's
  `v7.handler.stdio_multiplex_listen` [ via
  `<v7.start_setup.zenki.config>->{calc}{stdio}{multiplex}` ] and
  calc's own `<[base.cfg_bool]>->(<stdio.multiplex>)` check [ in
  `base.stdio_multiplex.connect` ] need to see.
- add `[base.stdio_multiplex.connect]` to the `: zenka-init :` block,
  alongside the existing `[base.auth.set_zenka_key:...]` and
  `[base.zenki.set_ondemand_timeout:4200]` calls. `connect` defers
  itself via `system.callbacks.initialized` if called too early, so
  call-order relative to those two is not critical.

## wire `calc.cmd.val`

in `src/calc.cmd.val`, after `$value_str` is computed
[ around line 30, right after the "calculation not successful" guard ]:

- call `<[base.stdio_multiplex.emit_num]>->('value', $value_str)`.
- for the formatted [ non-`$plain_value` ] path, after `$result_str`
  is built [ around line 42 ], call
  `<[base.stdio_multiplex.emit_eout]>->(1, \"$result_str\n")` —
  same string that goes to the session buffer via
  `base.buffer.add_line`, just also emitted as EOUT fd 1.

both calls are no-ops if calc isn't connected [ per the emitter
modules' existing connected-check ], so this is safe even before the
config change lands.

## non-goals

- no wiring of any other zenka.
- no automatic/global stdout-filehandle redirection — this remains
  two explicit `emit_*` calls at the one place calc produces output.
- no changes to `base.stdio_multiplex.connect`/`.emit_eout`/
  `.emit_num`/`.emit_str` themselves.

## acceptance criteria

- `p7c v7.restart calc` [ or natural on-demand start via `calc.val` ]
  followed by v7 log line: "stdio multiplex listener opened for calc".
- `p7c calc.val 2+2` results in v7's `<calc>.stdout` slot content
  containing the formatted result string [ `____ 4 ___ [...]` ].
- `<calc>.stdout.metric.value` reflects `4` after that call.
- `p7c calc.val plain 2+2` [ plain-value path ] still works normally
  and updates `<calc>.stdout.metric.value` to `4` without erroring,
  even though no `emit_eout` fires for that path.

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists. lowercase comments, `[ word ]` annotations,
`$ARG` not `$_`, one-sub-per-file [ no inline `sub {}` helpers ].

#,,,,,,,,,,..,.,,,,.,,..,,.,,,,.,,,.,,...,..,,.,.,...,...,...,..,,,,,,,,,,..,,
#MCO6GUYCFUAT2AUX4UHRYRNJQX44RBPK6DB2TKOSTMP6OMMDPJJICIFXVGO5GMCKPQMZVZEGPSQY6
#\\\|S256IGCUHHEEYAO4RR7RMWEBYVLGEQZLJABSMBY7DPMMXQKMQRL \ / AMOS7 \ YOURUM ::
#\[7]3OAJYDQX7NACM4SHU3GTT3GGVU7K6F453CAOTZY7K2GJYHDBYUCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
