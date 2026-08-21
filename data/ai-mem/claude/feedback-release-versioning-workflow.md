---
name: release-versioning-workflow
description: "exact sequence for marking a protocol-7 release (rel-ver file, src-ver bump, commit, tag, push) — order-sensitive, easy to get wrong"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e81d6781-e404-4cb2-9bd8-c1b6d0c366ef
  modified: 2026-08-21T00:40:57.960Z
---

`vc` is a plain shell alias for `git` (not a separate encrypted-commit
tool) — don't assume a password prompt seen around a commit step means
`vc`/`git` itself needs credentials; it was `us` (a separate unrelated
step in the sequence shown) prompting for a sourcecode decryption key,
not the commit.

**Correct order** (demonstrated live 2026-08-04, marking `AMOS7-v5.53.3`
for [[loader-reload-stale-cmd-modules]] + [[loader-eager-compile-nested-
hooks-under-loaded-ancestor]]):

1. `./bin/dev/release-version` — dry-run, prints the calculated candidate
   release version (deterministic AMOS7 harmonic-truth calculation from
   current `protocol-7.src-ver`, not a manual semver bump) to both
   stdout (decorated) and stderr (bare string).
2. `./bin/dev/release-version 2>cfg/protocol-7.rel-ver` — the
   actual way to write it to the rel-ver file: redirect stderr only,
   since stdout carries ANSI box-drawing decoration and stderr carries
   the bare `AMOS7-vX.Y.Z` string.
3. `./bin/dev/update-version` — bumps `cfg/protocol-7.src-ver`
   to a fresh value.
4. Commit everything (`git add -A` / `git commit`) — **must happen
   before** step 5, not after.
5. `./bin/dev/release-version -s AMOS7-vX.Y.Z` — sets the actual git tag
   on HEAD via `git tag <ver> -m <msg>`. Only run this **after** the
   commit lands, or it tags the wrong commit. The explicit version arg
   avoids re-running the (now-changed, since src-ver moved) calculation.
6. `git push <remote> <branch>` then **separately** `git push <remote>
   --tags` — pushing tags is not automatic with a normal branch push in
   this workflow.

**How to apply**: if asked to "mark a release" for a fix, don't
freelance the version numbers — either wait for the user to run/paste
steps 1-3 themselves (version calculation is their call, not mine to
invent), or if explicitly asked to prepare it, run the read-only dry-run
(step 1) only and surface the candidate version for confirmation before
touching any version file. Never call `release-version -s` before the
matching commit exists.

**`update-version amend` / `update-version reset amend`, confirmed live
2026-08-06**: a third variant alongside plain `update-version` (advances
to a new commit id, `.0` revision) and `update-version reset` (backfills
a *missing* version bump for the prior commit — see [[project-2026-08-06-
pii-purge-and-tag-drift-incident]] for that one live). `amend` keeps the
**commit-id segment unchanged** and increments only the revision suffix
— `3WPLH7ORLY-8893.0` → `3WPLNBEJDI-8893.1` (network-time portion moves
since it's timestamp-based, but the `-8893` commit-count stays fixed).
`reset amend` composes both: gets the amendable version for the
*already-committed* change (like plain `reset`) but as a revision bump
of it rather than a fresh commit-id (`-8892.1` in the confirmed run,
matching the prior commit's id with `.1` instead of advancing to
`-8893`). Purpose: force-pushing a fix *over* an already-pushed version
number when a critical bug needs to go away fast, while the `.N` suffix
still honestly marks that a revision occurred, rather than silently
rewriting history with no trace. A subsequent plain `update-version`
correctly moves forward to a fresh commit-id with revision reset to
`.0` (confirmed: `-8892.1` → next plain call gave `-8894.0`, skipping
past `-8893` since that id was already used/superseded in this test
sequence).

**every plain commit, not just release-marking** (confirmed live
2026-08-21, landing [[zenka-naming-cleanup]]'s `zenka.v7`/`start.cfg`
rename as commit `7ae191258`): the pre-commit hook itself auto-bumps
and stages `cfg/protocol-7.src-ver` + `read-me/md/README.md` +
`read-me/project-identity/source-code-versions.md` (commit-count/
network-timestamp version identifier) as part of *every* commit, no
separate `update-version` call needed for a normal commit. It also
re-signs/verifies all staged files' AMOS7 signatures and silently
strips any `Co-Authored-By:` / `Claude-Session:` trailer lines from
the commit message before it lands — expect the hook's own stdout
("removed author metadata from commit message") rather than an error
when that happens, it's normal project policy, not a failure.

#,,,,,,..,.,,,.,.,,,.,,..,..,,..,,...,.,.,,,,,..,,...,...,.,,,,.,,.,.,..,,..,,
#ZBFMJTG245ZMYG3UX7UKEDYTEKGUUFRZVKMTSXT5LQNUAECFMTKST272D2Y3TC2LGYD5UIONRTIOK
#\\\|QSZMECXTH7UTL5FWBVOAGTG3LQ32CKLXLTNWFAQT46KBGZH2AUH \ / AMOS7 \ YOURUM ::
#\[7]Q73WIJLKYL45FKHAXA24SR463XPEG2PSNUKSDL5C2LHCD2ZAMKCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
