# task: split base.handler.command into reply-dispatch + routing modules

## relation

`base.handler.command` (2319 lines) is the central protocol-7 command/
reply handler, called from every zenka's main input handler. it has
grown far past the size of any sibling module and is now hard to
review or extend. this task extracts its two largest, most
self-contained branches into sibling modules, similar in spirit to the
inline-helper-sub extraction series (`be9dc7f39`, `dc027b0c7`).

found via reading the full file (2319 lines) directly.

## the gap

two branches of the main `if/elsif` chain account for ~1300 of the
2319 lines and are reasonably self-contained in terms of the variables
they touch:

### branch A — reply-type dispatch [ lines ~602-1584, ~980 lines ]

handles incoming replies of type `TRUE|FALSE|WAIT|SIZE|CHRSIZE|STRM|
STRM-SIZE|GET|TERM` when `$cmd =~ m,^(TRUE|FALSE|WAIT|SIZE|CHRSIZE|STRM
|STRM-SIZE|GET|TERM)$,`. covers routed-reply forwarding, SIZE/CHRSIZE
chunk extraction, STRM/STRM-SIZE streaming state machines, and the
`unknown-reply-route` / `unknown-reply-type` hook points (with goto
labels `UNKNOWN_ROUTE_HANDLED` / `UNKNOWN_TYPE_HANDLED`, both internal
to this branch).

reads/writes: `$session`, `$route` (`$data{'route'}`), `$cmd`,
`$cmd_id`, `$s_cmd_id`, `$call_args`, `$input`, `$output`,
`$buffer_length`, `$user`, `$id`, `$refusal_type`.

### branch B — outbound routing to other zenki/users [ lines ~1957-
2270, ~330 lines ]

handles the `elsif` branches for absolute-path notation (`^host.cmd`,
not implemented), parent-branch tree-up (`..host.cmd`, not
implemented), and the main target-sid resolution + group-mode send:
sid/user/subname target resolution, ondemand-zenka queueing via
`<zenki.virtual>`, route setup via `<[base.route.add]>`, cmd logging,
and dispatching the command line to each target session's output
buffer. contains goto label `UNKNOWN_CMD_HANDLED` (defined just after
this branch, at line ~1931 — confirm whether it belongs to branch B or
the local-command branch above it when extracting).

reads/writes: `$cmd`, `$cmd_id`, `$id`, `$user`, `$call_args`,
`$command_mode`, `$args_orig`, `$re`, `$refusal_type`,
`$data{'session'}`, `<zenki.virtual>`.

## scope

create 2 new sibling modules:

- `src/base.handler.command.process_reply`
  - body = branch A, lifted into its own module.
  - called from `base.handler.command` via `<[...]>->()`, passed
    whatever subset of `$event`, `$session`, `$id`, `$user`, `$cmd`,
    `$cmd_id`, `$s_cmd_id`, `$call_args`, `$input`, `$output`,
    `$buffer_length`, `$re`, `$refusal_type` it needs — design the
    call signature for clarity, not minimal diff.
  - must preserve the exact `return 0/1` semantics back to
    `base.handler.command`'s caller (the event-loop watcher protocol:
    0 = command complete, 1 = command not complete). if the extracted
    module can't itself `return` to the *outer* caller, have it return
    a sentinel/result that `base.handler.command` translates into the
    correct `return`.
  - the `UNKNOWN_ROUTE_HANDLED` / `UNKNOWN_TYPE_HANDLED` goto labels
    are entirely internal to branch A — fine to keep as labels inside
    the new module, or replace with structured control flow
    (if/elsif/last) if that reads more cleanly — your call.

- `src/base.handler.command.route_to_target`
  - body = branch B, lifted into its own module.
  - same call-signature design freedom as above; same `return 0`
    semantics to preserve (branch B's paths all `return 0` —
    "comand complete" — except the two not-yet-implemented branches
    which fall through without returning; preserve that fallthrough
    behavior or make it explicit, your call).

`base.handler.command` itself shrinks to: parsing/setup (current
lines ~1-600), local-command dispatch (current ~1586-1934), the two
new `<[...]>->()` calls replacing branches A and B, and the tail
(~2272-2319).

## style latitude [ explicitly granted ]

