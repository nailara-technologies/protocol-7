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
shared directory traversal under the old verbose-path storage scheme.

## origin of DBI/DBD::SQLite in .deps/profiles.yaml's `tools` profile (2026-07-26)

`tools` installs `DBI`/`DBD::SQLite`, but `modules/` (the actual zenka
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

#,,,,,,,,,.,.,.,.,.,,,,,,,...,.,,,,.,,..,,,..,..,,...,...,...,.,.,,,.,.,,,,.,,
#OIGERXB6GANBYCYI674VSSOW7QNBQCVI73TS2UQPRKZ6CHVWJ7UXPT4HU3C7UVEMYSZ57PFDAB7X2
#\\\|Q5P3UQ65BG36MCZLX3TQU7REDUGCTORZZGE24VQDTPNWE3KYORO \ / AMOS7 \ YOURUM ::
#\[7]4D32RER2NEYZ7Y57GKEVJMYSSWTV7255MFLY43HHRG2IB2ABOQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
