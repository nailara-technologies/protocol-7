# perlmod load/autoload categorization results

Generated from static classification of the 152 files listed in
`data/tasks/perlmod-load-autoload-categorization.md`.
Files with no actual `base.perlmod.load`/`autoload` call are marked N/A.

## base (29 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/base.auth.set_v7_key | Crypt::Digest::BLAKE2b_384 | startup/one-shot | no | KEEP | only loads when base.init_code not yet initialized (early startup guard) |
| modules/base.chk-sum.bmw384.angle-bits | AMOS7::CHKSUM::BMW384 | unclear | yes | ALREADY-REDUNDANT | already loaded in base.chk-sum.bmw384 init_code |
| modules/base.chk-sum.bmw384.arc-segment | AMOS7::CHKSUM::BMW384 | unclear | yes | ALREADY-REDUNDANT | already loaded in base.chk-sum.bmw384 init_code |
| modules/base.chk-sum.bmw384.color | AMOS7::CHKSUM::BMW384 | unclear | yes | ALREADY-REDUNDANT | already loaded in base.chk-sum.bmw384 init_code |
| modules/base.chk-sum.bmw384.color-dist | AMOS7::CHKSUM::BMW384 | unclear | yes | ALREADY-REDUNDANT | already loaded in base.chk-sum.bmw384 init_code |
| modules/base.chk-sum.bmw384.coordinate | AMOS7::CHKSUM::BMW384 | unclear | yes | ALREADY-REDUNDANT | already loaded in base.chk-sum.bmw384 init_code |
| modules/base.chk-sum.bmw384.coordinate-str | AMOS7::CHKSUM::BMW384 | unclear | yes | ALREADY-REDUNDANT | already loaded in base.chk-sum.bmw384 init_code |
| modules/base.chk-sum.bmw384.group | AMOS7::CHKSUM::BMW384 | unclear | yes | ALREADY-REDUNDANT | already loaded in base.chk-sum.bmw384 init_code |
| modules/base.cmd.dependencies | (no load call) | N/A | N/A | N/A | only reads <base.perlmod.loaded>; not a load call site |
| modules/base.devmod.dump_var | Data::Dumper | debug-only (ad-hoc, not committed) | no | KEEP | corrected 2026-07-26: only real caller is base.init_code's `*main::dump_var` alias install (not an invocation, just a glob assignment); genuinely debug-only, should stay lazy — see feedback-perlmod-categorization-review-catches.md |
| modules/base.event.add_var | Event | unclear | yes | ALREADY-REDUNDANT | already loaded in base.event init_code |
| modules/base.file.chown_all | File::Find | rare (admin) | no | KEEP | admin chown utility; File::Find only needed on rare recursive ownership changes |
| modules/base.file.temp | File::Path | hot (core helper) | no | MOVE | core temp-file helper called frequently; File::Path should be in base.init_code |
| modules/base.file.tie_array | Tie::File | hot (core helper) | no | MOVE | core file helper called whenever tied arrays are needed |
| modules/base.gtk.attempt_load.glib_event | Glib::Event | startup/one-shot | no | KEEP | optional-module loader wrapper itself; called once at startup to probe Glib::Event |
| modules/base.gtk.ensure_display | Gtk3 | hot (helper) | no | KEEP | GUI-only helper; loading Gtk3 in base.init_code would force it on non-GUI zenki, so keep lazy here |
| modules/base.gtk.main_loop | (no load call) | N/A | N/A | N/A | only checks <base.perlmod.loaded> for Glib::Event |
| modules/base.handler.read.encryption-wrapper | Crypt::AuthEnc::ChaCha20Poly1305 | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |
| modules/base.handler.write.encryption-wrapper | Crypt::AuthEnc::ChaCha20Poly1305 | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |
| modules/base.list.subroutines | (no load call) | N/A | N/A | N/A | contains literal string in subroutine list; no actual call |
| modules/base.ntime.epoch_to_ntime | Math::BigFloat | rare (1 real caller) | no | KEEP | corrected 2026-07-26: only real caller is cube.cmd.localtime, an occasional console command, not a hot path |
| modules/base.parser.txt_box | AMOS7::TERM | rare (4 callers, mostly console/admin) | no | KEEP | corrected 2026-07-26: real callers are coding.tools.handler.read_file + 3 base.console./base.list. files; AMOS7::TERM confirmed rare/interactive-only elsewhere in this same table |
| modules/base.referenced_subroutines.clear_from_disk | (no load call) | N/A | N/A | N/A | only checks <base.perlmod.loaded> for Crypt::PRNG::Fortuna |
| modules/base.register_pm_deps | Module::CoreList | startup/one-shot | no | KEEP | registration helper run at startup; lazy load avoids CoreList bloat if unused |
| modules/base.start.prio_child | IPC::Open2 | startup (.start) | no | KEEP | startup/one-shot path, load call is acceptable here |
| modules/base.start.unlink_child | IPC::Open2 | startup (.start) | no | KEEP | startup/one-shot path, load call is acceptable here |
| modules/base.stdio.transport.connect | IO::Socket::UNIX | hot (helper) | no | MOVE | called on every (helper) invocation, modules should be in init_code |
| modules/base.stdio.transport.listen | IO::Socket::UNIX | hot (helper) | no | MOVE | called on every (helper) invocation, modules should be in init_code |
| modules/base.tmp_dir | File::Path | hot (core helper) | no | MOVE | called on every (core helper) invocation, modules should be in init_code |

