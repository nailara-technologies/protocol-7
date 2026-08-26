---
name: reload-modules-load-registry-fix
description: "base.cmd.reload's source phase ignored freshly-edited modules.load config (only replayed base.clear_p7_mods' previously-loaded set); base.p7_mod.loaded registry also got polluted with leaf subroutine names via whitelist_miss's direct base.load_code self-heal calls"
metadata:
  node_type: memory
  type: project
  modified: 2026-07-20
---

Two related but distinct bugs found while testing [[project-depgraph-conditional-calls-blindspot]]
on a live `cube` zenka after adding `ascii`/`format.yaml` to `cfg/zenki/cube/zenka.v7`'s
`modules.load`.

**Bug 1 — reload ignored new modules.load entries.** `base.cmd.reload`'s "source" phase
(`src/base.cmd.reload:57`, pre-fix) built its reload list purely from
`<[base.clear_p7_mods]>` — the namespaces already tracked as loaded — never consulting the
freshly re-read `<modules.load>` config value. So editing `modules.load` and running `reload`/
`reload all` any number of times would never compile in a brand-new namespace; only a fresh
zenka boot (which runs `[load_modules:<modules.load>]` once from the start file) or an explicit
`<[base.load_modules]>->('ns')` call would. Confirmed via `show-buffer undef-subs` still flagging
`ascii.frame.load`/`ascii.frame.render` as undefined after several `reload` runs.

Fix: union `@previously_loaded` (from `clear_p7_mods`) with the current `split(<modules.load>)`
list before building `@reload_modules`. This is additive-only, so it doesn't disturb the
`clear_p7_mods` accumulation needed for [[bug-swap-subs-reload-timing]]-style renamed namespaces.

**Known caveat — not fully solved.** Several zenki load code through a *second*, differently
named directive that this fix doesn't see: `modules.preload` (download, power, osd-logo,
rss-ticker, ssh, tile, X-11) or a literal string arg (`start-anim`'s `[load_modules:'start-anim']`,
`web-browser`/`ticker`'s `'set-up.json <zenka>.set-up'`). The union fix only reads `modules.load`
by name, so it's blind to those. The clean fix would record, at `[load_modules:<key>]`/
`[load_modules:'literal']` directive-expansion time, which config key(s) or literal set fed each
call into a small per-zenka registry, then have "reload source" re-evaluate the *current* value of
every recorded source — correctly handling both additions and removals for every directive shape,
without special-casing `modules.load` by name. **Not implemented** — flagged as the next step if
this needs to generalize beyond `modules.load` specifically.

**Bug 2 — `base.p7_mod.loaded` registry pollution.** Live `dump base.p7_mod.loaded` on `cube`
showed leaf subroutine names (`'base.code.call_optional'`, `'base.code.exists'`) sitting alongside
genuine namespaces (`base`, `ui`, `net`, `crypt.C25519`, ...). Confirmed via delete-then-reload
that these don't reappear from reload itself — one-time pollution from an earlier self-heal.

Root cause: `p7_load_code` (== `base.load_code`, `bin/Protocol-7:1481-1482,2039`) unconditionally
writes `$data{base}{p7_mod}{loaded}{$code_name}` for *whatever name it's given* — namespace or
leaf sub, no distinction. `base.register_p7_mod_load` (`src/base.register_p7_mod_load`,
called only from `base.load_modules`) is the intended, sole namespace-level writer — but
`base.handler.whitelist_miss`'s heal-policy loop calls `<[base.load_code]>->($sub_name)` *directly*
or a single missing sub, bypassing `base.load_modules` entirely, so that one leaf name gets
stamped into the same registry `base.mod.exists`/`base.clear_p7_mods` treat as namespace-only.

**Important: do not strip the writes from `p7_load_code` itself** — they're not purely redundant.
`register_p7_mod_load` sets `loaded=TRUE` optimistically *before* the load is attempted;
`p7_load_code` resets to `0` first and only restores `TRUE` if `$compilation_success` — it's the
*authoritative, accurate* success/failure signal for genuine `base.load_modules`-driven namespace
loads. Removing it would make every `base.load_modules` call register as loaded immediately even
on a hard compile failure.

Fix instead applied at the actual pollution source: in `base.handler.whitelist_miss`'s heal-policy
loop (`src/base.handler.whitelist_miss`, right after
`eval { <[base.load_code]>->($sub_name) }`), delete `<base.p7_mod.loaded>->{$sub_name}`
immediately — a single healed sub is not a loaded namespace. The `moved_to` fast-path's parallel
`else` branch (`base.load_code` call for a substituted leaf name) is effectively dead code today
(the `index($load_target,'.')>0` branch condition is true for nearly every real target, namespace
or leaf alike, so it almost always takes the `base.load_modules` branch instead) — left alone,
not urgent.

**`base.swap_subs` is unrelated** — confirmed by reading it. It only rewrites `%code` keys
in-memory and maintains `base.modules.moved_to`/`internal_name` (the rename map); it never touches
`base.p7_mod.loaded`. It runs from a module's `pre_init`/`init_code`, i.e. the "init" phase of
`base.cmd.reload` — strictly *after* "source". So a bare `reload source` never re-applies a
pending `swap_subs` rename; only `reload all`/`reload init` does. This is *why* relying on
`clear_p7_mods` (tracking actual current in-memory identity post-rename) rather than raw
`modules.load` text was originally necessary — a purely-internal rename (e.g. `base.event` →
`event`) may never appear in any zenka's `modules.load` under either name.

**Self-reference reload lag confirmed again**, same class as the existing
`base.referenced_subroutines.clear_from_disk` note in [[feedback-undef-sub-scanner-verification]]:
editing `base.cmd.reload` itself takes *two* `reload` invocations to fully apply — the first
recompiles the new source but is still executing the old in-memory closure; the second actually
runs the patched logic. Confirmed live: `ascii` only appeared in cube's "loading p7-source" list
on the second `reload` after the `base.cmd.reload` patch landed.

**Concrete trigger case**: `cube` zenka's `modules.load` was missing `ascii`/`format.yaml` —
`ascii.frame.load` needs `format.yaml.load_file` to parse frame yaml. Both added to
`cfg/zenki/cube/zenka.v7`; `show-buffer undef-subs` went from 2 flagged subs to empty
after the reload-sync fix + adding the missing namespaces.

**How to apply:** if a zenka's `modules.load` edit doesn't seem to take effect after `reload`,
check (a) whether `base.cmd.reload` itself was just patched (needs a second reload), (b) whether
the zenka actually uses `modules.preload` or a literal `load_modules` call instead of
`modules.load` (the union fix doesn't cover those), (c) `dump base.p7_mod.loaded` for stray
leaf-level pollution if something was recently self-healed via `whitelist_miss`.

#,,,,,,,.,,,.,,.,,.,,,..,,..,,..,,,.,,,..,.,,,..,,...,...,.,.,,,,,...,...,,..,
#V7FROALHKJRLY7JRZCCM6TL6QWESXWKNSOUF7XWLWH426HN6KAKQJ7Y3625XYJSIQRUK23UE3XZTA
#\\\|VK5SYAUAV2SK65N6ZR4WRFG2NJJ3TMLMWWAX3HD5FZEQMAS7RGN \ / AMOS7 \ YOURUM ::
#\[7]SW2BKRUDU6PPTCROVPC35J355KC6DO2NHOMQDHBVGNPDIJMEWCCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
