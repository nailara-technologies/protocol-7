## task: retire site-yaml's fork-per-request worker, use clients.https.get instead

### goal

`site-yaml.async_fetch.spawn` (landed earlier today, `data/tasks/
site-yaml-async-fetch.md` + `-import.md`) forks a one-shot worker per
fetch, running `LWP::UserAgent` inside the child, specifically to get the
event loop off the hook for a blocking network call. That fixed the
heartbeat-kill problem, but flagged two real, separate follow-on issues,
both now resolved by other work landed today:

1. fork-per-request is a real memory-safety concern on low-RAM hosts (see
   `data/ai-mem/claude/project-site-yaml-async-fetch-fork-memory-risk.md`).
2. the underlying `LWP`-via-proxy fetch to stepstone.de was *also* silently
   failing the whole time regardless of forking, because of Akamai's
   ALPN-based bot mitigation (`LWP` is HTTP/1.1-only, cannot be fixed).

Both are now solved by `clients.https.request`/`.get` (commits `4c4ea552c`
— real HTTP/2 support, and the proxy-CONNECT-tunnel commit landed right
after it — read both task files for full background, this task assumes
that context). `clients.https.get` is genuinely non-blocking with **no
forking at all**, and was live-verified today through the real proxy
against the real stepstone.de target with a real `200` and real content
(via a temporary devmod test against the `proxy` zenka — same target URL
site-yaml's own queue was failing on).

This task retires the fork-based worker entirely and replaces it with
direct, non-forking `clients.https.get` calls, while keeping `fetch_tick`
and `import.fetch_page`'s own classify/backoff/retry logic **completely
unchanged** — same discipline as the original async-fetch task: this is a
transport swap, not a logic change.

---

### the callback-shape problem, and how to solve it — read before writing anything

`site-yaml.async_fetch.spawn`'s `$on_done` is a plain Perl closure, called
directly in-process. `clients.https.get`'s `on_done` must be a **named
subroutine in `%code`** (a string), because it gets invoked from a
different module (`clients.https.h2.send_request` or `clients.http.
handler.io`) via `$code{$state->{'on_done'}}->($result)` — it cannot carry
an arbitrary closure.

So this isn't a 1:1 drop-in swap at the call site. The fix:

1. **Keep `fetch_tick`/`import.fetch_page`'s call sites passing an inline
   closure, unchanged in shape** — only the function name they call
   changes (see "where to implement" below). This preserves the two
   already-correct, already-tested classify/backoff/retry closures
   byte-for-byte.
2. **The new `site-yaml.async_fetch.request($id, $url, $on_done)`** (same
   signature as the old `.spawn`) stashes the closure it was given in a
   small pending-request registry (keyed by a fresh id from `base.gen_id`,
   NOT `$id` itself — `$id` is a job/page id, not guaranteed unique across
   `fetch_tick` and `import.fetch_page`'s independently-running queues,
   and two in-flight requests at once is a real possibility now that
   neither queue blocks on the other), then calls `clients.https.get` with
   `on_done => 'site-yaml.async_fetch.reply'` and the registry key passed
   through `params`.
3. **`site-yaml.async_fetch.reply`** is the one named handler registered
   with every `clients.https.get` call site-yaml makes. It looks up (and
   removes) the pending registry entry by the key in `$result->{'params'}`,
   translates `clients.https.get`'s result shape (`{ok, status, body,
   error, params}`) back into `site-yaml.http.get`'s existing contract
   (content string on success, numeric code on failure — see next
   section), and calls the stored closure with that translated value.
   **This is the only place that needs to know both shapes exist.**

---

### result-shape translation — exact contract to preserve

`fetch_tick`/`import.fetch_page`'s existing closures both do:
```perl
my $raw_result = shift;
... = ( $raw_result =~ m{\A\d+\z} )
    ? ## treat as a numeric failure code ##
    : ## treat as fetched html, extract from it ##
