:integrate-recent:

## scope

integrate the following recent additions from the may 2026 sessions:

### 1. ncode.cmd.search as coding zenka tool

`modules/ncode.cmd.search` was added and the ncode namespace loaded into
coding zenka via modules.load — but `ncode.cmd.search` is not yet a
defined tool in the coding zenka tool list. wire it so models can call
it during tasks.

- add tool definition to coding tools definitions
- tool name: `search_code_context` or similar [ distinguish from
  existing `search_code` which uses grep ]
- args: `path` [ target file, dir, or glob ], `pattern` [ regexp ],
  `context_lines` [ optional int, default 0 ]
- description should mention: context lines around matches, path can
  be file/dir/glob, case-insensitive match
- verify it appears in coding.list-tools after wiring

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

#,,..,.,,,.,,,..,,.,,,,.,,,.,,,,,,.,.,,..,,..,..,,...,...,...,...,,..,..,,,..,
#KSRTEILVFAL2BCEX27E7DE247CD65ZNR7CZPUOUM6ZWS5JALQ7UW2BN435VEIVLVETCM4RPGQDZAW
#\\\|44FZLU7SZNQCSZXLTJD7JYYBPB3B7CBLZV7ELYHDFDBVEKHAQVE \ / AMOS7 \ YOURUM ::
#\[7]SWKLEZSPWDDHWMJSASRDTT4QP65IWXQTT2YSP4CD7RSWHJYROKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
