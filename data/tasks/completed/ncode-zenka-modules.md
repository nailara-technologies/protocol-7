## [:< ##

# name  = task: ncode zenka modules — bin/ncode as network commands
# descr = expose bin/ncode functionality as src/ncode.* zenka commands.
#         high-priority workflow accelerator: makes ncode composable with
#         other zenki, callable from LLM tools, and the foundation for
#         LLM-assisted log optimization and signing workflows.

## status [ 2026-07-22 ] — DONE, live-verified

confirmed already fully implemented across earlier sessions (2026-07-17/20),
re-verified live this session (kimi K3 dispatch found nothing left to build).
all modules present: `ncode.init_code`, `.cmd.search`, `.replace`, `.sign`,
`.sign-batch`, `.diff`, `.diff-staged`, `.doc`, `.parse-headers`,
`.format-code`, plus extensions (`tool_list`, `apply`, `suggest`,
`transform`, `workflow`, `regex.*`). IPC::Open3 execution centralized in
`ncode.util.run_cmd` (same pattern as `coding.spawn_inference_server`).
on-demand config live at `cfg/zenki/ncode/` (420s idle timeout,
`start.on-demand = 1`, `max_concurrency = 1`). access granted via
cube/admin wildcard (`** ..*.**`) rather than `cube/access.zenki` per
`data/ai-mem/claude/topic-ncode-access-gap.md`'s corrected mechanism.
live-verified: `p7c ncode.search 'base.logt'`, `ncode.doc`,
`ncode.parse-headers`, `ncode.diff`/`.diff-staged` all working; on-demand
lifecycle confirmed (auto-starts on first search).

open: write commands (`.sign`, `.replace`, `.sign-batch`, `.format-code`)
intentionally NOT in `access.cmd.usr.cube` — pending signature-gated
approval system, see `topic-write-access-security-infrastructure`.

## context

`bin/ncode` is a powerful standalone tool used throughout development.
as `src/ncode.*`, it becomes network-accessible and composable.

existing research: `data/md/coding-tasks/ncode-zenka-self-refining-regex.md`
                   `data/tasks/ncode-workflow-patterns.md`
design track:      `data/md/design/DEVELOPER-WORKFLOW-ACCELERATION.md`

## what bin/ncode does today (baseline)

```bash
ncode search <pattern>          # grep with context
ncode s src <pattern>           # search in source files
ncode search tasks <term>       # search in data/tasks/
ncode search docs <term>        # search in data/md/
ncode replace <file> <old> <new>
ncode parse-headers <file>      # extract module name/descr
ncode format-code <file>        # perltidy
ncode sign <file>               # sign a module file
ncode doc <module>              # look up module documentation
```

## target: src/ncode.* as on-demand zenka

start config: on-demand, 420s idle timeout (same as image2html pattern)

```
modules.load = ncode.init_code
               ncode.cmd.search ncode.cmd.replace
               ncode.cmd.parse-headers ncode.cmd.format-code
               ncode.cmd.sign ncode.cmd.sign-batch
               ncode.cmd.diff ncode.cmd.diff-staged
               ncode.cmd.doc
```

## module specifications

### `ncode.init_code`
set up paths: `$data{ncode}{root} = <system.root_path>`,
`$data{ncode}{bin} = <system.root_path>/bin/ncode`.
verify bin/ncode exists and is executable.

### `ncode.cmd.search`
```
args: <pattern> [<scope>]
scope: src|tasks|docs|all (default: src)
```
calls bin/ncode search under the hood via IPC::Open3 (async pattern
from coding zenka). returns SIZE reply with matched lines + context.
line limit: configurable, default 200.

### `ncode.cmd.replace`
```
args: <file> <old_pattern> <new_string>
```
delegates to bin/ncode replace. returns TRUE/FALSE + lines changed count.

### `ncode.cmd.sign`
```
args: <file_path>
```
calls `bin/Protocol-7 sourcecode sign <file>` via IPC::Open3.
returns TRUE if signature applied, FALSE + error if failed.
note: signing requires the sourcecode zenka key — check availability first.