## channels (9 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/channels.cmd.ai-review-approve | JSON::PP | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/channels.cmd.ai-review-feedback | JSON::PP | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/channels.cmd.ai-review-status | JSON::PP | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/channels.cmd.ai-review-submit | JSON::PP | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/channels.handler.content-detected | JSON::PP | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |
| modules/channels.handler.playlist-integration | JSON::PP | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |
| modules/channels.memory-sync.batch-send | JSON::PP | hot (helper) | no | MOVE | called on every (helper) invocation, modules should be in init_code |
| modules/channels.util.yaml_decode | YAML::XS | hot (helper) | no | MOVE | utility called whenever channels decode YAML; should be preloaded |
| modules/channels.util.yaml_encode | YAML::XS | hot (helper) | no | MOVE | utility called whenever channels encode YAML; should be preloaded |

## coding (8 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/coding.learning.get_statistics | JSON::PP | unclear | yes | ALREADY-REDUNDANT | already loaded in coding init_code |
| modules/coding.learning.identify_patterns | JSON::PP | unclear | yes | ALREADY-REDUNDANT | already loaded in coding init_code |
| modules/coding.learning.record_outcome | JSON::PP | unclear | yes | ALREADY-REDUNDANT | already loaded in coding init_code |
| modules/coding.learning.update_success_rate | JSON::PP | unclear | yes | ALREADY-REDUNDANT | already loaded in coding init_code |
| modules/coding.routing.check_cache_first | JSON::PP | unclear | yes | ALREADY-REDUNDANT | already loaded in coding init_code |
| modules/coding.start.chmod_child | IPC::Open2 | startup (.start) | no | KEEP | startup/one-shot path, load call is acceptable here |
| modules/coding.tools.handler.git_diff_output | Git::Wrapper | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |
| modules/coding.vision-parser.extract.clean_json | JSON::PP | hot (core helper) | yes | ALREADY-REDUNDANT | already loaded in coding init_code |

## vision-batch (8 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/vision-batch.parent.cmd.cancel | YAML::XS | hot (.cmd) | yes | ALREADY-REDUNDANT | already loaded in vision-batch init_code |
| modules/vision-batch.parent.cmd.process | YAML::XS | hot (.cmd) | yes | ALREADY-REDUNDANT | already loaded in vision-batch init_code |
| modules/vision-batch.parent.cmd.status | YAML::XS | hot (.cmd) | yes | ALREADY-REDUNDANT | already loaded in vision-batch init_code |
| modules/vision-batch.parent.load_yaml_spec | YAML::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in vision-batch.parent init_code |
| modules/vision-batch.parent.persist | JSON::XS, File::Path | rare/moderate | partial | KEEP | JSON::XS already preloaded by vision-batch.parent.init_code; File::Path can stay lazy for non-hot persistence |
| modules/vision-batch.parent.process | JSON::XS | hot (helper) | yes | ALREADY-REDUNDANT | already loaded in vision-batch.parent init_code |
| modules/vision-batch.parent.shutdown | JSON::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in vision-batch.parent init_code |
| modules/vision-batch.parent.status | JSON::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in vision-batch.parent init_code |

