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
