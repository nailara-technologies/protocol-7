---
name: invoke model manager tool vision
description: planned Term::Clui model manager for invoke.ai — standalone first, zenka-ready, with collection profiles and image provenance
type: project
---

## vision

a perl Term::Clui interactive tool for invoke.ai model management that works
standalone first, with core logic designed for later reuse as a zenka.

## planned features

- model list/inspect: DB metadata + filesystem state (uuid + verbose symlinks)
- safe delete: remove uuid dir + DB entry + clean up dangling verbose symlinks
  (invoke UI deletion is avoided — leaves dangling symlinks, uuid alias risk)
- archive: remove files but preserve DB entry + metadata snapshot → .xz yaml
  constraint: do NOT archive models still referenced by output images
- restore: from archive → re-download or re-extract → re-register in DB
- export collection profile: model set + workflow config → xz-compressed yaml
- import/bootstrap: populate fresh invoke install from profile yaml
  (ideal for migrating established workflow setups to new machines)

## zenka evolution path

standalone tool → extract core logic (db queries, file ops, symlink mgmt)
→ zenka wrapper → wire vision llm for image quality scoring + provenance

## image management (separate category)

47K+ output images of varying quality — not manageable without vision llm zenki:
- quality scoring / culling assistance
- image → model provenance (which models/settings produced what)
- output image archive with model reference integrity checking

## invoke ui deletion risk (current)

avoid using invoke UI to delete models — it removes uuid dir + db entry
but leaves dangling verbose symlinks. the 2fd93aa6 uuid alias symlink is
also a risk (could delete a real model via the alias). external management
via scripts is safer and provides audit trail.

**Why:** prior incident where invoke UI deletion wiped multiple models due to
shared directory traversal under the old verbose-path storage scheme. user
recalled (2026-09-10) the scale directly: ~500GB wiped, recoverable only via
[[topic-invoke-model-management]]'s recovery/re-download script -- not a
minor incident. treat any request to delete/consolidate invoke model dirs as
needing FRESH explicit confirmation every session, never inferred from a
prior session's cleanup request.

session-verified 2026-09-10, before any deletion (none happened -- user
stopped once they recalled the wipe history): the Windows-side copy
(`/mnt/c/Users/User/Invoke/models/`, 121GB) and the external "real" copy
(`/mnt/ext-xfs-data/models-invoke/`, 75GB) are NOT 1:1 duplicates -- 166
files / 67GB across 45 distinct model directories exist ONLY on the Windows
side. Given the external copy may itself be a partial reconstruction from
the recovery script rather than a pristine original, a path-name diff
against it is not a reliable duplicate check on its own -- verify by file
size or hash before ever treating something as "already backed up
elsewhere," and back up before deleting rather than deleting on the
assumption a backup exists.

## origin of DBI/DBD::SQLite in .deps/profiles.yaml's `tools` profile (2026-07-26)

`tools` installs `DBI`/`DBD::SQLite`, but `src/` (the actual zenka
codebase) has zero references to either — confirmed via grep. Root cause:
InvokeAI itself stores its model registry in a SQLite DB, and reading it
(model list/inspect, the tooling described above,
`models.storage.adapter.invoke.discover`, `bin/scripts/invoke-ai/*`) needs
DBI/DBD::SQLite dev-side, not for any zenka runtime need. This is also
very likely the origin of `.deps/profiles.yaml`'s old `development` profile
name (renamed to `basic-remote-server` this session,
[[bug-inline-elf-perl-version-infinite-loop]]'s sibling commit) — a bundle
that grew around AI-model dev-tooling needs rather than being designed
around what a deployed zenka actually requires.

**How to apply:** if `tools`' apt/cpan list ever looks over-scoped for
"utility tools and scripts" again, check whether the actual justification
is a zenka need or an invoke.ai/model-management dev-tooling need before
assuming it's dead weight to prune.

#,,..,,..,.,,,,,,,,,.,.,.,..,,,,,,.,.,,,,,...,..,,...,...,...,.,,,,,,,...,.,,,
#LOJ5ZEGJHNPTK52B2JISHY4LJADPRIJ5TR6WC6P6I5UYC7PBDDUSFEYFU4QPD6FVC3XGUGZXTA4NW
#\\\|SGHAO5K3J4BBBMTE45J7SX36UZP6UI2UTYBL6YVGGJZMVKTYH5G \ / AMOS7 \ YOURUM ::
#\[7]D6SKVTM5UYCYE4MCDDANYWIDMMAXGYWH7Z5V3FPB5IKJULWUNEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
