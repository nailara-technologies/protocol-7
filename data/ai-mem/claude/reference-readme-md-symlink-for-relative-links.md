---
name: reference-readme-md-symlink-for-relative-links
description: repo-root README.md is a symlink to read-me/md/README.md, kept specifically so its relative-looking links (bin/, src/, cfg/) resolve against the repo root the way GitHub renders it -- resolve/traverse via the symlink path, not the real path
metadata:
  type: reference
---

`/README.md` at the repo root is a symlink to `read-me/md/README.md`
(the actual file lives under `read-me/`, not at the root). This isn't
incidental — the real file's own links are written as if it lives at
the repo root (`[bin/](bin/)`, `[cfg/](cfg/)`, `[src/](src/)`, etc.,
with no leading `/`), which only resolves correctly when the file is
reached via that root-level symlink, matching how GitHub renders a
repo's front-page README relative to the repo root.

Two other root-level symlinks exist for related reasons:
`session-state.md -> read-me/md/session-state/` and this same pattern
likely generalizes to other docs.

**How to apply:** any tool or script that walks/resolves this file's
relative links (see `bin/dev/md-link-tree`) must use the `README.md`
symlink path as its base for resolving relative targets, not
`realpath`/`abs_path` on it and not the real `read-me/md/README.md`
path directly — those differ by two directory levels and produce
false "broken link" results for every non-`/`-prefixed relative link
in the file (discovered 2026-09-04 building `md-link-tree`: defaulting
to the real path produced 21 false positives, all fixed by defaulting
to the symlink instead).

#,,..,...,.,.,,.,,,,.,..,,..,,..,,,,.,.,,,..,,..,,...,..,,,.,,,..,.,,,,..,...,
#ON43JDHEMIY4EKAELS4KTBEGRJ4OBYFTHJQ6FXSLYQ3KQOVT3FY2MWAOBCXBBLMWGNQWO6ILREMOU
#\\\|UK6OZKXNGF5SW77FFCFAMTTFMT3ETW4NNURCS7XJYD6YQD42KXJ \ / AMOS7 \ YOURUM ::
#\[7]XSMRX5KMUSYITBYV2NQRTSZVSY6U3UFFB4VMP635B4ASMLC64ICQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
