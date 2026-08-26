## task: memory-zenka-wiring

## dispatch
wire the memory zenka together end-to-end: `memory.init_code`,
`memory.cfg.defaults`, the startup/unfold sequence, and the multi-frontend
render fan-out (`memory.render.*`). produce a first working demo: progress
animation → structured load → focus init → scored tree → expanded composite.
read first: `data/md/design/MEMORY-TREE-SYSTEM.md` sections I, J, K;
`data/yaml/ascii-frames/memory-composite.yaml` (progress/expanded modes + unfold
notes); the deferred-init feedback (push onto `system.callbacks.initialized`);
the timer-args feedback. DEPENDS ON the other five tasks (frames, sources, tree
core, focus); this is the integration task — dispatch it last.

## prompt
assemble the memory zenka. module headers `## [:< ##`, `# name = ...`,
`# descr =` lowercase under 55 chars. lowercase narrative comments, `[ word ]`
annotations, NO manual signature stubs.

1. `memory.cfg.defaults` — set config in `<memory.cfg>`: `n_visible => 7`,
   `n_max_cap => 13`, `focus_decay => 0.85`, eviction threshold, default
   `curve_type => 'sigmoid'`, ai_mem dir, git commit limit.

2. `memory.init_code` — the wiring:
   - apply `memory.cfg.defaults`.
   - `<[memory.tree.init]>`.
   - register the source adapters to run (file, session, git; chat/task/index
     optional/guarded if not present yet).
   - schedule the `memory.focus.decay` repeating timer (after + interval +
     repeat:TRUE).
   - defer the first build+render: push a callback onto
     `system.callbacks.initialized` so the zenka comes up fast (< 100ms),
     mirroring the coding zenka's deferred-spawn pattern.

3. startup / unfold sequence (a `memory.startup` module or inline in the deferred
   callback) — realize the `memory-composite.yaml` unfold:
   - render `memory-composite` PROGRESS mode in a `\r` loop, advancing the
     PROGRESS bar and cycling STATUS as each adapter loads
     (`loading profile.. loading sessions.. indexing git.. scoring.. ready`).
     drive timing off the shared `base.curve` 50ms tick; do NOT block the event
     loop.
   - run each `memory.source.*` adapter, feeding leaves through
     `<[memory.tree.insert]>` with the right branch path.
   - `<[memory.focus.apply]>` to seed the focus vector.
   - `<[memory.tree.score]>` from the root.
   - commit the progress line (`\n`), then render `memory-composite` EXPANDED
     mode with the tree nested as a composed slot (use
     `<[ascii.frame.compose]>` to nest the `memory.tree.render` output into a new
     composed slot alongside the existing PROFILE/FEEDBACK/PROJECT/TASKS blocks —
     keep those standalone frames intact).

4. `memory.render.*` fan-out — the same `<memory.tree>` to four outputs:
   - `memory.render.context` — plain `<[ascii.frame.render]>`, compact variant,
     for LLM context injection (wire-compatible with `context.provider.frame`).
   - `memory.render.term` — `<[ascii.frame.render.color]>` ANSI for nshell/term.
   - `memory.render.web` — `<[ascii.frame.render.html]>`.
   - `memory.render.data` — `<[ascii.frame.render.data]>` structured hashref for
     a GTK3 consumer.
   each takes an optional `n` for zoom; pass it through to `memory.tree.render`.

5. demo command — `memory.show [variant] [n]` routing to the right
   `memory.render.*`, so `p7c memory.show term 7` prints the live colored tree.

## acceptance
- the memory zenka initializes in well under 100ms (heavy build deferred onto
  `system.callbacks.initialized`).
- the progress→expanded unfold renders: a growing progress bar with cycling
  status, committed with `\n`, then the expanded composite with the tree nested
  beneath, without blocking the event loop.
- `p7c memory.show term` prints a colored, scored, top-N memory tree built from
  the real `data/ai-mem` content; `p7c memory.show term 3` renders a visibly
  smaller tree.
- all four `memory.render.*` paths return output of the right kind (plain text,
  ANSI, HTML, hashref).
- the existing standalone profile/feedback/project/task frames still render
  unchanged inside the expanded composite; the tree is an added composed slot.
- the focus-decay timer is registered repeating (after + interval + repeat:TRUE).
- no manual AMOS7 signature stubs in any new file.

#,,.,,,,,,,,.,...,..,,..,,,,.,,,,,.,,,.,.,..,,..,,...,...,.,,,.,,,..,,,,,,,,.,
#2RMVCMGZFQBFT2DGXRZ43AWLQMSP42QIMHHZE3WBBSJHVLWIQKHG7YOCBHSFCBEWCHG7CMZR6FNJA
#\\\|NRDLNQA67ZUMMCHXYHU4WQA6SWTQQX44Q67UAH5XQ2Q347MC7PF \ / AMOS7 \ YOURUM ::
#\[7]523RA4Y6SNBDYC3KPYYPLQJJUXDJQ2QDN6SOQZTMYEHBC6DD7QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