## branch (7 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/branch.data.bind | YAML::XS | hot (branch cmd) | no | MOVE | branch data command invoked per bind operation; YAML::XS should be in branch.init_code |
| modules/branch.data.query | YAML::XS | hot (branch cmd) | no | MOVE | branch data command invoked per query; YAML::XS should be in branch.init_code |
| modules/branch.data.unbind | YAML::XS | hot (branch cmd) | no | MOVE | branch data command invoked per unbind; YAML::XS should be in branch.init_code |
| modules/branch.storage.list | YAML::XS | hot (helper) | no | MOVE | storage helper called when listing snapshots; YAML::XS should be in branch.init_code |
| modules/branch.storage.persist | YAML::XS | hot (helper) | no | MOVE | storage helper called when persisting snapshots; YAML::XS should be in branch.init_code |
| modules/branch.storage.restore | YAML::XS | hot (helper) | no | MOVE | storage helper called when restoring snapshots; YAML::XS should be in branch.init_code |
| modules/branch.storage.sync | YAML::XS | hot (helper) | no | MOVE | storage helper called when syncing snapshots; YAML::XS should be in branch.init_code |

## jobsite (7 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/jobsite.checksum.index | YAML::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in jobsite init_code |
| modules/jobsite.chksum.branch-color | Digest::BMW | rare (1 real caller) | no | KEEP | corrected 2026-07-26: only real caller is jobsite.chksum.group-by-branch, not a demonstrably hot path |
| modules/jobsite.dispatch.assessments | Encode, HTML::Entities | hot (helper) | no | MOVE | called on every (helper) invocation, modules should be in init_code |
| modules/jobsite.handler.stray-job-exported | JSON::XS | hot (.handler) | yes | ALREADY-REDUNDANT | already loaded in jobsite init_code |
| modules/jobsite.handler.stray-jobs-listed | JSON::XS | hot (.handler) | yes | ALREADY-REDUNDANT | already loaded in jobsite init_code |
| modules/jobsite.sync.apply_reverse | Encode | rare/conditional | no | KEEP | Encode only used in the reassess branch; keep lazy for uncommon path |
| modules/jobsite.util.build_prompt | HTML::Entities, Encode | hot (helper) | no | MOVE | used for every new job assessment prompt; preload in jobsite.init_code |

## context (6 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/context.delegate.collect | Crypt::Misc | hot (.handler) | no | MOVE | async delegation result handler; Crypt::Misc should be in context.init_code |
| modules/context.delegate.dispatch | Crypt::Misc | hot (helper) | no | MOVE | called on every (helper) invocation, modules should be in init_code |
| modules/context.git.recent_changes | Git::Wrapper | hot (helper) | no | MOVE | context helper called per context build; Git::Wrapper should be preloaded |
| modules/context.review.handler.page_result | Crypt::Misc | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |
| modules/context.share.export | JSON | hot (helper) | no | MOVE | context sharing helper called frequently; JSON should be in context.init_code |
| modules/context.share.import | JSON | hot (helper) | no | MOVE | context sharing helper called frequently; JSON should be in context.init_code |

## ncode (6 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/ncode.cmd.workflow | YAML::XS | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/ncode.regex.load | YAML::XS | startup/one-shot | yes | ALREADY-REDUNDANT | ncode.init_code already autoloads YAML::XS |
| modules/ncode.regex.save | YAML::XS | startup/one-shot | yes | ALREADY-REDUNDANT | ncode.init_code already autoloads YAML::XS |
| modules/ncode.start.chmod_child | IPC::Open2 | startup (.start) | no | KEEP | startup/one-shot path, load call is acceptable here |
| modules/ncode.transform.handler.wave_reply | Crypt::Misc | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |
| modules/ncode.transform.wave | Crypt::Misc | hot (helper) | no | MOVE | called in transform loops; preload Crypt::Misc in ncode.init_code |

