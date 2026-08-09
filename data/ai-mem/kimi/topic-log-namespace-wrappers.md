# log.string / log.fmt namespace wrappers

implemented 2026-08-09. task: `data/yaml/coding-tasks/log-namespace-wrappers.yaml`.

## what changed

added two core subs in `bin/Protocol-7`:

- `p7__log__string` → installed as `log.string` → delegates to `base.log`
- `p7__log__fmt`    → installed as `log.fmt`    → delegates to `base.logs`

both are plain wrappers: `base.log` and `base.logs` remain the real
implementations. the new names are additive; no existing call sites were
changed.

## %code registration mechanism

core subs named `p7__<category>__<name>` are scanned by
`p7_scan_main_subroutines()` and imported into `%code` by
`p7_import_main_subroutines()` at startup. the naming transform is:

- strip leading `p7__`
- replace remaining `__` with `.`

so:

```
p7__log__noerr   →  log.noerr
p7__log__string  →  log.string
p7__log__fmt     →  log.fmt
```

no manual `%code{...} = \&sub` assignment is needed; just defining the sub
in `bin/Protocol-7` with the right prefix makes it available. the same
mechanism installs the subs in `$data{'base'}{'core_subs'}` and marks them
as `core-sub` in `$data{'code'}{...}{'status'}`.

## two-phase pattern

like `log.noerr`, `log.error`, and `log.devmod`, the new wrappers have a
pre-init and post-init path:

```perl
if ( $code{'log.base_log_complete'}->() ) {
    $code{'base.log'}->(@ARG);   ## or base.logs for log.fmt ##
} else {
    ## direct console output + accumulate in <system.start.zenka-buffer> ##
}
```

`log.base_log_complete` returns true once both `base.log` and
`base.log.format_entry` exist in `%code`. until then, the wrapper must do
its own console output and buffer accumulation.

## non-obvious gotchas

1. **default verbosity keys in early path.**
   `p7_init_exec()` initializes
   `<system.zenka.verbosity.console>` / `.buffer` / `.logfile` and
   `<system.start.zenka-buffer>`. if the early path runs before that
   (e.g. a log call placed immediately after `p7_import_main_subroutines()`),
   these data paths are undefined. the wrappers default them explicitly:

   ```perl
   <system.zenka.verbosity.console> //= 0;
   <system.zenka.verbosity.buffer>  //= 1;
   <system.start.zenka-buffer>      //= [];
   ```

2. **`log.format_name` needs data from `p7_init_exec()`.**
   the early path uses `$code{'log.format_name'}->($hl)` for the prefix,
   which relies on `<system.node.name>`, `<system.zenka.name>`, and
   `<system.zenka.log_prefix_width>`. calling the wrappers before
   `p7_init_exec()` will produce uninitialized-value warnings and an empty
   prefix. in normal startup, early-path calls happen after `p7_init_exec()`
   but before `base.log` is loaded, so this is not an issue.

3. **level extraction matches `base.log`.**
   only a single leading digit is treated as a log level, matching the
   `base.log` / `base.logs` convention. this differs from `log.noerr`,
   which accepts any trailing integer (including negatives).

4. **`log.fmt` is a true `sprintf` wrapper.**
   it requires at least two arguments (format + one parameter, or level +
   format). a single-string call like `log.fmt('hello')` is an error; use
   `log.string('hello')` instead.

5. **do not manually register.**
   adding the `p7__log__*` sub definitions is sufficient. do not add a
   separate `%code{'log.string'} = ...` assignment; that would duplicate
   registration and could confuse the core-sub scanner.

## verification notes

- `perl -c bin/Protocol-7` passes.
- `./bin/Protocol-7 work -vvv overview` starts and exits cleanly.
- temporary post-init calls in `work.init_code` confirmed that
  `log.string` and `log.fmt` delegate correctly to `base.log` / `base.logs`.

#,,,,,,,.,,,.,,.,,..,,,.,,.,.,..,,,..,...,,,,,..,,...,...,.,,,...,.,,,...,...,
#56TNCKQSAMJXGGT5773PXZDBABXP2GMWYZGBVXTYRUTBTETMKFXX2UEB3WECUQPIBEUSJVIHWDFRY
#\\\|UV63OFSRVA2JCKSMJPAYBJ7SYWRNCKKYYBDS2Q7PI5N4M2A5T2U \ / AMOS7 \ YOURUM ::
#\[7]NW3VSZBFKZXT4RWALSVRJXO4ZKF6FXVFRRY7K3RVAIBWIJY2ZOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
