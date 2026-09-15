## [:< ##

# name  = task: generic 'usage' zenka -- taeki-privileged usage tracking, cached for other zenki
# descr = a real zenka (not a script, not a cache file) that tracks
#         external (and later internal) usage/quota values, runs with
#         the privilege to actually fetch them, and lets other zenki
#         (coding first) get a cheap cached read without ever touching
#         the underlying credentials themselves

## context

filed 2026-09-15, arising directly from trying to give the coding
zenka's local model a way to check Claude/Kimi account usage
(`bin/dev/usage-external`, built and live-verified earlier this
session -- see `data/tasks/mcp-server-usage-query-tool.md` for the full
build history). The natural first instinct -- a coding-zenka tool that
just shells out to the script -- hit a real, correctly-enforced wall:
the coding zenka drops privileges to the `protocol-7` unix user
(`<system.amos-zenka-user>`, `cfg/system-user-map`), and `/home/taeki`
is `0700` owned by `taeki:taeki` -- `protocol-7` cannot read into it
under any environment override, and was never meant to have its own
Claude/Kimi CLI login at all. A privilege boundary, not a bug.

The user's proposal, which this task scopes: don't bridge the boundary
per-call. Build a proper `usage` zenka that runs with the actual
privilege (taeki's), fetches and caches the value on its own schedule,
and exposes only the parsed numbers to whoever asks -- the same shape
`sourcecode` zenka already uses for the signing-key password (a real,
existing precedent for "a taeki-privileged zenka other things query
without holding the privilege themselves"). Generalizes past just
Claude/Kimi -- "multiple types of usage" was explicit in the ask.

## the real precedent for zenka-to-zenka value caching, traced not assumed

`coding.handler.refresh_mem_stats` (timer) -> `system.mem-used` via
`protocol-7.route-send` with a reply handler ->
`coding.handler.system_mem_reply` parses the percentage and caches it
into `<coding.system_mem_pct>` + `<coding.system_mem_pct_time>`. Plain
**timer-poll-and-cache**, not STRM. STRM (used elsewhere in this
codebase for live coding-session output, see `data/tasks/coding-zenka-
session-ui.md`) is a heavier, higher-frequency, session-scoped
mechanism built for streaming task output -- not the right tool for "is
my weekly quota below 90%", which changes slowly. **Mirror the
memory-stats pattern exactly for phase 1**, not STRM.

## phased scope, not started

**phase 1 -- the `usage` zenka itself.**

- **privilege**: runs as `taeki:protocol-7` (user:group), NOT the
  standard `<system.amos-zenka-user>` (`protocol-7`) every other
  service zenka drops to. Real, resolved precedent: `powershell`
  zenka's `[root.drop_privs:<system.AMOS-user>.':'.
  <system.amos-zenka-user>]` -- `<system.AMOS-user>` resolves to
  `<system.admin-user>` (`cfg/X11-vars`), which resolves to `taeki`
  (`cfg/system-user-map`). Copy `powershell` zenka's `zenka.v7`
  drop_privs line exactly, don't re-derive it. This is what gives the
  zenka read access to `/home/taeki/.claude/.credentials.json` and
  `~/.kimi-code/credentials/` (both `0700`, `taeki:taeki` -- confirmed
  this session, `protocol-7` cannot read them under any env override).

- **HTTP transport: async zenka-native code, NOT a subprocess.**
  Corrected mid-scoping, 2026-09-15 -- first drafts of this task
  considered shelling out to `bin/dev/usage-external` (or an `IPC::
  Open3` spawn, matching `coding.spawn_inference_server`'s pattern for
  a long-running server process). Neither is needed: this codebase
  already has a real, working, non-blocking async HTTPS client --
  `clients.https.request` / `.get` / `.post` (`src/clients.https.*`).
  Non-blocking connect, deferred TLS handshake via `event.add_io`,
  HTTP/2-capable, callback-based completion (`on_done` handler,
  `{ok, error|body, params}`). Use this directly -- `clients.https.get`
  for Kimi's plain `GET /usages`, `clients.https.post` for Claude's
  `count_tokens`/`max_tokens=0` probes. No fork, no pipe, no exec-status
  race to manage. Credential-file reads themselves stay a plain
  synchronous local disk read (fast, not a blocking concern) inside
  whatever code constructs the request.

- **structure: `plugin.usage.[claude|kimi].*`**, one plugin per
  provider, per the user's own steer. Real, documented, multi-zenka
  convention -- NOT invented for this task, see
  `reference-plugin-namespace-loading-convention` in memory /
  `src/base.load_plugins`: a zenka declares `plugins.load = plugin.
  usage.claude plugin.usage.kimi` and `[load_plugins:<plugins.load>]`
  in its `zenka.v7` (placed after `[load_modules:<modules.load>]`,
  before `[init_modules]` -- mirror `cfg/zenki/web/zenka.v7`'s
  placement exactly). `load_plugins` only loads/tracks modules -- it
  provides NO generic dispatch/hook framework, so each plugin's actual
  calling shape is this task's own design choice. `plugin.storage.
  inference`'s dispatch-by-`{operation}` hash shape is the closest
  existing convention example to mirror (check it before inventing a
  different shape). Each plugin owns its provider's specifics --
  credential-file path/field names, endpoint URL, request/header
  construction, response-parsing (the max_tokens=0 free-path discovery,
  the `count_tokens`-never-carries-headers finding, Kimi's `usage`/
  `limits`/`usages`-fallback schema handling) -- all already
  live-verified working this session in `bin/dev/usage-external`,
  reuse that KNOWLEDGE directly, don't re-derive it, just reimplement
  the transport half as async `clients.https.*` calls instead of
  `LWP::UserAgent`.

- exposes a query command (e.g. `usage.claude` / `usage.kimi` / a
  combined `usage.status`) returning ONLY parsed numbers -- used %,
  resets-in, status labels -- never anything credential-shaped, same
  discipline `bin/dev/usage-external` already follows. Given the
  transport is now genuinely async, the command's own reply is
  necessarily async too (a callback/reply-handler shape, not a
  synchronous return) -- design this consistently with how other
  async-reply commands in this codebase already work (e.g. `coding.
  handler.system_mem_reply`'s reply-handler pattern, see phase 2 below)
  rather than inventing a new async-reply idiom.

- no polling loop needed inside `usage` zenka itself for phase 1 --
  answer on request is enough to start; a zenka-internal refresh timer
  (to keep a warm cached value ready before anyone asks) is a
  reasonable phase-1.5 addition, not required to ship something useful.

- `bin/dev/usage-external` itself stays as-is, independently useful
  standalone for a human running it directly -- this phase does not
  deprecate or replace it, just builds a separate, zenka-native path
  to the same underlying data for other zenki to consume.

**phase 2 -- coding zenka as first consumer, mirroring the memory-stats
pattern exactly.**
- a `coding.handler.refresh_usage_stats`-shaped timer handler,
  `protocol-7.route-send`ing to the new zenka's query command with a
  reply handler that caches into `<coding.claude_usage_pct>` /
  `<coding.kimi_usage_pct>` (or similar) + timestamps, matching
  `coding.handler.system_mem_reply`'s shape precisely.
- a `coding.tools.handler.*` + `coding.tools.definitions` entry so the
  local model can read the cached value as a tool call -- this is the
  actual "local model gets it when called" deliverable, and by this
  point it's a trivial cached-variable read, no subprocess, no
  credentials anywhere near the coding zenka's own process.

**phase 3 -- threshold-crossing events (later, not designed yet).**
- "process events at certain thresholds" from the original ask --
  could be a push-on-threshold-cross to a subscriber list, could reuse
  STRM once there's a real second consumer needing live push rather
  than poll-and-cache. Don't design this prematurely; phase 1/2 alone
  already deliver the actual near-term need.

**phase 4 -- dependency types that assert against a usage value (later,
not designed yet).**
- explicitly a DIFFERENT layer from `data/tasks/dependency-soft-hard-
  distinction.md`'s work, which is about ZENKA-availability dependency
  cascades (does zenka B's downness restart zenka A) -- this would be a
  TASK-level precondition/gate ("don't start this expensive task if
  usage > 90%"), not a zenka-restart mechanism. Related vocabulary,
  same project, genuinely different mechanism -- don't conflate them
  when this phase is designed.

## open, not yet decided

- exact command/data-var naming (`usage.*` vs something else -- check
  for a namespace collision with any existing `usage`-prefixed
  module first).
- whether `usage` zenka is always-on (like `system`) or on-demand (like
  `calc`) -- given it wraps a personal-account credential check, on-
  demand with an idle timeout may be the more conservative default,
  but this is a judgment call for whoever implements, informed by how
  `sourcecode` zenka itself is deployed (standalone/manual per
  CLAUDE.md, not v7-managed) -- check that precedent's actual startup
  model before deciding.
- whether phase 1 needs its own signing-key-style secret at all, or
  whether taeki-privilege (file read access) alone is the full
  boundary being enforced here -- likely the latter, since this is
  about *file permission*, not an additional secret layer, but worth
  confirming against the `sourcecode` zenka precedent directly rather
  than assuming symmetry.

no design/implementation work done yet -- this is a capture-for-later
task file only.

#,,,,,,,,,...,,..,,,.,,,.,.,.,...,..,,,,.,.,.,..,,...,...,..,,..,,,,.,...,,,,,
#CRBYZVG63DNU64KINY44QSDFXWBFSJZJASAVMNIRULQCLVPQPKOM6ORQA4BMQFJLDDNSD3XXU37BE
#\\\|QZ2TQULTISC7QIFBRHYZ64M2WN7OW7V53JNTYX4RXLMQWXRG3KJ \ / AMOS7 \ YOURUM ::
#\[7]AREOOOBNFJID2PO73GPSUD5AYC5R63I3DEHGTXFPWAEHJPXFSEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
