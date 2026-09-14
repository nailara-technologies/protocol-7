---
name: reference-v7-zenki-dependency-resolve-self-heal
description: purpose of v7-zenki.resolve.object.zenka's "cascade-start" dependency hook -- brings manually/on-demand-started zenki back automatically when a base dependency (e.g. X-11) restarts, since they aren't in the system startup list
metadata:
  type: reference
---

## Why `v7-zenki.resolve.object.zenka` exists

Confirmed by the user 2026-09-14: this hook's purpose is specifically the **restart** case for a
base dependency like `X-11`. Zenki that depend on it (`compton`, `dbus`, `openbox`, ...) may have
been started manually or on-demand rather than being part of `v7-zenki.start_setup.globals.
zenki.enabled` (the system-boot auto-start list). Without this hook, once such a dependent got
stopped alongside X-11 going down, nothing would ever bring it back automatically when X-11 comes
back up — it isn't in the boot list, so nothing re-triggers a start for it. The hook is what makes
those dependents self-heal: they return the moment their dependency does, instead of requiring the
user to manually restart every dependent after every X-11 restart/crash-recovery.

## What actually happens, mechanically -- NOT an "attempt" or a spawn

Traced 2026-09-14 while investigating an apparently-alarming `[inference_server_sigchld]`-adjacent
log line: `v7-zenki.resolve.object.zenka` calls `zenka.cmd.start_once` → `zenka.cmd.start` with
`recursion => 1` (forces implicit start-mode). If the target's own dependencies aren't satisfied
yet, `zenka.cmd.start` does **not** spawn anything and does not retry/poll — it just calls
`dependency.ok`, sees it's false, and adds one `jobqueue` entry with `target_queue => 'depending'`.
That job sits completely inert (this is the `'waiting'` status `v7-zenki.list dependency <name>`
shows) until something else — the dependency actually coming online — calls
`jobqueue.check_dependencies`, which is what moves it to `'queued'` and lets it actually run. So
"cascade-starting" (the log's original wording, fixed this session) overstated it: there is no
attempt, only a dependency-wait registration.

`zenka.cmd.start`'s own manually-stopped guard (returns `'was manually stopped'`, no jobqueue entry
at all, if `$start_mode eq 'implicit'` and the target is in `<v7-zenki.zenka.manually_stopped>`) is
a **separate**, earlier short-circuit from the depending-queue path above — a deliberately-stopped
dependent doesn't even get this far.

## Log wording fixed this session

`v7-zenki.resolve.object.zenka`'s log line changed from `"cascade-starting zenka dependency
'$zenka_name'"` to `"zenka dependency '$zenka_name' not met -- queued, waiting on its own
dependencies"` — accurate to the depending-queue mechanism above, not implying an actual spawn
attempt.

#,,,,,..,,,..,.,.,,.,,,,,,,.,,..,,,..,.,.,,.,,.,.,...,...,...,.,,,...,..,,.,,,
#5U3M77FA3F6U5ZPNRXZYEIJ2JG6BEA7W7JOQT6S6U4JS5TT5PGFWI7YTLSXFB6ZGKULAUFSZSUQNU
#\\\|YBAOBXD6G65FDB3WFCOQCAVMYOFFFFQRYLIQYBTUJIQZB7CKIDF \ / AMOS7 \ YOURUM ::
#\[7]GESDNDBKPWNRFZOFFDKWW542RBDV2C7HXK4KAJMSCGKYLFARWKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
