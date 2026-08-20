# perlmod MOVE-recommendation re-verification — read-only, no edits

**Priority:** Medium
**Type:** Re-verification of an earlier categorization pass — DO NOT edit any code
**Model:** kimi K3

## Before you start

Read `data/ai-mem/kimi/MEMORY.md` and `data/ai-mem/kimi/coding-style.md` first.

## Background

`data/tasks/perlmod-categorization-results.md` is the output of an earlier
K2.7 dispatch that classified 152 `base.perlmod.load`/`autoload` call sites
outside `*.init_code`/`*.pre_init`/`*.post_init` files. Human review already
caught and corrected 6 misclassified rows (search that file for "corrected
2026-07-26" to see them) — all shared a pattern: a `MOVE` recommendation
backed by vague or templated reasoning ("called on every X invocation,
modules should be in init_code") that didn't match the file's real caller
count once actually checked.

That review only spot-checked a subset. **This task re-verifies all 59
currently-marked `MOVE` rows** (listed below, in the same `file ||| module(s)
||| frequency ||| reasoning` shape as the results file) before any of them
get handed to an actual refactor pass.

## Known methodology traps from the first review pass — read carefully

1. **Fan-in count ≠ call frequency.** A helper with exactly one static
   caller can still be called very often if that one caller is itself a
   hot path (e.g. inside an event loop or a per-request handler). Don't
   stop at "how many files reference this" — check what the caller(s)
   actually are and how often *they* run. Conversely, a caller that's
   itself only invoked once at boot (e.g. anything reached only through
   `base.root.drop_privs`, which per `CLAUDE.md`'s documented zenka startup
   sequence runs exactly once per zenka lifetime) means the callee is also
   effectively one-shot, no matter how "core" it sounds.
2. **`.cmd.*`/`.handler.*` files are invoked via cube's dynamic
   string-based command routing, not static code references.** Static
   grep for callers is *meaningless* for these — zero hits is expected and
   normal, not evidence of rarity. You cannot determine their real
   invocation frequency from source alone. For these files: look for
   corroborating signals instead of guessing — is the command granted
   broadly in `cfg/zenki/*/access.zenki` (`access.cmd.usr.cube`)
   or narrowly? Does the zenka itself seem to be a core/ubiquitous one or a
   niche feature? If you still can't tell confidently, say so explicitly —
   report `MOVE (unverified — cmd/handler frequency not determinable
   statically)` rather than asserting "hot" with invented confidence.
3. **Nested-namespace name collisions produce false-positive "callers."**
   Grepping for `llm.service.subprocess_wrapper` will also match
   `llm.service.subprocess_wrapper.estimate_tokens`'s own `# name = ...`
   header line — that's a *sibling* file in a nested namespace, not an
   actual caller. Confirm a "caller" hit is a real `<[module.name]>->()`
   invocation, not just a substring match against another file's own
   declared name.
4. **A templated-sounding justification is itself a red flag**, independent
   of which file it's attached to. If your own reasoning for a row reads
   almost identically to several other rows' reasoning, that's a sign you
   haven't actually checked that specific file — go check it for real
   before writing it down.

## The 59 rows to re-verify

```
modules/base.file.temp ||| File::Path ||| hot (core helper) ||| core temp-file helper called frequently; File::Path should be in base.init_code
modules/base.file.tie_array ||| Tie::File ||| hot (core helper) ||| core file helper called whenever tied arrays are needed
modules/base.handler.read.encryption-wrapper ||| Crypt::AuthEnc::ChaCha20Poly1305 ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/base.handler.write.encryption-wrapper ||| Crypt::AuthEnc::ChaCha20Poly1305 ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/base.stdio.transport.connect ||| IO::Socket::UNIX ||| hot (helper) ||| called on every (helper) invocation, modules should be in init_code
modules/base.stdio.transport.listen ||| IO::Socket::UNIX ||| hot (helper) ||| called on every (helper) invocation, modules should be in init_code
modules/base.tmp_dir ||| File::Path ||| hot (core helper) ||| called on every (core helper) invocation, modules should be in init_code
modules/channels.cmd.ai-review-approve ||| JSON::PP ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/channels.cmd.ai-review-feedback ||| JSON::PP ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/channels.cmd.ai-review-status ||| JSON::PP ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/channels.cmd.ai-review-submit ||| JSON::PP ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/channels.handler.content-detected ||| JSON::PP ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/channels.handler.playlist-integration ||| JSON::PP ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/channels.memory-sync.batch-send ||| JSON::PP ||| hot (helper) ||| called on every (helper) invocation, modules should be in init_code
modules/channels.util.yaml_decode ||| YAML::XS ||| hot (helper) ||| utility called whenever channels decode YAML; should be preloaded
modules/channels.util.yaml_encode ||| YAML::XS ||| hot (helper) ||| utility called whenever channels encode YAML; should be preloaded
modules/coding.tools.handler.git_diff_output ||| Git::Wrapper ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/branch.data.bind ||| YAML::XS ||| hot (branch cmd) ||| branch data command invoked per bind operation; YAML::XS should be in branch.init_code
modules/branch.data.query ||| YAML::XS ||| hot (branch cmd) ||| branch data command invoked per query; YAML::XS should be in branch.init_code
modules/branch.data.unbind ||| YAML::XS ||| hot (branch cmd) ||| branch data command invoked per unbind; YAML::XS should be in branch.init_code
modules/branch.storage.list ||| YAML::XS ||| hot (helper) ||| storage helper called when listing snapshots; YAML::XS should be in branch.init_code
modules/branch.storage.persist ||| YAML::XS ||| hot (helper) ||| storage helper called when persisting snapshots; YAML::XS should be in branch.init_code
modules/branch.storage.restore ||| YAML::XS ||| hot (helper) ||| storage helper called when restoring snapshots; YAML::XS should be in branch.init_code
modules/branch.storage.sync ||| YAML::XS ||| hot (helper) ||| storage helper called when syncing snapshots; YAML::XS should be in branch.init_code
modules/jobsite.dispatch.assessments ||| Encode, HTML::Entities ||| hot (helper) ||| called on every (helper) invocation, modules should be in init_code
modules/jobsite.util.build_prompt ||| HTML::Entities, Encode ||| hot (helper) ||| used for every new job assessment prompt; preload in jobsite.init_code
modules/context.delegate.collect ||| Crypt::Misc ||| hot (.handler) ||| async delegation result handler; Crypt::Misc should be in context.init_code
modules/context.delegate.dispatch ||| Crypt::Misc ||| hot (helper) ||| called on every (helper) invocation, modules should be in init_code
modules/context.git.recent_changes ||| Git::Wrapper ||| hot (helper) ||| context helper called per context build; Git::Wrapper should be preloaded
modules/context.review.handler.page_result ||| Crypt::Misc ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/context.share.export ||| JSON ||| hot (helper) ||| context sharing helper called frequently; JSON should be in context.init_code
modules/context.share.import ||| JSON ||| hot (helper) ||| context sharing helper called frequently; JSON should be in context.init_code
modules/ncode.cmd.workflow ||| YAML::XS ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/ncode.transform.handler.wave_reply ||| Crypt::Misc ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/ncode.transform.wave ||| Crypt::Misc ||| hot (helper) ||| called in transform loops; preload Crypt::Misc in ncode.init_code
modules/image-quality.analyze ||| Time::HiRes ||| hot (helper) ||| main image-quality entry point called per image; Time::HiRes is lightweight and should be preloaded
modules/image-quality.vision.encode_image ||| MIME::Base64 ||| hot (helper) ||| called for every analyzed image; preload in image-quality.init_code
modules/image-quality.vision.http_api ||| HTTP::Tiny, JSON::XS ||| hot (helper) ||| vision API client invoked per analyzed image; preload both modules
modules/image-quality.vision.parse_response ||| JSON::XS ||| hot (helper) ||| parses every successful vision response; preload JSON::XS
modules/plugin.auth.auth-keypair.tofu-notification ||| JSON::PP ||| hot (event callback) ||| TOFU callback fires during auth; preload JSON::PP in plugin.auth.auth-keypair.init_code
modules/plugin.web.jobs.list ||| YAML::XS, HTML::Entities ||| hot (web render) ||| YAML::XS already in plugin.web.jobs.init_code; add HTML::Entities and remove inline load
modules/plugin.web.space.orbital.synthetic-zenka-node ||| Digest::SHA, Crypt::Misc ||| hot (helper) ||| synthetic node builder called repeatedly; preload in orbital init_code
modules/workspace-transfer.cmd.bug ||| POSIX ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/workspace-transfer.cmd.checkpoint ||| POSIX ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/powershell.exec ||| IPC::Open3 ||| hot (helper) ||| core PowerShell invocation helper; preload IPC::Open3 in powershell.init_code
modules/powershell.pointer-stream-path ||| Crypt::Misc, AMOS7::SHM ||| hot (.cmd wrapper) ||| exposed via cmd wrapper; preload Crypt::Misc and AMOS7::SHM in powershell.init_code
modules/site-yaml.cmd.export-stray-job ||| JSON::XS, YAML::XS ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/site-yaml.cmd.list-stray-jobs ||| JSON::XS ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/httpd.vhost.dns_matches_local ||| IO::Interface::Simple, Net::DNS::Resolver ||| hot (helper) ||| DNS check helper likely used per vhost routing decision; preload in httpd.init_code
modules/models.backend.kimi_web ||| Crypt::Misc ||| hot (helper) ||| routes every kimi chat/task request; preload Crypt::Misc in models.init_code
modules/protocol-7-menu.handler.pointer-stream-path ||| AMOS7::SHM ||| hot (.handler) ||| called on every (.handler) invocation, modules should be in init_code
modules/screen.setup.cmd.snapshot ||| Cairo ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/screen.setup.ensure-display ||| Gtk3, Cairo, Glib ||| hot (helper) ||| Gtk3 already in screen.setup.init_code; add Cairo/Glib and drop redundant inline load
modules/transport.handle.socks5 ||| IO::Socket::Socks ||| hot (helper) ||| shared SOCKS5 connection helper; preload in transport.init_code
modules/calc.cmd.val.eval_bigrat ||| Math::BigRat ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/invoke-web.cmd.health ||| LWP::UserAgent ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
modules/llm.service.subprocess_wrapper ||| JSON::PP ||| hot (helper) ||| called on every (helper) invocation, modules should be in init_code
modules/websocket.send ||| Protocol::WebSocket::Frame ||| hot (helper) ||| core websocket send helper; preload in websocket.init_code
modules/zulum.cmd.export-streams ||| JSON ||| hot (.cmd) ||| called on every (.cmd) invocation, modules should be in init_code
```

## For each row

1. Re-derive real callers with `search_code`/`grep`, being careful about
   the false-positive traps above.
2. Trace at least one level up: what calls the caller(s)? Is that itself
   hot, one-shot, or admin/rare?
3. Decide: `MOVE` (confirmed hot, safe to relocate), `KEEP` (confirmed
   rare/conditional, or a `.cmd`/`.handler` file where you found concrete
   corroborating evidence of rarity), or `MOVE (unverified)` /
   `KEEP (unverified)` for `.cmd`/`.handler` files where you genuinely
   can't tell — don't force a confident-sounding answer where the
   information doesn't exist.
4. Write a **specific** one-line reason naming the actual caller(s) and
   what you found about their frequency — not a template.

## Output

Write to `data/tasks/perlmod-move-reverification-results.md`, same table
format as the original results file, one row per file in the same order as
listed above. Add a `changed?` column (`yes`/`no`) so it's easy to see which
of the 59 rows the deeper check actually moved.

## Constraints

- Do not edit any module file — this is verification only.
- If you learn something non-obvious, add it to
  `data/ai-mem/kimi/coding-style.md` or `data/ai-mem/kimi/MEMORY.md`.

## Notes

- signatures_note: leave signing to the system, no stub lines

#,,.,,..,,,..,,..,...,.,,,.,,,...,,,,,.,.,,..,..,,...,...,...,...,..,,,..,,..,
#I7773ZWBFY45V54HQVRO3XD2XE676JY232CTYMMMPQCR4HD5IJAOJMQPXSK3WGXCET7QFJNBQXJVA
#\\\|VX5V5C22XR3KP46PIXMQGDOLBL5FB5G7X2APBB4QZUDJLNUTXPA \ / AMOS7 \ YOURUM ::
#\[7]NDXQB7WZ5LLBTI5Y7RI5XHXY2VNWSREZUDD7JKTNGG6PXGJ2N6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
