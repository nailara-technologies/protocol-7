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

**How to apply**: this is DONE, committed (`2a19b6cd3`, `cb6e9c682`), pushed, and live-verified
(clean `base.cmd.reload` on the running instance). Full session detail, gotchas found, and the
concrete open-items list (install_workflow_shortcuts wiring decision, p7-`-name ambiguity,
~17 dead-`p7`-command doc references, the `v7-stdout-foldable-relay` task cluster, `LYE`, `QP3`)
lives in `/data/projects/protocol-7/HANDOVER.md` (dated 2026-09-02) — read that first rather than
re-deriving state, since it supersedes the prior 2026-09-01 handover. Related:
[[feedback-dont-preempt-version-bump-before-commit]],
[[feedback-no-inventing-infrastructure-naming]].

#,,..,,.,,,.,,.,.,...,,.,,,.,,,,,,,..,,..,,,,,..,,...,...,...,...,.,.,,,,,..,,
#SSG2X36DRS24OCEVQAA3Q2QJMAE5VCEIXCPRR627URULLRLBT4RKIG53GQTFVTPPNKXEE6WILARI6
#\\\|6KGSQ6P4O4OIJAAWVTRGDNUQXGTB5CKYMQPTOSQANZHXFGHFIHO \ / AMOS7 \ YOURUM ::
#\[7]XQN5N522TBAK26QTB7ZSIFUEE2GE3PZ4K7KEJH7V5GKJLZAYD2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