## image-quality (5 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/image-quality.analyze | Time::HiRes | hot (helper) | no | MOVE | main image-quality entry point called per image; Time::HiRes is lightweight and should be preloaded |
| modules/image-quality.vision.encode_image | MIME::Base64 | hot (helper) | no | MOVE | called for every analyzed image; preload in image-quality.init_code |
| modules/image-quality.vision.http_api | HTTP::Tiny, JSON::XS | hot (helper) | no | MOVE | vision API client invoked per analyzed image; preload both modules |
| modules/image-quality.vision.parse_response | JSON::XS | hot (helper) | no | MOVE | parses every successful vision response; preload JSON::XS |
| modules/image-quality.vision.subprocess | YAML::Tiny | hot (helper) | yes | ALREADY-REDUNDANT | already loaded in image-quality init_code |

## window (5 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/window.place.open_window | Gtk3, Cairo, Glib, Font::FreeType, Cairo::GObject | one-shot (window creation) | partial | KEEP | window creation is effectively one-shot per instance; remaining deps are window-open specific |
| modules/window.profile.color.load | YAML::XS | rare | no | KEEP | theme loading is user/configuration triggered and infrequent |
| modules/window.profile.color.save | YAML::XS | rare | no | KEEP | theme saving is user/configuration triggered and infrequent |
| modules/window.profile.load | YAML::XS | rare | no | KEEP | position profile load happens on window open, not a hot loop |
| modules/window.profile.save | YAML::XS | rare | no | KEEP | position profile save happens on window close, not a hot loop |

## keys (4 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/keys.console.github-pat | AMOS7::TERM | rare (.console) | yes | ALREADY-REDUNDANT | already loaded in keys init_code |
| modules/keys.select_archive_path | Curses::UI | rare (.console) | no | KEEP | console-only archive selection; heavy Curses::UI should stay lazy |
| modules/keys.select_archive_path.curs | Curses::UI | rare (.console) | no | KEEP | console fallback UI; keep Curses::UI lazy |
| modules/keys.select_archive_path.term_Clui | Term::Clui, Term::Clui::FileSelect | rare (.console) | no | KEEP | terminal fallback UI; keep lazy for rare console use |

## plugin (4 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/plugin.auth.auth-keypair.tofu-notification | JSON::PP | hot (event callback) | no | MOVE | TOFU callback fires during auth; preload JSON::PP in plugin.auth.auth-keypair.init_code |
| modules/plugin.web.jobs.list | YAML::XS, HTML::Entities | hot (web render) | partial | MOVE | YAML::XS already in plugin.web.jobs.init_code; add HTML::Entities and remove inline load |
| modules/plugin.web.jobs.stats | YAML::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in plugin.web.jobs init_code |
| modules/plugin.web.space.orbital.synthetic-zenka-node | Digest::SHA, Crypt::Misc | hot (helper) | no | MOVE | synthetic node builder called repeatedly; preload in orbital init_code |

## workspace-transfer (4 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/workspace-transfer.cmd.bug | POSIX | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/workspace-transfer.cmd.checkpoint | POSIX | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/workspace-transfer.console.bug | POSIX | rare (.console) | no | KEEP | rare command, keeping lazy load avoids eager bloat |
| modules/workspace-transfer.console.checkpoint | POSIX | rare (.console) | no | KEEP | rare command, keeping lazy load avoids eager bloat |

## crypt (3 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/crypt.C25519.load_keypair | AMOS7::TERM | rare (interactive branch) | no | KEEP | AMOS7::TERM only loaded when a password prompt is needed; keep lazy for interactive branches |
| modules/crypt.C25519.load_keys_from_secret | AMOS7::TERM | rare (interactive branch) | no | KEEP | AMOS7::TERM only loaded when decrypting an encrypted secret key; keep lazy |
| modules/crypt.C25519.load_single | AMOS7::TERM | rare (interactive branch) | no | KEEP | AMOS7::TERM only loaded when decrypting an encrypted private key; keep lazy |

