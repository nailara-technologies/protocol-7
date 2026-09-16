---
name: project-note-trash-ntime-tools-landed-2026-09-16
description: "LANDED (3 commits): note.* trash-based safety net + confirm_all guard, task_id path-escape sanitizer (note.util.safe_id), base.parser.duration ntime/unix fix, note.*'s last_update switched unix->ntime, three new coding-zenka local-model tools (ntime_convert, checksum, vax_int_convert)"
metadata:
  type: project
---

Session 2026-09-16, commits `3a7d592d7`, `e095f27da`, `4092ea9a4`.
Triggered by a real incident: probing `note_delete({})` (see
[[feedback-tool-probe-empty-args-destructive-default]]) wiped all 38
sections of the coding zenka's `unknown` note task tree, unrecoverable
except for a partial rescue scraped out of live terminal scrollback.

## note.* trash safety (the fix for the incident)

- `note.delete($task_id, $section, $confirm_all)`: an omitted/empty
  `$section` used to mean "delete everything for this task" — now
  requires an explicit `$confirm_all` truthy arg for that path, returns
  an error otherwise. Single-section delete unchanged in shape.
- Every destructive note.* op (delete, merge-overwrite, update-replace)
  now stashes the prior content first via `note.trash.stash` (xz +
  base32, `<task_dir>/trash/<section>.<ntime>.mxz.B32` — same reasoning
  as jobsite.job.write's `.yxz.B32` trash format: file.write defaults to
  UTF-8 text mode, base32 keeps compressed bytes safe through it)
  instead of unlinking/overwriting outright.
- Recovery/management: `note.trash.list`, `note.trash.rescue`,
  `note.trash.prune` (age-based, default 30 days) — exposed as coding
  zenka tools `note_list_trashed`, `note_rescue`, `note_prune_trash`.
- `note.merge` previously clobbered an existing target section
  unconditionally on a name collision — now stashes it first, aborts if
  the stash fails rather than overwriting unrecoverably.

## path-escape hardening

`task_id` had **zero** sanitization anywhere in the note.* namespace
(unlike `section`, which was already character-filtered) — reachable via
10 coding-zenka tool handlers that forward `args->{task_id}` straight
into a path. A bare `.`/`..` survives a plain `[^a-zA-Z0-9._-]` filter
unchanged (no forbidden chars) while still resolving as a real path
segment. New shared primitive `note.util.safe_id` (character filter +
explicit `.`/`..`-run rejection) applied everywhere task_id builds a
path: `note.delete/update/read/history/init/categorize/tag`,
`note.trash.*`, and `note.merge`'s `task_id:section` source-spec parsing
(which had a live arbitrary-file-**read** angle via a crafted spec, not
just a write-side risk). Live-verified via `coding.eval-code` and a
`task_id: ".."` probe through multiple tools — resolves to `unknown`, no
escape.

## ntime/unix duration bug (found investigating the incident's `note_list` output)

`note_list`/`note_recent` showed durations like `-3216923380830.05s
ago`. Root cause: `base.parser.duration` lacked the ntime-vs-unix
magnitude-detection its sibling `base.parser.timestamp` already had, so
it subtracted a raw ntime value (`created`, always ntime-sourced) from
real unix time with zero unit conversion. **Do not re-derive a fix by
hand** — `base.ntime.delta_seconds($start_ntime)` already exists and was
established for this exact bug class in `coding.cmd.list-tasks`'s
2026-08-19 fix (`dd162183b`); `base.parser.duration` now uses it. Also
added an optional 3rd `$scale` param (`'unix'|'ntime'`) so a caller that
already knows its input's scale doesn't have to rely on the ambiguous
magnitude heuristic at all (a `0`/small ntime value is indistinguishable
from a genuine near-1970 unix time by digit count alone) — default
behavior unchanged for the ~19 pre-existing call sites, only
`note_list`'s `created` field passes it explicitly.

Per project preference ("ntime internally where it still makes sense"):
note.*'s `.meta` had `created` (ntime) and `last_update` (unix, via
`base.time`) mixed in the same object with no external-interop reason
for either to be unix — `last_update` switched to `<[base.ntime]>` too,
across all 5 writers (`note.write/update/delete/merge/tag`).

## three new coding-zenka tools (closes a context gap for the local model)

The model had no way to compute or interpret p7's own encodings it
constantly reads in file signatures, note timestamps, job ids:

- **`ntime_convert`**: ntime<->unix, base32r decode (comp-int-backed
  internally, no separate comp-int tool needed), `ago_seconds` cutoffs
  (e.g. for `note_filter`'s `after` param, which is ntime-scale now).
  Needed a new primitive, `base.u2n_time` — the missing inverse of
  `base.n2u_time` (unix->ntime never existed as a reusable primitive).
- **`checksum`**: amos / bmw (L13 short form only — bmw384 is a
  *different*, unrelated geometric-coordinate mapper for the iris
  visualization, not a hash) / elf / jha (hex\|b32\|b64u\|harmonized
  modes). Also nested AMOS child checksums via `nest_parent`
  (`AMOS7::CHKSUM::Nested::child_chksum` — real feature, confirmed via
  `bin/amos-chksum -nest`, not the vision-tier thing it first looked
  like; needed `<[base.perlmod.autoload]>->('AMOS7::CHKSUM::Nested')`
  since the coding zenka doesn't load the `amos.chksum` namespace that
  normally `use`s it).
- **`vax_int_convert`**: bidirectional plain-integer <-> vax-int
  (`base.vax-int.encode/decode`, already existed) — the compact id
  encoding jobsite job ids use.

Deliberately excluded: `bmw384` (wrong domain), truth-template/harmonic-
truth-assertion features (`AMOS7::Assert::Truth`, a separate deep
concept), `protocol.amos-chksum.ext-cmd.*` (stateful session protocol,
not a tool shape), `models.cmd.get_path_by_amos` (no concrete need
found), standalone `comp-int` exposure (no tool-friendly use case beyond
what `ntime_convert` already covers transparently).

## how to apply

- If a future note_delete/rescue/trash question comes up, this is
  already built — don't re-investigate or re-build it, check
  `note.trash.list`/`note.trash.rescue` first.
- If touching any other `note.*` module not listed above, check whether
  it builds a path from `task_id` and is missing `note.util.safe_id`.
- If a duration/timestamp display looks like garbage (huge/negative),
  suspect an unconverted ntime value before anything else — check
  `base.ntime.delta_seconds` exists and is being used.
- Before hand-rolling any ntime/unix/checksum/vax-int conversion logic
  anywhere in this codebase, grep for an existing primitive first (this
  session initially built a redundant ntime conversion before finding
  `base.ntime.delta_seconds` already existed for exactly that purpose).

#,,,.,..,,,..,,..,,,,,.,,,,..,,.,,,,.,,,,,..,,..,,...,..,,.,,,.,.,,,,,.,,,,,.,
#METAEPQ53XXE462DL6KSGEDHZREIQ4XTKNZS7XNIBJAJYT5UBUSYYWGVYVWDEHSIZKGLRO256676U
#\\\|7YSP63MZ3CYES2EIANDDGJAHNMWXJPHZEORZONVVHII6URNKHDR \ / AMOS7 \ YOURUM ::
#\[7]4DV4PLFBVWM2G4372TEKIH5LIC76GBJB2PU7MA2ITBRZXT6YECDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
