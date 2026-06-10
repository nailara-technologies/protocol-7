# session status: tranche-1 follow-up (2026-06-10)

## fixed this session

- bmw-harmonize-l13-helper: v7 boot crash resolved.
  - whitelist: added `base.chk-sum.bmw.harmonize_L13` to 111
    `configuration/zenki/*/subroutine.white-list` files (next to existing
    `calculate_L13_sum` entries)
  - infinite-loop guard: added 100_000-iteration cap in
    `modules/base.chk-sum.bmw.harmonize_L13` (no time-based timeout when
    `AMOS7::TEMPLATE::template_count() == 0`)
  - root cause of "undefined value as subroutine reference
    [chk-sum.bmw.calculate_L13_sum:12]": `base.chk-sum.bmw.pre_init` aliases
    `base.chk-sum.bmw.*` -> `chk-sum.bmw.*` via `base.swap_subs`. call sites
    must use the SHORT alias `<[chk-sum.bmw.harmonize_L13]>`, not the
    `base.`-prefixed form. taeki fixed via
    `ncode r src '\[base.chk-sum.bmw\.' '\[chk-sum.bmw\.'` across:
    - modules/base.chk-sum.bmw.template_L13
    - modules/plugin.web.auth.create_session
    - modules/plugin.web.auth.destroy_session
    - modules/plugin.web.auth.verify_session
  - backend confirmed booting + `list sessions` working post-fix.

## still pending dispatch

- **stdio-multiplex-type-tag-codec.md** — 6th tranche-1 task, was NEVER
  dispatched (only 5 of 6 sent in the parallel batch). task file exists at
  `data/tasks/stdio-multiplex-type-tag-codec.md`. independent of the other
  5 — safe to dispatch standalone via kimi.

## still open / unverified

- **console-fold-primitive.md** — kimi run produced 0 files (Explore
  sub-agent timed out). per round-2 design doc this task owns
  `base.ui.fold` / `base.ui.unfold` / `base.cmd.ui-show.fallback`.
  console-foldable-render-baseline's run already created `base.ui.fold` and
  `base.ui.unfold` (created "to support the baseline acceptance path") but
  explicitly skipped `base.cmd.ui-show.fallback`. NEED TO DECIDE:
  - is `base.ui.fold`/`unfold` from render-baseline sufficient for
    fold-primitive's contract?
  - does `base.cmd.ui-show.fallback` still need a separate dispatch
    (could be a small standalone follow-up task)?

- **amos7-template-epoch-exclusion.md** — kimi run ended with
  `!TERM! manual shutdown [SIGINT]`. `data/lib-path/pm/AMOS7/TEMPLATE.pm`
  shows +83 lines (new `configure_epoch_window_callback`,
  `CALLBACK_epoch_window`, `TEMPLATE_epoch_window`, `+use Crypt::Misc`).
  compiles cleanly (`perl -Idata/lib-path/pm -e 'use AMOS7::TEMPLATE'` ->
  OK). status: looks complete/additive, but not cross-checked against the
  task file's full acceptance criteria — verify before committing.

## commit groups (once signed/staged)

1. bmw-harmonize fix: `base.chk-sum.bmw.calculate_L13_sum`,
   `.template_L13`, new `.harmonize_L13`, `plugin.web.auth.*` (3 files),
   111 whitelist files, `bin/dev/tests/checksum/test-bmw-harmonize-l13.pl`
2. console-stdio-slot-addressing: `base.slot.*` (8 modules) — appears
   complete, low-risk
3. console-foldable-render-baseline: `base.ui.*` (9 modules) — pending
   fold-primitive overlap decision above
4. amos7-template-epoch-exclusion: `AMOS7/TEMPLATE.pm` — pending
   acceptance-criteria check
5. `configuration/zenki/coding/start` — taeki's manual context-size edit
   (37000 -> 30000), unrelated to tranches, can commit independently

#,,..,,.,,..,,,..,,,.,,,,,.,.,.,.,.,,,,.,,,,.,..,,...,...,.,.,,..,...,...,,.,,
#IOJPBF2FVAXLTELTTLTWGICGYU4MPFEFJZLUNKVJHS43QP777LSPE7JHLM4FOCS55V36V2UZCQDLW
#\\\|4DTB7EHIMC2ZLZG6LCWQ6NVAVZHTT7R3P3J74F3J3UTUBAFZEZC \ / AMOS7 \ YOURUM ::
#\[7]CL52DVGHOGDLWKTPB7L2TRFPNOQZCHSS2GQBA77JFCB4UVQRBWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
