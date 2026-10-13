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

## update, 2026-09-15 (later same day) -- endpoint archaeology round

read-only follow-up: found the actual endpoints both CLIs use. no
traffic interception, no auth attempts, no endpoint calls -- everything
below is from `strings` on the two binaries plus `--help` output.
Key discovery that unblocked this: **both binaries DO contain their
application JS as greppable text.** the earlier narrow
`strings | grep -i usage` pass failed from signal drowning (Node/V8/
ICU internals also match "usage"), not from V8 code-cache packaging.
kimi's bundle is even unminified-ish source with `//#region` path
markers (e.g. `//#region ../../packages/oauth/src/managed-usage.ts`);
claude's is minified but its string table + call sites are intact.

### kimi: endpoint + payload fully recovered (high confidence)

from `packages/oauth/src/managed-usage.ts` in the binary:

- **endpoint**: `GET {KIMI_CODE_BASE_URL ?? "https://api.kimi.com/coding/v1"}/usages`
  (env `KIMI_CODE_BASE_URL` overrides; `.ai` mirrors of the same host
  exist in the region config). headers: `Authorization: Bearer <oauth
  access token>`, `Accept: application/json`, 8s AbortController timeout.
- **response payload** (from `parseManagedUsagePayload`): object with
  `usage: {used, limit, resetTime, name?}` (the weekly summary row;
  defaults to a 1-week window if absent), `limits: [{detail:
  {used, limit, resetTime}, name, window: {duration, timeUnit:
  "TIME_UNIT_MINUTE|HOUR|DAY|WEEK"}}]` (the per-window rows, e.g. the
  5h rolling window -> rendered as "5h limit ... resets in 4h 12m"),
  and `boosterWallet: {balance, monthlyChargeLimit, monthlyUsed,
  monthlyChargeLimitEnabled, currency}` (the "Extra Usage" section).
- **token source**: OAuth access token managed by `KimiOAuthToolkit`,
  stored under `~/.kimi-code/credentials/` (FileTokenStorage),
  auto-refreshed via `ensureFresh()` against oauth host
  `https://auth.kimi.com` (client id `17e5f671-...`). the CLI refreshes
  it before the `/usages` call, so a caller piggybacking on the same
  storage would need the same refresh dance (or piggyback on the CLI).
- adjacent endpoint discovered en route: `GET {base}/me`
  (`managedUserInfoUrl`) -- account info, same auth.
- only the "Plan usage"/"Extra Usage" sections of `/usage` hit this
  endpoint; "Session usage" and "Context window" stay local, matching
  the earlier finding.

### claude: endpoint + response shape recovered (high confidence on
path, good confidence on host)

from the minified bundle (`ugs` table + `pXn()` call site) and the
config object `_` in the binary:

- **endpoint**: `GET /api/oauth/usage` with two variant query flags:
  `?at_wall=1&skip_spend=1` and `?cedar_ember=1&skip_spend=1`
  (feature-flagged variants; plain is the default). 5s timeout,
  `refreshOAuth: true` (401 -> token refresh -> retry), per-host
  in-flight dedupe.
- **host**: the fetch client's origin resolves from
  `CLAUDE_AI_ORIGIN = "https://claude.ai"` (env-overridable, staging
  variant exists), so the full URL is
  `https://claude.ai/api/oauth/usage`. (Same-origin family:
  `/api/oauth/organizations/:orgUUID/...`, `/api/oauth/account/...`
  all live on the claude.ai web origin; `api.anthropic.com` serves the
  model API + `/api/oauth/claude_cli/*`.) One caveat: the host comes
  from a helper chain (`W0r()` -> `CLAUDE_AI_ORIGIN`) rather than a
  literal concatenation in the call site, so confidence is "read the
  config table + client binding", not "saw the exact URL string".
- **response items** (from the UI mapping code): entries with
  `scope.model.display_name`, `percent`, `resets_at`; the `/usage`
  panel renders titles like `Current week (Claude Sonnet 4)` with
  `limit: {utilization, resets_at}`. i.e. weekly/5h per-model
  percentages + epoch reset times, exactly the numbers the panel shows.
- **second, header-based channel**: every model API response on
  `api.anthropic.com` carries `anthropic-ratelimit-*` headers (seen in
  the binary: `anthropic-ratelimit-unified-5h-utilization`,
  `...-7d-utilization`, `...-overage-period-monthly-utilization`,
  `...-slow-budget-utilization`). These feed the status-line meter and
  the hook-context `rate_limits` block (`five_hour` / `seven_day` /
  `spend_limit`, each `{used_percentage, resets_at}` epoch seconds) --
  documented right in the binary's hook-context schema comment. So for
  claude there are TWO usage channels: the `/api/oauth/usage` fetch for
  the interactive panel, and ratelimit headers on normal model calls.
- **logging switches**: `claude -d api` / `--debug-file <path>`;
  the debug group `api_usage_fetch` logs `fetchUtilization: GET
  /api/oauth/usage (attempt N)` -- the cheapest way to watch the CLI
  make this call for real, if ever needed.

### scriptable surface: still none on either side

- `claude`: no `usage` subcommand (`claude usage --help` just reprints
top-level help), no `--json` usage dump. `--help` has no usage flag.
- `kimi`: subcommands are export/fork/provider/session/acp/web/server/
login/doctor/vis/migrate/upgrade -- nothing usage-shaped. `--help`
  likewise clean.

