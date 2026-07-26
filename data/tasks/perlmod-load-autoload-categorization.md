# perlmod load/autoload categorization — read-only classification pass

**Priority:** Medium
**Type:** Categorization only — DO NOT edit any code in this task
**Model:** kimi K2.7

## Before you start

Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md`
first — they document Protocol-7 conventions you need (P7 macro syntax,
`<[module.name]>` call form, `base.logs` vs `base.log`, etc.) even though
this task is read-only.

## Background

`base.perlmod.load` / `base.perlmod.autoload` both eagerly call
`Module::Load::{load,autoload}` the moment the statement executes — there is
no deferred/lazy behavior in either. When a module gets loaded via one of
these wrappers inside a per-call handler (a `.cmd.*`, `.handler.*`, or
similarly frequently-invoked file) instead of once in that zenka's
`*.init_code`, the wrapper logs `": skipping already present '%s'..,"` at
verbosity level 2 on every single call after the first. That noise is
**intentional** — a deliberate nag that a redundant load call should be
moved to `init_code`, not silenced (see
`data/ai-mem/claude/feedback-perlmod-load-noise-is-intentional.md` if you
want the full history; two real fixes already landed this session:
`Perl::Tidy` moved into `coding.init_code`, `AMOS7::Twofish` moved into
`p7-log.init_code`).

152 more call sites exist outside `*.init_code`/`*.pre_init`/`*.post_init`
files (a static grep found them, listed below) — this task is to
**classify each one**, not fix it. A separate follow-up task will do the
actual refactor once this classification is reviewed.

## The 152 files

```
modules/base.auth.set_v7_key
modules/base.chk-sum.bmw384.angle-bits
modules/base.chk-sum.bmw384.arc-segment
modules/base.chk-sum.bmw384.color
modules/base.chk-sum.bmw384.color-dist
modules/base.chk-sum.bmw384.coordinate
modules/base.chk-sum.bmw384.coordinate-str
modules/base.chk-sum.bmw384.group
modules/base.cmd.dependencies
modules/base.devmod.dump_var
modules/base.event.add_var
modules/base.file.chown_all
modules/base.file.temp
modules/base.file.tie_array
modules/base.gtk.attempt_load.glib_event
modules/base.gtk.ensure_display
modules/base.gtk.main_loop
modules/base.handler.read.encryption-wrapper
modules/base.handler.write.encryption-wrapper
modules/base.list.subroutines
modules/base.ntime.epoch_to_ntime
modules/base.parser.txt_box
modules/base.referenced_subroutines.clear_from_disk
modules/base.register_pm_deps
modules/base.start.prio_child
modules/base.start.unlink_child
modules/base.stdio.transport.connect
modules/base.stdio.transport.listen
modules/base.tmp_dir
modules/branch.data.bind
modules/branch.data.query
modules/branch.data.unbind
modules/branch.storage.list
modules/branch.storage.persist
modules/branch.storage.restore
modules/branch.storage.sync
modules/calc.cmd.val.eval_bigrat
modules/channels.cmd.ai-review-approve
modules/channels.cmd.ai-review-feedback
modules/channels.cmd.ai-review-status
modules/channels.cmd.ai-review-submit
modules/channels.handler.content-detected
modules/channels.handler.playlist-integration
modules/channels.memory-sync.batch-send
modules/channels.util.yaml_decode
modules/channels.util.yaml_encode
modules/coding.learning.get_statistics
modules/coding.learning.identify_patterns
modules/coding.learning.record_outcome
modules/coding.learning.update_success_rate
modules/coding.routing.check_cache_first
modules/coding.start.chmod_child
modules/coding.tools.handler.git_diff_output
modules/coding.vision-parser.extract.clean_json
modules/context.delegate.collect
modules/context.delegate.dispatch
modules/context.git.recent_changes
modules/context.review.handler.page_result
modules/context.share.export
modules/context.share.import
modules/credentials.cmd.add
modules/cred-mesh.key_holder.child
modules/crypt.C25519.load_keypair
modules/crypt.C25519.load_keys_from_secret
modules/crypt.C25519.load_single
modules/cube.cmd.link-upgrade
modules/data.mount.fuse.spawn
modules/debian.start.apt_child
modules/format.yaml.load_file
modules/format.yaml.load_str
modules/httpd.vhost.dns_matches_local
modules/httpd.vhost.read_manifests
modules/httpsd.check_certificate_available
modules/image-quality.analyze
modules/image-quality.vision.encode_image
modules/image-quality.vision.http_api
modules/image-quality.vision.parse_response
modules/image-quality.vision.subprocess
modules/invoke-web.cmd.health
modules/jobsite.checksum.index
modules/jobsite.chksum.branch-color
modules/jobsite.dispatch.assessments
modules/jobsite.handler.stray-job-exported
modules/jobsite.handler.stray-jobs-listed
modules/jobsite.sync.apply_reverse
modules/jobsite.util.build_prompt
modules/keys.console.github-pat
modules/keys.select_archive_path
modules/keys.select_archive_path.curs
modules/keys.select_archive_path.term_Clui
modules/llm.service.subprocess_wrapper
modules/menu-commands.format-provider-data
modules/models.backend.kimi_web
modules/models.task.fallback-direct
modules/ncode.cmd.workflow
modules/ncode.regex.load
modules/ncode.regex.save
modules/ncode.start.chmod_child
modules/ncode.transform.handler.wave_reply
modules/ncode.transform.wave
modules/p7-log.anon.key
modules/plugin.auth.auth-keypair.tofu-notification
modules/plugin.web.jobs.list
modules/plugin.web.jobs.stats
modules/plugin.web.space.orbital.synthetic-zenka-node
modules/powershell.exec
modules/powershell.pointer-stream
modules/powershell.pointer-stream-path
modules/protocol-7-menu.cmd.menu-update
modules/protocol-7-menu.handler.pointer-stream-path
modules/protocol.protocol-7.encryption.init
modules/protocol.protocol-7.link-upgrade.init
modules/radio.gap_fill.start
modules/route.bmw384.index.from-file
modules/route.bmw384.visual.wheel.oscilloscope
modules/screen.setup.cmd.snapshot
modules/screen.setup.ensure-display
modules/select.region.open_window
modules/signal.cancel.load
modules/site-yaml.cmd.export-stray-job
modules/site-yaml.cmd.list-stray-jobs
modules/site-yaml.job.scan_stray
modules/terminal.curses_ui.app.models
modules/terminal.curses_ui.widget.detail
modules/terminal.curses_ui.widget.list
modules/transport.handle.socks5
modules/transport.handle.udt-tunnel
modules/v7.check_zenka_deps
modules/v7.cleanup_temp_paths
modules/v7.setup_stdout_redir
modules/vision-batch.parent.cmd.cancel
modules/vision-batch.parent.cmd.process
modules/vision-batch.parent.cmd.status
modules/vision-batch.parent.load_yaml_spec
modules/vision-batch.parent.persist
modules/vision-batch.parent.process
modules/vision-batch.parent.shutdown
modules/vision-batch.parent.status
modules/websocket.send
modules/window.place.open_window
modules/window.profile.color.load
modules/window.profile.color.save
modules/window.profile.load
modules/window.profile.save
modules/workspace-transfer.cmd.bug
modules/workspace-transfer.cmd.checkpoint
modules/workspace-transfer.console.bug
modules/workspace-transfer.console.checkpoint
modules/X-11.autoconfigure.non-root-start
modules/X-11.background.next-rnd-index
modules/X-11.handler.protocol-warnings
modules/zulum.cmd.export-streams
```

## For each file, determine

1. **Namespace** — first dotted segment (e.g. `base`, `jobsite`, `coding`).
2. **Module(s) loaded** — what's passed to `base.perlmod.load`/`autoload` in
   this specific file.
3. **Call frequency** — is this file invoked on every network
   command/request to its zenka (`.cmd.*`, `.handler.*`, hot-path helper), or
   is it a rare/one-shot path (admin `.console.*` command, a startup-only
   `.start.*`/setup helper that just isn't named `*.init_code`, an error
   branch, a conditional feature rarely exercised)?
4. **Does `<namespace>.init_code` exist, and does it already load this same
   module?** (If yes, this file's load call is dead weight already covered
   — flag as `ALREADY-REDUNDANT`.)
5. **Recommendation**, one of:
   - `MOVE` — clearly hot-path or frequently called, safe/obvious candidate
     to relocate the load into `init_code`.
   - `KEEP` — genuinely rare/conditional (e.g. a big optional module only
     needed on an uncommon branch, where eager-loading at boot would be
     real waste for something almost never used) — moving would be wrong.
   - `ALREADY-REDUNDANT` — per point 4.
   - `UNCLEAR` — you can't tell invocation frequency confidently from
     static reading alone; needs human judgment.
6. **One-line reasoning** for the recommendation.

## Output format

Write your findings to a new file `data/tasks/perlmod-categorization-results.md`,
grouped by namespace, as a table:

```markdown
## <namespace> (N files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/base.foo.bar | Some::Module | hot (.cmd) | no | MOVE | called on every X command |
```

Order namespace sections by file count, descending (biggest namespace
first — this doubles as the batching order for the follow-up refactor task).

## Constraints

- **Do not edit any module file.** This is classification only.
- If you're unsure about a namespace's `init_code` (or whether one exists),
  check with `list_modules` or `search_code` rather than guessing.
- If you learn something non-obvious about this codebase while doing this
  (a naming pattern, a namespace quirk), add a note to
  `data/ai-mem/kimi/coding-style.md` or `data/ai-mem/kimi/MEMORY.md` in your
  usual format.

## Notes

- signatures_note: leave signing to the system, no stub lines

#,,..,,..,..,,...,.,,,.,.,,,.,..,,..,,..,,.,.,..,,...,.,.,,.,,,,.,...,,,.,,,,,
#BXGDXPGKD7RBY6JWZBFI33FVY67Q76MOVKPOIDNZZ2QF6QJWFVHWRK4MDOLWH3SX3FFYOBG7NMEPW
#\\\|3JLGYENIP7F77CQREWNBXBKH6XTXIARTF56O73RVVEFKD6LLAIP \ / AMOS7 \ YOURUM ::
#\[7]KARBZ4WGX62GBR6XXPP5KRUZOAPVRZIVW2RDQ4IGHCMNU6BGAADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
