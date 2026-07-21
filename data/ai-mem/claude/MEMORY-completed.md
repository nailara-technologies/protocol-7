# MEMORY-completed — Completed Sessions & System Status

session archive index and current live-system status (queue/roadmap, resolved bugs).

## Completed Sessions
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)
- [httpd route-arg parsing fix](topic-httpd-route-arg-parsing-fix.md), [jobsite stray-job recovery](topic-jobsite-stray-recovery.md) — LANDED 20bdf36ff / a52a6a4b8
- [coding-zenka resilience + model switch](project-coding-zenka-resilience-and-model-switch-2026-07-21.md) —
  LANDED b9689d5ad..047c5d338: ask-reply timeout/backend-key bugs, default model switched to
  ZDMAPAY:AR3OCKQ (vision-capable, VRAM-tuned), self-test retry+restart resilience (2 bugs found
  live-testing the fix itself), bin/ptd exclusion regex, SUGGESTION-INTEGRATION-QUEUE.md marked
  blocker-level. task-append backend-lock-leak bug diagnosed + unstuck live, NOT yet code-fixed.

## System Status
- [next-steps](topic-next-steps.md) — queue, roadmap
- letsencr working; reasoning.branch.* LIVE; coding zenka operational
- [signature endline bug](bug-signature-endline-restoration.md) — RESOLVED: state-0/7 harmonized
- [auth.client namespace split](topic-auth-client-namespace-split.md) — LANDED b674ecd80/ae6b1f79b:
  auth.* server/client split, undef-subs buffer + console_report toggle, new base.code.*/base.mod.exists
  primitives. nshell/cube swept clean-ish; coding + ~90 other zenki not yet swept.
- [base.handler.whitelist_miss eval->call_optional migration](project-depgraph-conditional-calls-blindspot.md)
  — LANDED c3870ebe5: crypt/source calls gated on base.mod.exists instead of eval; whitelist regen shrank
  as expected but bin/dev/dep-graph doesn't understand the conditional-call pattern yet.
- [reload modules.load + p7_mod.loaded registry fixes](project-reload-modules-load-registry-fix.md) —
  LANDED 1a3f2a33c: base.cmd.reload now unions modules.load into the reload set (caveat: modules.preload/
  literal load_modules calls still missed); whitelist_miss no longer pollutes base.p7_mod.loaded with
  leaf sub names on self-heal; cube's modules.load gained ascii + format.yaml.
- [sys-deps wiring completion](project-sys-deps-wiring-completion.md) — LANDED 255d8cc43 (+ v7 prereqs
  81403b3b8/c06c9d503/c80dfacfc/e1ca9351e): retired debian zenka's dependency-management stack +
  session's dependency-check half per the sys-deps-zenka-audit disposition table (K3 dispatch); v7
  gained auth.client/ascii/format.yaml in modules.load along the way. Real pipeline bugs in
  AMOS7::deps::* found+fixed during live verification, not just deletion.
- [ondemand-zenki registry wipe](project-ondemand-zenki-registry-wipe.md) — LANDED 255d8cc43:
  v7.set_up_ondemand_zenki was fed only the added-since-last-run delta, wiping <v7.ondemand_zenki> to
  empty on reload; broke clean-idle-shutdown detection for every on-demand zenka (restart-loop despite
  restart.disabled). Confirmed live at 0/56, fixed, confirmed 56/56.
- [ondemand idle timeout vs active STRM streams](ondemand-idle-timeout-active-streams.md) — LANDED
  9eba08e3d + a4fdfa300: base.event.callback.io-idle-restart now checks base.stream.*'s existing
  session/streams/producer state before re-arming shutdown; on-demand zenki serving live STRM push
  subscribers (graphics-matrix, X-11, nodes, kimi-web, ticker, radio, discover, external, mod-test)
  no longer get shut down mid-subscription every idle cycle. Two follow-up regressions found via
  live testing and fixed in a4fdfa300: 8 producers weren't calling base.stream.close on push
  failure (leaked producer state, permanently blocked re-arming); the idle watcher itself is a
  one-shot that needed an explicit nudge from base.stream.close to notice cleanup happened.
  graphics-matrix.init_code also made reinit-safe (mkdir/timer registration were reload-unsafe,
  unrelated pre-existing bug found in the same session). Both directions live-verified.
- [base.log vs base.logs sprintf confusion](feedback-base-log-vs-logs-sprintf.md) — LANDED 9eba08e3d:
  113 call sites across 63 files were passing a %s/%d template + args to base.log (which never
  sprintfs) instead of base.logs; root-caused a live p7-log crash-loop, then swept codebase-wide via
  kimi k2.7, independently re-verified clean.
- [dependency restart reconnect primitive](project-dependency-restart-reconnect-primitive.md) —
  LANDED 7e83d6915 + a18850091: new v7.notify_restart + base.zenka.on_restart primitive, so a
  running zenka detects when a dependency it has a stateful relationship with restarts (STRM
  subscribe, SHM handshake) and reconnects automatically. Opus's first pass used instance_id as
  the restart signal -- wrong, v7.zenka.instance.restart reuses the same instance_id in place --
  corrected to cube_sid, which changes on every restart. Both pilots wired and live-verified:
  protocol-7-menu/powershell pointer-stream (SHM) across two consecutive v7.restart cycles, and
  base.strm.subscribe's own publisher-restart re-affirm gap (STRM, dispatched to kimi k3,
  independently re-verified) across two consecutive cred-mesh/proxy restart cycles.

#,,.,,,..,.,,,,..,,,,,,,,,,..,,,.,,..,,.,,.,.,..,,...,...,...,,.,,,..,,.,,,..,
#CCR2TRDKZZRTMQ22Q5BN6ESMCKBQ5IXINZAECQWN6BOHMWG2ZDC7N5N4KEWPQRKH2LTOLXFJDCIQI
#\\\|CFUZ2QVQAZAX555AVVJB2IHQVEJN3D4GXZJD7R5MUYFKXTN3URS \ / AMOS7 \ YOURUM ::
#\[7]FOUDGOAKCQ6NULWQGKIVF3J7AZA4JOF7RNF77AOQVRY4CDZASKAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
