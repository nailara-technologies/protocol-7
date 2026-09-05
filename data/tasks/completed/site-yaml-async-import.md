## task: make site-yaml.cmd.import's search-page fetch non-blocking

### goal

`site-yaml.cmd.import` is the command jobsite actually triggers on its
recurring import cycle. it fetches up to `<site-yaml.import_max_pages>`
search-result pages **synchronously**, in a `for my $page` loop, calling
`site-yaml.stepstone.search` (which internally does a blocking
`LWP::UserAgent->get()`) and then, between pages, sleeping with a **blocking**
`select(undef,undef,undef,$delay_search)`. this is a separate blocking path
from `site-yaml.handler.fetch_tick` (already made non-blocking in
`data/tasks/site-yaml-async-fetch.md`, landed) — it does not route through
`fetch_tick` or the async worker at all.

confirmed live as the actual cause of a heartbeat kill, *after* the
`fetch_tick` fix landed:

```
:. si.,.ml : site-yaml.http.get : https://stepstone.de/jobs/devops-engineer/in-Offenburg => 500 read timeout
:. jobsite : : fetch-done [devops]: import queued: 0 new, 0 skipped, 0 errors
site-yaml.heart
..no response, will likely timeout..
```

that `site-yaml.http.get` call is `cmd.import` → `stepstone.search` →
`http.get`, not `fetch_tick`. fix this the same way, reusing the primitive
that already landed.

this is a **transport** change only — same ground rule as the prior task.
`cmd.import`'s filtering/dedup/block-file/early-break logic is settled and
must not change in *behavior*, only in *when* it runs (inside a callback
instead of inline in a loop).

---

### precedent to mirror

1. **`site-yaml.async_fetch.spawn` / `site-yaml.handler.fetch_io` /
   `site-yaml.handler.fetch_timeout` / `site-yaml.async_fetch.finalize`**
   (just landed, `data/tasks/site-yaml-async-fetch.md`) — the fetch worker
   itself. reuse it as-is, do not fork a second implementation of it.
   `finalize`'s `$on_done->($result)` contract is unchanged: content string
   on success, numeric HTTP code on failure.
2. **`coding.cmd.complete-analysis`** (real, landed code, not a sketch) —
   the deferred-cmd-reply pattern this task needs: capture
   `$call->{'reply_id'}`, stash it in a state hashref, `return { 'mode' =>
   qw| deferred | }`, and later call `<[base.callback.cmd_reply]>->(
   $reply_id, $reply_hashref )` from whatever handler eventually finishes
   the work — see `coding.handler.check-completion-chain` for the call
   site shape. read `src/base.callback.cmd_reply` too — it validates
   `$reply_id` is numeric and looks it up in `<base.cmd_reply>`, which
   `base.handler.command` populates automatically whenever a command
   returns `mode => deferred`; nothing to set up manually beyond capturing
   `$call->{'reply_id'}` and returning that mode.

---

### where to implement

new modules:

| file | role |
|---|---|
| `src/site-yaml.stepstone.search_from_html` | pure extraction, no fetch — the href-scraping logic currently inside `stepstone.search`, moved out verbatim (mirrors `stepstone.job_from_html` from the prior task) |
| `src/site-yaml.import.fetch_page` | spawn the async fetch for one search-result page, process its result on completion, decide continue/stop — the new state-machine step replacing one loop iteration |

modified:

| file | change |
|---|---|
| `src/site-yaml.cmd.import` | keep all argument parsing/validation (url, full_mode, reply_handler allow-list, skip ids, block_file parsing) unchanged; replace the `for my $page (1..$max_pages)` loop with: build one import-state hashref holding everything the loop body currently closes over, call `site-yaml.import.fetch_page` for page 1, `return { 'mode' => qw| deferred | }` |
| `src/site-yaml.stepstone.search` | becomes a thin wrapper: fetch via `site-yaml.http.get`, then delegate to `site-yaml.stepstone.search_from_html`. kept synchronous and byte-identical in behavior — still used by `site-yaml.cmd.fetch` via `site-yaml.extract` (out of scope, untouched) |

**explicitly out of scope — do not touch:**

