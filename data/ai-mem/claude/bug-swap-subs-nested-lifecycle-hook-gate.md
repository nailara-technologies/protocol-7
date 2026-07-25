---
name: bug-swap-subs-nested-lifecycle-hook-gate
description: "RESOLVED: swap_subs-moved namespaces (base.base32 -> base32 etc.) crashed on first use of a freshly-added short-name call site instead of falling back to on-demand compile -- four-part fix, e90dd04ae/5f2f42b36 + base.init_code base registration"
metadata:
  node_type: memory
  type: project
---

## symptom

Jobsite added two new call sites, `<[base32.encode]>`/`<[base32.decode]>`
(post-`swap_subs` short names for `base.base32.*`), without regenerating
`subroutines.load-early`. Expected: deferred-compile safety net kicks in
on first call, same as any other non-whitelisted sub. Actual: hard crash
— `<[base32.encode]>` compiles to a bare `$code{'base32.encode'}->()`
(`p7_syntax__translate`, no existence guard) and that key never existed
in `%code` at all, not even as a stub.

## root cause chain (four separate, stacked bugs)

**1. `bin/Protocol-7`'s lifecycle-hook stub gate was namespace-depth-blind.**
Around `p7_load_code`'s whitelist-miss branch (~line 1588), a lifecycle
file (`pre_init`/`init_code`/`post_init`/`end_code`) only got a deferred
stub if its name matched `$code_name` at exactly one segment
(`^\Q$code_name\E\.(pre_init|...)$`). `base` is always loaded as a single
top-level token (`p7_load_code(qw|base|)`, bin/Protocol-7:48 — a
*separate* call from a zenka's own `[load_modules:<modules.load>]`, not
merged into it), so every `base.<X>.pre_init` (`base.base32.pre_init`,
`base.chk-sum.bmw.pre_init`, `base.event.pre_init`, ~16 total) is "one
segment past `base`" and got silently skipped — **no stub at all**, not
even a broken one. `base.init_modules` enumerates `%code` directly by
`.pre_init$` pattern (modules/base.init_modules:19-30), so a missing stub
means the mover never runs, `swap_subs` never fires, and the short name
never gets created.

Confirmed this is not `base`-specific in the code, just in occurrence:
any namespace's *own* nested lifecycle hook two-plus segments deep would
hit the identical bug; `base` just has by far the most `swap_subs`-movers
living directly under it.

**Fix**: widened the gate to accept lifecycle hooks nested anywhere under
`$code_name`'s tree (`^\Q$code_name\E(?:\.[\w-]+)*\.(pre_init|...)$`),
matching `dep-graph`'s existing (static-analysis-only) equivalent logic —
see [[topic-base32-namespace]] for the earlier `dep-graph` swap-parser
fix that solves the *same* class of problem for the offline whitelist
generator only.

**2. `base.handler.deferred_compile` didn't self-heal across a swap.**
Once (1) is fixed, `base.base32.pre_init` gets a stub, runs, and
`swap_subs` moves the *already-installed* `base.base32.encode`/`.decode`
deferred stubs to `base32.encode`/`.decode` (a real hash-key move, not a
copy). But that stub closure identifies itself via a compile-time
`# line 1 "base.base32.decode"` hint — it has no idea it now lives under
a different key. Every call through the new key: resolves its own
identity as the *stale* pre-swap name, recompiles that name fresh (as a
brand-new hash entry), `goto`s there for this one call — works, but the
key actually being called through is never updated, so the **next** call
repeats the entire recompile from scratch, forever. Observed as an
infinite `..: deferred compile : base.base32.decode ..,` / `compiling
..,` loop in the log.

**Fix**: `base.swap_subs` already records `$data{'code'}{$sub_name}
{'moved_to'}` for anything it relocates (base.swap_subs:69-71), and that
metadata survives even after the `%code` key itself is deleted.
`deferred_compile` now checks it right after compiling and aliases the
resolved coderef onto the moved-to key too, so the second and all
subsequent calls hit the real sub directly.

