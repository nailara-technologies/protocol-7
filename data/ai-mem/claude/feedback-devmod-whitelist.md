---
name: devmod whitelist lifecycle hooks
description: dep-graph/gen-sub-whitelist must always include lifecycle hooks for loaded module namespaces
type: feedback
---

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

#,,,.,,..,,..,.,,,,,.,,,.,.,.,,,,,,.,,..,,.,.,..,,...,.,.,...,.,.,,.,,..,,..,,
#EIUJ54EXBB63H752PED6FIVNF662PVZ43IJW7KPX7VEYPFZPEQBGB73QZUEUOPURVMZJRE5IQMTUW
#\\\|T2TZPJLAU3SKKXJZHOH44VIVRVONDAG3ANMW6Z56RXZP3BXCDJH \ / AMOS7 \ YOURUM ::
#\[7]ZQH54GPAT4JOFTQRLWYNVBTXDRFIXP44BQTWPL7V7H4KDO4A6SBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