this is not a pure mechanical extraction. while moving the code:

- apply protocol-7 style conventions from
  `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md` and
  `data/yaml/code-style/CONVENTIONS.yaml` (lowercase comments,
  `[ word ]` annotations not `( word )`, `##[ SECTION ]##` dividers).
- dedupe the repeated ~10-line "delete route" sequence that appears
  4+ times verbatim within branch A (after SIZE, CHRSIZE, STRM close,
  STRM-SIZE close) — factor into a small helper sub-module if that's
  cleaner, e.g. `base.handler.command.delete_route`.
- tighten the near-duplicate SIZE vs CHRSIZE reply-processing blocks
  in branch A if a clean shared helper falls out naturally — but don't
  force it if the divergence (byte vs character counting) makes a
  shared helper awkward/unclear.
- general readability cleanup of the moved code is welcome — clearer
  variable names, removing dead/commented-out code, etc. — as long as
  behavior is unchanged and the protocol-level `return` semantics
  documented above are preserved exactly.

## non-goals

- do NOT touch sections 1-3 (parsing/setup, lines ~1-600), the
  local-command dispatch (~1586-1934), or the tail (~2272-2319) beyond
  the minimal edits needed to call the two new modules and to define
  `UNKNOWN_CMD_HANDLED` correctly if its scope changes.
- do not change the multi-line / single-line command parsing protocol,
  the alias/reroute logic, or the `!TERM!` backchannel handling.
- do not change wire-protocol behavior in any way — same bytes in,
  same bytes out, for every code path.

## registration

after the new modules are created:
- add `base.handler.command.process_reply` and
  `base.handler.command.route_to_target` (and
  `base.handler.command.delete_route` if created) to
  `src/base.list.subroutines`, near the existing
  `base.handler.command` entry (~line 1175).
- update `data/md/documentation/module-dependency-graph.asc`:
  - extend the `base.handler.command : ...` deps line (~line 899) to
    include the new module names.
  - add dep lines for the new modules themselves, listing whichever of
    `base.logs`, `base.logt`, `base.sprint_t`, `base.stream.*`,
    `base.route.add`, `base.has_access`, `base.handler.hooks*`,
    `base.zenki.ondemand_registered`, `base.protocol-7.command.send.local`,
    `base.format.multiline_command`, `base.callback.reset_strm_size_timer`,
    `base.cnt_s`, `base.gen_id`, `base.cfg_bool`,
    `base.session.shutdown` etc. each module actually calls.

## acceptance criteria

- `base.handler.command` and both new modules pass `perl -c` /
  syntax check.
- `base.handler.command` is reduced to roughly 1000-1100 lines.
- whichever zenka loads `base.handler.command` (check
  `cfg/zenki/*/start` for it in `modules.load` — it's
  loaded essentially everywhere) reloads with no load errors via
  `p7c <zenka>.reload`.
- manual smoke test: a simple single-line command round trip (e.g.
  `p7c <zenka>.heart` or similar) still gets a `TRUE`/reply response
  end to end, confirming branch A (reply dispatch) and branch B
  (routing) both still work.

## signatures note

no `#,,..` stub. do NOT run update-signatures unless asked. lowercase
comments, `[ word ]` annotations, `$ARG` not `$_` for new code,
one-sub-per-file for any new helper modules. keep `# descr =` lines
under 55 chars.

#,,.,,.,,,,,,,.,.,.,,,.,,,.,,,,,.,,,,,.,.,.,.,.,.,...,...,...,,.,,,,.,,.,,,,,,

#,,,.,,,,,,,.,,..,,..,.,.,,.,,,,,,,,.,..,,.,.,..,,...,...,,.,,..,,,..,...,,,,,
#ZITROINMTHKPE4IKNJCITLDVL2ISE7ALUZBZ3MNND6FPNER6GSTJOWRWJTIUSRKMVCCAPPCQSKFF2
#\\\|OUVQ72HMDSEW2PVVHTVXWL7CLVMHX36WVUSINLHWLO4J4CHPBCW \ / AMOS7 \ YOURUM ::
#\[7]H7KYAPIHMHLHFJODMRCMC5AQAZ4N6M3C47ZLTENTX7RQDYPFC2BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
