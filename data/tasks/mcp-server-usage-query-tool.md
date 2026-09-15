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

## proposed scope, not started

- an MCP tool (`mcp__protocol-7__claude_usage` / `kimi_usage`, or a
  single combined tool) returning whatever subset of {session context
  usage, weekly plan %, 5h rolling window %, reset countdowns} is
  actually obtainable per the investigation above.
- if only session-level (local, transcript-derived) usage turns out to
  be gettable without a live API call, that's still useful -- ship a
  partial tool rather than blocking on the harder weekly/5h numbers.
- consider whether this belongs in `bin/mcp-server-p7` directly (most
  of the existing Claude/Kimi session-reading infrastructure already
  lives there) rather than a new standalone script.

no design/implementation work done yet -- this is a capture-for-later
task file only, and the FIRST step for whoever picks it up is the data-
source investigation above, not writing tool code.

#,,.,,,,,,.,.,...,,..,,.,,,.,,,,.,...,..,,.,.,..,,...,..,,,,.,...,..,,..,,...,
#5KONBTS4WKENPVBSN5R5XVITLCRAKUQPXCKYXBXWWZGJSVIJF6TN5WIKLHBGVZMGTYIPBCIL34TIE
#\\\|P7PM2AZ4WQMFTEFTU6G7P6TSP3OLQOAV3KZ5I2DOJHOJFGCLAYH \ / AMOS7 \ YOURUM ::
#\[7]TUBO3HKB7U34UUCEJCE645EICX27PJLLIPKYJPTJDQKDZXFHUABA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
