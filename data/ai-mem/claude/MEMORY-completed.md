# MEMORY-completed — Completed Sessions & System Status

session archive index and current live-system status (queue/roadmap, resolved bugs).

## Completed Sessions
- [topic-completed](topic-completed.md) — all session summaries (Feb 2026 → present)
- [httpd route-arg parsing fix](topic-httpd-route-arg-parsing-fix.md), [jobsite stray-job recovery](topic-jobsite-stray-recovery.md) — LANDED 20bdf36ff / a52a6a4b8

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
  PENDING SIGN: base.cmd.reload now unions modules.load into the reload set (caveat: modules.preload/
  literal load_modules calls still missed); whitelist_miss no longer pollutes base.p7_mod.loaded with
  leaf sub names on self-heal; cube's modules.load gained ascii + format.yaml.
- [sys-deps wiring completion](project-sys-deps-wiring-completion.md) — PENDING SIGN: retired debian
  zenka's dependency-management stack + session's dependency-check half per the sys-deps-zenka-audit
  disposition table (K3 dispatch); v7 gained auth.client/ascii/format.yaml in modules.load along the
  way. Real pipeline bugs in AMOS7::deps::* found+fixed during live verification, not just deletion.
- [ondemand-zenki registry wipe](project-ondemand-zenki-registry-wipe.md) — LANDED (uncommitted):
  v7.set_up_ondemand_zenki was fed only the added-since-last-run delta, wiping <v7.ondemand_zenki> to
  empty on reload; broke clean-idle-shutdown detection for every on-demand zenka (restart-loop despite
  restart.disabled). Confirmed live at 0/56, fixed, confirmed 56/56.

#,,,,,..,,,..,,,.,,.,,,,.,.,,,,.,,...,..,,...,..,,...,...,..,,.,,,,,.,.,.,,..,
#PWVHVM3I4IQUM44HH4RMUXZBS5MYJ64SMRKU5MJXRLGXBJ5DOO52AKOZCFXRU3MSLMXR45N6A5XHA
#\\\|NG4THGPJEEFBDPKTPCTVQOOAUMTDPNPZCZZ7HQ23PE5FJLXXWX6 \ / AMOS7 \ YOURUM ::
#\[7]CVIFGHYZKTW4FYUWI6L2XNLRARVGO5JE5RNWJZ6O36TS4OILP6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
