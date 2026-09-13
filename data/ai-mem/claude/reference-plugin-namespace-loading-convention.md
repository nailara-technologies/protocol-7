---
name: reference-plugin-namespace-loading-convention
description: "plugin.<zenka>.* is a real, established loading convention (base.load_plugins + [load_plugins:<plugins.load>] directive) already used by 5+ zenki -- how to add plugin support to a zenka that doesn't have it yet"
metadata:
  type: reference
---

Confirmed live 2026-09-14 while scoping `plugin.nshell.coding-session`.
`plugin.<zenka>.*` is a real, multi-zenka convention, not just a naming
style — already used by `plugin.auth.*`, `plugin.httpd.radio.*`,
`plugin.storage.*` (coding zenka), `plugin.user-edit.*`, and web.

**Mechanism**: a zenka's `zenka.v7` declares `plugins.load = plugin.foo
plugin.bar` (space-separated names) and calls `[load_plugins:
<plugins.load>]`, placed right after `[load_modules:<modules.load>]` and
before `[init_modules]` — see `cfg/zenki/web/zenka.v7` for the minimal
real example (`plugins.load = plugin.web` / `[load_plugins:
<plugins.load>]`).

**What it actually does** (`src/base.load_plugins`): filters the given
names to ones starting with `plugin.`, compiles them via the same
`base.load_code` loader every other module uses, and registers each in
a `<plugins.status>` hash for later `base.reload_plugins` tracking. It is
purely a load-and-track mechanism — **no generic hook/dispatch framework
comes with it**. A plugin module is just a normal callable (see
`plugin.storage.inference`'s dispatch-by-`{operation}` shape as a
convention example); any hook interface (on_focus/on_submit/whatever) is
designed and wired by the consumer, not provided by `load_plugins`
itself.

**How to apply**: a zenka with no `plugins.load` line yet (nshell had
none before 2026-09-14) can gain plugin support by adding both the
`plugins.load = ...` var and the `[load_plugins:<plugins.load>]`
directive to its start file, mirroring web's placement exactly. Don't
expect load_plugins to give you hook registration for free — that part
is always custom per consumer.

#,,.,,..,,.,,,.,,,,..,,..,,,,,..,,...,.,.,,,,,..,,...,...,,,,,..,,..,,.,,,,..,
#VVKWSWF6AYU6NXTX5DPYTDCMWJZZLJFEP77ZWZQGNCAB6JIUFEDF6CQ2VJVHDOA34GFLM22G44SRM
#\\\|GF7RUPMFGZTWUGV4FRXSA3RI7MB4SM77D7MOLUABTWLEDFTGFHE \ / AMOS7 \ YOURUM ::
#\[7]Z5K45PTJDWFUNE2S6OCK6Y2DYIJAOWSBVNFYDN6SYJULA36GSGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
