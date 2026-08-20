# perlmod MOVE-recommendation re-verification results

Re-verification of the 59 `MOVE` rows from `data/tasks/perlmod-categorization-results.md`,
per `data/tasks/perlmod-move-reverification.md`. Read-only; no module files edited.

Method: real callers traced via grep (both long and runtime-swapped short names),
false positives excluded (own `# name =` headers, nested-namespace siblings),
`.cmd.*`/`.handler.*` files corroborated via `cfg/zenki/*/access.zenki`
grants + route-send handler references, and callers traced one level up.

**Outcome: 11 of 59 MOVEs confirmed, 48 changed to KEEP / KEEP (unverified).**

## Re-verified rows (same order as task list)

| file | module(s) | frequency | init_code has it? | recommendation | reasoning | changed? |
|------|-----------|-----------|--------------------|-----------------|-----------|----------|
| modules/base.file.temp | File::Path | hot (per atomic state write) | no | MOVE | `<[file.temp]>` called by base.file.zenka_dir.write:126 on every atomic `>`-mode state write; that helper has 60+ call sites incl. per-visit paths like proxy.log.visit | no |
| modules/base.file.tie_array | Tie::File | rare (1 real caller) | no | KEEP | only invocation is index.cmd.add-wordlist:46, an operator-triggered cube command; fires a handful of times per index-zenka lifetime | yes |
| modules/base.handler.read.encryption-wrapper | Crypt::AuthEnc::ChaCha20Poly1305 | hot (per encrypted message) | no | MOVE | installed as state-3 session input handler by protocol.protocol-7.init_code:91 / encryption.init:106 — the per-message read path of every encrypted session | no |
| modules/base.handler.write.encryption-wrapper | Crypt::AuthEnc::ChaCha20Poly1305 | hot (per encrypted session + writes) | no | MOVE | factory for the per-session output encryption handler installed by protocol.protocol-7.encryption.init:115-127 on every encrypted link | no |
| modules/base.stdio.transport.connect | IO::Socket::UNIX | startup/one-shot | no | KEEP | sole caller base.stdio_multiplex.connect:37, invoked once per zenka startup only in calc's zenka-startup.v7 init block | yes |
| modules/base.stdio.transport.listen | IO::Socket::UNIX | startup/one-shot | no | KEEP | sole caller v7.handler.stdio_multiplex_listen:48, itself called exactly once from v7.post_init:21 | yes |
| modules/base.tmp_dir | File::Path | startup/one-shot (conditional) | no | KEEP | only caller is the temp-home branch of base.root.drop_privs:187, reached at most once per zenka lifetime | yes |
| modules/channels.cmd.ai-review-approve | JSON::PP | rare (manual dev workflow) | no | KEEP | no static caller; reachable only via the dev-only cube wildcard grant in cfg/zenki/channels/start, part of a manual 4-step review workflow in an on-demand zenka | yes |
| modules/channels.cmd.ai-review-feedback | JSON::PP | rare (manual dev workflow) | no | KEEP | dynamic cube routing only; invoked once per review round in the same occasional ai-review workflow | yes |
| modules/channels.cmd.ai-review-status | JSON::PP | rare (manual dev workflow) | no | KEEP | zero static callers; user-polled status command in the on-demand channels zenka | yes |
| modules/channels.cmd.ai-review-submit | JSON::PP | rare (manual dev workflow) | no | KEEP | no static invocation anywhere; manually-triggered first step of a rarely-used review pipeline | yes |
| modules/channels.handler.content-detected | JSON::PP | undeterminable (no caller found) | no | KEEP (unverified) | no static call and no handler registration anywhere; part of an apparently unwired content-discovery feature — cmd/handler frequency not determinable statically | yes |
| modules/channels.handler.playlist-integration | JSON::PP | undeterminable (no caller found) | no | KEEP (unverified) | zero invocation sites; sibling of the same unwired discovery pipeline (references channels.discovery.stats that only content-detected populates) | yes |
| modules/channels.memory-sync.batch-send | JSON::PP | never (unwired) | no | KEEP | nothing calls it — channels.memory-sync.sync-handler:47-48 documents the periodic batch sender as future work | yes |
| modules/channels.util.yaml_decode | YAML::XS | hot (per channel update) | no | MOVE | single YAML entry point for channels.cmd.update:34, the central write path for every channel publication; with start.on-demand=1 it loads on virtually every zenka activation | no |
| modules/channels.util.yaml_encode | YAML::XS | never (unused) | no | KEEP | not a single invocation exists — every channel writer encodes with JSON::PP inline instead | yes |
| modules/coding.tools.handler.git_diff_output | Git::Wrapper | hot (per tool call) | no | MOVE | called by coding.tools.handler.git_diff_staged:17 and git_diff_unstaged:17 on every git-diff tool call in the coding-agent loop; coding.init_code already preloads the other tool-path deps but not Git::Wrapper | no |
| modules/branch.data.bind | YAML::XS | rare (manual cube cmd) | no | KEEP (unverified) | dynamic routing only via branch zenka/cube grants; branch namespace is design-stage with no automated caller — cmd frequency not determinable statically | yes |
| modules/branch.data.query | YAML::XS | rare (manual cube cmd) | no | KEEP (unverified) | no static caller; reads the binding table that only the equally-manual branch.data.bind populates | yes |
| modules/branch.data.unbind | YAML::XS | rare (manual cube cmd) | no | KEEP (unverified) | reachable only as a manual cube command paired with branch.data.bind | yes |
| modules/branch.storage.list | YAML::XS | rare (manual cube cmd) | no | KEEP (unverified) | no code path ever calls it; operator-inspection command for local-YAML snapshots only | yes |
| modules/branch.storage.persist | YAML::XS | rare (manual cube cmd) | no | KEEP (unverified) | manual cube command only; the automated storage-backend sync that would make it hot is still an unchecked design-doc item | yes |
| modules/branch.storage.restore | YAML::XS | rare (manual cube cmd) | no | KEEP (unverified) | zero static callers; snapshot restore is inherently a recovery/manual operation | yes |
| modules/branch.storage.sync | YAML::XS | rare (manual cube cmd) | no | KEEP (unverified) | referenced only by docs and cube grants; branch.init_code registers only a route-cleanup timer, nothing calling sync | yes |
| modules/jobsite.dispatch.assessments | Encode, HTML::Entities | hot (per fetch batch) | no | MOVE | every completed fetch batch funnels into it via jobsite.handler.fetch-done / fetch-drain / new-job-settle / queue-depth-reply:37 / stray.claim_next; jobsite.init_code preloads YAML::XS+JSON::XS but not Encode/HTML::Entities | no |
| modules/jobsite.util.build_prompt | HTML::Entities, Encode | hot (per assessed job) | no | MOVE | called per-job inside every assessment batch by jobsite.dispatch.assessments:132 and per-repair by dispatch.repair, so the per-call autoloads fire repeatedly within each batch | no |
| modules/context.delegate.collect | Crypt::Misc | occasional (per delegation reply) | no | KEEP | fires once per completed delegation reply via models.handler.delegate_result:26 / context.delegate.handler.result:13; Crypt::Misc is already base-loaded at startup in any networked zenka, so a MOVE buys nothing | yes |
| modules/context.delegate.dispatch | Crypt::Misc | occasional (event/user-driven) | no | KEEP | called only by context.review.iterate:57 and models.task.do-delegation:24 on review/delegation events; Crypt::Misc load is a no-op against base-startup loading | yes |
| modules/context.git.recent_changes | Git::Wrapper | hot (per model request) | no | MOVE | rendered via `<[context.git.recent_changes:budget=N]>` in coding-assistant.tmpl (every coding-backend model request), plus per recent_changes tool call and per context-compose build; Git::Wrapper absent from coding.init_code preloads | no |
| modules/context.review.handler.page_result | Crypt::Misc | occasional (per review page) | no | KEEP (unverified) | reply handler registered only by user-triggered context.review.iterate:61; Crypt::Misc redundant with base-startup loading — handler frequency bounded by manual review sessions | yes |
| modules/context.share.export | JSON | undeterminable (no caller) | no | KEEP (unverified) | zero invocations in any module or template; only design-doc references — share channel is design-stage | yes |
| modules/context.share.import | JSON | undeterminable (no caller) | no | KEEP (unverified) | unused receive-side of the unimplemented share channel; its load never fires in practice | yes |
| modules/ncode.cmd.workflow | YAML::XS | rare (manual dev cmd) | no | KEEP | absent from ncode zenka's own access whitelist — only the context dev-zenka wildcard can route to it, and the YAML::XS load is conditional (only for .yaml workflow definitions) | yes |
| modules/ncode.transform.handler.wave_reply | Crypt::Misc | occasional (dev-only pipeline) | no | KEEP | reply callback for the transform pipeline whose parent ncode.cmd.transform has no access grant in any production zenka start file | yes |
| modules/ncode.transform.wave | Crypt::Misc | occasional (dev-only pipeline) | no | KEEP | sole caller ncode.cmd.transform:44 is unreachable except through the context zenka's dev wildcard | yes |
| modules/image-quality.analyze | Time::HiRes | per-image during on-demand batches | no | KEEP | runs inside vision-batch child workers (vision-batch.child.analyze_job:26) started on-demand; Time::HiRes is core and base.perlmod.load caches after the first image — moving to image-quality.init_code wouldn't even cover the real execution process | yes |
| modules/image-quality.vision.encode_image | MIME::Base64 | per-image during batches | no | KEEP | only reached via image-quality.analyze inside vision-batch children; MIME::Base64 is core and self-caching after the first image of a batch | yes |
| modules/image-quality.vision.http_api | HTTP::Tiny, JSON::XS | per-image during batches | no | KEEP | vision-batch.child.init_code:7 already preloads JSON::XS in every process that calls this; HTTP::Tiny is core — the proposed move is redundant on the actual execution path | yes |
| modules/image-quality.vision.parse_response | JSON::XS | per-image during batches | no | KEEP | only caller chain runs in vision-batch child workers where JSON::XS is already preloaded with imports by vision-batch.child.init_code | yes |
| modules/plugin.auth.auth-keypair.tofu-notification | JSON::PP | rare (once per new client key) | no | KEEP | called exclusively from the first-time-pin branch of plugin.auth.auth-keypair.validate-incoming-tofu:157 — fires once per brand-new client key ever, not per auth; JSON::PP is core | yes |
| modules/plugin.web.jobs.list | YAML::XS, HTML::Entities | occasional (per jobs-page view) | yes (YAML::XS) | KEEP | claim verified — plugin.web.jobs.init_code already autoloads YAML::XS (that part is redundant); HTML::Entities only exercised on jobs-page renders of a personal vhost, cached after first view | yes |
| modules/plugin.web.space.orbital.synthetic-zenka-node | Digest::SHA, Crypt::Misc | occasional (per UI node-click) | no | KEEP | reached only via plugin.web.space.orbital.json.context:69 on the `?context=` path, which fires on user node-click navigation — the 13 s browser poll hits the context-less path instead; Digest::SHA is core | yes |
| modules/workspace-transfer.cmd.bug | POSIX | rare (manual dev cmd) | no | KEEP | only reachable via the manually-invoked workspace-transfer bug-commit command (cmd.bug-commit:13); POSIX is core Perl | yes |
| modules/workspace-transfer.cmd.checkpoint | POSIX | rare (manual dev cmd) | no | KEEP | zero static callers and no scheduled invocation — runs only when a developer manually checkpoints | yes |
| modules/powershell.exec | IPC::Open3 | occasional (on-demand cmds) | no | KEEP | callers powershell.cmd.display-switch-toggle:12 and powershell.plugin.screenshot-capture.invoke:50 are on-demand user commands in the niche windows-bridge zenka; IPC::Open3 is core | yes |
| modules/powershell.pointer-stream-path | Crypt::Misc, AMOS7::SHM | rare (once per stream session) | no | KEEP | runs once per pointer-stream handshake (protocol-7-menu.pointer-stream-init fires once from graphical-startup-init), not per pointer frame — confirmed by prior session notes | yes |
| modules/site-yaml.cmd.export-stray-job | JSON::XS, YAML::XS | rare (stray-job recovery) | yes (YAML::XS) | KEEP | sole trigger is jobsite.stray.claim_next during stray-job recovery (normally zero per day); site-yaml.init_code already preloads YAML::XS, leaving only JSON::XS lazy for a near-never command | yes |
| modules/site-yaml.cmd.list-stray-jobs | JSON::XS | occasional (startup + per batch) | no | KEEP | triggered by jobsite.stray.check once 2 s after jobsite startup (non-repeating timer) and again per fetch-drain/fetch-done batch — far below event-loop frequency | yes |
| modules/httpd.vhost.dns_matches_local | IO::Interface::Simple, Net::DNS::Resolver | rare (vhost install time) | no | KEEP | only caller is httpd.cmd.install-vhosts:55 at vhost setup/config time — the original "per vhost routing decision" claim is wrong; request routing never touches it | yes |
| modules/models.backend.kimi_web | Crypt::Misc | hot (per kimi chat request) | no | MOVE | models.cmd.chat:54 → models.chat.invoke_model:127 → models.backend.kimi_web runs on every kimi/kimi-code chat request and does a per-call Crypt::Misc load; models.init_code does not preload it | no |
| modules/protocol-7-menu.handler.pointer-stream-path | AMOS7::SHM | rare (once per menu startup) | no | KEEP | once-per-startup reply handler in the pointer-stream SHM handshake chain (registered by handler.pointer-stream-start:22); preloading would tax every menu startup for a single call | yes |
| modules/screen.setup.cmd.snapshot | Cairo | occasional (manual cmd) | no | KEEP | no static caller; manual cube invocation only — Cairo autoload happens at most on the first user snapshot | yes |
| modules/screen.setup.ensure-display | Gtk3, Cairo, Glib | hot (per window open / monitor enum) | yes (Gtk3, Glib::Object::Introspection) | MOVE | verified: screen.setup.init_code already loads Gtk3 and calls Gtk3->init, so only Cairo/Glib need adding; called by screen.setup.open_window:15 and enumerate-monitors:8 in this already-GUI-only zenka | no |
| modules/transport.handle.socks5 | IO::Socket::Socks | rare (no configured profile) | no | KEEP | transport.select:148 would dispatch it per proxied connection, but no shipped profile (atom.yaml, default.yaml) configures socks5, so the type never materializes | yes |
| modules/calc.cmd.val.eval_bigrat | Math::BigRat | occasional (manual cmd) | no | KEEP | calc zenka exists solely for the manually-issued `val` command (sole caller calc.cmd.val:34 + self-recursion); Math::BigRat is core Perl and there is no automated caller | yes |
| modules/invoke-web.cmd.health | LWP::UserAgent | rare (manual admin cmd) | no | KEEP | the 30 s health timer in invoke-web.init_code:59 targets invoke-web.handler.check_health, NOT this cmd — the cmd is only reachable manually via cube | yes |
| modules/llm.service.subprocess_wrapper | JSON::PP | per inbound email | no | KEEP | real callers are smtpd.classify:27,33 (via smtpd.cmd.inject/reclassify) and llm.service.consensus_vote:53 — bounded by inbound-email rate; JSON::PP is core and cached after the first mail | yes |
| modules/websocket.send | Protocol::WebSocket::Frame | per kimi prompt/approval | yes (in kimi.init_code) | KEEP | loaded exclusively in the kimi zenka whose kimi.init_code:6-9 already preloads Protocol::WebSocket::Frame, so the inline load is already a redundant no-op — nothing to move | yes |
| modules/zulum.cmd.export-streams | JSON | hot (5 Hz timer) | no | MOVE | zulum.init_code:55-62 itself schedules it on a 200 ms repeating timer (interval 0.2 s, repeat TRUE) for the iris oscilloscope stream-state export, for the entire zulum zenka lifetime | no |

