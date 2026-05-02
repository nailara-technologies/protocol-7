:integrate-recent:

## scope

integrate the following recent additions from the may 2026 sessions:

### 1. ncode.cmd.search as coding zenka tool [ DONE ]

wired as `ncode_search_context` in `coding.tools.definitions` +
`coding.tools.dispatch`. dispatch wrapper builds arg string from
structured `target`/`pattern`/`context` params and calls
`$code{'ncode.cmd.search'}` directly.

### 2. topology documents in orbital visualization

the following documents were added to `data/md/development/`:
- `PUNCTUATION-TOPOLOGY.md`
- `HYPERSPACE-TOPOLOGY.md`
- `FIELD-COHERENCE-SYNTHESIS.md`
- `STYLE-PHILOSOPHY.md`
- `BASE-HANDLER-COMMAND-REFACTOR-PLAN.md`

check whether the space.v7.ax visualization or the orbital data system
references `data/md/development/` as a source. if there is a mechanism
for making these documents browsable or addressable via the orbital
visualization [ orbital.json, templates.json, or similar ], wire them
in. if not, record the gap as a suggestion.

### 3. jinja template file config wiring

`coding.jinja.template_file` is set to an absolute path in the coding
zenka start file. check whether this should be resolved relative to
`<system.root_path>` like other path configs — and if other model
configs [ like when switching models ] should auto-select between
`qwen3.5-fixed.jinja` and `qwen3.6-fixed.jinja` based on the loaded
model's family. record finding and apply if straightforward.

### 4. gen-sub-whitelist namespace-only handling

`bin/dev/gen-sub-whitelist` was updated to skip namespace-only targets
gracefully. verify the coding zenka subroutine whitelist was regenerated
and now includes the ncode.* modules it inherited. run
`gen-sub-whitelist coding` and check the output.

### 5. cross-namespace: ncode.cmd.search ↔ existing search_code tool

the existing `search_code` tool uses grep. `ncode.cmd.search` adds
context lines. check if there are places in the codebase where
search_code results are used and context lines would help — record
as suggestion for future task improvement.

## style note

read `data/md/development/STYLE-PHILOSOPHY.md` before making any
code changes. all new modules and edits should follow p7 style
conventions. `$ARG` not `$_`.

## signatures note

do not investigate or modify AMOS7 signatures. leave signature lines
at end of module files untouched.

#,,..,,.,,..,,.,,,,.,,...,,..,..,,,,,,,.,,,..,..,,...,..,,,,,,.,.,,.,,,..,,.,,
#EONFHMLXTOSHMPQBLCT4XZZRXULEMLSCQECB26TUVKFI2IQG27KR7TDFYNDGMWXLVWU7JULHQC7X6
#\\\|GI66IBXNRCNPUHJRQ4BHYL7DI7DAP74NMINAOTU7AZLOWTUE2CY \ / AMOS7 \ YOURUM ::
#\[7]6JNNKAXGUZKGD64DD7PGT6ABNFHX7D7T3JX3T5YZT2B2S3MGUYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
