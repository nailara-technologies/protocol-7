# Task: study HANDOVER.md and orient for continuation

status: completed

## before you start

read your memory files:
- `data/ai-mem/kimi/MEMORY.md` — index to your saved memories
- `data/ai-mem/kimi/coding-style.md` — coding conventions for this project
- `data/yaml/code-style/CONVENTIONS.yaml` — quick reference

## objective

study the handover document and prepare to continue development of the
context.* namespace, ncode regex engine, and review pipeline. this is an
orientation task — no code changes, just building understanding.

## steps

1. read `HANDOVER.md` in the project root — this is the comprehensive
   state from the claude session that built 49 modules across context.*,
   ncode.*, channels.memory-sync.*, and the context zenka configuration

2. read the design documents referenced in the handover:
   - `data/md/coding-tasks/context-namespace-design.md` — master design
   - `data/md/coding-tasks/context-batch-review-pipeline.md` — review pipeline
   - `data/md/coding-tasks/ncode-zenka-self-refining-regex.md` — ncode design

3. read the ncode foundation modules to understand what exists:
   - `src/ncode.init_code`
   - `src/ncode.regex.load`
   - `src/ncode.regex.apply`
   - `src/ncode.regex.save`
   - `data/yaml/ncode-patterns/p7-style.yaml` — 12 seed patterns

4. read the context zenka start file to understand module loading:
   - `cfg/zenki/context/zenka.v7`

5. identify the next implementation targets from the handover:
   - `ncode.regex.assess` — check if a diff can become regex
   - `ncode.regex.expand` — add new pattern with confidence tracking
   - `ncode.transform.wave` — single regex + LLM refinement cycle
   - runtime testing of context.* modules via nshell commands

6. write a brief summary of your understanding to
   `data/ai-mem/kimi/handover-orientation.md` — what you learned,
   what you plan to work on first, any questions or concerns

## style reminders

- `qw| word |` is correct P7 style for single scalar strings
- `m{}` when pattern contains pipes, `m||` otherwise
- lowercase comments, `[ bracket ]` annotations, `$ARG` not `$_`
- never add AMOS signature stubs — leave clean for signing system
- `ptd` for formatting and syntax checking after writing modules
- see `data/ai-mem/kimi/coding-style.md` for full guide

## context

the context zenka is live and running via `v7.start context`. it loads
context.*, ncode.*, format.yaml.*, and channels.* module namespaces.
zero compile errors after the latest fixes. the ncode seed patterns
include pipe-delimiter detection, comment style, qw-quoting, module
call syntax, and other P7 conventions that ncode should eventually
enforce automatically during code generation.

#,,,.,.,,,,..,,.,,,,,,.,,,...,,..,,,.,.,.,.,,,..,,...,..,,...,,,.,.,,,,,.,...,
#BRRCE3ZLT6AYSRE2F7D33RJYLZQUCKZ2JZMIBWGERMA5KPH7CFPKJR4ALNHFN6UIR37VJQGMSE5YK
#\\\|7F3QQJ5FMGB3KF53PJDDQHAYAI67IW6GZPNYZSQWVX5NYZFBB2F \ / AMOS7 \ YOURUM ::
#\[7]RK6GXNY4MPNPH5EOFIIGTQR7SRIZVCV3FMYBDN53FZMGK7BO6GCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
