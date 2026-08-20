---
name: AMOS7::P7 subroutine loader vision
description: dep-graph based P7 module loader for standalone scripts and MCP handlers
type: project
originSessionId: 327ba945-ac12-456a-985f-690320d1550f
---
vision: `AMOS7::P7` (or similar namespace) as a dependency-graph-aware loader that
makes P7 subroutines callable from plain Perl scripts and MCP tool handlers without
needing a running zenka.

**Why:** current `do()` loaded MCP tool handlers must be pure Perl — they cannot use
`<[module.name]>` P7 syntax because that requires the P7 parser/compiler. this limits
what MCP tools can do directly. same limitation applies to any standalone script that
wants to reuse P7 module logic.

**How it would work:**
- `use AMOS7::P7 qw| some.module.name other.module |`
- loader parses the module file, resolves `<[...]>` dependencies recursively
- builds a dep graph, loads and compiles in order
- exposes subroutines as callable Perl refs in the current namespace
- handles the `<[mod.name]>->()` implicit no-arg call syntax

**Related, already-real infra in bin/Protocol-7**: seamless export/import of subroutines
between its two internal scopes, so subs can move freely between them:
1. the `p7_`-prefixed "core" subs living in `main::` (plain top-of-file perl subs)
2. the "inline subroutines" block after `__DATA__` (bin/Protocol-7:5798) — each entry is
   a named, base32-ish encoded + checksum-signed blob, e.g. `.:[ base.parser.pattern_split ]:.`
   at line 5804, closed with a `<...:NNNN:NNNNNN:NNNNNNN>` signature line and a `:.` terminator.

`p7_import_main_subroutines()` (bin/Protocol-7:217) scans `main::` for `p7_*`-prefixed
subs and installs them into `%code` (`p7__foo` -> `foo`, otherwise `p7_foo` -> `base.foo`,
`__` -> `.`). `p7_export_inline_subroutines_with_exact_style()` (bin/Protocol-7:5512) goes
the other way, exporting inline subs back out with exact style preserved (`as-is`/`decoded`/
`encoded` content formats, optional pattern filter). Per user (2026-08-05): this
bidirectional move-ability between the two scopes is the general direction, and is
expected to eventually extend to `AMOS7::` packages themselves too, so every non-main
code scope stays minimal/flexible with sane dependency graphs rather than ownership
being fixed to "this sub lives in this file forever."

**How to apply:** when MCP tool handlers need to call P7 modules directly (instead of
shelling out to bin/chat or p7c), implement AMOS7::P7 first. until then, keep handlers
as pure Perl with the `## pure perl only — loaded via do()` comment as a marker.

the `do()` comment in mcp.tool.p7_chat_* modules serves as a TODO marker for this upgrade.

**Extraction already started, and it's bi-directional now**: `data/lib-path/pm/AMOS7/Protocol/P7Syntax.pm`
exports `p7_syntax__translate` (P7 `<[module.name]>` / `<data.key>` -> plain perl
`$code{...}`/`$data{...}`), deliberately dependency-free so it can run during
`bin/Protocol-7`'s own bootstrap (before `use lib` for data/lib-path/pm is safe) — an
inline copy also lives in `bin/Protocol-7` itself (`sub p7_syntax__translate`, kept in
lockstep by hand, see the comment above it there) for that reason. Consumers: `bin/dev/ptd`,
`bin/format-code` (running `perl -c` after translating), and inside a running zenka
`src/devmod.cmd.eval-code` calls the zenka-side wrapper `<[base.syntax.translate]>`
so `eval-code` accepts P7 syntax, not just pure perl. Per user (2026-08-05): the
perl<->P7 conversion is now bi-directional (perl syntax foldable back to `<[..]>`/`<..>`
style too), making this the first real consumer of the code-parser extraction goal. the
reverse direction (perl -> P7) is harder than P7 -> perl because it requires judging
affected scope (e.g. whether a `$code{'x'}->()` call is safe/intended to fold into
`<[x]>` in context) rather than a pure mechanical regex swap — still manageable, not a
blocker, just asymmetric in difficulty.

**Same vision applies to bin/* standalone scripts**, not just MCP handlers: the shim a
src/ routine needs to run outside a full zenka is generally small — a `%data` hash
seeded with a few init values (matching `bin/Protocol-7` / `base.init_code`), plus a
static whitelist of subs known to work without the `%code` dispatch or zenki network.
Until AMOS7::P7 exists, porting/duplicating logic out of zenka modules (e.g.
`src/ascii.frame.*`) into standalone-usable AMOS7::* packages is fine — see
[[topic-bin-todo-style-refresh]]. don't over-optimize to avoid that duplication now;
prioritize not degrading style/functionality/flexibility. revisit consolidation once
AMOS7::P7 lands.

#,,..,...,,,,,..,,,,.,.,,,,,,,.,.,,..,..,,,,,,..,,...,...,...,...,..,,..,,,,,,
#FYQPZEEDIMMUQNE2WFSR732OMZNJR2X5S4D5OSVUE4JHXVCQZWSZQKUYSF4QBZT5RVXEQICUJRTJY
#\\\|ZYAZFQATO2EBOUNYZ44OSCP272HD3CF6GVUXWZMTWZABQFCHDWV \ / AMOS7 \ YOURUM ::
#\[7]CPYMVKMSNVQ67A63AY3Q5DTFNYZZYKPCLJNZ7WYCQ4TJ22YLBQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
