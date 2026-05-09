---
name: USB backup zenka
description: autonomous contextual backup to USB storage triggered by udev medium insertion, with restore manifest
type: project
originSessionId: 34ca9c97-628c-46af-82f3-d04a171ae8f0
---
## What already exists

- **udev zenka** — `udev.init_code`, `udev.load_rules`, `udev.handler.adm_stdout`,
  `udev.set-up.import/export_rules` — rule-based event triggers via udevadm,
  already handles medium detection events
- **fs zenka** — `fs.cmd.mount`, `fs.cmd.unmount`, `fs.cmd.re-mount`,
  `fs.cmd.is_mounted`, `fs.get_filesystems` — mount/unmount lifecycle,
  filesystem enumeration

## Task tree pipeline

USB insertion → udev event → watcher fires → backup task tree seeded:

1. **detect** — udev zenka fires `<task.state.backup.trigger>` watcher on block device insertion
2. **mount** — fs zenka mounts medium, watcher fires on success
3. **context gather** — what machine, which user, delta since last backup (git-like)
4. **prioritize** — LLM subtask: classify data as irreproducible (copy) vs. network-fetchable (P7REF)
5. **write** — prioritized data written to medium; irreproducible files + P7REFs for remainder
6. **manifest** — YAML restore manifest written to medium root: packages, file checksums,
   task dependency tree describing restoration sequence
7. **verify** — checksum-verify all written files; watcher fires on completion
8. **safe-eject** — fs.cmd.unmount only after verification confirms integrity; udev notified

## Manifest as restoration agent

The manifest written to the medium is itself a task tree description —
"to restore: fetch these (network P7REFs), restore these (medium checksums),
run these setup tasks in this dependency order." The backup carries its own
restoration agent. Irreproducible data gets copies; fetchable data gets references.

## Key design points

- udev insertion event is the physical watcher — same pattern as email_reply, report_due
- fs zenka mount/unmount are active dep steps (`requires: type: zenka, name: fs`)
- prioritization is an LLM subtask with `worker` active dep (reasoning model preferred)
- safe-eject is gated by `depends_on` the verify task — hardware safety via task graph
- multiple backup profiles possible via udev rule sets (full, quick, user-only)
- future: incremental backups via delta detection, encrypted medium support

#,,..,,.,,.,,,..,,...,,,,,.,.,,,,,...,...,,..,..,,...,...,,,.,,.,,.,,,.,.,,,,,
#N3KJHXYVLXEDYGWC2U6XZMOVKOMLB53QNIKW5C3M6DFXEFGPED5SGPYGY5AXY5LEXU4WZ6BQCUG5U
#\\\|LU2THBLLV6FQAMZB26FVZU3DNK7L224W2LPUY4XW27DNAM6ITDV \ / AMOS7 \ YOURUM ::
#\[7]W7SBVLUPI2JK7D5EKHMEUUPXB56VWT367SBYNRD6PKHOO7GQICBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