## Summary

- **MOVE confirmed (11):** base.file.temp, base.handler.read.encryption-wrapper,
  base.handler.write.encryption-wrapper, channels.util.yaml_decode,
  coding.tools.handler.git_diff_output, jobsite.dispatch.assessments,
  jobsite.util.build_prompt, context.git.recent_changes,
  models.backend.kimi_web, screen.setup.ensure-display, zulum.cmd.export-streams
- **KEEP / KEEP (unverified) (48):** everything else — predominantly `.cmd`/`.handler`
  files whose only reachability is a manual/dev cube grant, dead-or-unwired code
  (channels.handler.content-detected, channels.handler.playlist-integration,
  channels.memory-sync.batch-send, channels.util.yaml_encode, context.share.*),
  one-shot startup paths (base.stdio.transport.*, base.tmp_dir), or loads already
  redundant with an existing init_code preload (websocket.send, plugin.web.jobs.list,
  image-quality.vision.* in vision-batch children).

## Cross-cutting findings (for the refactor pass)

1. `base.perlmod.load` short-circuits via the `<base.perlmod.loaded>` registry —
   repeat per-call loads are one hash lookup. A MOVE must be justified by first-call
   latency or boot consolidation, not per-call overhead. This alone deflates most
   "called on every invocation" reasoning for core Perl modules (POSIX, JSON::PP,
   Time::HiRes, MIME::Base64, HTTP::Tiny, IPC::Open3, Math::BigRat, Digest::SHA).