```
so `site-yaml.async_fetch.reply` must produce exactly one of:
- **success**: `$result->{'ok'}` true and `$result->{'body'}` defined →
  pass `$result->{'body'}` straight through (this is already-decompressed
  text on the h2 path, per the HTTP/2 task's own body-decoding work).
- **failure**: anything else → pass a numeric code. Prefer `$result->{
  'status'}` if it's a real HTTP status (defined, nonzero — covers both
  a clean non-2xx response AND `ok=>FALSE` with a real status, which
  `clients.https.get` can return together). If there's no usable status
  (a transport-level failure — proxy/connect/TLS/timeout — `status` will
  be undef or 0 in that case per `clients.https.*`'s own contract), fall
  back to a synthetic code — reuse **599**, the exact value the old
  fork-worker's `async_fetch.finalize` already used for "no usable reply,"
  so any log-message/behavior keyed on that specific number elsewhere
  doesn't need to change either.

---

### where to implement

new modules:

| file | role |
|---|---|
| `src/site-yaml.async_fetch.request` | replaces `.spawn` — same `($id, $url, $on_done)` signature, calls `clients.https.get` instead of forking |
| `src/site-yaml.async_fetch.reply` | the one named `on_done` handler — registry lookup, result-shape translation, invokes the stored closure |
| `src/site-yaml.async_fetch.headers` | returns the verified browser-realistic header hashref (see below) — one place, not duplicated between the two call sites this task doesn't touch and doesn't need to |

delete (fully retired, nothing else references them — confirm with a repo-wide grep before deleting, don't just trust this list):

| file | why |
|---|---|
| `src/site-yaml.async_fetch.spawn` | replaced by `.request` |
| `src/site-yaml.async_fetch.finalize` | no more forked worker to finalize |
| `src/site-yaml.handler.fetch_io` | no more forked worker's pipe to drain |
| `src/site-yaml.handler.fetch_timeout` | no more forked worker to time out — `clients.https.get`'s own `timeout` param covers this now |

modify:

| file | change |
|---|---|
| `src/site-yaml.handler.fetch_tick` | the single `<[site-yaml.async_fetch.spawn]>->($id, $url, sub {...})` call becomes `<[site-yaml.async_fetch.request]>->($id, $url, sub {...})` — **only the function name changes**, the closure body is untouched |
| `src/site-yaml.import.fetch_page` | same : `<[site-yaml.async_fetch.spawn]>->("import:$import_id:page$st->{'page'}", $page_url, sub {...})` becomes `<[site-yaml.async_fetch.request]>->(...)` — same closure, only the function name changes |
| `cfg/zenki/site-yaml/zenka.v7` | add `clients.https` to `modules.load` (currently `auth.client net protocol io.unix ui site-yaml # devmod # <- <!>` — site-yaml does not load `clients.https` today at all) |
| `cfg/zenki/site-yaml/subroutines.load-early` | remove the 4 deleted modules' entries, add the 3 new ones |
| `cfg/zenki/cube/access.zenki` | the `v7.register_child` grant added earlier today for site-yaml's fork-workers (`access.cmd.usr.site-yaml`) is now dead — no more forking, nothing to register. Remove it, since leaving an unused permission grant around is the kind of thing that gets confusing later. |

**explicitly out of scope, do not touch**: `site-yaml.http.get`,
`site-yaml.stepstone.job`/`.search` (the synchronous fetch+extract
wrappers, still used by `cmd.fetch`), `site-yaml.init_code`'s LWP setup —
`cmd.fetch` still needs all of this and isn't part of this task. This
means `LWP::UserAgent` stays loaded in site-yaml's init_code; don't remove
it, `cmd.fetch` would break.

---

### the header set — required, not optional

Getting past ALPN alone is not enough (confirmed live earlier today — a
minimal request gets `RST_STREAM` from Akamai without a realistic header
set). `site-yaml.async_fetch.headers` must return exactly:

```perl
return {
    'user-agent'                => 'Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0',
    'accept'                    => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'accept-language'           => 'de-DE,de;q=0.9,en;q=0.8',
    'accept-encoding'           => 'gzip, deflate, zstd',    ## never br, see http2 task ##
    'upgrade-insecure-requests' => '1',
    'sec-fetch-dest'            => 'document',
    'sec-fetch-mode'            => 'navigate',
    'sec-fetch-site'            => 'none',
    'sec-fetch-user'            => '?1',
};
```
this is the exact set that got a genuine 200 with real content both in
today's standalone verification and in the live devmod test against the
real `proxy` zenka. Don't abbreviate it.

---

### proxy value — read the existing config, mirror its semantics exactly

