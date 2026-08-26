# task: fix base.log/base.logs API confusion — ~100 call sites

## background

`base.log` and `base.logs` look nearly identical at call sites (`<[base.log]>->(...)` vs
`<[base.logs]>->(...)`) but have different contracts:

- `src/base.log` — "generate a log entry". Signature (see file header):
  `args = log_level log_msg [log_buffer] [time-stamp]` — exactly those 4 positional args,
  shifted in that order. **It does not sprintf the message.** Passing more than 2-3 args means
  the 3rd lands in `$log_buffer` and the 4th in `$time_stamp` — silently misinterpreted, not
  used for template substitution.
- `src/base.logs` — "'base.log' sprintf wrapper". Does `sprintf(shift @ARG, @ARG)` on the
  template + remaining args, then calls `base.log` with the result. This is the one to use
  whenever the message has `%s`/`%d`/etc. placeholders and trailing arguments to fill them.

Confirmed live this session: `base.code.call_expected` called `<[base.log]>->(0, ':: expected
subroutine missing :. %s', $sub_name)` — the literal `%s` never got substituted (base.log just
logs the raw template string), and `$sub_name` (e.g. `'p7-log.buffer.local_logfile_write'`) got
passed through as `$log_buffer`, which then failed `base.buffer.add_line`'s name validation
(`^[\w\-_]{1,24}$` — too long, contains dots), producing a `base.s_warn`/`invalid buffer name`
spam loop. That specific instance is already fixed (this session, commit pending), along with 4
siblings caught by an initial narrower grep. A follow-up broader sweep found ~100 more.

## the pattern to fix

Any call of the shape:

```perl
<[base.log]>->( $level, "template with %s or %d", $arg1, $arg2, ... );
```

where the message string contains `%s`/`%d`/etc. **and** is followed by one or more additional
arguments that are clearly meant to fill those placeholders (not an intentional `$log_buffer`/
`$time_stamp` override — those are rare and would not correlate with `%` placeholders in the
message).

**Not a bug** — leave these alone:
```perl
<[base.log]>->( $level, sprintf( "template with %s", $arg ) );   ## already sprintf'd first ##
<[base.log]>->( $level, "plain message, no placeholders" );       ## no % anything ##
```

**The fix**: change `base.log` to `base.logs` at the call site. Nothing else changes — same
arguments, same order, `base.logs` sprintfs internally then calls `base.log` with the result.

## confirmed call sites (file:line, current as of this task file's writing — re-verify each,
## the exact line number may drift if the file was touched by something else first)

```
src/base.indexcube.pop:26
src/base.indexcube.reset:15
src/base.reload_whitelist:16
src/coding.handler.models_find_alternative_reply:14,26,34,39,44,51
src/coding.handler.models_get_entry_reply:14,22,31,36,41,46
src/coding.handler.models_list_all_reply:13,21,29,34,39
src/coding.handler.models_recommendations_reply:14,25,31,39,45
src/coding.handler.models_record_invocation_reply:15,29,37,42,49
src/coding.handler.models_resolve_path_reply:14,27,35,40,47
src/cube-13.cmd.jump:51
src/data.handler.indexer.notify:11
src/data.hooks.notify:16
src/data.hooks.register:28
src/data.mount.fuse.spawn:282
src/decoder.callback.reduce-entropy:48
src/decoder.cmd.erase-level:37
src/decoder.cmd.reduce-entropy:55
src/decoder.handler.on-boundary:32,58
src/decoder.zenka.receive_entropy:70
src/devmod.cmd.receive-multiline:10
src/httpd.handler.download_transfer.test:33
src/httpd.handler.download_transfer.test-broken:33
src/httpd.request_handler:19
src/httpd.route_dispatcher:35
src/httpsd.route_template_request:36,67,89,136
src/letsencr.child.cmd.query-algos:53
src/menu-commands.format-provider-data:24
src/models.attach_file:78
src/models.chat.invoke_model:23
src/models.cmd.conversation_add_turn:81,96
src/models.cmd.conversation_create:66
src/models.cmd.conversation_get_context:53,71
src/models.cmd.substitute_template:33,77
src/models.conversation.add_turn:84,99
src/models.conversation.create:55
src/models.conversation.get_context:44,62
src/models.list_attachments:48
src/models.template.substitute:22,66
src/plugin.web.space.cmd.context:35
src/plugin.web.space.grid.scan:17,74
src/plugin.web.space.index.load:15,26,49
src/plugin.web.space.index.persist:15,26,38,49,60
src/plugin.web.space.index.scan:17,95
src/protocol-7-menu.cmd.gfx-action-key:59
src/protocol-7-menu.cmd.menu-update:8,89
src/protocol.amos-chksum.connect_callback:15,38
src/protocol.sftp.connect_callback:51
src/source.signature_valid:130,168,188,193,200
src/ssh.connection.start:159
src/work.calculate_suggestion_relevance:92
src/X-11.start_gpu_metric_feed:28
src/zulum.init_code:30
```

