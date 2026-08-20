## dep-graph: -zenka=NAME flag — reachability analysis and export set ##

single self-contained task: extend `bin/dev/dep-graph` with a `-zenka` flag
that resolves which modules are reachable from a zenka's entry points, and
which loaded modules are never called.

mark checklist items as completed alongside the corresponding commits.

---

### context

`bin/dev/dep-graph` already maps all module-to-module call sites statically.
the dep-graph data structure is `$graph->{caller}{callee} = call_count`.

each zenka has a start file at `cfg/zenki/NAME/start` that defines:
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
      `cfg/zenki/NAME/start` — die with clear message if not found

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

## start file list output flags

three complementary flags for inspecting what a start file declares,
without running reachability analysis. works with both `-zenka=NAME`
and `-stdin`.

- [x] `-list` — print a deduplicated, sorted list of all declared items
      (modules and config includes combined), one per line
- [x] `-list-modules` — print only `modules.load` entries, one per line
- [x] `-list-configs` — print only `load_config` file includes, one per line

### context

start files can include config files alongside module loading:
```
load_config = cfg/shared-params
load_config = cfg/zenki/cube/zenka-startup.v7
modules.load = auth net protocol cube ...
```

`-list-configs` extracts the `load_config = VALUE` lines.
`-list-modules` extracts the `modules.load = VALUE` token list.
`-list` combines both, deduplicates, and sorts.

output is plain one-per-line — pipe-friendly for use with grep, xargs, etc.

### runtime-loaded module ambiguity

the static loaded set from `modules.load` is not the complete picture.
modules can also be loaded at runtime via:
- `<[base.load_modules]>->( $list )` — loads additional module sets
- `<[base.perlmod.register_loaded_module]>->( $name )` — registers a
  dynamically loaded perl module as part of the loaded set

these calls are detectable by the dep-graph scanner (already scans
`$code{'literal'}` patterns). a future pass could:
- collect all `base.load_modules` call sites within reachable modules
- flag them in the ambiguous section alongside variable dispatch:
  ```
  :: runtime module loading [ statically unresolvable set extension ]:
     module.name  [ base.load_modules at line N ]
  ```
- `base.perlmod.register_loaded_module` calls with a literal string arg
  ARE resolvable statically and should be added to the loaded set

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

- [x] once partial context is available, classify each dispatch site:
      `[ probable ]`   — name pattern or conditionals strongly constrain values
      `[ constrained ]` — some context narrows the set but not to one target
      `[ open ]`       — no usable context, all loaded modules are candidates
- [x] gives LLMs a signal for where to focus analysis effort
- [x] confidence label included in output alongside line/variable info

**implementation notes:**
- `classify_dispatch_confidence()` scans ±15 lines around dispatch site
- detects: regex patterns (`=~ /.../`), literal comparisons (`eq '...'`)
- detects: hash lookups (`exists $hash{$var}`)
- detects: conditional guards (`if/unless/while` containing the variable)
- classification:
  - `probable`: regex + conditional, or literal + conditional
  - `constrained`: hash lookup, or regex/literal without conditional
  - `open`: no constraining patterns found

### phase 3: regex logic rule plugin interface

- [x] declarative rule format for resolving ambiguity
- [x] LLMs write rules: `module_glob : var ~ /context_pattern/ -> resolution`
- [x] rules stored in `cfg/dep-graph/rules/*.rules`
- [x] rules applied automatically during analysis
- [x] resolved sites removed from ambiguous list, reported as `[rule-resolved]`
- [x] resolved targets added to reachable set (with `.*` prefix wildcard support)

**implementation notes:**
- rule format: `module_glob : var ~ /pattern/ -> template` or `var ~ /pattern/ -> template`
- module_glob: `*` = any, `foo.bar.*` = prefix, `foo.bar.baz` = exact
- context_pattern matched against ±15 lines around dispatch site
- template: `$1`..'$5` are regex captures, `$var` is variable name
- first real rule: `protocol.amos-chksum.command-handler` → `protocol.amos-chksum.ext-cmd.*`

### phase 4: automated coverage completion

- [ ] rules run automatically on new code
- [ ] only "logic-breaking" code [variable mutations] needs LLM review
- [ ] dep-graph becomes self-improving: rules → less ambiguity → more rules
- [ ] edges resolved by rules tagged `[ rule-resolved ]` vs `[ static ]` in
      output — keeps provenance clear and makes rules auditable

#,,,,,,,.,,,,,,..,.,,,.,.,...,.,.,...,,..,,.,,..,,...,...,.,.,...,..,,...,..,,
#XHUKV4KUAPF6HVN5ZOG22I2QJECNN57J35YEEMG67646QIRPO5Z3G4M2NNBRT5MEOSQ4MSABJMNHG
#\\\|JZPVWHH4BNTBBH7QNTJIAHX545QIIXH57SBI32PRXNZMKD2LUCH \ / AMOS7 \ YOURUM ::
#\[7]YHGXW3U3XO4WIXF5N5OBE3F5DGBPXTM4UKFQ6AI26E2CMIGUKABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
