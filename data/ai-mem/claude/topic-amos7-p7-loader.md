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

**How to apply:** when MCP tool handlers need to call P7 modules directly (instead of
shelling out to bin/chat or p7c), implement AMOS7::P7 first. until then, keep handlers
as pure Perl with the `## pure perl only — loaded via do()` comment as a marker.

the `do()` comment in mcp.tool.p7_chat_* modules serves as a TODO marker for this upgrade.

#,,,.,.,.,.,,,.,,,...,,.,,,.,,...,,..,,,,,,,,,..,,...,...,,.,,...,..,,,,,,,.,,
#HRWB6XTFMXNRKHFXLYTZEKO74V7HKMS5OZIIAADDUUKUWWMFMHXWP657H3Y7TJRXCSRQH462G5EWA
#\\\|52X5ZLOPBFQXFKDKAMVP4IRK4HRFZR5MGNNJLULNJQ5TKAGAC77 \ / AMOS7 \ YOURUM ::
#\[7]VOIXKZVQBSEZTABDK2BPITJZVAFHQNODSJA6KODDRTUF2ZNUUYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
