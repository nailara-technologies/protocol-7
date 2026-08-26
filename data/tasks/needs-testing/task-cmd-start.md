## task: task.cmd.start

Create module `src/task.cmd.start` — transitions a pending task to in_progress.

### context

Task zenka uses a queue at `<task.queue>` (a hashref keyed by 7-char uppercase IDs).
Status flow: pending → claimed → in_progress → done/failed.

`task.cmd.claim` sets status=claimed and records agent.
`task.cmd.start` is the next step: claimed → in_progress, recording started_at timestamp.

Use `<[base.ntime.b32]>` for timestamps (already used in claim/complete).

### reference modules

- `src/task.cmd.claim` — param parsing pattern, status guard, timestamp update
- `src/task.cmd.complete` — same param style with id + optional result

### spec

**params** (same two-path parsing as claim/complete):
- `id` — 7-char task ID (uppercase, truncated)
- no other params needed

**logic**:
1. parse id from param hash or args string
2. truncate/uppercase to 7 chars
3. return false if id missing
4. look up task in `<task.queue>`
5. return false if not found
6. guard: only claimed tasks can be started (status must eq 'claimed')
7. set `status = 'in_progress'`
8. set `started_at = <[base.ntime.b32]>`
9. set `updated_at = <[base.ntime.b32]>`
10. log: `task <id> started`
11. return `{ mode => 'true', data => "task <id> started" }`

### style notes

- lowercase comments
- no inline subs
- follow exact style of task.cmd.claim (copy structure, adapt content)
- do NOT add the `#,,.,,,...` stub — leave file clean for signing

### signatures note

Do NOT copy or invent AMOS7 signatures. Leave the new file without any signature
footer — `bin/Protocol-7 sourcecode update-signatures` will add the real footer.
The fake single-line stub `#,,.,,,...` blocks signing — never add it.

#,,,.,,,,,,,,,..,,..,,,..,,.,,,,,,.,,,.,.,,,.,..,,...,...,...,,..,,,.,,..,.,,,
#4DBT34LXNZ6H5V5NRHMGVZB637HVHSZ2ZH6MPMLYQZXRC5RUDZBFFMD7BRWMTP3YGCFPH4M2ZJA5W
#\\\|NLCOBIFG3YCPLL3CBZX4XO6LRBCZBCOEPMEACRDL5DEA3NU7DYR \ / AMOS7 \ YOURUM ::
#\[7]JV353JF4JMJAYC3CVCGVRWN3T6LMCWIDYCIGOT4IP2TQIYY57WCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
