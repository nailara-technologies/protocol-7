---
name: topic-ncode-safe-refactor-workflow
description: "ncode's existing preview/backup/undo/grace-period CLI strengths need a network+web-UI equivalent, aimed at making autonomous zenka/model refactors as safe as human-approved ones"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**2026-07-17, design-only.** Surfaced right after scoping `ncode`'s
read-only network access (see [[topic-ncode-access-gap]],
[[topic-write-access-security-infrastructure]] for the write/sign
approval side). This note is the ncode-specific expansion the user wants
on top of that — distinct from the general signature-approval
infrastructure, though it will plug into it once that exists.

## what already exists in bin/ncode (confirmed by reading the code, not assumed)

- `preview()` (`-preview-only` flag) — styled diff shown before applying.
- `create_backup` / `cmd_restore_backup` — tar.gz/tar.xz archives under
  `backups/`, restorable via `bin/ncode restore-backup [-latest]`.
- `undo` / `undo-move` commands.
- **`ncode.cmd.suggest` + `ncode.cmd.apply` already ARE a change-queue,
  not just a CLI concept** — confirmed 2026-07-17 while chasing an
  unrelated arg-passing bug (see [[topic-ncode-access-gap]]'s sibling
  bugfix). `suggest` scans files against a checksum-addressed pattern
  library (`<ncode.patterns>`), computes a session-root checksum from
  `ntime + sorted file list`, and stores each candidate fix in
  `<ncode.pending>` keyed by a content-derived `fix_id`
  (`checksum(pattern:file:line)`) with `status => 'pending'`. `apply`
  then batch-applies by `fix_id` list or by `--session <root>` (all
  pending fixes from one suggest run), running each fix's regex steps,
  checking `verify.no_match` conditions, and **auto-reverting the file
  to its original content on verify failure** — `status` flips to
  `'applied'`/`'failed'` accordingly. This is precisely the
  checksum-addressed, session-scoped, auto-revert-on-failure shape the
  web change-queue UI (point 2 below) needs on the backend — it doesn't
  need to be invented, just exposed and given a UI. Not yet checked:
  both `suggest` and `apply` retrieve their args via `my $params = shift
  // {}` rather than `$call->{'args'}`/`$call->{'param'}` — a third
  calling convention distinct from the `$ARG`-vs-`$call` bug just fixed
  elsewhere in `ncode.cmd.*` (see [[topic-ncode-access-gap]]); worth
  live-testing before relying on them over the network, not assumed
  broken or working.
- **`warn_apply()` (line ~1271) already IS the grace-period-abort
  feature** the user described, verified live via `ncode search
  "A P P L Y I N G"`: blinks "A P P L Y I N G   C H A N G E S" for ~3s
  (7 iterations × 0.42s `IO::Select->can_read` poll on STDIN), any
  keypress during that window calls `&aborted` which `exit`s *before*
  `create_backup`/`overwrite_source_files` run at all three call sites
  (lines 726→746→750, 974→994→998, 1219→1233→1236) — a genuine
  pre-write abort, not a post-write undo. **Important constraint**: it's
  called `warn_apply() unless $AI_FRIENDLY` — disabled in non-interactive/
  AI-friendly output mode, because it fundamentally depends on raw TTY
  keystroke polling (`&raw_mode_on`, `IO::Select` on `\*STDIN`). No
  network command or web UI has an equivalent raw-TTY channel to poll —
  **this is the actual gap**, not the absence of the safety concept.

So the ask is not "build a grace-period abort" — it's "give this exact
UX a real equivalent when the caller isn't a human at an interactive
terminal."

## privilege-separation model for .git access — LANDED 2026-07-17

While fixing `ncode.cmd.diff`/`.diff-staged` (blocked on `.git` being
`taeki`-owned, 755 — even read-only git ops need to write `.git`'s own
index-refresh/lock file), settled a real design question worth recording
for the *next* privilege decision (write access to actual project
files): **primary UID stays the restricted service account
(`protocol-7`), `taeki` is only ever a *supplementary* group** — never
the reverse. Checked concretely: `taeki`'s account is in `sudo`,
`docker`, and `dip` groups; `docker` group membership is root-equivalent
(container socket access). Running any network-facing zenka with
**primary UID=taeki** would mean a bug in a regex-apply routine or a bad
LLM-suggested change inherits full admin-equivalent system access, not
just repo-write. This holds across every deployment shape (user-desktop,
dev-desktop, remote-server, appliance) — if anything it matters more on
server/appliance.

Mirrored `coding`'s existing pattern exactly (`coding.init_code`'s
`assume_admin_group`/`allow_chmod_apply` config + `coding.start.
chmod_child`), scoped narrowly to `.git` only (not the whole working
tree — that's the separate, bigger decision still gated behind
[[topic-write-access-security-infrastructure]]):
- `ncode.start.chmod_child` (new) forks a privileged helper that drops
  to `taeki`'s UID (so it can legitimately chmod taeki-owned paths) —
  verified live running as `taeki` in `pstree`. Only understands `gwd`
  (grant group-write on a directory) and `restore` (reset to an exact
  mode), and refuses to act unless the target's *current* group already
  matches the resolved admin group — can't be used to escalate onto
  unrelated paths.