2. Crypt::Misc is already loaded at startup in any networked zenka via base paths
   (base.chk-sum.jha.init_code, base.handler.link-upgrade,
   base.handler.write.encoding-wrapper) — inline Crypt::Misc loads elsewhere are
   no-ops; MOVE recommendations for it are moot unless the zenka is non-networked.
3. The channels zenka is `start.on-demand = 1` with a dev-only cube wildcard grant;
   "granted" does not mean "hot".
4. The branch.* and context.share.* namespaces are design-stage — several modules
   have zero callers anywhere.
5. image-quality.* runs inside vision-batch child processes, whose own
   vision-batch.child.init_code already preloads JSON::XS — moving loads to
   image-quality.init_code would not cover the real execution path.

#,,,,,,,,,...,,,,,,..,.,,,.,,,..,,,,.,.,.,,..,..,,...,...,.,.,.,.,,..,..,,,,.,
#J2HHT5Y7E7GJYGO74KCQJV5VBKLK5CBNGGKAADFAJORM2L3DMLYBPXXTOOAZRCK4NHKGRZI5XIRWK
#\\\|QVJVNMAY54SM75G3JZ6GOMLATO2WXJGULHMZFUR6WWXTWMIV4WR \ / AMOS7 \ YOURUM ::
#\[7]LXIUEUJZ5NK5BF2PRFEWNSZUXKOBZ2RZACY7IEL4LEMKHH4AQUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
