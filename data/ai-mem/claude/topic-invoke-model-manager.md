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

#,,..,..,,.,.,,..,.,,,,,.,..,,...,,..,.,.,.,,,..,,...,...,...,,..,,.,,...,,..,
#T7QL6TONP3C4QLTZFOBGBMXLMYM57CTZCGADEPRLTEXW62AX4WR3JCCWHPYPU2OT6B4O45PEMO5O4
#\\\|TMFZHRCMPBH5RN2MHZK4TJ6XELEFOC5WVXJ5FDMJB3SACGKZ2Q6 \ / AMOS7 \ YOURUM ::
#\[7]7N5FBGCQQAUCY7EPKZWOOTB4UYG3PQ7XAQ3AVNHZYGQ2AUPAGGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