`site-yaml.init_code` already has a `bypass_proxy` check:
```perl
if ( <[base.cfg_bool]>->( <site-yaml.bypass_proxy> // FALSE ) ) {
    $data{'site-yaml'}{'ua'}->no_proxy(qw| stepstone.de www.stepstone.de |);
}
```
`site-yaml.async_fetch.request` needs the equivalent decision for the
`proxy` param it passes to `clients.https.get`: if `bypass_proxy` is true,
pass no `proxy` param (direct connection, matching what `no_proxy` does
for the LWP path today); otherwise pass `$ENV{'https_proxy'} //
$ENV{'http_proxy'}`. `clients.https.get`'s `proxy` param is a caller
decision by design (see the proxy-CONNECT task's own design notes) — this
is exactly that caller making the decision, once, not the transport doing
it implicitly.

---

### pitfalls

- **registry key collision** — see the callback-shape section above. Use
  a fresh `base.gen_id`-issued key for the pending-request registry, not
  the job/page `$id` passed into `.request` — that id is not guaranteed
  unique across the two independent call sites (`fetch_tick` and
  `import.fetch_page`) that can now genuinely run concurrently, since
  neither blocks on a forked child anymore.
- **don't forget to actually delete the pending registry entry** once
  `async_fetch.reply` has looked it up and dispatched to the closure — a
  registry that only grows would be a slow, silent memory leak over a
  long-running zenka's lifetime.
- **the numeric-failure-code contract is a real, load-bearing string
  match** (`$raw_result =~ m{\A\d+\z}` in both untouched caller closures)
  — a status of `0` or an empty string would NOT match that pattern and
  would be silently treated as fetched HTML instead of a failure. Make
  sure every failure path in `async_fetch.reply` produces a genuinely
  positive integer (599 fallback, or a real HTTP status), never `0` or
  `''`.
- **`clients.https` must actually be added to site-yaml's `modules.load`**
  — it isn't loaded today at all. Don't just add the new `site-yaml.
  async_fetch.*` files to `subroutines.load-early` and assume `clients.
  https.get` resolves; without the `modules.load` change it won't compile.
- **repo-wide grep before deleting anything** — the task lists 4 files as
  safe to delete based on today's own knowledge that they were purpose-
  built for site-yaml only, but verify with `grep -rl` before removing,
  don't just trust this list blindly.

---

### verify

```bash
bin/dev/ptd -c src/site-yaml.async_fetch.request src/site-yaml.async_fetch.reply \
    src/site-yaml.async_fetch.headers src/site-yaml.handler.fetch_tick \
    src/site-yaml.import.fetch_page
grep -rln "site-yaml.async_fetch.spawn\|site-yaml.handler.fetch_io\|site-yaml.handler.fetch_timeout\|site-yaml.async_fetch.finalize" src/*.* cfg/zenki/*/*.* 2>/dev/null
## should be EMPTY after this task -- if anything still references the old names, something was missed ##
```

### test plan

no live zenka access assumed (same as the proxy-CONNECT task) — static
verification plus a hand-trace of both closures against the new
`async_fetch.request`/`.reply` pair is sufficient for the dispatch itself.
Live verification against the real site-yaml zenka (`p7c site-yaml.
import-url url=<a real stepstone job URL>`, confirm `site-yaml.heart`
still answers immediately and the job actually gets queued rather than
logging `fetch failed`) will be done independently afterward.

---

## signatures_note

module files end with a 4-line `#,,,` AMOS7 data signature block. do not
hand-write or copy those blocks for new/changed files — leave signing to
`bin/Protocol-7 sourcecode update-signatures`. register the 3 new modules
and remove the 4 deleted ones in `cfg/zenki/site-yaml/subroutines.load-early`.

---

### dispatch

model: k3-256k

prompt: |
  implement the task at data/tasks/site-yaml-retire-fork-use-clients-https.md

  read data/tasks/site-yaml-async-fetch.md, data/tasks/site-yaml-async-import.md,
  data/tasks/clients-https-http2-support.md first for full background --
  this task assumes you understand why the fork-based worker existed, why
  it's being retired, and what clients.https.get already does correctly.

  the "callback-shape problem" section is the one genuinely tricky part of
  this task -- read it twice before writing site-yaml.async_fetch.request
  or .reply. clients.https.get's on_done must be a named sub, not a
  closure; the existing callers pass closures and must keep doing so
  unchanged. the registry-key design solves this -- don't invent a
  different mechanism.

  the header set section is not a suggestion -- use that exact set, it's
  live-verified, not a starting point.

  read the "pitfalls" section, especially the numeric-failure-code
  contract -- getting this wrong (returning 0 or '' on a transport
  failure instead of a positive integer) breaks the existing, untouched
  caller logic silently, in a way static syntax checking won't catch.

  use $ARG not @_ where the file already does; lowercase comments; bracket
  annotations [ like this ]; do not touch the trailing signature blocks.

#,,..,...,...,.,,,,..,...,,,,,.,,,.,.,.,,,.,,,..,,...,...,..,,,,.,..,,.,.,,.,,
#2DAYLQFI4ZFCNZN56PTW7XNOAD3GIVOCBF4LCSATCGE4I6N7FLLRH2TWDKSAJNV7QS4SBAVZHWNDA
#\\\|QF2AO43IPHN7OQQAOXN6YYGBMQXNDAJOUYSL4T5YS3KIYHQOH47 \ / AMOS7 \ YOURUM ::
#\[7]3CFQ3FE3UY5QJ3GKGSFNWKTZCSJH7TESLVIJ5TJVJ4TVJ6LSPEDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