**3. `base.register_src_deps` tracked every nested lifecycle hook as its
own independent dependency.** Side effect of (1): all ~16 nested
`base.*` lifecycle hooks (plus, incidentally, any other nested module
under an already-loaded top-level namespace, e.g.
`sourcecode.console.sign` under `sourcecode`) now get individually
registered as `configuration/zenki/<zenka>/source/<name>` touch-files on
every zenka, even though the parent namespace (`base`) is already
registered and covers them.

**Fix**: `register_src_deps` now walks a module name's dotted ancestors
and skips writing its own touch-file the moment any ancestor is already
registered on disk or is part of the same registration batch. Generic —
not lifecycle-specific — confirmed to also collapse
`sourcecode.console.sign` correctly.

## 4. `base` itself was never registered on a plain boot (resolved same session)

Initially deferred as "minor," then reproduced hard: `sourcecode` starts
fresh each time and *still* re-created all ~14 nested touch-files, which
ruled out "stale process" and proved `base` genuinely never gets
registered at plain startup for any zenka — only `base.cmd.reload`'s
`source`/`all` path does it (`base.load_modules(@reload_modules)` at
modules/base.cmd.reload:98, where `base.clear_p7_mods` reports `base` as
"previously loaded"). Worse than "surprising": `sourcecode` (and any
other standalone/unnetworked zenka — `keys`, etc.) can never reach
`base.cmd.reload` at all, so for those it's not a transient gap, it's
permanent — fix (3)'s ancestor-collapse check will *never* have a `base`
entry to find for them.

Boot-time registration can't happen at `bin/Protocol-7:48`
(`p7_load_code(qw|base|)`) — that call runs before `<system.zenka.name>`
exists and bypasses `base.load_modules` entirely, so `base.register_src_
deps` isn't even compiled yet. `base.init_modules` runs `pre_init` for
every namespace before any `init_code` (confirmed by
`base.init_code`'s own "chk-sum swap not yet applied" comment about
`post_init`/`init_code` ordering), so by `base.init_code` time all
`swap_subs` movers have already run and zenka identity is set — added
`<[base.register_src_deps]>->(qw| base |)` there.

## landed

`bin/Protocol-7`, `modules/base.handler.deferred_compile`,
`modules/base.register_src_deps` — commit `e90dd04ae`. Stray
already-committed per-sub touch-files from before fix (3) cleaned up in
`5f2f42b36`. Fix (4), `modules/base.init_code` — not yet committed as of
this writing.

## related

[[topic-base32-namespace]] — earlier, narrower fix to the same class of
problem, scoped to `dep-graph`'s static whitelist generator only.
[[feedback-swap-subs-not-fragile]] — corrected: the claim there ("missing
whitelist entry only delays lazy-load, never breaks correctness") was
only true *after* this session's fix; before it, a fresh short-name call
site on an un-whitelisted swap could crash outright. See that file's
update note.
[[feedback-base-swap-subs-promote-pattern]] — corrected: "no wiring
needed beyond adding the file" assumed the lifecycle-hook gate already
handled nested namespaces correctly; it didn't, until this fix.

#,,,.,,..,.,.,,.,,,..,.,,,,,,,,..,...,,,.,,..,..,,...,...,..,,,,,,...,.,.,...,
#JOFYZGTK3257XG4YGKOT7B7JYJMBFINQQXX4DIIJTNZ2KVMUWEHH5OHRDWPDNTNDDRWBGPPWTU5W4
#\\\|UBIDU7HMIPJQM456QUH3OTVDRSCGG3GDISVKHXJLTQBZ7TNXWBA \ / AMOS7 \ YOURUM ::
#\[7]Y3HSQE2SSTAYE4E2LFECINOZP3YN2CLTUXERMFASMWIY72GO44CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
