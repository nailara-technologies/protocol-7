## [:< ##

# name  = task: token/plan usage query tool for mcp-server-p7
# descr = expose the same usage info both Claude Code and Kimi's CLIs
#         show via their interactive `/usage` command as a programmatic
#         MCP tool, so a dispatching session (or a script) can check
#         quota state without a human reading the interactive UI

## context

filed 2026-09-15, motivated by an ordinary end-of-session check: the
user pasted their Claude Code `/usage` panel (session/context/weekly/5h
usage with reset countdowns) as plain conversational context this
session, multiple times, to help gauge how much budget was left for
`coding.lora_train_spawn` / Kimi dispatch decisions. Both CLIs
(`claude`, `kimi`) already have this data and render it on `/usage` --
the ask is to make it queryable by `bin/mcp-server-p7` instead of
requiring a human to run the interactive command and paste the result.

## why this isn't scoped yet -- read before implementing

quick investigation this session found no local state file backing
`/usage` in either `~/.claude` or `~/.kimi` (searched by filename for
"usage"/"quota"/"limit", nothing). The numbers shown (weekly % used,
reset-in countdown, 5h rolling window) are account-level state that
almost certainly lives on each provider's backend, not derived from
local transcript accounting -- meaning `/usage` is very likely a live
API call the interactive CLI makes at render time, not a local
computation. **Before writing any tool code, figure out how each CLI
actually gets this data**:

- does `claude` or `kimi` expose ANY non-interactive/scriptable way to
  get the same data (a flag, a `--json` output mode, an env var)? Check
  `claude --help` / `kimi --help` output, and whether either CLI has a
  documented API/config surface for this specifically.
- if not, is there an underlying API endpoint either CLI's `/usage`
  command calls that could be called directly (needs the CLI's own
  network traffic inspected, or its source/docs read, to find this --
  don't guess at an endpoint).
- Kimi's session state lives at `~/.kimi/sessions/<hash>/<uuid>/
  context.jsonl` (per `bin/mcp-server-p7`'s existing session reader --
  see its `_kimi_session_dir` / `_list_kimi_sessions` functions) -- worth
  checking whether local token-count accounting from transcripts could
  at least approximate SESSION usage (the "2.5k / 1M context window"
  line) even if weekly/5h plan limits stay unreachable without the
  live API.

## update, 2026-09-15 -- investigated further, conclusion changed

Confirmed both halves directly:

- **weekly/5h plan usage is a genuine live API call on BOTH platforms,
  not local computation** -- the user's own `/usage` invocations this
  session took ~100s ("Brewed for 1m 40s") to render, which is real
  network latency, not a local file read. No local state file backs it
  anywhere in `~/.claude` or `~/.kimi` (checked). Not pursuing a way to
  call that endpoint directly -- that would mean reverse-engineering a
  private API, which isn't something to do here; a quick pass over the
  installed CLI binaries' strings (both are large bundled Node
  executables, not plain source) turned up nothing application-specific
  anyway, just V8/Node/OpenSSL internals.

- **session/context-window token counts ARE fully readable locally, for
  both CLIs, with no API call**: Claude's session JSONL
  (`~/.claude/projects/<project>/<uuid>.jsonl`) has a standard Anthropic
  API `usage` object (`input_tokens`, `cache_creation_input_tokens`,
  `cache_read_input_tokens`, `output_tokens`) on every assistant message
  -- summing the input-side fields on the latest message gives current
  context size. Kimi's session JSONL
  (`~/.kimi/sessions/<hash>/<uuid>/context.jsonl`) is even more direct:
  periodic `{"role": "_usage", "token_count": N}` checkpoint entries
  with the running total already computed -- just read the last one.

**but this turned out to be the wrong number for the actual motivating
use case.** The point of this task was checking whether there's enough
quota left to keep dispatching work (`coding.lora_train_spawn`, Kimi
dispatches, etc.) -- and context-window fill answers a completely
different question (when will THIS conversation hit compaction) than
the rolling session-rate-limit / weekly-plan-percentage that actually
gates "can I keep working" (the user's own correction, mid-session: "that
token count of the current session will say nothing about session
limits, only about when compaction will likely occur"). Kimi's own
`/usage` panel even labels these as three separate meters -- "Session
usage", "Context window", and "Plan usage" are not the same thing, and
only "Context window" is the one sitting in the local JSONL.

## conclusion -- not building the originally-proposed tool

The genuinely useful number (rolling session / weekly plan %) has no
local source on either platform and isn't worth chasing via reverse-
engineering. The number that IS cheaply available locally (context-
window fill) answers a real but different, less critical question, and
shipping it under an "MCP usage tool" framing would be actively
misleading about what it tells you. **Closing this task without
implementation** -- if a future session wants context-window-fill
specifically (e.g. to predict compaction timing), the exact JSONL
fields/paths above are enough to build it directly, no further research
needed. Session-rate-limit / weekly-plan quota stays a "read `/usage`
yourself" number, no MCP shortcut planned.

#,,..,.,,,..,,.,.,.,.,,,,,,,,,...,..,,,,.,.,,,..,,...,...,,.,,,,.,..,,,.,,.,,,
#YDCLMAAW7QAXXVJSUPO5SSBSG5YSOPM3OVMYQZADB7YEB4LL65C36WRCSNEX6YTLHGWYYBQYITGX4
#\\\|ZND2E47UTDIL77P7PSMSZW2GA3CRWDYUS7C5EPHLMB2FS5NNCLS \ / AMOS7 \ YOURUM ::
#\[7]WDBNIRRHSWG5W6RLWXEZZJ443O2R4DSLMOMAAGQ74JRBGZEIMUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
