---
name: release-versioning-workflow
description: exact sequence for marking a protocol-7 release (rel-ver file, src-ver bump, commit, tag, push) — order-sensitive, easy to get wrong
metadata:
  type: feedback
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
2. `./bin/dev/release-version 2>configuration/protocol-7.rel-ver` — the
   actual way to write it to the rel-ver file: redirect stderr only,
   since stdout carries ANSI box-drawing decoration and stderr carries
   the bare `AMOS7-vX.Y.Z` string.
3. `./bin/dev/update-version` — bumps `configuration/protocol-7.src-ver`
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

#,,,.,.,,,,,.,,.,,,..,,.,,.,.,,,.,,..,,,.,,.,,..,,...,...,.,.,,..,.,,,...,,,.,
#HJQ2APP4D3M6AZE2ZX43OWCGVJYP424MQSRDN4HCFEXTU2EYZV2FSA3EX7IXXNLEDNT54T62K47XM
#\\\|K37OU3WTXBCKLYIBWNQ5GSZYEY5EAT7RLIS2FOW7ZMRXUZYWVGJ \ / AMOS7 \ YOURUM ::
#\[7]RYTMU42DDTPYH26XVAR6DZ4FQ3Y2UHA57X7JBMYQLHZI7LWYBKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
