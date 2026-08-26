# perlmod MOVE-recommendation re-verification — results

Re-verification of the 59 currently-marked `MOVE` rows from
`data/tasks/perlmod-categorization-results.md`, applying the four
methodology traps documented in `data/tasks/perlmod-move-reverification.md`:

1. fan-in count ≠ call frequency (trace one level up, esp. `base.root.drop_privs`
   is one-shot-per-zenka-lifetime)
2. `.cmd.*` / `.handler.*` files are dispatched dynamically — static grep is
   meaningless; look at `access.cmd.usr.*` breadth or say `MOVE (unverified)`
3. name-collision false positives — a header `# name = X.Y.Z` in a sibling
   file is not a caller of `X.Y`
4. templated-sounding reasoning is itself a red flag

Callers were re-derived with literal-bracket grep `<[module.name]>`, plus the
short-form when a family is on the `<[base.swap_subs]>` swap list
(`base.file.*` → `file.*`). Reply-handler and timer references were
additionally scanned as unbracketed strings.

Verification pass also cross-checks that the file actually contains a
`base.perlmod.{load,autoload}` call — several rows had none, meaning the
original classification cited a module that isn't loaded via perlmod in that
file at all (found via `use`, `require`, or ambient-preload); those are
flagged `N/A (no perlmod load in file)`.

## Results

`changed?` = does the deeper check overturn the original `MOVE` label?

