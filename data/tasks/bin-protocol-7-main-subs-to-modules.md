# bin/Protocol-7 : named subs in main:: are a transitional state

## the plan [ user, 2026-09-30 ]

the named perl subs in `bin/Protocol-7` [ and its translator copy
`data/lib-path/pm/AMOS7/Protocol/P7Syntax.pm` ] are not the target form --
their very presence in that form IS the plan to convert them. it was never
written down, so no model recognized it : "the plan is implicit by their very
presence in that form.. but no llm will recognize that if we do not write it
down somewhere".

**for any model working here : do not treat a named `sub` in `main::` as a
pattern to extend. a new helper there adds to what has to be converted -- if
one is truly needed [ early boot, before %code exists ], name it with the
`p7_` prefix and add it to the inventory below.**

## why they have to go

- outside the module system : no `<[..]>` call, no per-module file, no
  signature per module, no whitelist [ `subroutines.load-early` ]
- never reloadable : a change only takes effect when the whole process
  restarts -- `reload source` does not touch them [ seen 2026-09-30 : the
  translator fix reaches each zenka only at its next start ]
- the translator exists twice [ `bin/Protocol-7` + `P7Syntax.pm` ], kept in
  lockstep by hand -- every fix is written twice [ 2026-09-30 : kimi's
  `inside_key_chain` \ `match_qlike_op` change ]
- 11 of the 13 translator subs do not even carry the `p7_` prefix
  [ `find_paired_end`, `match_qlike_op`, `inside_key_chain` .. ] -- they sit
  in `main::` next to everything else

## inventory [ 2026-09-30 ]

- `bin/Protocol-7` : 86 named subs. groups :
  - boot \ config : `p7_stdin_configuration`, `p7_init_exec`,
    `p7_security_hardening`, `p7_resolve_zenka_symlink_chain`,
    `p7_early_whitelist_load`, `p7_load_perl_modules`, ..
  - code loading : `p7_load_code`, `p7_purge_code`,
    `p7_import_main_subroutines`, `p7_scan_main_subroutines`,
    `p7_referenced_subroutines__*`, `p7_load_inline_subroutines`, ..
  - translator [ 13, also in P7Syntax.pm ] : `find_paired_end`,
    `find_samechar_end`, `consume_body`, `consume_second_body`,
    `inside_key_chain`, `match_qlike_op`, `qlike_class`,
    `translate_segment`, `render_body`, `match_heredoc_marker`,
    `extract_heredoc_body`, `p7_syntax__scan`, `p7_syntax__translate`
  - ntime \ base32 : `p7_ntime`, `p7_ntime__step_back`, `p7_ntime__b32`,
    `p7_base_util_base32_*`, `p7_encode_ntime_to_B32`, ..
  - logging \ errors : `p7__log__*`, `p7_format_error`, `p7_caller`,
    `p7_sig_warn`, `p7_delay_warning`, ..
  - export \ inline subroutine tooling : `p7_export_*`, `p7_encode_*`,
    `p7_detect_*`, ..
  - regenerate : `grep -oE '^\s*sub [a-zA-Z_]\w*' bin/Protocol-7`
- `P7Syntax.pm` : the 13 translator subs, used by `bin/format-code`,
  `bin/dev/ptd`, `bin/test-scripts/*`

## the catch

some of them run BEFORE %code exists or is compiled : the translator is
needed to compile the modules at all, the loader loads them, the early log
path logs their errors. these cannot simply become modules compiled by
themselves. options to weigh, per group :
- a bootstrap core that stays in the binary [ as small as possible ], plus
  its later-phase parts moved to modules that replace \ shadow it once %code
  is up [ `p7_import_main_subroutines` \ `p7_scan_main_subroutines` look like
  an existing bridge from main:: into %code -- check what they do first ]
- one translator source : `bin/Protocol-7` loads `AMOS7::Protocol::P7Syntax`
  instead of carrying its own copy, if the boot order and the lib path allow
  it at that point [ it is under data/lib-path/pm, found via the BEGIN block ]
- reloadability : a reloadable replacement for the parts that are safe to
  swap at runtime [ translator yes -- it only acts on source text ; the
  loader loop itself probably not ]

## not now

no conversion planned yet -- this file exists so the direction is known.
related : multiple v7-zenki \ cube set-ups and parallelism [ base features
queued first, user 2026-09-30 ], a self-test framework with deep coverage.

#,,.,,,..,,,,,.,.,,,.,.,.,,,,,...,,,.,.,,,.,,,..,,...,...,.,.,..,,,..,.,,,,..,
#GXUT5N7Q56PMCYYZ3TQ2AA65OLHVLXKS5PBA5VKJ72NA75I4POGBEXLXMXTNUA43OBFDRJBXPFJXO
#\\\|AGNZSRNANVGEKSDM34WVJANYXEOSDX5FDWR4WEHNLRXZUUVDE2Z \ / AMOS7 \ YOURUM ::
#\[7]IDLQ2JID2YQPW7MED4GXHBUB7G6U7CZ6VWCCEE5GALKVHZKF7IAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
