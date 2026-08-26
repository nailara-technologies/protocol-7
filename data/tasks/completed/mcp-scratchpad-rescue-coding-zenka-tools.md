# mcp-server-p7 scratchpad tools → mirror as native coding-zenka tools

## context

commit 34cd626c9 (`mcp-server-p7: add session scratchpad support + scratchpad_import
tool`) added two things to `bin/mcp-server-p7`:

- `session_catchup` gained a `scratchpad=1` param: appends
  `/tmp/claude-*/<uuid>/scratchpad/` text to the session text before summarizing,
  routed through the coding zenka's local model (`_do_summarize` → cube →
  `coding.summarize-context`). token-free, already confirmed working.
- `scratchpad_import`: list (`all`/`imported`/`tmp`), raw single-file read
  (`file=`), and import-into-repo modes. import copies a session's
  `/tmp/.../scratchpad/` into `data/scratchpad/<bmw-L13 of the /tmp session
  path>/` with an `IMPORT-INFO` provenance record (original_path, session_tmp,
  session_uuid, bmw_l13, imported_at, files).

both were exercised this session (Sonnet, on `base`): imported 6 previously-staged
scratchpad dirs, triaged all 6 as droppable (pure ephemeral debug capture / design
assets already shipped elsewhere in the repo / a task-completion audit report gone
stale — checked directly against `data/tasks/completed/` and it had already
diverged from what the report claimed / research whose conclusion was already
shipped as `src/base.stream.frame.detect.harmonic`), and deleted them. the
triage heuristic that mattered: **before keeping an import, grep the repo for
whether the content already shipped, and for anything reporting task status,
check `data/tasks/completed/` directly rather than trusting a frozen snapshot** —
none of it needed to survive.

## what's being asked

both tools above are *reactive* — they only run when an external model (claude or
kimi) is alive, has token budget, and chooses to call them. the gap: nothing
rescues/categorizes leftover `/tmp/claude-*/<uuid>/scratchpad/` content when no
external session is driving it — e.g. both external model accounts have hit
their token ceiling, or a session just never got around to importing anything,
and a reboot is about to wipe `/tmp`.

wanted: mirror the scratchpad functionality as **native coding-zenka tools**
(same pattern as `read_file`/`search_code`/etc. in `coding.tools.definitions` +
`coding.tools.dispatch` — tool schema + dispatch entry gated on `exists
$code{'module.name'}`), so the coding zenka's own local model can run the
rescue+categorize job on its own timer, independent of any external LLM call.

## structural note: keying

`scratchpad_import` keys an imported dir by the bmw-L13 of the *session's*
`/tmp/claude-*/<uuid>/` path, because it works from one already-identified
session. a system-wide sweep has no single "current session" to start from — it
should instead **walk `/tmp/claude-*/<uuid>/scratchpad/` directly and use the
session uuid itself as the key** (same uuid that names the dir under
`/tmp/claude-*/` and the transcript under `~/.claude/projects/<project>/<uuid>.jsonl`),
computing the bmw-L13 only at the point of actually importing into
`data/scratchpad/<bmw>/`, to stay consistent with the existing repo layout.
`_scratchpad_list`'s `tmp` scope in `bin/mcp-server-p7` already has the
directory-walking logic to lift from.

## permission finding — verified, not assumed

checked directly (`ps`, `/proc/<pid>/status`, `stat`, `getfacl`) rather than
guessed:

- coding zenka process runs as uid/gid 777 (user `protocol-7`), **with
  supplementary group 1000 (`taeki`) already attached** — group membership is
  not the blocker.
- but `/tmp/claude-1000/` itself is created `0700` (`drwx------`), group bits
  `---`, no ACL. group membership currently grants nothing because the
  directory's group permission bits are all zero.

so the fix is a **scoped `chmod g+rx` on just the `scratchpad/` subdirectory**
of each session's tmp dir (not the whole session tmp dir, which may hold other,
more sensitive stuff) — done once by something already running as `taeki` (e.g.
`mcp-server-p7` itself, opportunistically, the first time it touches a session;
or a small hook). after that one grant, the coding zenka can read that specific
`scratchpad/` dir directly through its existing group membership — no privileged
relay process needed for this part, unlike the pattern `session_catchup` had to
use for the actual conversation transcripts (`~/.claude/projects/.../*.jsonl`,
different location/perms, not in scope here).

## proposed tools (names indicative)

- `scratchpad_list_all` — enumerate every `/tmp/claude-*/<uuid>/scratchpad/`
  dir system-wide, independent of any specific "current session" (port
  `_scratchpad_list`'s tmp-scope logic).
- `scratchpad_categorize` — read one scratchpad dir's files and produce a
  verdict (keep / drop / needs-human-review) with reasoning, via the coding
  zenka's own local-model call. default-droppable: pure ephemeral debug
  capture/instrumentation, generated preview assets already shipped elsewhere
  in the repo (grep to confirm), and status/audit reports whose claims no
  longer match live state (check `data/tasks/completed/` for task-status
  reports specifically).
- `scratchpad_rescue` — for dirs categorized "keep", perform the same import
  as `scratchpad_import` (bmw-L13 dest dir, `IMPORT-INFO` provenance). "drop"
  verdicts need no action — `/tmp` self-cleans on reboot.
- trigger: a periodic timer (coding zenka already has async/timer plumbing,
  see `coding.async_spawn_inference_servers`) running the sweep occasionally
  (hourly / on zenka startup), not gated behind an external LLM choosing to
  call a tool.

## out of scope here

reading `~/.claude/projects/.../*.jsonl` (the actual conversation transcripts)
directly from the coding zenka — that's a different location/owner/perms
situation and `session_catchup` already solves it by extracting text in the
privileged process and passing it as content. this task is scratchpad-only.

#,,..,,,,,,,,,,..,.,,,..,,.,,,...,.,,,...,,.,,..,,...,..,,.,.,,.,,...,,,.,,..,
#TMFPFGIJ3VJY47MKAKGE2V2B5FGSE5TNH6ZYGR2VKUHUTAKWA2B3VE3JGN4T7DMWAF4QPH56EUTMM
#\\\|PKOWVRFHW3N7PWCNLMRBXKLUMVZLK6L2ZKUHK6DOGTYU6XW6233 \ / AMOS7 \ YOURUM ::
#\[7]VQJPQETRKW2GXL6ANQ62KWOUQP6ZQ5GPOGMZBJCOQDKPSDDKHKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
