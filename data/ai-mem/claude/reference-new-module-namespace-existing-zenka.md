---
name: reference-new-module-namespace-existing-zenka
description: adding a brand-new module namespace as a dependency of an already-running zenka needs modules.load + a source/<namespace> marker file, not just subroutines.load-early
metadata:
  type: reference
---

Caught live 2026-08-09 wiring the new `editor.*` namespace into `nshell` (a
zenka that already exists and runs fine) as part of the editor.* migration
(see [[topic-editor-namespace-migration-status]]). After landing nshell's
switch from `AMOS7::TERM::editor_*` to `editor.control.*` and adding the
new call sites to `configuration/zenki/nshell/subroutines.load-early`
(which the module-dependency-graph auto-scanner correctly picked up), a
live restart still failed on first Up-arrow press:

```
protocol-7 subroutine editor.control.create not defined
[nshell.read_from_buffer:29]
```

`subroutines.load-early` only affects EARLY-COMPILE ORDERING of subs
already scheduled to load — it does not, by itself, cause a new module
NAMESPACE to be loaded into the zenka at all. Two more pieces were needed:

1. **`configuration/zenki/<zenka>/start`**: the namespace has to be added
   to the `modules.load = ...` line, e.g. `modules.load = ... editor
   nshell devmod`.
2. **`configuration/zenki/<zenka>/source/<namespace>`**: an empty
   (0-byte) marker file — every other namespace a zenka loads from has a
   matching empty file here (`ls configuration/zenki/nshell/source/`
   shows `ascii`, `auth`, `base`, `net`, `nshell`, etc., all 0 bytes).
   This is presence-checked, not content-read.

**Why:** `subroutines.load-early` is a scheduling/ordering list for compile
timing of subs that will be loaded regardless; `modules.load` + the
`source/` marker is what actually tells the zenka's module loader a given
namespace exists and should be sourced from disk at all. Adding call sites
to the first without touching the other two produces exactly this failure
mode — code that references the new namespace fine at the Perl-syntax
level (nothing to catch via `perl -c`), fails only at runtime when the
routing layer looks up a subroutine that was never registered.

**How to apply:** whenever wiring code in an EXISTING, already-deployed
zenka to depend on a module namespace it didn't previously use, check all
three of: (a) `subroutines.load-early` entries for the new calls (cosmetic/
ordering only), (b) the namespace name added to that zenka's `start` file
`modules.load` line, (c) a new empty `source/<namespace>` file alongside
the zenka's other namespace markers. Missing (a) alone is usually harmless
(lazy-compiles per call); missing (b) or (c) is a hard runtime failure that
only surfaces when the new code path is actually exercised, which can be
well after the change is written/committed if that code path isn't hit
immediately.

Related but distinct scenarios, don't conflate: [[reference-add-new-ondemand-zenka]]
covers standing up a WHOLE NEW zenka that's never started (5 pieces,
different failure modes, involves `v7`/`cube` registration this case
doesn't need since `nshell` already exists and is registered).
[[feedback-plugin-namespace-loading]] covers a THIRD mechanism —
`plugin.X.*` cross-namespace lazy-loading via `base.white-list.register`,
for namespaces meant to load on-demand per-request rather than eagerly at
zenka startup, which is not what `editor.*` needed here (nshell wants it
loaded once at start, not recompiled per call).

#,,.,,,.,,..,,...,,,,,,..,..,,.,.,,,.,.,,,...,..,,...,..,,,..,..,,.,.,,..,.,,,
#5U5KI4APU625RYJZPQDERMPTO5UKBBIH4S6N2BSPB7QESZ3Z3M7Y6O4UTTIKXQD5ZLX42MHE23OKY
#\\\|P6DEEMGMEMFENYJ46LS5IFQVRCKBACFEFYKHD7W2FH7AWUFW5A4 \ / AMOS7 \ YOURUM ::
#\[7]JWCNSGXOFZTJM6MFDPHMQUTGF4WVYLYI25DOPWRJONYF5Y6P4CDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
