# amos-term interaction prototype + SHM fixes [ 2026-08-04 ]

Task: data/yaml/coding-tasks/amos-term-interaction-plugin.yaml — buffer lifecycle
RESOLVED (dedicated named buffer `name:agent-interaction`, lazy window, Z-shift
scrollback; ask_user_stream needs only buffer name, no window handle).

Prototype modules live + verified headless in amos-term zenka:
- amos-term.interaction.ask [ core, mirrors nshell.bridge ]
- amos-term.handler.interaction-changed [ reply accumulation + delivery ]
- amos-term.handler.interaction-deliver [ default delivery endpoint ]
- amos-term.cmd.interaction-{ask,reply,status} [ test entry points ]
- amos-term.buffer-write now dispatches on_buffer_change [ re-entrancy-guarded,
  optional client_type param so writers filter their own writes ]

## BUGS FIXED in amos-term.buffer-create [ affect ALL SHM consumers ]

1. Whole-scalar assign `${$mmap_ptr} = "\0" x N` DETACHES the Sys::Mmap mapping →
   segment silently process-private, backing file never updated. Fix: in-place
   substr assignment.
2. Voxel data was addressed from mapping offset 0 = on top of the 512-byte P7SH
   header [ SHM_HEADER_SIZE ]. shm_ptr is now a data-region alias
   `\substr( $$mmap_ptr, header_size )`; raw mapping kept as shm_map_ptr — all
   consumers [ buffer-write, shift_z, erase, render ] transparently offset.

## GOTCHAS

- window client_name must match <regex.base.usr> [ alnum + - _ , NO dots ] —
  base.session.init rejects it otherwise.
- `reload source` ignores edits to already-loaded cmd modules [ known issue:
  data/tasks/loader-reload-stale-cmd-modules.md ] → use v7.restart <zenka>.
- new modules UNSIGNED → `bin/Protocol-7 sourcecode update-signatures` [ needs
  interactive key password ].

## Remaining on that task

timeout-degrade timer → record_question, inotify watcher on plugin dirs [ never
implemented despite docs claiming it ], plugin-type scaffolding, GTK window-open
path.

#,,,.,,..,..,,,.,,...,,,.,.,,,,.,,..,,,.,,,,.,...,...,...,.,,,...,.,,,.,.,.,,,
#F2ANWQMK6BAJSOEYN4FPVJ6BWYDGZCAMZ5JLLT4576GM7MHFLZ2N6JOHFMV4ESLQPMDYLHGZ5FZ5M
#\\\|GKPRBLJXPVW2PWK72JPXK3NW3AF3HU54RS3QM362TZ2LY7MF4QL \ / AMOS7 \ YOURUM ::
#\[7]E7XRHIV3UHDZJN3VK64S5KUB6FL3RC5LR4O6JPH2PBDLHAIPXKAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## remaining scope implementation [ 2026-08-09 ]

Completed the open items from data/yaml/coding-tasks/amos-term-interaction-plugin.yaml:

1. **5th plugin-type registration**: `<amos-term.plugin-types>` now includes
   `interaction` with hook `agent.query` and dir `modules/amos-term.plugin-interaction`.
   Scaffold file created: `modules/amos-term.plugin-interaction.init_code`.

2. **Timeout degrade timer**: `amos-term.cfg.interaction_timeout` defaults to
   300s. `amos-term.interaction.ask` installs a single-shot `event.add_timer`
   keyed to the attach_id. On fire, `amos-term.handler.interaction-timeout`
   writes a JSONL entry to `observations/questions.jsonl` (same shape as
   `coding.tools.handler.record_observation`) and calls the reply_handler with
   a timeout sentinel. Timer is cancelled on reply in
   `amos-term.handler.interaction-changed`.

3. **Inotify hot-reload watcher**: `amos-term.plugin-install_watcher` installs
   `base.inotify.install_io_watcher` once, then watches `modules/` for
   `amos-term.plugin-*` close-write/modify events. A changed file that is also
   in `<amos-term.plugin-loaded>` is reloaded via `base.load_code` and its
   loaded timestamp is refreshed. Plugin files live flat under `modules/`, so
   the watcher filters by filename prefix rather than watching non-existent
   per-type directories.

4. **GTK window-open path**: `amos-term.interaction.ask` now attempts
   `amos-term.window-open` on the dedicated buffer when `$ENV{DISPLAY}` or
   `<x11.display>` is present, autoloading Gtk3 first. Failure is logged and
   non-fatal; headless operation continues to work.

5. **Signatures**: all new/modified modules were left for
   `bin/Protocol-7 sourcecode update-signatures`; the tool requires the
   `proto-7.sourcecode` key passphrase, which is not available in afk mode.

## non-obvious gotchas

- **inotify**: there are no real `modules/amos-term.plugin-<type>/`
  directories; files are flat. Watch `modules/` and filter by
  `^amos-term\.plugin-` filename prefix.
- **reload mechanism**: use `base.load_code` directly on the changed module;
  the loader's staging/swap path handles already-compiled modules correctly
  for plugin files (unlike the known cmd-module deferred-stub issue).
- **timer data**: `event.add_timer` callback receives the Event object; pass
  context through `$event->w->data` and verify the pending state is still the
  same question before degrading (attach_id guard).
- **record_observation**: the timeout handler writes locally in the amos-term
  zenka_dir using the same JSONL shape as `coding.tools.handler.record_observation`
  because the coding namespace is not loaded in the amos-term process. A
  future cross-zenka route-send to coding could move this to the coding data
  dir if desired.

#,,,.,..,,.,.,.,.,,.,,...,,.,,,.,,.,.,..,,,.,,..,,...,...,,.,,,..,,,,,,.,,,.,,
#U3CYW5ANNTNFO3WIORM3YUAKNPQW6UVROFIHSJRNQW4BHOBAGN75DZHTI5CLLIM6HONMBIIQH54V4
#\\\|VTVADGZ5IVZUELORHNMOPMZ3ZV4ZXUYMRSGCMYPAQDCBGTOYX7U \ / AMOS7 \ YOURUM ::
#\[7]YQ7REMGOSR7DIC5XUX4LLCBUDUOUEBOLALON2SMUHNGH4RCMXWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
