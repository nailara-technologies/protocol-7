---
name: project-2026-07-30-gap-audit
description: 2026-07-30 audit of open items from the 2026-07-24→07-30 completion cluster — tracks what's still unfixed/unverified/undecided so it doesn't need re-extraction from memory next session
metadata:
  node_type: memory
  type: project
  originSessionId: 8a65c64f-bcd4-43e6-9d47-e37ee5dc8750
  modified: 2026-07-30
---

Checklist from a full gap sweep of the 2026-07-24 → 2026-07-30 completion
cluster (see [[MEMORY-completed]], [[topic-next-steps]], [[MEMORY-active]]).
Mark items done here as they land instead of re-deriving this list from
scratch in a future session.

## known fix needed, not yet done
- [x] all 6 dot-containing `.cmd.` command names **RESOLVED 2026-07-31**
  across 4 commits (`b7d9d163e` build, `5e6987573` calc, `be1e24add`
  ext-pkg, `017d8c24b` forensics). Forensics' fix also caught the real
  live breakage point: `openvas.cmd.report-to-forensics` was
  constructing the broken dotted command string for actual cross-zenka
  dispatch. See [[bug-forensics-dotted-command-names]].
- [x] `bin/format-code` **FIXED 2026-07-31** — 2 distinct root causes
  (not a padding-math bug): `code_marker_re` false-triggered on prose
  (`$var [` with a space, tightened to require immediate adjacency),
  and the atomic bracket-remark protection wrongly truncated a
  multi-line block's extension scan (`$as_continuation` flag added).
  K3 dispatch (`k3qbv0g17`, `kimi-code/k3-256k`), 53-file regression
  sweep byte-identical, independently re-verified on both real
  motivating files + dereference-detection regression check. See
  [[topic-format-code-bugs-fixed]] "open bug, root-caused 2026-07-31".
- [ ] `bin/dev/dep-graph` doesn't understand the conditional-call pattern
  (post [[project-depgraph-conditional-calls-blindspot]] `c3870ebe5`)
- [ ] `base.cmd.reload` still misses `modules.preload`/literal
  `load_modules` calls (post [[project-reload-modules-load-registry-fix]]
  `1a3f2a33c`)
- [ ] `perl-mod-reload` "subroutine redefined" warnings — mod-test zenka
  exists to fix this, not started (see
  [[project-perl-mod-reload-subroutine-redefined-warnings]])
- [x] session-37 `source.extract_sig_body` "1 char too long" bug —
  **RULED OUT 2026-08-01, not a bug.** Reproduced the size-mismatch
  condition itself with a synthetic footer (regex-level test, `+1` char
  in a checksum line vs `<source.sign_template>`): it does set
  `yourum-fake-signature => TRUE` in strict mode, confirmed. But real
  generated footers are deterministic in length (always exactly
  `length(<source.sign_template>)`), so this branch can *only* ever fire
  on a hand-typed/hallucinated stub — never on a genuine signature. Every
  live caller already does the correct thing with the flag:
  `strip-signature-footer` strips it anyway (footer is removed from
  `$src_ref` unconditionally before the size check even runs, per
  `source.extract_sig_body:172`), `verify-p7-signatures` reports it
  invalid (correct — it IS fake), `update-signatures` discards the
  return value and always strips. `work.parent.scan_history` /
  `base.handler.whitelist_miss` don't special-case the flag but only
  check `structure-was-valid`, and falling through to "not validly
  signed" is the correct outcome for a fake stub in both. The
  caller-side handling traces back to `1623337c7` (Nov 2025), predating
  the session-37 bug note — it was likely already fixed when reported.
  See [[topic-fake-signature-footer-detection]].
  **FOLLOW-UP 2026-08-02 (kimi)**: the *actual* reported symptom
  ("over-long fake footer never stripped") was a real, distinct bug —
  lines longer than every regex ceiling (`{70,85}`/`{70,90}`) bypassed
  all strip patterns AND the real-signature extraction start marker.
  Fixed: open-ended `{70,}` minimums across all footer-recognizing
  regexes in `source.extract_sig_body` + stub-strip persistence fix in
  `sourcecode.console.strip-signature-footer`. Live-verified before/
  after via the sourcecode console zenka. **LANDED `2528fb353`**, task
  file archived to `data/tasks/completed/`.

## verification never run
- [ ] openvas-agent phase 1 — implemented + file-verified, **not boot-tested
  live** ([[project-nessus-trial-installed-2026-07-29]] area)
- [x] ncode tier-A chain — **corrected 2026-07-31, this line was already
  stale**: `expand → suggest → apply` *was* run as one continuous chain on
  2026-07-24 (kimi K3 dispatch `kbx4su758`, against a scratch file, found +
  fixed 2 real bugs). What was genuinely untested was `assess` as the entry
  point against a real repo occurrence — tried 2026-07-31, found a blocking
  bug instead: see [[bug-ncode-assess-replace-not-backreferenced]].
