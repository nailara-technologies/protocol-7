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

**How to apply**: this is DONE, committed (`23a0e8d53`, `3f1d6b40f`), pushed, and live-verified
(clean `base.cmd.reload` on the running instance). Full session detail, gotchas found, and the
concrete open-items list (install_workflow_shortcuts wiring decision, p7-`-name ambiguity,
~17 dead-`p7`-command doc references, the `v7-stdout-foldable-relay` task cluster, `LYE`, `QP3`)
lives in `/data/projects/protocol-7/HANDOVER.md` (dated 2026-09-02) — read that first rather than
re-deriving state, since it supersedes the prior 2026-09-01 handover. Related:
[[feedback-dont-preempt-version-bump-before-commit]],
[[feedback-no-inventing-infrastructure-naming]].

#,,..,..,,,,,,.,,,.,,,,.,,,,,,..,,.,.,,..,.,,,..,,...,...,...,.,.,,.,,.,.,,,.,
#2GP5QJ62GYJ7GJDOYPXJTK24QTPP4WGYQD7YFT6LVPRXC5AP7RPGF4CSZPK5SWGMFAPLKQAZDRFSW
#\\\|VAQJRC6DOAY5CKEUNOXR5NTTXVHAXOQA6PRASLKJ6J6BG25CVYE \ / AMOS7 \ YOURUM ::
#\[7]QTEI3J6GWXGGYHT5SVMTQCVODU72FNA5HYZJ52FG2CB6OFK3UEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
