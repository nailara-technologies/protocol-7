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

the orbital visualization template is at:
`data/web-root/vhosts/space.v7.ax/orbital.json.tmpl`

read that file. if there is a `docs` or `references` section, add
entries for the new topology documents. if not, record the gap as a
note_write suggestion [ use note_write tool, do not create files ].

### 3. jinja template file config wiring [ record finding only ]

`cfg/zenki/coding/start` line 45 sets:
`coding.jinja.template_file = /data/projects/protocol-7/data/jinja/templates/qwen3.5-fixed.jinja`

this is an absolute path. check whether `coding.spawn_inference_server`
or whichever module reads `coding.jinja.template_file` resolves it
relative to `<system.root_path>`. if it uses the value verbatim [ no
resolution ], record as a note_write suggestion for making it relative.
do not change config or code for this item — record only.

### 4. gen-sub-whitelist namespace-only handling [ DONE ]

`bin/dev/gen-sub-whitelist coding` was already run this session and
regenerated `cfg/zenki/coding/subroutine.white-list` with
1004 entries including the new `coding.buffer.task_write` module.
no further action needed.

### 5. cross-namespace: ncode.cmd.search ↔ existing search_code tool

`search_code` tool in `coding.tools.dispatch` uses grep [ no context
lines ]. `ncode_search_context` [ just added ] uses `ncode.cmd.search`
with `-C N` context lines. record as note_write whether the system
prompt or tool descriptions should mention that `ncode_search_context`
is preferred when context around matches is needed.

## style note

read `data/md/development/STYLE-PHILOSOPHY.md` before making any
code changes. all new modules and edits should follow p7 style
conventions. `$ARG` not `$_`.

## signatures note

do not investigate or modify AMOS7 signatures. leave signature lines
at end of module files untouched.

#,,.,,...,,,,,,,.,.,,,...,.,,,.,.,,,,,,.,,.,.,..,,...,...,...,,,.,,,.,,,,,..,,
#XS3FGIKWQ4WNUZ4OVVWU2DM3A7HIKODUWS2ENIU4UI2K6A5CGPA4AHPKGG2YA4U3EQF2CBXJ6YJBW
#\\\|F36MHRBAKUNHALPOYPKWUZ42COHZ5NM6MQJXWNZFTY4UISNEKGO \ / AMOS7 \ YOURUM ::
#\[7]IP4UQLXIIWN2VUCGRIW6HL6RZNV3MGGOCCI7WDD5KUKL4HU7IWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
