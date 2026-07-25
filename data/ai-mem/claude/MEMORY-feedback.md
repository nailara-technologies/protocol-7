# MEMORY-feedback — Feedback & Gotchas

hard-won lessons and failure modes. kimi/claude dispatch strategy & infra hardening, tasks-completed
scan-verdict distrust, no-sudo on p7-owned files, perl and/or precedence, p7 route-send wire protocol,
coding-zenka reasoning/edits/inject pitfalls, ncode tooling, perltidy self-heal, arg calling convention,
memory-management timing, git-log false-duplication, webkit-vs-firefox css blindspots.

## Feedback
- [edit-via-project-path-not-dotclaude](feedback-edit-via-project-path-not-dotclaude.md) — edit memory via data/ai-mem/claude/, not ~/.claude/projects/.../memory/ (same file, latter re-prompts every edit)
- [base-prefix-stripped](feedback-base-prefix-stripped.md) — base.X→X swap_subs families (event, file, base32, templates, chk-sum, zenka.push, etc.); never conclude a bare call is broken from `ls modules/` alone; two families swapping to the same short name confuses dep-graph's scanner
- [filter-repo-amend](feedback-filter-repo-amend.md) — `AMEND=1` prefix required for any git history-rewrite: filter-repo AND plain `commit --amend` both, else silently blocked by pre-commit's version-mismatch check
- [whitelist-vs-access-cmd-usr-cube](feedback-whitelist-vs-access-cmd-usr-cube.md) — subroutine.white-list renamed to subroutines.load-early 2026-07-25 (compile timing only); access.cmd.usr.cube (cube routing) is the separate mechanism, don't conflate
- [file-stat-shadowing](feedback-file-stat-shadowing.md) — bin/Protocol-7's global `use File::stat` makes bare `stat()` return an object everywhere, not a 13-elem list; use `File::stat::stat(...)->mtime` etc. (was orphaned/unindexed — cost a live debugging detour before being found)
- [reload-success-doesnt-guarantee-new-file-loaded](feedback-reload-success-doesnt-guarantee-new-file-loaded.md) — `reload all` reported success twice without recompiling a fresh jobsite.cmd.* file; verify with a literal marker, escalate to a full v7.restart, don't just re-reload
- [webkit-double-click-dispatch](feedback-webkit-double-click-dispatch.md) — web-browser zenka's WebKit fires click twice for one tap on some buttons, Firefox doesn't; wrap every handler in a shared debounceClick() from the start, don't patch button-by-button
- [tasks-completed-scan-verdict-trust](feedback-tasks-completed-scan-verdict-trust.md) — "still open" as unreliable as "move to completed"; 31/52 false negs, incl. live auth gap
- [kimi-dispatch-infra-hardening](topic-kimi-dispatch-infra-hardening.md) — --afk flag, k3/k2.7/k2.7-fast routing; MCP bridge timeout ≠ dispatch failure
- [kimi-k3-thinking-effort](topic-kimi-k3-thinking-effort.md) — Low/High/Max in vendor UI, not in API/installed CLI
- [coding-zenka buffer rescue](topic-coding-zenka-session9.md) — idle-shutdown backups readable via group-perm `xz -dc`, no sudo
- [nested-dispatch-session-tracking](feedback-nested-dispatch-session-tracking.md), [webkit vs firefox css blindspots](feedback-webkit-vs-firefox-css-blindspots.md)
- [no sudo for privileged fs ops](feedback-no-sudo-privileged-fs-ops.md) — never `sudo` a protocol-7-owned file; hand command to user
- [small-generic-components-before-wiring](feedback-small-generic-components-before-wiring.md) — for multi-feature-converging fixes, decompose into a few independently-complete generic pieces before any code; pick a low-stakes pilot
- [perl and/or precedence in my-assignment](feedback-perl-and-or-precedence-in-my-assignment.md) — `my $x = A and B` only assigns A; use && / ||
- [p7 route-send wire protocol](feedback-p7-route-send-wire-protocol.md), [oversize single-line protocol](feedback-oversize-single-line-protocol.md)
- [no unsolicited cross-zenka push](feedback-no-unsolicited-cross-zenka-push.md), [vax-int vs v7-epoch](feedback-vax-int-vs-v7-epoch.md)
- [log string hygiene](feedback-log-string-hygiene.md), [ondemand timeout tiering](feedback-ondemand-timeout-tiering.md)
- [claude_dispatch summarize hang](feedback-claude-dispatch-summarize-hang.md)
- [init-code-return-values](feedback-init-code-return-values.md), [memory-sync-timing](feedback-memory-sync-timing.md), [memory-management](feedback-memory-management.md)
- [claude-dispatch-strategy](feedback-claude-dispatch-strategy.md), [kimi-code-review](feedback-kimi-code-review.md), [kimi-signatures](feedback-kimi-signatures.md), [kimi-dispatch](feedback-kimi-dispatch-pattern.md)
- [kimi-k2.7-vs-k3-tier-economics](project-kimi-k2.7-vs-k3-tier-economics.md) — K3 categorically stronger reasoning, not just steering; ~3.75x price reflects it, use for higher-impact tasks
- [model-precision-analysis](feedback-model-precision-analysis.md), [coding-zenka-edits](feedback-coding-zenka-edits.md)
- [coding-zenka-reasoning](feedback-coding-zenka-reasoning.md), [coding-zenka-inject](feedback-coding-zenka-inject.md)
- [arg-regression](feedback-arg-regression.md), [arg-calling-convention](feedback-arg-calling-convention.md)
- [prefer-parsed-config](feedback-prefer-parsed-config.md), [true-false](feedback-true-false-constants.md)
- [web-serialization-and-inlining](feedback-web-serialization-and-inlining.md), [task-show-multiline](feedback-task-show-multiline.md)
- [list-return-format](feedback-list-return-format.md), [stop-and-revert](feedback-stop-and-revert.md)
- [utf8-module-literals](feedback-utf8-module-literals.md), [watcher-state-machines](feedback-watcher-state-machines.md)
- [ncode-tools](feedback-ncode-tools.md), [perltidy-sil0](feedback-perltidy-sil0.md) — use ncode replace/parse-headers; ptd `-sil=0` self-heals
- [git-log-all-false-duplication](feedback-git-log-all-false-duplication.md) — false "dup commits" = pager strips +/-, colors lost
- [ncode-access-gap](topic-ncode-access-gap.md) — a zenka only sees its direct neighbor; grant access.cmd.usr.cube
- [ncode-safe-refactor-workflow](topic-ncode-safe-refactor-workflow.md) — .git chmod-child LANDED; warn_apply TTY-only
- [cmd-module-call-convention](feedback-cmd-module-call-convention.md) — .cmd. network modules use $call, not $ARG
- [design-ideation-capture](feedback-design-ideation-capture.md), [coding-timeout-restart-loop](feedback-coding-timeout-restart-loop.md) — offer spin-off docs
- [swap-subs-not-fragile](feedback-swap-subs-not-fragile.md) — base.swap_subs whitelist itself isn't fragile; real gap was missing canonical doc of active swaps AND (corrected 2026-07-25) the loader's own nested-lifecycle-hook coverage, see [[bug-swap-subs-nested-lifecycle-hook-gate]]
- [swap-subs-nested-lifecycle-hook-gate](bug-swap-subs-nested-lifecycle-hook-gate.md) — RESOLVED e90dd04ae: base.<X>.pre_init (base32, chk-sum.bmw, ...) never got a stub when un-whitelisted, so swap_subs never ran and short-name call sites crashed instead of deferred-compiling; also fixes deferred_compile self-recompile loop + register_src_deps ancestor collapse
- [init-reports-one-shot-flush](feedback-init-reports-one-shot-flush.md) — system.init_reports flushes once at connect only; deferred-reply/live-runtime sends need system.callbacks.initialized or direct route-send instead
- [undef-sub-scanner-verification](feedback-undef-sub-scanner-verification.md) — check eval-wrapping/guards + grep for sprintf-constructed dynamic dispatch before renaming anything; scanner has zero reachability analysis
- [v7-zenka-startup-config-placement](feedback-v7-zenka-startup-config-placement.md) — zenka-startup.v7 keys must be top-level not inside a ':' section, or v7 never sees them; v7.reload config doesn't re-parse the file, need v7.reload all/init
- [swap-subs-not-fragile](feedback-swap-subs-not-fragile.md) — base.X→X swap safe/mechanical, but check `ncode s src:base.X swap_subs` before calling any base.* primitive from new code, or you'll call the pre-swap dead name
- [eval-error-macro-call-site](feedback-eval-error-macro-call-site.md) — reading $EVAL_ERROR inline as an arg at a `<[...]>` call site can come back empty; capture into a lexical (or use `<[base.str.eval_error]>`) immediately after eval
- [kimi-dispatch-idle-timeout-recovery](feedback-kimi-dispatch-idle-timeout-recovery.md) — MCP 1800s-idle "failed" ≠ dispatch failed; underlying process often finishes fine, recover via session_catchup(client:kimi, session_id) not re-dispatch
- [posix-group-write-precedence](feedback-posix-group-write-precedence.md) — chmod-child grants need | 0020 (group-write) not | 0002 (other-write); a process that's a supplementary-group member of the file gets checked against group bits only, other bits never consulted; write_with_perms still has this bug live

#,,..,..,,,.,,,,,,...,,,.,,..,,.,,,..,,,,,.,.,..,,...,...,..,,,..,..,,...,,..,
#YGCEPLYTWLNI4URUX6PA2CPUQFXADQIKJVN6LWFFXJCQGELMSIQ3COTQF7G6AWTSNBVQ57HZH5RCS
#\\\|UERPRSPA6MK4TEVDJ55DE54C7F53RK5ULEGIR6XFZNIUSA7QB7I \ / AMOS7 \ YOURUM ::
#\[7]PNXK6C7QWEOFW5GFUFTP56R5NKXLQT4WBPQRSE5BB5YGE6ILKECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
