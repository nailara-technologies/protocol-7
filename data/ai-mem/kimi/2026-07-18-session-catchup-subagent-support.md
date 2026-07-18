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
- `_list_subagent_transcripts($s)`: unified per-client listing, hashrefs
  {id,type,descr,model,file,mtime}, sorted by mtime (kimi uses meta
  created_at). Also used for the list-mode marker.
- `_extract_subagent_text($s, $filter)`: per-transcript header
  `.:[ subagent N .[ type ]:. description [ model ] ]:.` + extracted body.
- List mode annotates sessions of both clients with `[+N sub]`.
- Result header notes e.g. `[subagents only: 1 transcript matching 'fable']`;
  clean isError when nothing matches.

### Verification (E2E over real MCP stdio + live coding zenka)

- claude subagents=2 + tail_chars=150000 on session 5d437747: 6 rolling
  chunks, accurate consolidated summary of fable+opus tier-2 derivation.
- kimi subagents=2 on live session: 1 explore transcript summarized correctly.
- claude subagent_id='fable': selected exactly 1 of 6 transcripts, accurate
  summary of the fable derivation (impossibility proof, decoder-as-witness,
  2000 trials / 0 false locks).
- filter no-match and no-subagents sessions -> clean isError, no inference.

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

#,,,.,,,.,..,,...,.,.,,.,,,,.,.,,,..,,.,,,.,,,..,,...,...,.,,,..,,,,.,,..,,..,
#WDSZEX2X45HJNS7RUPOPML5IQQRBL6ARIQ4ID43FEVWHKK676PRZN4KYWWD5NXLT26R74LIWYVFKI
#\\\|JF47G3XOYRFLTNFKB7QZIJHAPSZKPUBUTBFKHRL3JMRUZJZTG4Q \ / AMOS7 \ YOURUM ::
#\[7]HEHZ2UNJW5ML6SP5CP5RRBITYH5K3Q6ZUS3EUPBM6K67MAVGCUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
