## [:< ##

# name  = task: kimi zenka — model listing + switching via kimi-web's config API
# descr = the kimi zenka has zero visibility into or control over which
#         model the connected kimi-web backend runs. kimi-web's own REST
#         API already exposes this; add two commands wiring it through.

## context — verified live this session, not guessed

`kimi` is a P7 zenka (`src/kimi.*`) connecting as a client to a
manually-started external `kimi-web` process over websocket + a small
REST API. Do not touch `src/kimi-web.*` (separate, unrelated,
immature zenka-management layer).

The zenka predates K3's introduction and has no `model` concept anywhere
in `src/kimi.*` (confirmed by grep). Verified directly against the
live running `kimi-web` backend this session:

```
$ curl --noproxy '*' http://127.0.0.1:5494/openapi.json
```

relevant endpoints (full schemas in the fetched spec if you want to
re-verify — this was checked live, not assumed):

- `GET /api/config/` → `GlobalConfig` :
  `{ default_model, default_thinking, models: [ConfigModel, ...] }`.
  `ConfigModel` : `{ provider, model, max_context_size, capabilities,
  display_name, name, provider_type }`. Live response right now:

  ```json
  {
    "default_model": "kimi-code/k3",
    "default_thinking": true,
    "models": [
      { "name": "kimi-code/kimi-for-coding",           "max_context_size": 262144,  "capabilities": ["video_in","image_in","thinking"] },
      { "name": "kimi-code/kimi-for-coding-highspeed",  "max_context_size": 262144,  "capabilities": ["video_in","image_in","thinking"] },
      { "name": "kimi-code/k3",                         "max_context_size": 1048576, "capabilities": ["video_in","image_in","thinking"] },
      { "name": "kimi-code/k3-256k",                    "max_context_size": 262144,  "capabilities": ["image_in","thinking"] }
    ]
  }
  ```

  Note the real model-key names: `kimi-code/kimi-for-coding` is what
  this codebase's memory calls "k2.7" elsewhere
  (`data/ai-mem/claude/project-kimi-k2.7-vs-k3-tier-economics.md`),
  `kimi-code/kimi-for-coding-highspeed` is "k2.7-fast". Don't assume
  those memory-file short names are the literal API keys — they aren't.

- `PATCH /api/config/` → `UpdateGlobalConfigRequest` :
  `{ default_model?, default_thinking?, restart_running_sessions?,
  force_restart_busy_sessions? }`, returns `UpdateGlobalConfigResponse`
  (schema not yet inspected — check it live before relying on its shape).

**Important scope limit, confirmed from the schemas**: model selection
is **global to the kimi-web process**, not per-session.
`CreateSessionRequest` (`POST /api/sessions/`) only has `work_dir`/
`create_dir`; `UpdateSessionRequest` (`PATCH /api/sessions/{id}`) only
has `title`/`archived`. There is no per-session model override in this
API. Don't build anything that implies otherwise — a "set model" command
in this zenka changes what *new dispatches* run on globally, not what a
specific in-flight session uses.

## what to do

1. **Verify live yourself first** — re-run the curl commands above
   (remember `--noproxy '*'` or set `no_proxy=localhost,127.0.0.1`,
   proxy env vars intercept plain localhost requests in this
   environment) against the actual running backend before writing code,
   in case anything has changed since this task was written. Also fetch
   `UpdateGlobalConfigResponse`'s schema (not inspected here) so you know
   what a successful PATCH actually returns.
2. Extend `src/kimi.session.start_api_child`'s child mini-protocol
   (the `verify <url>` / `create <url> <json_body>` text commands already
   there) with two more: something like `get <url>` (generic GET,
   returns the JSON body) and `patch <url> <json_body>` (generic PATCH).
   Prefer generic verbs over hardcoding config-specific commands in the
   child, matching the existing pattern's shape — but use judgment if a
   generic verb doesn't fit the existing line-protocol cleanly.
3. Add `src/kimi.cmd.list-models` — calls the new `get` verb against
   `<kimi.web.base_url>/api/config/`, formats the `models` array
   (name, max_context_size, capabilities) plus which one is
   `default_model`, similar output style to `kimi.cmd.status`.
4. Add `src/kimi.cmd.set-model <model-name>` — validates the given
   name against the `models` list from a fresh `GET /api/config/` (don't
   trust a stale cached list), then `PATCH /api/config/` with
   `{"default_model": "<name>"}`. Decide live, after reading the
   `UpdateGlobalConfigResponse` schema and testing against a harmless
   no-op case first (e.g. re-setting the current model), whether to also
   expose `restart_running_sessions`/`force_restart_busy_sessions` as
   optional flags on this command or leave them false/omitted by
   default — err toward not force-restarting anything without the user
   explicitly asking, given this zenka's history of reconnect-related
   bugs fixed this session.
5. Update `src/kimi.commands`' help text (or wherever the command
   list shown by `p7c kimi.commands` is generated — grep for the
   existing command descriptions' source) so the two new commands show
   up there.
6. Read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/
   MEMORY.md` first — note the two gotchas already logged there from
   this session's earlier fixes: `<[module.name]>->(...)` vs
   `<module.name>->(...)` (bracket form required for subroutine calls),
   and the `$SIG{PIPE}`-at-DEFAULT danger if any test touches a real
   socket.
7. Live-verify: `p7c kimi.list-models` should show the real 4 models
   from the live curl above; `p7c kimi.set-model kimi-code/k3-256k`
   then `p7c kimi.list-models` again should show the new default; set it
   back to `kimi-code/k3` afterward so the live system isn't left on a
   different default than before this task ran.
8. No existing test harness for `src/kimi.*` — live verification via
   `devmod.cmd.eval-code` / direct `p7c` calls is the house-appropriate
   substitute, same as the two prior fixes this session.

## style / house conventions

- comments lowercase, `[ word ]` not `( word )` for annotations.
- do not commit — leave staged for the user to review/sign/commit.
- commit-message convention: state the concrete API surface used, what
  was added, and what was verified live.

## if you learn something non-obvious

Add to `data/ai-mem/kimi/coding-style.md` and/or `data/ai-mem/kimi/
MEMORY.md` in your own established format.

#,,,.,.,.,...,...,,.,,,,,,...,,.,,.,,,.,.,.,,,.,.,...,.,.,.,,,.,.,.,,,,.,,...,
#EZCUK2UNYGCBZFW7K5NMAPCMOTB3NNYEHHOLY4YKY47RZIQZQINKX35OMGPGE4HZYGLP4PSWCTCCC
#\\\|AVL6S4HCJYXQ3Q7537K7TE57OOB3PW7UCIZMIJDNIJ7YQTEQQOH \ / AMOS7 \ YOURUM ::
#\[7]P2Y265A4NEC743CMC663IDL3JBQLK45XNMKHGTJZP63CFLWG7KBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
