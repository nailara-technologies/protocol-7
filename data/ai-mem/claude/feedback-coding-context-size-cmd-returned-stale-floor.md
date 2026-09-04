---
name: feedback-coding-context-size-cmd-returned-stale-floor
description: two coding-zenka context-size bugs found together 2026-09-04 — coding.cmd.context-size returned the static config floor instead of the live server n_ctx (real but minor), and bin/mcp-server-p7's _model_chunk_size cached safe-context-size for the process lifetime, ignoring later model switches (the actual cause of "lighter model doesn't help")
metadata:
  type: feedback
---

`coding.cmd.context-size` (`src/coding.cmd.context-size`, exposed as the
`context-size` command in `cfg/zenki/coding/zenka.v7`'s `access.cmd`
list) used to return only `<inference.model.context_length>` — the
static configured floor (e.g. `42500`). `coding.spawn_inference_server`
auto-expands context above that floor when VRAM allows a smaller model
more room (log line: `context expanded to %d [auto > configured floor
%d]`), and stores the real value it launched with as `n_ctx` on
`<coding.inference_servers>->{$backend}` — but nothing ever fed that
back into what `context-size` reported. Fixed 2026-09-04: it now checks
`$server->{'n_ctx'}` first, falling back to the configured floor only
when no server is running.

**Turned out NOT to be what broke the dispatch/summarize model-switch
symptom** — verified live 2026-09-04: `coding.safe-context-size` (the
command `bin/mcp-server-p7` actually calls) was already correct even
before this fix (returned `144993` while plain `context-size` still
showed the stale `42500`), because `coding.cmd.safe-context-size`
reads `$server->{'calculated_ctx'}` from the live running server, not
the static floor. So this fix is real and worth keeping (anything else
calling plain `context-size` was still getting stale data), but it
was a red herring for the "switching models doesn't help" report.

**The actual cause of that symptom**: `bin/mcp-server-p7`'s
`_model_chunk_size()` (used by `_do_summarize`, the
`coding_summarize`/dispatch-summarize path — see
[[feedback-claude-dispatch-summarize-hang]]) cached the result of
`coding.safe-context-size` in a `my $model_context_tokens` **global**,
queried only once on first use and reused for the entire lifetime of
the long-lived `mcp-server-p7` process. Since that process outlives many
individual coding-zenka model switches, every summarize call after the
first was sized off whatever context happened to be live the very
first time, regardless of later model changes. Fixed 2026-09-04: removed
the global and the cache-once guard, now queries fresh on every call —
one cheap local `cube_command` round-trip, negligible next to the
summarize operation itself.

**How to apply:** when a "should be bigger/different now" value looks
stuck across a state change (model switch, config reload, etc.) in a
long-lived process, suspect a `my $x; unless (defined $x) { ... }`
cache-once pattern with no invalidation hook — grep the binary/module
for the variable name, not just the command it queries.

#,,,,,,..,,..,..,,.,,,...,...,,.,,.,.,,.,,,,.,..,,...,...,...,.,.,,..,.,,,..,,
#JD3Y4AGZSCTDI2BN4WE273AZH3AOB2VVAVVD7IUMEXKIAKR77BKZL5KXN2TYDYTU7DSALTYNC7UIW
#\\\|MYW4RHHDDJ7KU3T74UVB6OPRP7GCVCBF7ROHGB4IY3E76YWRKUY \ / AMOS7 \ YOURUM ::
#\[7]JV4PUIGXCO2ZFHWDWLFBJKFWXXHPR2CDD6MVSSOF3CJFCC65UODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