- `site-yaml.cmd.fetch`, `site-yaml.extract`, `site-yaml.cmd.import-url`,
  `site-yaml.handler.fetch_tick` — all unchanged. `cmd.import-url` already
  just pushes one item onto the queue and returns immediately; it was never
  part of the blocking problem.
- `site-yaml.fetch.schedule` / `.state` / `.backoff` — unchanged, called
  exactly as today once page processing finishes queuing jobs.

---

### implementation spec

#### 1. `site-yaml.stepstone.search_from_html`

move `stepstone.search`'s body from `## extract all job page hrefs...`
(line 11 today) through `return \@jobs;` verbatim into this new file,
taking `($url, $html)` instead of `($url)`. no logic changes.

#### 2. `site-yaml.stepstone.search` becomes

```perl
my $url  = $ARG[0] // '';
my $html = <[site-yaml.http.get]>->($url);
return "fetch failed: $url" if not defined $html;
return <[site-yaml.stepstone.search_from_html]>->( $url, $html );
```

byte-identical behavior to today, still synchronous.

#### 3. `site-yaml.cmd.import` — the new tail

everything through block-file parsing and the `$allow_early_break`
computation (today's lines up to `my $max_pages = ...` / `my $delay_search
= ...`) stays exactly as-is. replace the loop and everything after it with:

```perl
my $import_id = <[base.gen_id]>->( $data{'site-yaml'}{'import_state'} //= {} );

$data{'site-yaml'}{'import_state'}{$import_id} = {
    'reply_id'         => $call->{'reply_id'},
    'url'              => $url,
    'reply_handler'    => $reply_handler,
    'skip'             => \%skip,
    'block'            => \%block,
    'full_mode'        => $full_mode,
    'allow_early_break'=> $allow_early_break,
    'max_pages'        => $max_pages,
    'delay_search'     => $delay_search,
    'page'             => 1,
    'queued_count'     => 0,
    'skip_count'       => 0,
    'err_count'        => 0,
};

<[site-yaml.import.fetch_page]>->($import_id);

return { 'mode' => qw| deferred | };
```

#### 4. `site-yaml.import.fetch_page`

```perl
## [:< ##

# name  = site-yaml.import.fetch_page
# descr = fetch one search-result page async, process it, continue or finish

my $import_id = shift;
my $st        = $data{'site-yaml'}{'import_state'}{$import_id};
return unless defined $st;

my $page_url = $st->{'url'};
if ( $st->{'page'} > 1 ) {
    $page_url .= ( $st->{'url'} =~ m{\?} ) ? '&' : '?';
    $page_url .= "page=$st->{'page'}";
}

<[base.logs]>->(
    1, '<import> fetching page %d of %d [break:%d]',
    $st->{'page'}, $st->{'max_pages'}, $st->{'allow_early_break'}
) if $st->{'max_pages'} > 1;

<[site-yaml.async_fetch.spawn]>->(
    "import:$import_id:page$st->{'page'}",
    $page_url,
    sub {
        my $raw_result = shift;

        my $links
            = ( $raw_result =~ m{\A\d+\z} )
            ? "fetch failed: $page_url"
            : <[site-yaml.stepstone.search_from_html]>->( $page_url, $raw_result );

        if ( ref $links ne qw| ARRAY | ) {
            <[base.logs]>->(
                0, 'import: page %d search failed : %s',
                $st->{'page'}, $links
            );
            ## note : today's code does NOT increment err_count here either ##
            ## -- preserve that exactly, this task is transport-only        ##
            return <[site-yaml.import.finish]>->($import_id);
        }

        if ( not @{$links} ) {
            return <[site-yaml.import.finish]>->($import_id);
        }

        my $page_new = 0;
        for my $link ( @{$links} ) {
            my $id = $link->{'id'};

            if ( length $id and $st->{'skip'}{$id} ) {
                $st->{'skip_count'}++;
                next;
            }

            if ( %{ $st->{'block'} } ) {
                my $blocked = 0;
                for my $field (qw| id url company city |) {
                    my $value = $link->{$field} // '';
                    next if not length $value;
                    my $sum = <[site-yaml.util.field-checksum]>->($value);
                    next if not length $sum;
                    if ( $st->{'block'}{"$field:$sum"} ) {
                        $blocked = 1;
                        last;
                    }
                }
                if ($blocked) {
                    $st->{'skip_count'}++;
                    next;
                }
            }

            push @{ $data{'site-yaml'}{'fetch_queue'} },
                {
                'id'            => $id,
                'url'           => $link->{'url'},
                'reply_handler' => $st->{'reply_handler'},
                };
            $st->{'queued_count'}++;
            $page_new++;
        }

        if ( $st->{'allow_early_break'} and $page_new == 0 ) {
            <[base.logs]>->(
                1, 'import: page %d all duplicates : stopping early',
                $st->{'page'}
            );
            return <[site-yaml.import.finish]>->($import_id);
        }

        if ( $st->{'page'} >= $st->{'max_pages'} ) {
            return <[site-yaml.import.finish]>->($import_id);
        }

        ## next page, after the same inter-page delay -- was a blocking   ##
        ## select() sleep, now a one-shot timer                            ##
        $st->{'page'}++;
        <[event.add_timer]>->(
            {   'after'   => $st->{'delay_search'},
                'repeat'  => FALSE,
                'handler' => qw| site-yaml.handler.import_next_page |,
                'data'    => { 'import_id' => $import_id },
            }
        );
    }
);

return;
```

`site-yaml.handler.import_next_page` is a two-line timer-handler shim:
`my $event = shift; my $import_id = eval { $event->w->data }->{'import_id'};
<[site-yaml.import.fetch_page]>->($import_id);` — add it as a 6th new
module, small enough not to need its own numbered section.

#### 5. `site-yaml.import.finish`

```perl
## [:< ##

# name  = site-yaml.import.finish
# descr = import page loop is done : queue fetch timer, reply, clean up

my $import_id = shift;
my $st        = delete $data{'site-yaml'}{'import_state'}{$import_id};
return unless defined $st;

if ( $st->{'queued_count'} and not defined $data{'site-yaml'}{'fetch_timer'} ) {
    <[site-yaml.fetch.schedule]>;
}

<[site-yaml.fetch.state]>->('save');

my $summary = sprintf 'import queued: %d new, %d skipped, %d errors',
    $st->{'queued_count'}, $st->{'skip_count'}, $st->{'err_count'};
<[base.logs]>->( 1, 'site-yaml.import : %s', $summary );

<[base.callback.cmd_reply]>->(
    $st->{'reply_id'},
    { 'mode' => qw| size |, 'data' => $summary }
);

return;
```

---

### pitfalls [ read before writing ]

- **the `$allow_early_break` and stale-queue-drop logic in today's
  `cmd.import` run once, before the loop, not per page** — keep them there,
  in the unmodified prefix of `cmd.import`, computed before
  `site-yaml.import.fetch_page` is ever called. don't recompute them inside
  `fetch_page`.
- **`err_count` is never actually incremented in today's code**, even on a
  search failure (`last` happens with no `$err_count++`). this looks like a
  latent bug but is explicitly **out of scope** — this task is a transport
  conversion, not a logic fix. preserve the existing (odd) behavior exactly;
  do not add the increment as a "drive-by fix."
- **worker ids must not collide with `fetch_tick`'s.** `fetch_tick` uses
  stepstone's own numeric job ids as worker ids in the same
  `<site-yaml.fetch_worker>` hash `async_fetch.spawn` keys into. the
  `"import:$import_id:page$page"` prefix above guarantees no collision —
  don't simplify it to a bare page number.
- **`site-yaml.import_state` must be cleaned up on every terminal path**,
  including the search-failure path — `import.finish` is the only place
  that deletes it; every early-return branch in `fetch_page` must route
  through `import.finish`, never `return` directly on a terminal condition.
- if a live instance is reachable, sanity-check that a second concurrent
  `cmd.import` call (before the first finishes) doesn't collide — each gets
  its own `$import_id` via `base.gen_id`, so this should already be safe,
  but confirm nothing in `import.fetch_page`/`import.finish` accidentally
  reads/writes without going through `$st` for the specific `$import_id`.

---

### what NOT to change

- the per-link skip/block-file filtering logic, verbatim — same conditions,
  same field list (`id url company city`), same checksum lookup.
- the stale-queue-drop block and reply_handler allow-list check at the top
  of `cmd.import` — untouched, still synchronous, still run before any
  async step begins.
- `site-yaml.fetch.schedule` / `.state` / `.backoff` — untouched.
- `site-yaml.stepstone.search`'s contract (string on success / numeric code
  on failure) — matches `site-yaml.http.get`'s existing contract, same as
  `stepstone.job` from the prior task.

---

### verify

```bash
grep -n "select( undef" src/site-yaml.*                 ## must be empty : no blocking sleeps left ##
grep -n "site-yaml.stepstone.search\b" src/site-yaml.*   ## should show search_from_html split cleanly ##
grep -n "err_count" src/site-yaml.import.fetch_page      ## confirm NOT incremented on search failure ##
bin/dev/ptd -c src/site-yaml.stepstone.search_from_html src/site-yaml.stepstone.search \
    src/site-yaml.cmd.import src/site-yaml.import.fetch_page \
    src/site-yaml.import.finish src/site-yaml.handler.import_next_page
```

### test plan

```bash
p7c site-yaml.import url=<a-real-stepstone-search-url>
## while pages are being fetched [ multi-page import, or add an artificial ##
## delay if testing single-page ] :
p7c site-yaml.heart          ## must reply immediately, not after import completes ##
```

the load-bearing check is the same as the prior task: `heart` must answer
while a page fetch is in flight. the reply to `site-yaml.import` itself
should arrive later, asynchronously, once all pages are processed — confirm
it still carries the same `import queued: N new, M skipped, E errors`
summary shape callers already parse.

---

## signatures_note

module files end with a 4-line `#,,,` AMOS7 data signature block. do not
hand-write or copy those blocks for new/changed files — leave signing to
`bin/Protocol-7 sourcecode update-signatures`. register the new modules
(`stepstone.search_from_html`, `import.fetch_page`, `import.finish`,
`handler.import_next_page`) in `cfg/zenki/site-yaml/subroutines.load-early`.

---

### dispatch

model: k2.7

prompt: |
  implement the task at data/tasks/site-yaml-async-import.md

  read src/site-yaml.async_fetch.spawn, src/site-yaml.handler.fetch_io,
  src/site-yaml.handler.fetch_timeout, src/site-yaml.async_fetch.finalize
  first — these already landed (prior task) and must be reused as-is, not
  reimplemented. note site-yaml.async_fetch.spawn's socketpair call uses
  Socket::AF_UNIX() / Socket::SOCK_STREAM() / Socket::PF_UNSPEC() (fully
  qualified, not bareword) -- a real bareword-under-strict-subs bug was
  found and fixed there after the fact; if you write any similar socket
  code, use the same fully-qualified form from the start.

  also read src/coding.cmd.complete-analysis and
  src/coding.handler.check-completion-chain for the deferred-cmd-reply
  pattern (capture $call->{'reply_id'}, return mode=>deferred, call
  base.callback.cmd_reply later) -- this is real, landed code, use it as
  the precedent, not a task-file sketch.

  the task file's code sketches are close to final but not gospel -- fix
  anything that doesn't actually compile or doesn't match this codebase's
  real primitives as you find them.

  read the "pitfalls" section before writing site-yaml.import.fetch_page --
  the err_count non-increment is a deliberately preserved existing quirk,
  not something to fix; do not add the increment.

  use $ARG not @_ where the file already does; lowercase comments; bracket
  annotations [ like this ]; do not touch the trailing signature blocks.

#,,,.,.,.,...,...,...,...,..,,,.,,.,.,,.,,...,..,,...,...,.,.,,..,..,,,,.,,.,,
#NUX65ZENLBUSOFRK5H4M7SQI2ZFRCYTVXFIYYXSLFLGTOAINGNHNFOJBSWDGV72CK5Z5XLX37Z4CC
#\\\|G2BA4F3MQRLJXCOHMJF5R2G6ZX55Y4KIYIETFOCH2JKZP3E52XK \ / AMOS7 \ YOURUM ::
#\[7]TKCQBXTZ3E2Q2OEOCVQ4UOK34WMZ322Y465ZQDB2NMWPQSJONYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
