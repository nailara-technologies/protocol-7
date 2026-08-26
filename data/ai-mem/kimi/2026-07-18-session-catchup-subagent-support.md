## 2026-07-18: session_catchup subagent transcript support [ claude + kimi ]

### What was added

`bin/mcp-server-p7` `session_catchup` supports subagent transcripts for both
clients. claude: `~/.claude/projects/<proj>/<uuid>/subagents/agent-*.jsonl`
with `.meta.json` sidecars (agentType/description/model). kimi:
`~/.kimi/sessions/*/<uuid>/subagents/<agent-id>/context.jsonl` with
`meta.json` (subagent_type/description/created_at) — same role/content schema
as the main context, so the existing extractor parses both unchanged.

- Tool param `subagents`: 0 = exclude (default), 1 = append transcripts to
  session text, 2 = summarize only the subagent transcripts (recover lost
  subagent context; transcripts persist on disk after agents close).
- Tool param `subagent_id`: case-insensitive substring filter over agent
  id/type/model/description (all matches included); implies subagents=2.
- Tool param `scratchpad` [ claude ]: append the session's /tmp scratchpad
  file contents [ test scripts/artifacts, volatile ] to the summary text.
  Size-capped [ 24KB/file, 120KB total ], binaries listed by name+size only.
  The volatile source path is injected in-band so summaries keep it.
- New tool `scratchpad_import`: imports a claude session scratchpad into
  `data/scratchpad/<bmw-L13>/` where the id is the checksum of the session
  tmp path WITH trailing slash [ same as `bin/bmw-L13 /tmp/claude-*/<uuid>/`
  — convention verified against user examples ]. Writes IMPORT-INFO with
  original_path/session_tmp/uuid/bmw/timestamp/count, preserves mtimes.
  `file=<name>` reads one scratchpad file raw [ 100KB cap ] instead.
  No session_id = list mode [ `list=all|imported|tmp` ]: merges repo and
  /tmp state keyed by bmw id, status column `repo` | `/tmp` | `repo+/tmp`
  [ re-import candidate ], file counts per side when both exist
  [ helper `_scratchpad_list`, computes would-be ids via _bmw_l13 of the
  session tmp path so /tmp entries line up with their future repo dirs ].
- List mode annotates sessions: `[+N sub]` [ both clients ], `[+N scr]`
  [ claude scratchpad files ].
- `_list_subagent_transcripts($s)`: unified per-client listing, hashrefs
  {id,type,descr,model,file,mtime}, sorted by mtime (kimi uses meta
  created_at). `_extract_subagent_text($s, $filter)`,
  `_claude_scratchpad_dir($uuid)`, `_extract_claude_scratchpad_text($uuid)`.
- Result header notes e.g. `[subagents only: 1 transcript matching 'fable']`,
  `[includes scratchpad: 5 files]`; clean isError when nothing matches.

### Verification (E2E over real MCP stdio + live coding zenka)

- claude subagents=2 + tail_chars=150000 on session 5d437747: 6 rolling
  chunks, accurate consolidated summary of fable+opus tier-2 derivation.
- kimi subagents=2 on live session: 1 explore transcript summarized correctly.
- claude subagent_id='fable': selected exactly 1 of 6 transcripts, accurate
  summary of the fable derivation (impossibility proof, decoder-as-witness,
  2000 trials / 0 false locks).
- scratchpad=1 + subagent_id='fable': scratchpad harness code summarized
  [ exhaustive L=2-6 + mid-frame shift tests ].
- scratchpad_import: id ADCZI54SBIRB4→CXTUKDMIFGBEI after switching the key
  to session-tmp-path; raw file read; empty/missing/file-not-found errors
  all clean. server `_bmw_l13` output verified identical to bin/bmw-L13.
- filter no-match and no-subagents sessions -> clean isError, no inference.

### /tmp/claude-1000 layout [ claude code session tmp dirs ]

`/tmp/claude-<uid>/<proj>/<uuid>/scratchpad/` — session work files [ regular
files, VOLATILE: gone on reboot ]. `tasks/<agent-id>.output` — symlinks to
the persistent subagent transcripts in ~/.claude [ already covered by the
subagents support; non-symlink .output files are background shell outputs,
duplicated in ~/.claude tool-results/ ]. First scratchpad import of session
5d437747 [ fable/opus frame-lock harnesses ]: data/scratchpad/CXTUKDMIFGBEI/.

### Notes

- perl gotcha: `scalar glob()` iterates instead of counting — collect into an
  array first (used in list-mode marker).
- running MCP server processes keep old code: clients must restart their
  session (or MCP connection) to pick up this change.
- DATA SIGNATURE footer of bin/mcp-server-p7 not regenerated (needs user
  passphrase; user re-signs themselves).
- recovered raw transcripts of that session also live in
  `data/md/recovered-subagents/` (copied there by the parallel claude session;
  originally extracted to data/recovered-subagents/ by kimi).

#,,..,.,,,.,.,...,,.,,...,,,.,...,,,.,,..,.,.,..,,...,...,...,,.,,,,.,.,.,,.,,
#35Z5NOLXJ2WNZXWXMXV5PNVYTAGJGGVKO3WZM4S5MBLPRHG6GSK7Q5S6GY7KCCJCXGR3N3TSCFAGM
#\\\|MYXKP3QX4FI6RBLLG24E566EVP5TV52F2OHWD6E6O6MQPYYPRFX \ / AMOS7 \ YOURUM ::
#\[7]ARS4MOENJTJBLQUIJ5IKRJPPH3FGFVQSEBR7MDCDKBDYOAXFQSCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