That's the list from one detection pass — **do not trust it blindly**. Re-derive it yourself
before editing (files may have shifted line numbers, and the detection regex used to build this
list has known blind spots — it already missed `X-11.start_gpu_metric_feed`'s original instance
once because the message contained an embedded single-quote that broke a naive character-class
regex; that one is fixed as of this task, included above only for the sweep's completeness check).
A reliable re-derivation approach: for every `<[base.log]>->(...)` call in `src/`, check
whether the message argument contains `%s`/`%d`/etc. AND there are additional arguments after it
that aren't wrapped in their own `sprintf(...)` — `ncode search` or a careful multi-line-aware
script both work; a naive single-line grep will miss calls formatted across multiple lines (most
of the list above wraps arguments onto several lines).

## verification

- after fixing, re-run the detection sweep and confirm zero remaining matches in `src/`
  (excluding `subroutine.white-list` files, which just list sub names and will contain
  `base.log`/`base.logs` as plain text matches, not code).
- spot check a few fixed call sites read correctly in context (arg order didn't shift, no stray
  syntax error from the one-word rename).
- this is a pure rename at each site (`base.log` → `base.logs`), so no whitelist/
  `base.list.subroutines` regeneration should be needed — `base.logs` is already a real,
  always-loaded base module every zenka has.
- no live reload/functional test needed per site (100 files is too many to individually exercise)
  — but if convenient, pick 2-3 already-easy-to-trigger ones (e.g. `data.hooks.notify`, since
  hook registration/notification is easy to trigger) and confirm the message now renders with
  real values instead of literal `%s`/`%d`.

## signatures note

module files have a 4-line AMOS7 signature footer — do not reproduce or invent these. leave
edited files without a footer; the signing tool adds it. existing signatures on files you don't
touch must not be modified.

## dispatch notes

- this is a large but extremely mechanical, low-risk fix (one-word rename at ~100 well-identified
  call sites, same pattern every time) — good fit for `kimi_dispatch model=k2.7`, no design
  judgment needed, just careful, complete execution
- explicitly warn kimi not to touch any `base.log` call that's already using `sprintf(...)` or has
  no `%` placeholders in its message — those are correct as-is
- given the volume, this may need `kimi_continue` for multiple passes to get through the whole
  list without running out of turn budget — that's fine, just don't lose track of which files are
  done (kimi should re-run its own detection sweep partway through to check progress rather than
  trusting a static checklist that might drift)
- root-cause trail: this session's `v7` undef-sub sweep → `auth.client` fix → sys-deps wiring →
  `v7.ondemand_zenki` registry-wipe fix → live backend restart surfaced the `p7-log` crash-loop →
  traced to `base.log`/`base.logs` confusion in `base.code.call_expected` → broader sweep found
  this. See `data/ai-mem/claude/` for the fuller trail if useful context (not required reading).

#,,,.,..,,...,...,..,,,.,,,,,,,..,.,.,,.,,.,.,..,,...,...,...,,.,,,,,,..,,.,,,
#55IWNUBDYNQVUOVEJZ3OHFJ6ADWRFKAYVYAGLYYWK37TTQ4XMGHQXBQS5BKMBDP2D4H4A6RDJTMCW
#\\\|UB47DEOOKVPCIVWSBZRRJYB6UKONEWUVE3IURCZ7K4TKWB3CIXG \ / AMOS7 \ YOURUM ::
#\[7]NMUUYXRBXCNVU36O3UKH5LRQH4AJL77LX2ODRHFBFLSXWE74BUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