## powershell (3 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/powershell.exec | IPC::Open3 | hot (helper) | no | MOVE | core PowerShell invocation helper; preload IPC::Open3 in powershell.init_code |
| modules/powershell.pointer-stream | AMOS7::SHM, IPC::Open3 | startup/one-shot | no | KEEP | spawns persistent pointer hook once; inline load is fine |
| modules/powershell.pointer-stream-path | Crypt::Misc, AMOS7::SHM | hot (.cmd wrapper) | no | MOVE | exposed via cmd wrapper; preload Crypt::Misc and AMOS7::SHM in powershell.init_code |

## site-yaml (3 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/site-yaml.cmd.export-stray-job | JSON::XS, YAML::XS | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/site-yaml.cmd.list-stray-jobs | JSON::XS | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/site-yaml.job.scan_stray | YAML::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in site-yaml init_code |

## terminal (3 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/terminal.curses_ui.app.models | Curses::UI | startup/one-shot | no | KEEP | standalone curses app entry point; keep Curses::UI lazy |
| modules/terminal.curses_ui.widget.detail | Curses::UI | occasional | no | KEEP | detail widget called on demand; keep lazy |
| modules/terminal.curses_ui.widget.list | Curses::UI | occasional | no | KEEP | list widget called on demand; keep lazy |

## v7 (3 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/v7.check_zenka_deps | AMOS7::deps::module, AMOS7::deps::os_package, AMOS7::deps::debp | startup/one-shot | no | KEEP | per-zenka dependency check runs once at startup |
| modules/v7.cleanup_temp_paths | File::Path | rare | no | KEEP | instance cleanup on sub-process exit; not a hot path |
| modules/v7.setup_stdout_redir | File::Spec, Fcntl | startup/one-shot | no | KEEP | one-time stdout log setup; preloading not warranted |

## X-11 (3 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/X-11.autoconfigure.non-root-start | Capture::Tiny | one-shot | no | KEEP | system X11 configuration helper; run rarely/once |
| modules/X-11.background.next-rnd-index | (no load call) | N/A | N/A | N/A | only checks <base.perlmod.loaded> for Crypt::PRNG::Fortuna |
| modules/X-11.handler.protocol-warnings | (no load call) | N/A | N/A | N/A | base.perlmod.load appears only in a commented-out debug block |

## format (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/format.yaml.load_file | YAML | unclear | yes | ALREADY-REDUNDANT | already loaded in format.yaml init_code |
| modules/format.yaml.load_str | YAML | unclear | yes | ALREADY-REDUNDANT | already loaded in format.yaml init_code |

## httpd (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/httpd.vhost.dns_matches_local | IO::Interface::Simple, Net::DNS::Resolver | hot (helper) | no | MOVE | DNS check helper likely used per vhost routing decision; preload in httpd.init_code |
| modules/httpd.vhost.read_manifests | YAML::XS | startup/config-reload | no | KEEP | manifest scan runs at startup or config reload, not per request |

## models (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/models.backend.kimi_web | Crypt::Misc | hot (helper) | no | MOVE | routes every kimi chat/task request; preload Crypt::Misc in models.init_code |
| modules/models.task.fallback-direct | Crypt::Misc | rare/conditional | no | KEEP | only triggered on delegation failure; keep lazy |

## protocol-7-menu (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/protocol-7-menu.cmd.menu-update | YAML::XS | hot (.cmd) | yes | ALREADY-REDUNDANT | already loaded in protocol-7-menu init_code |
| modules/protocol-7-menu.handler.pointer-stream-path | AMOS7::SHM | hot (.handler) | no | MOVE | called on every (.handler) invocation, modules should be in init_code |

## protocol (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/protocol.protocol-7.encryption.init | Crypt::AuthEnc::ChaCha20Poly1305 | startup/init-related | no | KEEP | startup/one-shot path, load call is acceptable here |
| modules/protocol.protocol-7.link-upgrade.init | (direct use Crypt::Misc, Crypt::Curve25519) | N/A | N/A | N/A | uses direct `use` statements and <base.perlmod.loaded> check; no base.perlmod.load call |

## route (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/route.bmw384.index.from-file | Crypt::Misc | startup/one-shot | no | KEEP | one-shot module indexing; Crypt::Misc cached after first load |
| modules/route.bmw384.visual.wheel.oscilloscope | JSON | rare (visual mode) | no | KEEP | only used for oscilloscope wheel render mode; keep lazy |

