---
name: feedback-dead-defensive-code-is-a-bad-example-not-just-clutter
description: the user's stated *why* for treating obsolete-but-plausible-looking guards (e.g. an always-true `if (exists $code{'literal'})`) as worth actively cleaning up, not just harmless clutter to leave alone
metadata:
  type: feedback
---

Stated directly 2026-09-18, about the `coding` zenka's dozens of `if (exists $code{'literal.name'})`
guards that are provably always-true (every namespace they check is in that zenka's own static,
unconditional `modules.load`/`plugins.load`, loaded before `init_modules` ever runs — cleanup
delegated to a `k2.8` dispatch, session `753d5696-2f49-4127-a1c6-763a81505cae`): dead defensive code
like this isn't just inert clutter to tolerate. It **looks like it matters** — a real conditional,
guarding something that reads as
important — while actually being a no-op by construction. Left in place, it's a bad example for
future code: a new implementation or expansion (written by a person or an LLM) that copies the
pattern nearby will cargo-cult a guard that looks meaningful but does nothing, propagating the
same false signal forward instead of learning "this namespace is always loaded here, no guard
needed."

**How to apply:** when a cleanup task is specifically about removing dead-but-plausible-looking
code (not just simplifying working logic), don't treat it as low-priority tidiness. The value isn't
(only) the lines removed — it's preventing the pattern from being copied into new code later,
especially in a codebase where LLM-assisted generation is a first-class workflow (see
`data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`) and visual/structural consistency is
explicitly relied on to shape what gets generated next.

#,,..,,.,,,,,,...,..,,.,,,,..,,.,,,..,,..,,.,,.,.,...,...,.,.,..,,,..,...,,,.,
#WVMGWHQWOTSAAOQREZKVRDRD4RWRQL6XAAYDKI3LMCTDMQUJ74AYG5UCTTPVJZ6HQKYAFJWIGB3CK
#\\\|DYDFLNHIVCBVCZ377D3ZKM6RBS4GDYGQJ36XYQDH5WUSEMECXTF \ / AMOS7 \ YOURUM ::
#\[7]Y2WW4RFDJQUAHAYOH6SQCPP34X4WLTPH4MFIO7SM7ZLIAM45F4BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
