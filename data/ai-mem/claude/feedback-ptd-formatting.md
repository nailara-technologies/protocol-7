---
name: ptd-as-post-generation-step
description: use ptd (not ptd -c) after writing modules — formats code and checks syntax in one step
type: feedback
---

Use `ptd` (not `ptd -c`) as a regular step after generating P7 modules. It formats the code AND does syntax check implicitly. The user runs ptd before signing anyway, so a separate `ptd -c` step is redundant.

**Why:** saves a step in the workflow — ptd already covers syntax checking.
**How to apply:** after writing a new module, run `ptd src/name` instead of `ptd -c src/name`. Skip the separate syntax check.

#,,..,...,...,,.,,,..,,,.,...,.,.,.,.,...,.,.,..,,...,..,,,..,..,,,,,,,,.,,,,,
#UGKAYLP22TBBBCRWQ2TTP7UNZFQXVDEQTGUUEB3BYEE3P2JD3HAQVINVZBJFJS5M2S4NERWY3KPFI
#\\\|SSAUMU4QH6J7KF557T4HP25DPP46NXMQVK2A3T52D47HFKNUFEC \ / AMOS7 \ YOURUM ::
#\[7]NNT6QOFCPUENXDUKA7PJ2MTK6KBLSKJH4ZPYCZVDWA4LZBLC66BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
