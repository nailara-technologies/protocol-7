## dep-graph: -zenka=NAME flag — reachability analysis and export set ##

single self-contained task: extend `bin/dev/dep-graph` with a `-zenka` flag
that resolves which modules are reachable from a zenka's entry points, and
which loaded modules are never called.

mark checklist items as completed alongside the corresponding commits.

---

### context

`bin/dev/dep-graph` already maps all module-to-module call sites statically.
the dep-graph data structure is `$graph->{caller}{callee} = call_count`.

each zenka has a start file at `configuration/zenki/NAME/start` that defines:
- which modules are loaded: `modules.load = mod1 mod2 ...` (may span lines
  with `\` continuation)
- the entry-point invocation sequence: bracketed `[cmd:param]` calls that
  are executed top to bottom during startup

the reachable set from a zenka's entry points is also the exact module bundle
needed for standalone script export (roadmap item).

### reference: start file structure

```
system.zenka.name = cube
modules.load      = auth net protocol cube crypt.C25519 \
                    base.something ...
[root.check_system_user:<system.amos-zenka-user>]
[load_modules:<modules.load>]
[init_modules]
[root.drop_privs:<system.amos-zenka-user>]
[zenka.loop]
```

entry-point commands in the start sequence resolve to module names via
the standard `base.` / `base.cmd.` prefix lookup used by the loader.
for this static analysis, treat `[cmd:param]` as a call to `base.cmd`
or `base.cmd.cmd` — whichever exists in the dep-graph.

`[load_modules]`, `[init_modules]`, `[zenka.loop]`, `[root.*]` are
infrastructure calls — include them in the entry-point seed if present
in the dep-graph, skip silently if not.

### implementation: -zenka=NAME flag

- [x] add `-zenka=NAME` option to `%opt` and `GetOptions`
- [x] when `-zenka` is set, locate start file at
      `configuration/zenki/NAME/start` — die with clear message if not found

### start file parsing (static only — no execution)

- [x] extract `modules.load` value: join continuation lines (trailing `\`),
      split on whitespace — this is the **loaded set**
- [x] extract entry-point commands: lines matching `^\s*\[([^\]:]+)` —
      capture the command name, strip params after `:`
- [x] resolve each entry-point command to a module name using the same
      prefix logic as the loader:
      - try `base.cmd.NAME` first, then `base.NAME`, then `NAME` as-is
      - keep only names present as keys in the dep-graph
      - skip silently if no match (infrastructure calls like `root.*`)

### reachability walk

- [x] seed the walk with all resolved entry-point module names
- [x] walk transitively using the existing dep-graph (same logic as
      `_append_tree_deps` but collecting a set, not rendering)
- [x] result: `%reachable` — all modules transitively called from any
      entry point

### output

- [x] default (no `-text` / `-dot`): print reachability summary to STDOUT:
      ```
      :: zenka : cube
      :: loaded   : N modules
      :: reachable: M modules
      :: unreachable (never called):
         name.of.dead.module
         another.dead.one
         ...
      ```
- [x] with `-text`: render the full reachable subgraph as a tree
      (one tree per entry-point, using existing `generate_tree_output`)
- [x] unreachable list sorted by `sort_by_length` [ consistent with rest ]

### ambiguity warnings for runtime dispatch

the dep-graph scanner already detects `$code{'literal.name'}` patterns.
it cannot resolve variable-keyed dispatch like `$code{$callback}->()` or
`$code{$ARG}->()` — these are runtime-determined call targets.

- [x] during the reachability walk, collect any module that uses variable
      dispatch: `\$code\{\s*\$\w+\s*\}` (no quotes around the key)
- [x] report these separately after the unreachable list:
      ```
      :: ambiguous dispatch (runtime-resolved, may call any loaded module):
         module.name  [ $code{$callback}->() at line N ]
         ...
      ```
- [x] this gives llm context to reason about which modules COULD be called
      even if they appear unreachable from static analysis
- [x] note: `$code{'literal'}` patterns are already resolved by the scanner
      and do not need to appear here

### notes

- do not attempt to parse `[load_modules:<modules.load>]` expansion —
  just use the literal `modules.load` value already extracted
- continuation lines: a line ending in `\` means the value continues on
  the next line — strip the `\` and append
- the loaded set may contain short aliases like `auth`, `net`, `cube` —
  these expand to full module names at runtime but for static analysis,
  treat them as prefixes: a loaded alias `cube` covers all modules whose
  name starts with `cube.`
- no protocol-7 runtime needed — pure static file analysis

### style

- lowercase comments, `[ annotation ]` not `( annotation )`
- `$ARG` instead of `$_`
- follow conventions visible in the existing `bin/dev/dep-graph` code

### review

- [x] reviewer runs `bin/dev/dep-graph -zenka=cube` and confirms output
      lists loaded/reachable counts and any unreachable modules
- [x] reviewer runs `bin/dev/dep-graph -zenka=cube -text` and confirms
      tree output is scoped to reachable modules only
- [x] reviewer spot-checks one reported unreachable module against grep
      to confirm it is genuinely uncalled in the cube zenka context

### completed — commit [pending]

---

## future enhancements [roadmap]

### phase 1: variable origin backtracking

- [x] backtrack where ambiguous dispatch variables are introduced
- [x] report start range line numbers: `[ 45-120 : code{ $callback } ]`
- [x] gives LLMs the full context window to reason about possible values
- [x] special case: if variable originates from `@ARG` / a parameter, flag it
      explicitly — scope widens to "whatever the caller passed" and tracking
      must cross into the caller's code [ qualitatively different from local ]

**implementation notes:**
- handles multi-line `my` declarations: `my $var\n    = ...`
- detects parameter patterns: `my $var = shift`, `my $var = $ARG[N]`, `my ( $var ) = @ARG`
- output format: `[ 112-120 : code{ $var } ]` or `[ 112-120 : code{ $var } [param] ]`

### phase 2: variable handover tracking

- [x] track variable assignments through the code
- [x] follow handovers: `$callback = $other_var`
- [x] widen scope when variables pass through multiple subroutines
- [x] report extended range: `[ 12-145 : code{ $callback } via $other_var ]`
- [x] if variable crosses a module boundary via parameter passing, note the
      originating call site so cross-module flow is traceable

**implementation notes:**
- recursive `backtrack_variable_origin()` follows handover chains
- detects: `$var = $other_var`, `$var = $other->()`, `$var = $other->{key}`
- builds via chain: `via var1->var2->var3` for multi-hop handovers
- circular reference protection via `$visited_vars` tracking
- cross-module parameter passing detected via `[param]` origin type

### phase 2.5: confidence annotation

- [ ] once partial context is available, classify each dispatch site:
      `[ probable ]`   — name pattern or conditionals strongly constrain values
      `[ constrained ]` — some context narrows the set but not to one target
      `[ open ]`       — no usable context, all loaded modules are candidates
- [ ] gives LLMs a signal for where to focus analysis effort
- [ ] confidence label included in output alongside line/variable info

### phase 3: regex logic rule plugin interface

- [ ] declarative rule format for resolving ambiguity
- [ ] LLMs write rules: `if $callback =~ /^(foo|bar)$/ → resolve to base.cmd.$1`
- [ ] rules stored in `configuration/dep-graph/rules/`
- [ ] rules applied automatically during analysis

### phase 4: automated coverage completion

- [ ] rules run automatically on new code
- [ ] only "logic-breaking" code [variable mutations] needs LLM review
- [ ] dep-graph becomes self-improving: rules → less ambiguity → more rules
- [ ] edges resolved by rules tagged `[ rule-resolved ]` vs `[ static ]` in
      output — keeps provenance clear and makes rules auditable

#,,.,,..,,,.,,.,,,..,,,,,,,..,.,.,...,,,,,,,,,..,,...,...,...,..,,...,,,,,.,.,
#K2MAXME2SVOFVSZE6W5YFY6ZRFW5SON2CLQMUFPFXIAWPNMJMIWPSIDPMJH3LVIK7UJAYUF4PWW5S
#\\\|QKRO4QMQSU47VOUN52ZZKK445NBIGL3M6KQS4Y5JUOS4UYNVTAA \ / AMOS7 \ YOURUM ::
#\[7]XLY2KRK4QLSTI5KR3G6AAVBNWROMYXXINSVVIPWER6BG3A2ORUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
