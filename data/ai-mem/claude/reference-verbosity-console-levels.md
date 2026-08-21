---
name: reference-verbosity-console-levels
description: "system.zenka.verbosity.console/buffer/logfile scale is 0-5, not a generic log-level enum -- 3+ changes what gets compiled, 4/5 dump internals to console, not named severities like FATAL"
metadata:
  type: reference
---

`<system.zenka.verbosity.console>` (and the parallel `.buffer`/`.logfile`
knobs) is not a conventional named-severity log level (no ERROR/WARN/INFO/
DEBUG/FATAL enum) — it's a numeric intensity scale, and levels 3+ change
zenka *behavior*, not just log verbosity:

- **level 3** (`-vvv` at startup): subroutines are compiled WITH extra
  debug/tracing code inlined that is not present in normal operation —
  this shows subroutine calls and parameters as they execute. Not just
  "print more," a genuinely different compiled artifact.
- **level 4**: `src/v7.init_code`/`src/v7.post_init` gate extra
  console-visible detail behind `<system.zenka.verbosity.console> > 4`
  (e.g. `$verbosity_factor = 5.447 * ($level - 1)` in `v7.init_code`) —
  parsed code gets printed to console at this level.
- **level 5**: `src/devmod.post_init` dumps the entire `%data` hash to
  console (`Dumper(\%data)`) when the `devmod` module is loaded — the most
  intense level, whole-state introspection.

**Caught live 2026-08-21**: a kimi dispatch (unrelated task) added an
undisclosed, unused `%level_desc` hash to `src/base.log` mapping
`0=>ERROR, 1=>INFO, 2=>DEBUG, 3=>TRACE, 4=>FATAL` — wrong on two counts:
dead code (never referenced after being built), and wrong semantics (4 is
not a terminal/fatal severity here, it's a console-detail intensity
level). Reverted before commit.

**How to apply**: don't assume this is a syslog-style severity enum when
reading or writing anything that branches on `<system.zenka.verbosity.*>`
values, and don't let a model (yours or a dispatched one) invent a
named-level mapping for it — the real scale is 0-5 numeric intensity, with
3/4/5 specifically wired to compile-time tracing / parsed-code dump /
full `%data` dump respectively, not to severity meanings like FATAL.

#,,..,,..,...,.,,,...,..,,..,,,,,,,,,,.,.,,,.,..,,...,...,,.,,,.,,,,.,..,,.,.,
#GS5CYLEXQQD2CUWNJTLTZ5WC7EBN4I6XPKKQDJSAJVUSSLJWBGXUMNZP7MKZ7ELOBPXFP3P363FIM
#\\\|J7AUN36PQHPLXMUU5NM23C2J3LOGZ44ITI5MREBXFASBS5LHQKP \ / AMOS7 \ YOURUM ::
#\[7]4VL4G6PZVMDMOS3O7ALLXRGYMZXPDGLUZWVYIMSKVNH6OMIO2CAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
