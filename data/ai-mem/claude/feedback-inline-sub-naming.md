---
name: inline sub extraction naming convention
description: how helper subs named _foo become module files when extracted from P7 modules
type: feedback
originSessionId: c1117ac8-6abc-4bfb-87da-871e78f681bc
---
When extracting inline subroutines from P7 modules, follow these naming rules:

**Rule 1 — no leading underscore:** helper subs named `_foo` become module files without the underscore.
Pattern: `sub _process_candidate { }` in `ncode.regex.expand` → `ncode.regex.expand.util.process_candidate`

**Rule 2 — no `.cmd.` in util namespaces:** util modules extracted from a `.cmd.` dispatcher must NOT inherit the `.cmd.` segment — they are not network commands themselves.
Pattern: sub extracted from `storage.cmd.visual` → `storage.visual.util.proximity` (not `storage.cmd.visual.util.cmd_proximity`)

**Rule 3 — no `cmd_` prefix:** the `cmd_` prefix on sub names is also redundant in the module name.
Pattern: `sub cmd_proximity` → `storage.visual.util.proximity`

**Why:** `.cmd.` marks network-accessible command handlers; util modules are internal helpers only callable via code, not via the network. Inheriting `.cmd.` would misleadingly suggest they are commands.

**How to apply:** When instructing extraction from a `.cmd.X` source, specify target namespace as `X.util.*` (drop the `.cmd.` entirely). Include all three rules explicitly in the task prompt.

#,,,.,.,.,.,.,,,.,,,.,,.,,,..,..,,,,,,.,.,..,,..,,...,...,.,,,...,.,,,,.,,,..,
#POTCSRT43NN2ECBGSH2UYJC6WUYVFY4R55LGHCQRL7VHSDVBXQRNQOHPQFRJPNW74BC3YUKUSOIP2
#\\\|2WBER2FJYX5MRNYXMCI75D5VGJBUYJ7YUIJONEIFPSGLHOF6SNM \ / AMOS7 \ YOURUM ::
#\[7]ZPE6SNWFIFRGH55WHIQQQOATBCLUFTX4F6PJXYQCAWZXZZOCHGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