- [x] `coding-round-timeout-no-autorestart` — **RESOLVED 2026-07-31, for
  real this time**: original theory (reasoning-only stream falls into
  `http_complete`'s dead "clean close" no-op branch) was correct all
  along. My own mid-investigation "refutation" was itself wrong — based
  on a substring grep that didn't isolate the log's level field; this
  logfile's verbosity is 1 and records zero level-2 lines ever, so
  absence of that log string proved nothing either way. K3 dispatch
  confirmed live via tracer + mock server: no exception, exact branch
  fires as diagnosed. Fix (bounded answer-nudge retry, then visible
  failure) staged and signed. See
  [[project-coding-round-timeout-no-autorestart-observed-2026-07-26]].

## waiting on a human decision, not on K3
- [ ] 4 identity-component decisions from `48ea62376` (2026-07-30):
  key-naming/storage location, succession-edge marking, group-key custody,
  lineage-vs-membership in-band distinguishability — see
  `data/md/design/ZENKA-IDENTITY-COMPONENT.md`
- [ ] `credentials.*` vs `cred-mesh.*` naming, unresolved
- [ ] whether `ncode.cmd.suggest/apply/assess` stay on the cube whitelist
  long-term, or fold into [[topic-write-access-security-infrastructure]]

## dispatched and landed this session (2026-07-30 → 07-31)
- [x] `ncode-pattern-scope-stack-phase2.md` dispatched to kimi K3
  (`auto_summarize=false`) — namespace scope-stack + part-0
  `ncode.regex.apply` status-gate fix, live-verified via p7c, user
  confirmed signed+staged, committed `f8108af44`.
  See [[topic-ncode-pattern-learning-loop]].
- [x] `ncode-assess-replace-backreference-fix.md` dispatched to kimi K3
  (`auto_summarize=false`) — fixed `context.pattern.extract_from_change`'s
  token branch to reconstruct `replace` via `$1` instead of the literal
  training value; persisted `comment-paren-annotation-to-bracket` and
  applied it live against 3 real files with 3 different unseen words
  (`surface`/`offline`/`alternate`), independently re-verified via `ptd
  -c` and diff. Committed `d2b86045e`.
  See [[bug-ncode-assess-replace-not-backreferenced]].
- [x] `task-append` backend-lock-leak — dispatched to kimi K3
  (`kimi-code/k3-256k`, first real use of this model — worked well,
  see [[reference-kimi-k3-256k-model]]). One-line fix
  (`analysis.routed_to` not `execution.backend`), but the real value was
  the traced root cause: a **double-acquire**, not a wrong-bucket
  release — `task-append` stores the wrong key so `enqueue_round`
  acquires under it, then `async.request` separately acquires under the
  *correct* key, and every release path only ever reads the wrong stored
  key back, leaking the correct-key lock forever. Live-verified by
  reloading the module into the running coding zenka and reproducing the
  original 66-minute-stall bug shape twice (leak case + gpu-routed
  regression check), independently re-verified via `ptd -c` and diff.
  Committed `ea2406122`. All three task files from this session archived
  to `data/tasks/completed/` in the same commit.

## stale-memory corrections made this session (2026-07-30)
- `perlmod-move-confirmed-refactor.md` **landed `d3f3ac001` (2026-07-26)** —
  [[topic-next-steps]] still said "expected results"/in-flight; corrected in
  place.
- `base.devmod.dump_var` wrapper is committed (confirmed live in
  `src/base.init_code`, clean working tree) — [[topic-next-steps]] said
  "unstaged, pending sign/stage"; corrected in place.
- audio-waveform "pending human sign-off" note in [[MEMORY-active]] is
  *likely* stale (clean tree, later commits build on top) but not
  independently re-verified the same way — flagged, not force-corrected.

## checked and ruled out
- whether the `elf_match` defect class (checksum compared to raw small int,
  plus a mode param the callee doesn't accept — see `b27ecf4a1`) recurs
  elsewhere: grepped for `elf_mode` usage and chk-sum-result-vs-small-int
  comparisons codebase-wide. `context.tree.checksum.*` is the only other
  `elf_mode` consumer and threads it correctly through to
  `base.chk-sum.elf.inline` — not the same bug. No second instance found.

#,,,,,,,,,,.,,,.,,,.,,,..,,..,.,.,,,.,,..,..,,.,.,...,...,,..,...,.,,,.,,,,..,
#2S56EFGDLMPUQXYHSAWHQKVFSVEM6GEE5FKKY2SLXLZ7J3TFIWPEQWKNTM2DAIRKXSIH2ITDBNVNA
#\\\|XKMR4N4DPEYF3P7ITSVSAOTQG6YQ5XZRA2TEPEINKYMCHLKKV62 \ / AMOS7 \ YOURUM ::
#\[7]4DJYWU5CSWR4IR6A3HBXPDFRF6PYEPBUYI3XKL2K6PRWWES43WBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