| file | module(s) | frequency (re-verified) | recommendation | changed? | reasoning |
|------|-----------|-------------------------|-----------------|----------|-----------|
| src/base.file.temp | File::Path | hot (multi-caller helper) | KEEP | yes | file contains NO `base.perlmod.{load,autoload}` call for File::Path — original row is stale/inaccurate; nothing to move. Note: this file is called under its swapped short name `<[file.temp]>` (`base.file.*` → `file.*` via swap_subs), with 4 real callers (lm-vision.cmd.analyze_image per-image, ncode.cmd.apply per-apply, graphics.matrix.visual.phash per-phash, base.file.zenka_dir.write per-write) — if a File::Path load ever gets added here, then MOVE would apply |
| src/base.file.tie_array | Tie::File | rare (1 caller, admin cmd) | KEEP | yes | only real caller is `<[file.tie_array]>` in `index.cmd.add-wordlist` (one-shot admin wordlist import); "hot core helper" label doesn't match — one rare caller, load-on-demand is fine |
| src/base.handler.read.encryption-wrapper | Crypt::AuthEnc::ChaCha20Poly1305 | N/A | N/A (no perlmod load in file) | yes | grep shows 0 `base.perlmod.{load,autoload}` calls in this file (only `use`/direct calls) — nothing to move; classification stale. The handler itself IS on the encrypted-transport read path (referenced from `protocol.protocol-7.init_code` as `handler => base.handler.read.encryption-wrapper`) so would be hot if a load did exist |
| src/base.handler.write.encryption-wrapper | Crypt::AuthEnc::ChaCha20Poly1305 | N/A | N/A (no perlmod load in file) | yes | grep shows 0 `base.perlmod.{load,autoload}` calls in this file — nothing to move; classification stale. Paired-write counterpart of read wrapper — would be hot if a load did exist |
| src/base.stdio.transport.connect | IO::Socket::UNIX | rare/single-caller | KEEP | yes | only real caller is `base.stdio_multiplex.connect` (line 37), which itself has 0 static callers — this whole subtree is a stdio-multiplex helper used only when a zenka opens a multiplex socket, not a general per-call helper. Load-on-demand appropriate |
| src/base.stdio.transport.listen | IO::Socket::UNIX | startup/one-shot | KEEP | yes | only caller is `v7.handler.stdio_multiplex_listen`, invoked once from `v7.post_init` at v7 boot — classic startup path, load-on-demand is correct |
| src/base.tmp_dir | File::Path | startup/one-shot (per methodology trap 1) | KEEP | yes | only caller is `<[base.tmp_dir]>` inside `base.root.drop_privs` (line 187) — per methodology trap #1 and CLAUDE.md's documented startup sequence, `base.root.drop_privs` runs exactly ONCE per zenka lifetime (6 static callers, all in `*.init_code`/`*.post_init`/startup paths: coding.init_code, X-11.chk.early-priv-drop, v7.zenka.start, X-11.post_init, web-browser.set-up.set_privs, ncode.init_code). Effectively one-shot |
| src/channels.cmd.ai-review-approve | JSON::PP | unverified (dynamic cmd) | MOVE (unverified — cmd frequency not determinable statically) | no | .cmd file, no static callers (expected); not exposed in `cfg/zenki/cube/access.zenki` (channels/ai-review-* cmds don't appear there at all — narrow use only from within channels/context zenki). Loaded in `subroutines.load-early` for both zenki. Feature-usage-dependent; cannot confirm hot statically |
| src/channels.cmd.ai-review-feedback | JSON::PP | unverified (dynamic cmd) | MOVE (unverified — cmd frequency not determinable statically) | no | same shape as ai-review-approve — no static callers, not in cube access.zenki, narrow feature-usage dependent |
| src/channels.cmd.ai-review-status | JSON::PP | unverified (dynamic cmd) | MOVE (unverified — cmd frequency not determinable statically) | no | same shape as ai-review-approve |
| src/channels.cmd.ai-review-submit | JSON::PP | unverified (dynamic cmd) | MOVE (unverified — cmd frequency not determinable statically) | no | same shape as ai-review-approve |
| src/channels.handler.content-detected | JSON::PP | unverified (dynamic handler) | MOVE (unverified — handler frequency not determinable statically) | no | .handler file, no static callers; used as an async reply/event handler (name only appears in subroutines.load-early). Feature-flow dependent; cannot confirm hot statically |
| src/channels.handler.playlist-integration | JSON::PP | unverified (dynamic handler) | MOVE (unverified — handler frequency not determinable statically) | no | same shape as content-detected — dispatched by string, no static callers |
| src/channels.memory-sync.batch-send | JSON::PP | unverified (helper by name, dispatch unclear) | MOVE (unverified) | no | 0 static callers; name suggests periodic/timer-driven batching but no timer registration found for it. Cannot confirm frequency statically |
| src/channels.util.yaml_decode | YAML::XS | N/A | N/A (no perlmod load in file) | yes | grep shows 0 `base.perlmod.{load,autoload}` in this file — it uses `YAML::XS::Load(...)` directly, relying on ambient preload elsewhere. Nothing to move. Its 1 real caller `<[channels.util.yaml_decode]>` is `channels.cmd.update` (a normal channel publish cmd — moderately hot) so a MOVE would be justified IF a load were added |
| src/channels.util.yaml_encode | YAML::XS | rare (0 static callers) | KEEP | yes | 0 real callers found (`<[channels.util.yaml_encode]>` matches nothing outside the load-early list); paired-encode counterpart of decode but unused statically. Load-on-demand fine — if usage picks up later, reclassify |
| src/coding.tools.handler.git_diff_output | Git::Wrapper | N/A | N/A (no perlmod load in file) | yes | grep shows 0 `base.perlmod.{load,autoload}` for Git::Wrapper — the file actually uses `require Git::Native; require Git::Native::Diff;` (a different loading mechanism, and different module). Original row cited the wrong module and wrong loader. 2 callers (`git_diff_unstaged`, `git_diff_staged`) but there's nothing to move |
| src/branch.data.bind | YAML::XS | hot (branch cmd, real command) | MOVE | no | confirmed as a real branch command exposed in `cfg/zenki/cube/access.zenki` under `access.cmd.usr.branch = ... branch.data.*` and listed in `branch/zenka.v7` — invoked per-bind. YAML::XS is not currently in branch.init_code — moving it there is correct |
| src/branch.data.query | YAML::XS | hot (branch cmd, real command) | MOVE | no | same as bind — exposed under `branch.data.*` cube-access wildcard, per-query invocation |
| src/branch.data.unbind | YAML::XS | hot (branch cmd, real command) | MOVE | no | same as bind — per-unbind invocation |
| src/branch.storage.list | YAML::XS | hot (branch cmd, real command) | MOVE | no | exposed under `branch.storage.*` cube-access wildcard in access.zenki; invoked per-list |
| src/branch.storage.persist | YAML::XS | hot (branch cmd, real command) | MOVE | no | same as list — per-persist invocation |
| src/branch.storage.restore | YAML::XS | hot (branch cmd, real command) | MOVE | no | same as list — per-restore invocation |
| src/branch.storage.sync | YAML::XS | hot (branch cmd, real command) | MOVE | no | same as list — per-sync invocation |
| src/jobsite.dispatch.assessments | Encode, HTML::Entities | N/A | N/A (no perlmod load in file) | yes | 0 `base.perlmod.{load,autoload}` calls in file. 5 real callers (jobsite.handler.queue-depth-reply, jobsite.stray.claim_next, jobsite.handler.fetch-drain/-done, jobsite.handler.new-job-settle) — file IS on hot dispatch path, but nothing here to move. Encode/HTML::Entities must be loaded elsewhere or via ambient |
| src/jobsite.util.build_prompt | HTML::Entities, Encode | N/A | N/A (no perlmod load in file) | yes | 0 `base.perlmod.{load,autoload}` calls in file. 4 real callers (jobsite.dispatch.reassess_now, .assessments, .repair, jobsite.cmd.show-prompt) — genuinely on the prompt-build path, but nothing to move |
| src/context.delegate.collect | Crypt::Misc | hot (2 confirmed callers) | MOVE | no | confirmed real callers: `models.handler.delegate_result` (async delegation reply, per-delegation) and `context.delegate.handler.result` (same path). Called via `$code{'context.delegate.collect'}->(...)` — legitimate dynamic dispatch, but definitely on the async-delegation reply hot path per completed delegation |
| src/context.delegate.dispatch | Crypt::Misc | hot (2 real callers on delegate/review paths) | MOVE | no | confirmed real callers via `$code{'context.delegate.dispatch'}` in `context.review.iterate` and `models.task.do-delegation` — per-dispatch; also exposed in `access.cmd.usr.*` for context.delegate. Real hot path |
| src/context.git.recent_changes | Git::Wrapper | N/A | N/A (no perlmod load in file) | yes | 0 `base.perlmod.{load,autoload}` calls — file uses `require Git::Native; require Git::Native::Diff;` (different module, different loader). Original row cited wrong module and loader. Referenced from context.priority.rank, context.compose.quick, coding.tools.handler.recent_changes, and context.init_code preloads for it |
| src/context.review.handler.page_result | Crypt::Misc | hot (real handler on review-iterate path) | MOVE | no | confirmed used as `reply_handler => 'context.review.handler.page_result'` in `context.review.iterate` (line 61) — per-page-of-review invocation. Real hot path within a review flow |
| src/context.share.export | JSON | hot (helper) | MOVE (unverified — no static callers found) | no | 0 static callers `<[context.share.export]>` outside subroutines.load-early — likely dispatched via cube command routing (context.share.export/import feels like a paired cmd), but not present in cube access.zenki excerpts examined. Cannot confirm hot statically |
| src/context.share.import | JSON | hot (helper) | MOVE (unverified — no static callers found) | no | same as export — no static callers, cannot confirm hot statically |
| src/ncode.cmd.workflow | YAML::XS | unverified (dynamic cmd) | MOVE (unverified — cmd frequency not determinable statically) | no | .cmd file, no static callers (expected); not in cube access.zenki excerpts — loaded in context/subroutines.load-early. Usage frequency unclear |
| src/ncode.transform.handler.wave_reply | Crypt::Misc | hot (real reply handler for wave transform) | MOVE | no | referenced as reply handler in `ncode.transform.wave` (line 109: `// qw\| ncode.transform.handler.wave_reply \|`) — invoked once per wave-transform LLM reply; if transform is used, this fires per operation |
| src/ncode.transform.wave | Crypt::Misc | medium (1 caller: ncode.cmd.transform) | MOVE | no | 1 real caller `<[ncode.transform.wave]>` in `ncode.cmd.transform` — that caller is itself a cube command (ncode.transform), invoked once per transform request. Confirmed on the ncode.transform hot path |
| src/image-quality.analyze | Time::HiRes | hot (per-image entry point, 2 static callers) | MOVE | no | 2 real callers: `vision-batch.child.analyze_job` (called inside a per-job worker loop in `vision-batch.child.loop`) and `vision-batch.child.cmd.analyze_image`. Time::HiRes is lightweight — MOVE justified |
| src/image-quality.vision.encode_image | MIME::Base64 | hot (per-image, called from http_api) | MOVE | no | 1 real caller: `image-quality.vision.http_api` (line 21), which is itself on the per-image analyze chain via `image-quality.analyze` — confirmed hot |
| src/image-quality.vision.http_api | HTTP::Tiny, JSON::XS | hot (per-image, called from analyze) | MOVE | no | 1 real caller: `image-quality.analyze` (line 34) — per-image invocation, confirmed hot |
| src/image-quality.vision.parse_response | JSON::XS | hot (per-image, called from analyze) | MOVE | no | 1 real caller: `image-quality.analyze` (line 55) — per successful vision response, confirmed hot |
| src/plugin.auth.auth-keypair.tofu-notification | JSON::PP | conditional (TOFU callback, only on new keys) | KEEP | yes | 1 real caller: `plugin.auth.auth-keypair.validate-incoming-tofu` (line 162) — TOFU notification fires only when a NEW/UNKNOWN key is encountered, which is a rare/conditional event (steady-state auth doesn't hit this). Load-on-demand is appropriate; "hot event callback" label overreaches |
| src/plugin.web.jobs.list | YAML::XS, HTML::Entities | unverified (web render helper) | MOVE (unverified) | no | 0 static callers `<[plugin.web.jobs.list]>` — likely rendered via dynamic template lookup (plugin.web.*). Frequency depends on web-jobs page traffic which is not statically knowable. YAML::XS `already in plugin.web.jobs.init_code` claim from original row would need per-init check — HTML::Entities is the actionable add if MOVE stands |
| src/plugin.web.space.orbital.synthetic-zenka-node | Digest::SHA, Crypt::Misc | hot (called from orbital json.context) | MOVE | no | 1 real caller: `plugin.web.space.orbital.json.context` (line 69), itself called from `plugin.web.space.state` — orbital state builder invoked repeatedly for the space UI |
| src/workspace-transfer.cmd.bug | POSIX | rare (1 static caller = wrapper cmd) | KEEP | yes | 1 real caller: `workspace-transfer.cmd.bug-commit` (line 13) — both are user-issued dev commands (bug reports, not automated). POSIX is core-Perl and lightweight but true frequency is admin-rare. Load-on-demand fine |
| src/workspace-transfer.cmd.checkpoint | POSIX | unverified (dev cmd, likely admin-rare) | KEEP (unverified — cmd frequency not determinable statically) | yes | .cmd file, 0 static callers (expected). Name "checkpoint" and content ("quick checkpoint commit and push") plus git-integration read as manual/admin dev command, not per-request hot path. Companion to workspace-transfer.cmd.bug which is also admin-rare. Load-on-demand appropriate |
| src/powershell.exec | IPC::Open3 | hot (5 callers incl. powershell.init_code) | MOVE | no | 5 real callers: powershell.init_code (called during init!), .plugin.screenshot-capture.invoke, .cmd.notify-recover, .notify, .cmd.display-switch-toggle. Since powershell.init_code itself calls it, the module IS loaded at init anyway — MOVE both simplifies and makes the loading explicit |
| src/powershell.pointer-stream-path | Crypt::Misc, AMOS7::SHM | conditional (per pointer-stream cmd) | MOVE | no | 1 real caller: `powershell.cmd.pointer-stream-path` (a cube command exposed in `access.cmd.usr.zenki` for powershell). Per-invocation of the cmd; module preload is the right call given the cmd exists and is exposed |
| src/site-yaml.cmd.export-stray-job | JSON::XS, YAML::XS | rare (admin/inspection cmd) | KEEP | yes | .cmd file — exposed narrowly in cube access.zenki under `site-yaml.export-stray-job` alongside `list-stray-jobs`/`confirm-stray-claimed`. Name and pairing suggests admin inspection of stray jobs, not per-request. Load-on-demand appropriate |
| src/site-yaml.cmd.list-stray-jobs | JSON::XS | rare (admin/inspection cmd) | KEEP | yes | .cmd file, same pattern as export-stray-job — inspection/admin, load-on-demand appropriate |
| src/httpd.vhost.dns_matches_local | IO::Interface::Simple, Net::DNS::Resolver | rare (per-install operation, not per-request) | KEEP | yes | 1 real caller: `httpd.cmd.install-vhosts` (line 55) — this is a vhost INSTALL/setup command, run manually to install vhost configs, NOT per-request routing. Original row assumed "per vhost routing decision" — wrong path. Rare admin, load-on-demand is fine |
| src/models.backend.kimi_web | Crypt::Misc | N/A | N/A (no perlmod load in file) | yes | 0 `base.perlmod.{load,autoload}` calls in file — nothing to move. 1 real caller (`models.chat.invoke_model` → `models.cmd.chat`) confirms it IS on the chat hot path, but the cited load doesn't exist |
| src/protocol-7-menu.handler.pointer-stream-path | AMOS7::SHM | rare (fires only on pointer-stream cmd sequence) | KEEP | yes | 1 real caller as reply handler in `protocol-7-menu.handler.pointer-stream-start` (line 22) — fires only when a pointer-stream is started from the menu, not per-menu-render. Rare interactive event; load-on-demand appropriate |
| src/screen.setup.cmd.snapshot | Cairo | rare (user-triggered minimap render) | KEEP | yes | .cmd file — descr "render display-layout minimap to PNG file" — user-invoked screenshot/minimap render, not automatic. Not exposed in cube access.zenki excerpts (narrow use). Cairo is heavy; keeping it lazy avoids paying for it on zenka boot when screen.setup is used only for layout config |
| src/screen.setup.ensure-display | Gtk3, Cairo, Glib | N/A | N/A (no perlmod load in file) | yes | 0 `base.perlmod.{load,autoload}` calls in file — nothing to move. 3 real callers (screen.setup.cmd.gtk-focus-recover, .enumerate-monitors, .open_window). Original row cites Gtk3/Cairo/Glib as "already in screen.setup.init_code; add Cairo/Glib and drop redundant inline load" — but there IS no inline load here to drop |
| src/transport.handle.socks5 | IO::Socket::Socks | unverified (dynamic dispatch handler) | MOVE (unverified) | no | 0 static callers `<[transport.handle.socks5]>` — the file itself uses a conditional-load pattern (`base.perlmod.loaded` OR `base.perlmod.autoload`). Likely dispatched dynamically as one of several `transport.handle.*` connection strategies. Cannot confirm frequency statically, but pattern is already load-on-demand-with-cache — preload only if SOCKS5 is a common transport in this deployment |
| src/calc.cmd.val.eval_bigrat | Math::BigRat | hot (recursive helper on calc eval path) | MOVE | no | **FILE PATH IN ROW IS WRONG** — actual file is `src/calc.val.eval_bigrat`, not `src/calc.cmd.val.eval_bigrat`. Recursive helper (calls itself, plus 1 caller `<[calc.val.eval_bigrat]>` in `calc.cmd.val` — the main calc cmd) — every calc invocation walks the Math::Symbolic tree with a BigRat evaluate per node. If calc is used at all, this is the arithmetic core |
| src/invoke-web.cmd.health | LWP::UserAgent | unverified (health-check cmd) | KEEP (unverified — cmd frequency not determinable statically) | yes | .cmd file — descr "check invoke.ai HTTP health endpoint". Not exposed in cube access.zenki excerpts (invoke-web.cmd.* not there). Health-check commands are typically admin-invoked or periodically-polled, unclear which here. Given LWP::UserAgent is heavy, err toward KEEP unless a periodic caller emerges |
| src/llm.service.subprocess_wrapper | JSON::PP | hot (3 callers on consensus/classify paths) | MOVE | no | 3 real callers: `llm.service.consensus_vote` (multi-model voting), `smtpd.classify` (2 call sites — per-message classification via `smtpd.cmd.inject`/`.reclassify`). Confirmed on hot per-message classification path. NOTE: methodology trap #3 (name-collision) explicitly cited this module — verified the 3 hits are real `<[llm.service.subprocess_wrapper]>` invocations, not sibling `.estimate_tokens` false positives |
| src/websocket.send | Protocol::WebSocket::Frame | hot (3 real callers, per outgoing frame) | MOVE | no | 3 real callers: `kimi.wire.send` (base send helper called by kimi.wire.initialize + kimi.wire.prompt), `kimi.wire.question_respond`, `kimi.wire.approval_respond`. Every outbound kimi-web websocket frame goes through this — genuinely hot |
| src/zulum.cmd.export-streams | JSON | N/A | N/A (no perlmod load in file) | yes | 0 `base.perlmod.{load,autoload}` calls in file — nothing to move. HOWEVER: this file IS extremely hot — registered as a timer handler in `zulum.init_code` firing every 200ms (5 Hz) with `after=1, interval=0.2, repeat=TRUE`. If JSON load were added here it would be the strongest MOVE case in the list; as-is, nothing to move |

## Summary

Recount verified directly against the table's `recommendation`/`changed?`
columns (the first-pass counts below this line didn't add up; corrected
2026-08-26):

- **Total re-verified:** 59
- **Unchanged — still some form of MOVE (`changed?` = no):** 34
  - Confirmed `MOVE` (clean, hot verified): 22
  - `MOVE (unverified)` — cmd/handler/dispatch frequency not statically
    determinable, or no static callers found at all: 12
- **Changed — flipped away from MOVE (`changed?` = yes):** 25
  - Flipped to `KEEP` (rare / one-shot / admin): 13 confirmed + 2
    `KEEP (unverified)` = 15
  - Flipped to `N/A` (file has no `base.perlmod.{load,autoload}` call at
    all — nothing to move): 10
- **Row itself defective (wrong file path):** 1 (`calc.cmd.val.eval_bigrat`
  → actual file is `calc.val.eval_bigrat`); counted under the 22
  confirmed-MOVE for the fixed path
- Check: 22 + 12 + 15 + 10 = 59 ✓; 34 unchanged + 25 changed = 59 ✓

The `N/A (no perlmod load in file)` bucket is the most consequential
finding of this pass: 10 of the 59 rows cite a `MOVE` recommendation for
a load call that doesn't exist in the file. In each case the file is
either (a) using `use`/`require` for a different loader, (b) using a
different module than the row claims (`Git::Wrapper` vs `Git::Native`),
or (c) relying on ambient preload from elsewhere. Any refactor pass that
follows this list must skip these rows — moving a nonexistent load has
no effect and would silently mis-record the "moved" state.

The `MOVE (unverified)` bucket contains 12 `.cmd`/`.handler`/dispatch
rows where static grep genuinely cannot determine frequency; per
methodology trap #2 these should either be settled by a live-invocation
trace on the running zenkas, or accepted as "preload defensively because
the module isn't heavy."

The 15 flipped-to-KEEP rows share a common pattern with the 6
human-corrected rows from 2026-07-26: templated "hot (.cmd/.handler/
helper)" reasoning that doesn't survive checking the actual caller.
Notable examples: `base.tmp_dir` (one-shot per zenka lifetime via
`base.root.drop_privs`, methodology trap #1); `base.file.tie_array` (one
admin caller); `httpd.vhost.dns_matches_local` (vhost INSTALL command,
not per-request routing); `plugin.auth.auth-keypair.tofu-notification`
(fires only on unknown-key events, not per-auth); `site-yaml.cmd.
list-stray-jobs`/`export-stray-job` (admin inspection cmds).

## Constraints observed

- No module file was edited (verification only).
- No stub signature lines added — signing left to the system.

#,,,,,,,.,...,,,,,..,,,,.,,,,,..,,.,.,.,.,...,..,,...,...,.,.,,,.,,,,,,,,,.,,,
#SNCGIM5XGL7PPKMBV6N5HIR5RZDMTZKCNIJH2MRKYRRMNNXTMBSB7GJQPRHEA2VX3D4WMY3Y7XXYO
#\\\|IDDJICKE7NEZGSABJNSSDZWTWJENBHB2C7PNC7BZPAL7GJKPXEB \ / AMOS7 \ YOURUM ::
#\[7]2TACKNKJNFGXECPLPTN2ZP7U6BPEOYLLRRPXEC7CJROEAXPPGEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
