---
name: feedback-multi-commit-needs-version-bump-per-commit
description: this repo's pre-commit hook requires a fresh ./bin/dev/update-version (and sometimes a manual re-sign) before each individual commit, not just once per session
metadata:
  type: feedback
---

When committing multiple separate batches in one session, the pre-commit hook rejects the
second/third commit with "version mismatch detected" if the version file wasn't bumped again
since the previous commit — `./bin/dev/update-version` is required **before every single commit**,
not once per session. The hook's own error message says exactly this (`suggestion: run
./bin/dev/update-version to fix`) and explicitly warns not to bypass with `-bypass-sig-check` /
`SKIP_SIGNATURE_CHECK=1`.

**Why:** version numbers are how this project tracks commits; the hook enforces one version bump
per commit at signature-check time.

**How to apply:** when splitting a session's changes into multiple `git commit -- <files>` batches,
run `./bin/dev/update-version` immediately before each commit attempt (not just before the first),
then re-check `git status --short` — the version/doc-tracking files it touches (`cfg/protocol-7.src-ver`,
`read-me/md/README.md`, `read-me/project-identity/source-code-versions.md`) need to be included in
that commit's pathspec. After `update-version`, if the pre-commit hook itself doesn't handle
signing (it usually does — "staging version files / checking signatures / signatures are valid" —
but not always, confirmed live 2026-09-14 on a mid-session commit), the version files may need an
explicit re-sign pass first (the user ran one manually: output looked like "updating N source file
signatures... staging N signed files... done" — exact tool name not confirmed, but the missing-piece
symptom is `":.  : no signature footer present ..,"` on the just-touched version files) before the
commit will pass.

#,,,,,.,.,.,,,,..,.,,,..,,,,,,.,.,,..,.,.,.,,,..,,...,...,..,,..,,...,.,.,.,.,
#GWCZBUSBT35LZZKNUZTP5OMZNT33WDRJRXP3APILKAQ6HQBXL7FX5CYLPXR3NXWBUOC65RSWQJR2U
#\\\|GSFRLFHLG3D5FAAT35VHQJWZZZCXPT3JM6KMS33FOSZBQA7IMBB \ / AMOS7 \ YOURUM ::
#\[7]RAWIOAXLCTX4X3ML2TJ2AGE7FDYP5DWO2VXHSPVF3PG5MZYFYGCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