## screen (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/screen.setup.cmd.snapshot | Cairo | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |
| modules/screen.setup.ensure-display | Gtk3, Cairo, Glib | hot (helper) | partial | MOVE | Gtk3 already in screen.setup.init_code; add Cairo/Glib and drop redundant inline load |

## transport (2 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/transport.handle.socks5 | IO::Socket::Socks | hot (helper) | no | MOVE | shared SOCKS5 connection helper; preload in transport.init_code |
| modules/transport.handle.udt-tunnel | UDT::Simple | rare/optional | no | KEEP | UDT is optional/registry-guarded; keep inline to avoid forcing optional module |

## calc (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/calc.cmd.val.eval_bigrat | Math::BigRat | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |

## credentials (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/credentials.cmd.add | AMOS7::TERM | hot (.cmd) | yes | ALREADY-REDUNDANT | already loaded in credentials init_code |

## cred-mesh (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/cred-mesh.key_holder.child | Crypt::Misc | unclear | yes | ALREADY-REDUNDANT | already loaded in cred-mesh init_code |

## cube (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/cube.cmd.link-upgrade | (direct use Crypt::Misc) | N/A | N/A | N/A | uses direct `use Crypt::Misc` and <base.perlmod.loaded> check; no base.perlmod.load call |

## data (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/data.mount.fuse.spawn | Filesys::Fuse3 | rare (mount cmd) | no | KEEP | FUSE mount spawn is a rare operation; optional Filesys::Fuse3 should stay lazy |

## debian (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/debian.start.apt_child | IPC::Open2 | startup (.start) | no | KEEP | startup/one-shot path, load call is acceptable here |

## httpsd (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/httpsd.check_certificate_available | Crypt::OpenSSL::X509, Date::Parse | startup/periodic | no | KEEP | certificate validation runs at startup or periodic checks, not per request |

## invoke-web (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/invoke-web.cmd.health | LWP::UserAgent | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |

## llm (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/llm.service.subprocess_wrapper | JSON::PP | hot (helper) | no | MOVE | called on every (helper) invocation, modules should be in init_code |

## menu-commands (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/menu-commands.format-provider-data | YAML::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in menu-commands init_code |

## p7-log (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/p7-log.anon.key | AMOS7::13, Crypt::Misc | startup/one-shot (lazy) | no | KEEP | key derivation must run after final EUID is set; cannot move to init_code |

## radio (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/radio.gap_fill.start | List::Util | unclear | yes | ALREADY-REDUNDANT | already loaded in radio init_code |

## select (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/select.region.open_window | Gtk3, Cairo, Glib, Font::FreeType, Cairo::GObject | one-shot (interactive window) | partial | KEEP | opens user-interaction window occasionally; font/render deps only needed at window-open time |

## signal (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/signal.cancel.load | YAML::XS | unclear | yes | ALREADY-REDUNDANT | already loaded in signal.cancel init_code |

## websocket (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/websocket.send | Protocol::WebSocket::Frame | hot (helper) | no | MOVE | core websocket send helper; preload in websocket.init_code |

## zulum (1 files)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning |
|------|-----------|-----------|--------------------|-----------------|-----------|
| modules/zulum.cmd.export-streams | JSON | hot (.cmd) | no | MOVE | called on every (.cmd) invocation, modules should be in init_code |

#,,,,,,..,,..,,,.,,,.,.,,,,..,.,.,,..,..,,.,.,..,,...,...,.,,,,..,,.,,..,,...,
#ZDPBB44NEFD3PFT7ONLJJJMO3CRQBHLMH2H4A5IZY742XYJTRCD5CDD2I6IEADWCTKMGHZZQ6DT6I
#\\\|5GGGXPFVMESP2GBEFZ5IZE6HOGGQWLLEKKEZCYROTBNI5QEYFBM \ / AMOS7 \ YOURUM ::
#\[7]2ISNMGFLVIUIPNIBJW4YU75YKVKSW2FO3TUK2Q533KOMF26WAABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
