---
name: devmod whitelist lifecycle hooks
description: dep-graph/gen-sub-whitelist must always include lifecycle hooks for loaded module namespaces
type: feedback
---

dep-graph whitelist generation has two known gaps:

## gap 1: watcher-dispatch handler strings not traced

Modules that are dispatched via a watcher object (e.g. `$watcher` as a key in a hash,
then called via `$watcher->data` or similar) are NOT reachable via dep-graph's call graph.
Their `'handler' => qw| some.module |` string references are therefore never scanned.

**Example**: `coding.cancel_watcher.backend_monitor` is registered via
`<coding.watcher_pair>->{$watcher}` — dep-graph never visits the file, so
`coding.handler.drain_pipe` (referenced as `'handler' => qw| coding.handler.drain_pipe |`)
is not auto-detected. Workaround: manually add to `base.list.subroutines`.

**How to fix**: Add watcher-dispatch modules to a `source/` tracking list or
extend dep-graph to scan all modules in the coding namespace unconditionally
(similar to lifecycle hook treatment).

## gap 2: lifecycle hooks for loaded namespaces

dep-graph whitelist generation is incomplete for lifecycle hooks.
When a module namespace is in `modules.load`, the following must ALWAYS
land in the whitelist regardless of dependency graph reachability:
- `<namespace>.init_code`
- `<namespace>.pre_init`
- `<namespace>.post_init`
- `<namespace>.end_code`

**Why:** These are convention-based hooks called by the module loader,
not referenced from code. dep-graph's reachability analysis won't find
them, but they MUST be present or the module fails to initialize.

**How to apply:** When working on dep-graph or gen-sub-whitelist, ensure
lifecycle hooks for all `modules.load` namespaces are unconditionally
included. Current issue visible with `devmod.*` on the models zenka.

#,,,,,,.,,,,.,,,,,,,.,.,,,...,.,.,,,.,..,,.,.,..,,...,...,.,,,...,...,.,.,..,,
#WOHFY7226LMCPXLT327D3OR6LH3747NQCOKI6Z4KDGNBPCITWXSDLG3C7A25C53FRHKQE5BV7FI3Y
#\\\|BABDVXQPJFD2AX5QOGZ2OPMV46YZYZTYZKD33FKCCOWEMUA7245 \ / AMOS7 \ YOURUM ::
#\[7]AGIGCPHTUZ4ISYJJSU5IXQMOTXAJQF6OX4M7DA6TT53GWEMJTEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
