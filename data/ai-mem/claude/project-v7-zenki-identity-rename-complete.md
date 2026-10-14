---
name: project-v7-zenki-identity-rename-complete
description: the v7 management zenka was renamed to v7-zenki (full-consistency scope) and the p7-<zenka> symlink prefix change landed, both live-verified and pushed; full detail in HANDOVER.md 2026-09-02
metadata:
  type: project
---

The `v7` management zenka was renamed to `v7-zenki` across `src/`, `cfg/`, and `bin/Protocol-7`
(full-consistency scope: files, config, data-key/code-sugar, quote-word identity comparisons,
access-control identity keys, runtime paths) plus a follow-up commit covering `bin/dev`,
`bin/admin`, `bin/test-scripts`, a purge-exclusion-list fix in `bin/Protocol-7`, a new
symlink-chain zenka-name-resolution feature (todo `MPV`, done), and a `README.md`/`data/md/`
documentation catchup.

**Why**: continuation of an established rename-cleanup campaign this session, sequenced as
DPM (stop->terminate) -> DCZ (symlink prefix v7.-> p7-) -> this full identity rename, per the
user's own "all-or-nothing... difficult for bugs to hide" framing.

**How to apply**: this is DONE, committed (`bd98e1c17`, `e410ea153`), pushed, and live-verified
(clean `base.cmd.reload` on the running instance). Full session detail, gotchas found, and the
concrete open-items list (install_workflow_shortcuts wiring decision, p7-`-name ambiguity,
~17 dead-`p7`-command doc references, the `v7-stdout-foldable-relay` task cluster, `LYE`, `QP3`)
lives in `/data/projects/protocol-7/HANDOVER.md` (dated 2026-09-02) — read that first rather than
re-deriving state, since it supersedes the prior 2026-09-01 handover. Related:
[[feedback-dont-preempt-version-bump-before-commit]],
[[feedback-no-inventing-infrastructure-naming]].

#,,,,,..,,,.,,...,,,,,,.,,,..,,,,,...,,,.,,,.,..,,...,...,,..,,..,,,,,,,,,,,,,
#KHKEAT5R3EGHQPPY4LOHJEHFYSMU6QUH422YZUPB74JEXVBBHV6MLCCFW3AN32WSJY46R6DPR3CG6
#\\\|ZQNTALB3D4WBRQAQFMRHZY3TDOBD22EXFHPHELCCYZT54MB6I4D \ / AMOS7 \ YOURUM ::
#\[7]SCBQFO3AMPWLIBQBIYS5XFU6U6MHOT7QEP6YK52UAEZPJWNXM6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
