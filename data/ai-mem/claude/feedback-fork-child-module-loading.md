---
name: fork-child module loading
description: modules used by parent after fork must be loaded in the parent branch, not child branch
type: feedback
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
---
In fork-child zenki (letsencr, weather, etc.), `base.load_runtime_modules` calls in the
child branch only populate the child's `%code`. The parent has its own separate `%code`
and needs its own explicit loads.

**Why:** letsencr crashed with "undefined value as subroutine reference" in
`save_certificate` calling `letsencr.x509_field` — module was loaded in the child branch
but never in the parent branch. `base.load_runtime_modules` in `parent.init_code` didn't
work either (runs too late / different context).

**How to apply:** In `fork_letsencr_child` (and equivalent modules), the parent `else`
branch must call `load_runtime_modules` for every module the parent-side code calls
directly, right after loading the primary namespace (`letsencr.parent`). Same pattern
applies to any zenka using `base.fork` with split parent/child namespaces.

#,,,,,,..,.,,,,.,,.,.,.,,,,..,.,.,.,.,,,.,,..,..,,...,...,,..,,.,,.,,,,,,,,.,,
#J3BOBGS7UQGCAI4F76YQIRLIJVXP3C7AS6YJPJ5W35GHX3OGKQBTUQDOJ4U5N553BYOLEMI4VBSCC
#\\\|PUL2S4PRLH773SL7FPLNJQ7RB2NHS77U53LBBQDYSSVKCVDMJSJ \ / AMOS7 \ YOURUM ::
#\[7]IIZJNEAIYSO6EHET4MS6MH4IDKDLZUSJQ6VIBAK3EWV3VQQQCOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