- `ncode.init_code` now resolves `<ncode.cfg.drop_privs_admin_group>`
  from `<system.root_path>`'s owning group, forks the chmod-child,
  requests `gwd <root>/.git` once at startup, then calls
  `base.root.drop_privs` (moved here from the start file's
  `[root.drop_privs:...]` line, matching `coding`'s structure — path
  setup and the chmod-child fork must happen before dropping privileges).
  Confirmed live: process holds `taeki`'s gid as a supplementary group
  (`Groups:` in `/proc/<pid>/status`), `.git` is `775 taeki:taeki`.
- Also needed (found live, not anticipated): `ncode.cmd.diff`/
  `.diff-staged` called bare `git diff`/`git diff --cached` with no
  `-C <root>` — the actual first-order bug. If the zenka's own CWD isn't
  the repo root, git fails with "Could not access 'HEAD'" regardless of
  permissions. `safe.directory` (git's dubious-ownership override) was
  necessary too but not sufficient alone — all three (safe.directory,
  `.git` group-write, `-C <root>`) were required together; each
  individually still reproduced the failure.

**How to apply:** this is the reusable pattern for the next privilege
decision, not just this one — when a zenka needs write access to
taeki-owned paths, default to zero access, add `assume_admin_group`/
`allow_chmod_apply` as explicit opt-in config, scope the chmod-child's
grants to the narrowest path that unblocks the actual need, and never
consider running the zenka's primary UID as the admin user itself.

## the vision, as described

1. **network/web equivalent of `warn_apply`**: user's own answer —
   assign a **timeout to the change approval** itself, replacing raw
   STDIN keystroke polling with a pending-apply state that has an
   explicit cancel action (command/button) available during the
   timeout window. Mirrors `warn_apply`'s blink-then-commit shape
   (visible countdown, any cancel action aborts before write) without
   assuming a TTY — a network command or a web UI can both expose
   "cancel within N seconds" the same way jobqueue's dependency/timeout
   primitives already model waiting-with-a-deadline elsewhere in this
   codebase ([[topic-coding-round-timeout-adaptive]] is a structurally
   similar precedent: soft ceiling + explicit escalation, not silent
   blocking).
2. **change-queue / column-based web UI**: modeled directly on the
   existing jobsite UI ([[topic-jobsite-ui-usability]]) — same
   column/card layout, but cards are code-change suggestions instead of
   job postings. Natural extension of the same preview/backup strengths,
   but as a *queue* of pending changes rather than one at a time. Same
   security model as [[topic-write-access-security-infrastructure]]:
   one signature approves, downstream trust inherits from it.
3. **the actual goal — safe autonomous refactor workloads**: once
   preview/backup/grace-period/undo have a network/web equivalent and
   are batchable through the queue UI, **zenki and models themselves**
   should be able to propose fast code refactors with the same safety
   guarantee a human gets today at the CLI, enabling things currently
   too expensive to sustain continuously:
   - nightly style-compliance-only passes
   - comment coherence/quality upgrades (rewriting comments toward
     "meaningful coherence" without touching logic)
   - dynamic style-convention upgrades over time — approved cheaply in
     batches/groups rather than reviewed individually, without weakening
     the safety guarantee ("just signature validation, not weaker").

User's own framing of why this matters: these continuous style/coherence
passes are a real, measurable component of project quality (coherence in
whatever style a project has chosen), but are currently expensive to
sustain — cheap batch approval over a safe preview/backup/grace-period
pipeline is what makes them sustainable.

## how to apply

- Don't reinvent preview/backup/undo — they exist and work
  (`bin/ncode`). The actual build surface is: (a) a non-TTY equivalent
  of `warn_apply`'s abort window, (b) exposing that + preview/backup
  over the network command layer once write access is granted, (c) the
  jobsite-style queue UI on top.
- The change-queue web UI should reuse jobsite's existing column/card
  patterns ([[topic-jobsite-ui-usability]]) rather than building fresh.
- Sequencing: this plugs into
  [[topic-write-access-security-infrastructure]]'s signature-approval
  system once that exists — don't build ncode write/apply network
  commands ungated in the meantime.

[[topic-ncode-access-gap]]
[[topic-write-access-security-infrastructure]]
[[topic-jobsite-ui-usability]]

#,,..,...,,,.,,,,,,,,,,,,,,.,,.,.,,,.,,.,,,,.,..,,...,...,.,,,,,,,,,,,,,.,,,,,
#ZO2EMD2PZVPAR37DYTCPPID57UFY3ITCIX77D5TUZHEZ5ISKKCIQGWXQI5NIWOTRGQCWVLBOH5JVA
#\\\|5UIYX7XYCID3JAZCSKXSOJHGKWOEC5BKA6364TEG6PBVMY4L5YU \ / AMOS7 \ YOURUM ::
#\[7]VNH54UM7UNTOOZQYBZQYTKFDGT4ZRWRUY32ZQHQJGK7DS55BXQAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