### `ncode.cmd.sign-batch`
```
args: [<glob_pattern>]  (default: all modified tracked files)
```
find all files needing signing (modified + no valid signature).
sign each in sequence. return count signed / count failed.

### `ncode.cmd.diff`
```
args: <file_path> [<ref>]  (ref default: HEAD)
```
`git diff <ref> -- <file>`. returns SIZE reply with unified diff.

### `ncode.cmd.diff-staged`
no args. `git diff --cached`. returns SIZE reply.
useful for pre-commit review from LLM tools.

### `ncode.cmd.doc`
```
args: <module_name_or_path>
```
delegates to `bin/ncode doc`. returns SIZE reply with module docs.

### `ncode.cmd.parse-headers`
```
args: <file_path>
```
extract `# name = ...` and `# descr = ...` from module header.
return { name, descr } as formatted SIZE reply.

### `ncode.cmd.format-code`
```
args: <file_path>
```
run perltidy with `-sil=0` (per feedback-perltidy-sil0.md).
return TRUE + lines changed, or FALSE + error.

## access control

add to cube `access.cmd.usr.taeki` (or equivalent):
```
ncode.search
ncode.replace
ncode.sign
ncode.sign-batch
ncode.diff
ncode.diff-staged
ncode.doc
ncode.parse-headers
ncode.format-code
```

also expose to coding zenka for LLM tool access:
add to `src/coding.tools.*` as tool definitions.

## coding zenka tool integration

once ncode zenka is live, add these as coding zenka tools:

```
sign_file:          p7c ncode.sign <path>
sign_batch:         p7c ncode.sign-batch
diff_staged:        p7c ncode.diff-staged
search_code:        already exists — migrate to ncode.search backend
format_file:        p7c ncode.format-code <path>
```

the coding zenka's `search_code` tool can route through ncode.search
once the zenka is live — centralizing the search implementation.

## validation

```bash
# basic search
p7c ncode.search 'base.logt'
# → matched lines with context

# sign a file
p7c ncode.sign src/base.init_code
# → TRUE (or FALSE + error if key unavailable)

# diff staged
p7c ncode.diff-staged
# → unified diff of all staged changes

# doc lookup
p7c ncode.doc base.logt
# → module documentation
```

## dispatch prompt

implement the ncode zenka on-demand zenka.

1. create `cfg/zenki/ncode/zenka.v7` — on-demand zenka config,
   420s idle timeout, load all ncode.* modules

2. create all modules listed above: `ncode.init_code`, `ncode.cmd.search`,
   `ncode.cmd.replace`, `ncode.cmd.sign`, `ncode.cmd.sign-batch`,
   `ncode.cmd.diff`, `ncode.cmd.diff-staged`, `ncode.cmd.doc`,
   `ncode.cmd.parse-headers`, `ncode.cmd.format-code`

3. each module that calls bin/ncode or git: use IPC::Open3 for
   non-blocking execution (pattern from coding.spawn_inference_server)

4. add access entries to cube/access.zenki for taeki

5. verify: `p7c ncode.search 'base.logt'` returns matched lines

check `bin/ncode` source for exact argument syntax before implementing
— use it directly rather than re-implementing logic in Perl.

#,,.,,,,,,,,.,,,,,,,,,,,,,,..,..,,.,,,.,,,.,.,..,,...,...,.,.,.,.,,..,,,,,.,.,
#IL6RCIOPVKOXW6LBLYKH65RUU5F4Q3WDMFOMRC6DHUQJSW4RZUTOZHVPFXOVSNONBQKSPUQ4TELJM
#\\\|CI62N4YVJIJOHKMFW72X5DH37IGZ3OLEKFARPE6RPLZIL26QRE3 \ / AMOS7 \ YOURUM ::
#\[7]AW7YCYM6WT3F2LXTHSDDTGXBFD6BMRPCOLLZO2WCCYAYTIHER2BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