### misc findings

- kimi logging: bundled undici honours Node's `NODE_DEBUG=fetch` /
  `NODE_DEBUG=undici` (`util.debuglog("fetch")` call sites in the
  bundle); `KIMI_CODE_DEBUG=1` only gates a step-timing TUI display,
  not HTTP logging.
- accompanying files: neither install ships asar/resource bundles.
  `~/.kimi-code/` extras are cache (query-store = vector/embeddings
  store, client-configs, banner), logs, oauth/credentials dirs --
  nothing usage-shaped. `~/.local/share/claude/` contains only version
  binaries. No third place to look locally.

### does this reopen the task?

It changes the *feasibility* picture, not the *desirability* one.
What was closed as "would need reverse-engineering a private API" is
now "the API surface is fully documented in the local binaries" --
endpoint, auth scheme, payload schema, refresh flow, for BOTH platforms.
A `bin/mcp-server-p7` tool could, in principle, read the same on-disk
credentials (`~/.kimi-code/credentials/`, and for claude the keychain/
`~/.claude` oauth token storage -- NOT inspected here, credentials were
out of scope) and call these endpoints directly. Whether it SHOULD is
unchanged from the closure rationale: it piggybacks a private,
undocumented, ToS-grey API on both sides, breaks silently when either
vendor changes it, and duplicates what `/usage` already shows a human.
Also note the closure's core point still stands -- the motivating number
is "can I keep dispatching", and both endpoints answer exactly that,
but reliability/friction of a credentials-carrying MCP tool vs. a human
reading `/usage` once a session is a judgment call, not a research gap.
No code written; no endpoints called; nothing implemented.

## update, 2026-09-15 (later still) -- reopened for real: built, live-
## verified, working

The user made the judgment call the previous section left open: this is
their own account, their own already-authorized OAuth token, the same
data the official client already fetches for them -- reading it
programmatically is not meaningfully different from a human reading
`/usage`, just without the ~100s round trip for a number you check
often. Built as **`bin/check-usage`** (standalone script, `bin/is-true`/
`bin/amos-chksum` convention -- `BEGIN` + `data/lib-path/pm`, not a
zenka module), by Kimi dispatch, live-tested against both real accounts
before being called done.

**Kimi channel: genuinely free**, a plain `GET /usages` with no model
call at all. Credential found at `~/.kimi-code/credentials/kimi-code-
env-*.json` -> `access_token` (short-lived, ~15min; script warns and
suggests `kimi` re-run if near expiry rather than implementing the
refresh dance itself).

**Claude channel: the free path doesn't actually work** --
`POST /v1/messages/count_tokens` was verified LIVE to return zero
`anthropic-ratelimit-*` headers despite being Anthropic's documented
no-cost endpoint. Real, confirmed negative, not assumed. Falls back to
a `max_tokens:1` call (~9 tokens total, the minimum that returns the
header set) only when the free probe comes up empty -- re-probed fresh
every run in case Anthropic ever adds the headers to `count_tokens`
later. Credential at `~/.claude/.credentials.json` ->
`claudeAiOauth.accessToken`, confirmed exact path this session.

**Cloudflare note**: the interactive-panel endpoint
(`claude.ai/api/oauth/usage`, from the "endpoint archaeology" section
above) is bot-protected and deliberately NOT used -- spoofing past that
would be actively defeating an anti-bot measure, a meaningfully
different and more adversarial thing than using a stored token against
a standard API endpoint. The ratelimit-header channel on
`api.anthropic.com` (the actual model-serving API host, not the
consumer web app) was the point of pivoting away from it.

Live output at build time (Kimi's, 7 day matches the user's own
`/usage` screenshot from earlier this session almost exactly -- 85%
both):
```
== Kimi plan usage ==
  plan usage   : 79 / 100  ( remaining 21 )
  resets       : ... ( in 1d 7h 22m )
  5 hour       : 12 / 100  ( remaining 88 )
  resets       : ... ( in 2h 22m )

== Claude rate limits ==
  5 hour       : 3.0% used
  resets       : ... ( in 4h 37m )
  status       : allowed
  7 day        : 85.0% used
  resets       : ... ( in 1d 4h 7m )
  status       : allowed_warning
```

Credential values are never printed anywhere in the script (verified by
direct read-through of the full 403-line file, plus a grep for
Bearer-token-shaped strings -- none found). Pending: needs
`bin/Protocol-7 sourcecode update-signatures` (password-gated, left a
marked placeholder rather than faking a footer).

**Status: done.** This closes the loop the earlier sections opened --
feasibility was established via binary archaeology, then actually built
and verified rather than left as a research note.

#,,.,,,..,.,.,,.,,...,,.,,...,,.,,...,.,,,,..,..,,...,...,..,,...,,..,,,,,,,,,
#2NOKEVCVP5J6CPAURQK2KAZUP563N4SH3CAGSCL3MVQ626IN2NGLT5EUEGXEUQY3GMG3F76SMM5EY
#\\\|MKN7MZ5TGFWDZYSOULLQTAR6KTSLHI4AOGNHC4MN7HZEOGJTXAT \ / AMOS7 \ YOURUM ::
#\[7]Q2MRRIWD7RMF6ZR63LNCWQLYDQ5RVAI5TUKY2VKWTJWB56K75OBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
