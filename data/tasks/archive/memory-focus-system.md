## task: memory-focus-system

## dispatch
implement the `memory.focus.*` namespace — the attention vector that steers what
the tree surfaces: `set`, `boost`, `decay`, `apply`, `matches`. read first:
`data/md/design/MEMORY-TREE-SYSTEM.md` section D; the timer-module-args feedback
(timer body gets event as `$ARG[0]`, guard with `@ARG > 1`; timers need
after + interval + repeat:TRUE); the cross-zenka + access-control feedback
(`cube/access.zenki` is the real gate). the focus vector lives at
`<memory.focus>` as `{ topic => boost_factor }`. depends on nothing structural —
`memory.tree.score` consumes it but this namespace stands alone.

## prompt
implement the focus vector system. state at `<memory.focus>` (hashref
`topic => boost`). module headers `## [:< ##`, `# name = memory.focus.X`,
`# descr =` lowercase under 55 chars. lowercase narrative comments, `[ word ]`
annotations, NO manual signature stubs.

1. `memory.focus.set` — args `topic boost` (explicit args via `@_ ? shift : $ARG`
   convention). set `<memory.focus>->{$topic} = $boost` as a persistent boost
   (does not decay below this floor — store the floor separately, e.g.
   `<memory.focus.floor>->{$topic}`).

2. `memory.focus.boost` — args `topic [boost]` (default a moderate spike, e.g.
   2.0). multiply/raise the topic's current boost as a TEMPORARY spike that
   decay will erode back toward its floor (or 1.0 if no floor).

3. `memory.focus.decay` — timer body. it is a timer module, so the event arrives
   as `$ARG[0]`; guard any real-arg path with `@ARG > 1`. multiply every topic's
   boost toward its floor (or 1.0) by `<memory.cfg.focus_decay>` (default 0.85):
   `boost = floor + (boost - floor) * rate`. drop topics that have decayed to
   within epsilon of 1.0 and have no floor. register this timer in init with
   after + interval + repeat:TRUE.

4. `memory.focus.apply` — fold current activity into the vector so it reflects
   *now*: read the active task name (via the task zenka / `task.show` route or a
   local hint) and add a strong boost; read the last K p7c command namespaces
   routed through this zenka and add low ambient boosts. called at render time.
   enforce a per-source contribution cap (max boost added per topic per apply)
   to prevent any single chatty source from pinning the vector.

5. `memory.focus.matches` — args `node topic`. predicate: TRUE if the node's
   title/body/source_ref contains the topic token (case-insensitive). this is
   the hook pass-2 scoring uses; when the index integration lands it will also
   consult `index.cmd.lookup`, but for now substring match is the contract.

rate-limiting / poisoning note for the implementer: the actual enforcement that
prevents foreign zenki from poisoning the vector is the `cube/access.zenki`
whitelist (only listed zenki may route `memory.focus.set`/`boost`), and
cross-zenka calls are route-send + SIZE-reply only. do not build a separate
trust layer; just respect that gate and keep the per-source cap in `apply`.

## acceptance
- `memory.focus.set` / `boost` mutate `<memory.focus>` correctly; set creates a
  persistent floor, boost creates an erodible spike.
- `memory.focus.decay` reduces boosts toward floor/1.0 by the configured rate,
  guards `@ARG > 1`, and is registered as a repeating timer (after + interval +
  repeat:TRUE) in init.
- `memory.focus.apply` adds active-task + recent-command boosts with a per-source
  cap, and is idempotent enough to call every render.
- `memory.focus.matches` returns the constant TRUE/FALSE values and matches
  substring tokens case-insensitively across title/body/source_ref.
- `memory.tree.score` pass 2 visibly reorders children when a focus topic is set
  vs cleared.
- no manual AMOS7 signature stubs in any new file.

#,,.,,,,,,...,...,.,,,,.,,,..,.,.,.,,,..,,,,.,..,,...,...,,.,,,,,,,.,,,,.,.,,,
#33VSVK4XJM43RRPUERH3JHHKUL6K6TYCLWMYYONMDS6L7VBSMTZ6WDMCXMJQBU6FKNG4EQTMMHVHW
#\\\|XIURJ4XYVAMBYB7FNDEWT6BXOJMQZ365FS3X4RIWSDPU6VQCHEV \ / AMOS7 \ YOURUM ::
#\[7]CDK3BLBMUPMNCPOAF647MNMQBQNPCJD5Z2GLGNPCQB3CQ7VW2QDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
