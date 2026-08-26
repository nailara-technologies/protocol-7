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
src/base.auth.set_v7_key
src/base.chk-sum.bmw384.angle-bits
src/base.chk-sum.bmw384.arc-segment
src/base.chk-sum.bmw384.color
src/base.chk-sum.bmw384.color-dist
src/base.chk-sum.bmw384.coordinate
src/base.chk-sum.bmw384.coordinate-str
src/base.chk-sum.bmw384.group
src/base.cmd.dependencies
src/base.devmod.dump_var
src/base.event.add_var
src/base.file.chown_all
src/base.file.temp
src/base.file.tie_array
src/base.gtk.attempt_load.glib_event
src/base.gtk.ensure_display
src/base.gtk.main_loop
src/base.handler.read.encryption-wrapper
src/base.handler.write.encryption-wrapper
src/base.list.subroutines
src/base.ntime.epoch_to_ntime
src/base.parser.txt_box
src/base.referenced_subroutines.clear_from_disk
src/base.register_pm_deps
src/base.start.prio_child
src/base.start.unlink_child
src/base.stdio.transport.connect
src/base.stdio.transport.listen
src/base.tmp_dir
src/branch.data.bind
src/branch.data.query
src/branch.data.unbind
src/branch.storage.list
src/branch.storage.persist
src/branch.storage.restore
src/branch.storage.sync
src/calc.cmd.val.eval_bigrat
src/channels.cmd.ai-review-approve
src/channels.cmd.ai-review-feedback
src/channels.cmd.ai-review-status
src/channels.cmd.ai-review-submit
src/channels.handler.content-detected
src/channels.handler.playlist-integration
src/channels.memory-sync.batch-send
src/channels.util.yaml_decode
src/channels.util.yaml_encode
src/coding.learning.get_statistics
src/coding.learning.identify_patterns
src/coding.learning.record_outcome
src/coding.learning.update_success_rate
src/coding.routing.check_cache_first
src/coding.start.chmod_child
src/coding.tools.handler.git_diff_output
src/coding.vision-parser.extract.clean_json
src/context.delegate.collect
src/context.delegate.dispatch
src/context.git.recent_changes
src/context.review.handler.page_result
src/context.share.export
src/context.share.import
src/credentials.cmd.add
src/cred-mesh.key_holder.child
src/crypt.C25519.load_keypair
src/crypt.C25519.load_keys_from_secret
src/crypt.C25519.load_single
src/cube.cmd.link-upgrade
src/data.mount.fuse.spawn
src/debian.start.apt_child
src/format.yaml.load_file
src/format.yaml.load_str
src/httpd.vhost.dns_matches_local
src/httpd.vhost.read_manifests
src/httpsd.check_certificate_available
src/image-quality.analyze
src/image-quality.vision.encode_image
src/image-quality.vision.http_api
src/image-quality.vision.parse_response
src/image-quality.vision.subprocess
src/invoke-web.cmd.health
src/jobsite.checksum.index
src/jobsite.chksum.branch-color
src/jobsite.dispatch.assessments
src/jobsite.handler.stray-job-exported
src/jobsite.handler.stray-jobs-listed
src/jobsite.sync.apply_reverse
src/jobsite.util.build_prompt
src/keys.console.github-pat
src/keys.select_archive_path
src/keys.select_archive_path.curs
src/keys.select_archive_path.term_Clui
src/llm.service.subprocess_wrapper
src/menu-commands.format-provider-data
src/models.backend.kimi_web
src/models.task.fallback-direct
src/ncode.cmd.workflow
src/ncode.regex.load
src/ncode.regex.save
src/ncode.start.chmod_child
src/ncode.transform.handler.wave_reply
src/ncode.transform.wave
src/p7-log.anon.key
src/plugin.auth.auth-keypair.tofu-notification
src/plugin.web.jobs.list
src/plugin.web.jobs.stats
src/plugin.web.space.orbital.synthetic-zenka-node
src/powershell.exec
src/powershell.pointer-stream
src/powershell.pointer-stream-path
src/protocol-7-menu.cmd.menu-update
src/protocol-7-menu.handler.pointer-stream-path
src/protocol.protocol-7.encryption.init
src/protocol.protocol-7.link-upgrade.init
src/radio.gap_fill.start
src/route.bmw384.index.from-file
src/route.bmw384.visual.wheel.oscilloscope
src/screen.setup.cmd.snapshot
src/screen.setup.ensure-display
src/select.region.open_window
src/signal.cancel.load
src/site-yaml.cmd.export-stray-job
src/site-yaml.cmd.list-stray-jobs
src/site-yaml.job.scan_stray
src/terminal.curses_ui.app.models
src/terminal.curses_ui.widget.detail
src/terminal.curses_ui.widget.list
src/transport.handle.socks5
src/transport.handle.udt-tunnel
src/v7.check_zenka_deps
src/v7.cleanup_temp_paths
src/v7.setup_stdout_redir
src/vision-batch.parent.cmd.cancel
src/vision-batch.parent.cmd.process
src/vision-batch.parent.cmd.status
src/vision-batch.parent.load_yaml_spec
src/vision-batch.parent.persist
src/vision-batch.parent.process
src/vision-batch.parent.shutdown
src/vision-batch.parent.status
src/websocket.send
src/window.place.open_window
src/window.profile.color.load
src/window.profile.color.save
src/window.profile.load
src/window.profile.save
src/workspace-transfer.cmd.bug
src/workspace-transfer.cmd.checkpoint
src/workspace-transfer.console.bug
src/workspace-transfer.console.checkpoint
src/X-11.autoconfigure.non-root-start
src/X-11.background.next-rnd-index
src/X-11.handler.protocol-warnings
src/zulum.cmd.export-streams
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
| src/base.foo.bar | Some::Module | hot (.cmd) | no | MOVE | called on every X command |
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

#,,,.,,..,..,,.,,,...,,..,.,.,..,,.,.,.,,,,,,,..,,...,...,.,.,,..,,.,,,.,,,..,
#KFC4OMODFQKU7ZDOITXZRTXOHKEINYCLP33SMA3YCY5FSJU4QB6MKB6575POPYGNRXFMVCQQNJMAO
#\\\|UFVVVGNQTHTUP666DSDDRVE5POPMDUDVBOQZNGMVX7KCZ3ERVFV \ / AMOS7 \ YOURUM ::
#\[7]TNDKOQ6XFEDZGXVFTU5AWIZCM6L37Y47KOBU2RONPBJSAJRR7EDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
