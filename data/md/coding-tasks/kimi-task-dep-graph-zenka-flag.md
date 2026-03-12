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

#,,,.,,,.,.,.,.,.,..,,,,.,.,,,,..,..,,.,.,...,..,,...,...,..,,.,.,,,.,.,.,,..,
#ZFGPEFJR674MCAVTUNYLEZOHSTJIWIB55GG627MGU2IBEIPVWOL2CYL5463GVTQBT562VMJMGUTEU
#\\\|3SGD76BD6IHB63FYJ5SCS3XV2DFQG2JZWZRUN7VTNN5JTR5KGWZ \ / AMOS7 \ YOURUM ::
#\[7]752GNNGPT7GFMW36YGM666XJQH5LCFJAPYZK2HP5ENPWVVDQPWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
