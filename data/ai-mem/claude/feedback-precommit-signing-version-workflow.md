---
name: feedback-precommit-signing-version-workflow
description: "pre-commit hook demands a version bump + valid signatures on EVERY commit, checked independently each time — splitting one batch of work into N commits means N rounds of update-version + update-signatures, not one; also source_path_set_up's configuration/zenki/*/* glob only reaches 2 path levels, missing 3-level paths like recipes/<name>.yaml or packages/<name>.yaml"
metadata:
  type: feedback
---

Two separate pre-commit hook gates, both re-checked fresh per commit —
not once per session, not once per batch:

1. **version mismatch** — `configuration/protocol-7.src-ver` must match
   `<network-timestamp>-<expected-commit-count>.0`. Bumped via
   `./bin/dev/update-version` (touches `configuration/protocol-7.src-ver`,
   `read-me/md/README.md`, `read-me/project-identity/source-code-versions.md`
   — see [[feedback-version-files-every-commit]]). Because expected commit
   count increments with each actual commit, splitting one logical change
   into N separate commits requires running `update-version` N times, once
   right before each commit — running it once up front and reusing the
   bump for later commits in the same batch fails with "version mismatch
   .., expected *-<N+1>.0" on the second commit onward.
2. **unsigned files in staged set** — every staged file needs a valid
   AMOS7 signature footer, checked via
   `bin/Protocol-7 sourcecode update-signatures`. Also re-checked fresh
   per commit; a file with no footer at all fails even if untouched by
   the current diff (e.g. a config yaml that was never signed).

   **Signing is the USER's step, not one you can run.** The command
   prompts interactively for the `proto-7.sourcecode` key decryption
   password and aborts without it ("source signature key :. not loaded").
   Ask; don't burn a run finding out. `update-signatures :stage:` signs
   AND re-stages exactly the files it signed, leaving other staged
   batches alone — that is the form to ask for. Confirmed 2026-08-12.
3. **descr/param line length** — a module's `# descr =` (and `# param =`)
   text must be **55 chars or less**, counted after the `= `. Fails the
   commit with "descr/param lines too long" and names the file, line and
   count. Cheap to get right while writing the module; annoying to hit
   after signing, since fixing the line invalidates the signature and
   costs another signing round (2026-08-12: exactly that, on
   `users.cmd.field-options`).

**Gotcha (2026-07-29, build-zenka/ext-pkg-zenka session): `update-signatures`
only signs files reachable through `modules/sourcecode.source_path_set_up`'s
`@copy_sources` glob list.** `configuration/zenki/*/*` reaches exactly two
path levels below `zenki/` (e.g. `<zenka>/README.md`) — it does NOT match
three-level paths like `configuration/zenki/build/recipes/<name>.yaml` or
`configuration/zenki/ext-pkg/packages/<name>.yaml`. Files outside the glob
silently get skipped by `update-signatures` (no error, no footer added) and
then fail the "unsigned files in staged set" check at commit time with no
obvious cause — the fix is adding an explicit `<zenka>/<subdir>/**` entry
(see the existing `configuration/zenki/openvas/bin/**` precedent in the
same file) alongside the `access.cmd.usr.*` fix, not re-running
`update-signatures` harder. After adding the path, re-running
`update-signatures` also silently re-signs any *other* already-committed
file that happened to fall in the newly-covered glob and was missing a
footer (harmless, signature-only diff, no content change) — expect that
side effect and fold it into whichever commit is in flight rather than
treating it as unrelated scope creep.

**Two things that need no effort from you:** a `commit-msg` filter strips
`Co-Authored-By:` / `Claude-Session:` trailers on its own — leave them in,
they simply do not land. And while `bin/admin/vc_commit` enforces that the
subject passes AMOS7 harmonic truth (`is_true`, 13–76 chars), the user
confirmed 2026-08-12 that this is **not a strict rule** — commit with
`git commit -F` and a normal message rather than searching for a subject
that satisfies `is_true`. (`bin/is-true` also disagrees with vc_commit's
internal call, so it is not even a reliable oracle for it.)

**How to apply, when splitting a batch of finished work into several
commits:** before each `git commit`, in order: (1) stage that commit's
files, (2) if the hook reports a version mismatch, have the version
bumped and re-add the three version files, (3) if it reports unsigned
files, check whether they're reachable via `source_path_set_up` first
(fix the glob if not) before re-running the signing pass, then re-add.
Retry the commit only after both gates pass. Don't try to pre-solve this
by bumping/signing once for the whole batch up front — it won't survive
past the first commit.

#,,.,,,.,,.,,,.,,,,..,..,,,,.,.,,,.,,,...,..,,..,,...,..,,.,,,,,,,,..,.,.,,..,
#ZV6RLTJIJV7HEF3OJESXPUKN6KOPGIYCSRZXCGJCDK3MYPVBUDVUOYMKEJGXYLLL2QH3QOONVZXCK
#\\\|NOXOODOKKFGVG3NHMZT3YDOW72GMVRBCXTBMT2QGWSDIHVPK5PX \ / AMOS7 \ YOURUM ::
#\[7]VWBIUKMUZPTYMGASBZYWPANSXUXI23H3XREB4OFLJOP6LCVMEODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
