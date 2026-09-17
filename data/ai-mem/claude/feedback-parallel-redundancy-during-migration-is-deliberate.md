---
name: feedback-parallel-redundancy-during-migration-is-deliberate
description: the user's stated general philosophy for standalone-script-to-zenka (and similar) migrations -- deliberate short-term redundancy across parallel code paths is a feature, not a gap to flag or rush to unify
metadata:
  type: feedback
---

2026-09-17, said directly while I was working through `fetch.file.
huggingface.*` vs `invoke-model-recover` (see
[[vision-automated-model-testing-and-selection-pipeline]]): this
project's general inertia direction is standalone scripts migrating
into proper zenki over time. `fetch-files` is the most recent code in
the download-resilience context, "by far not feature complete yet," and
likely won't end up the only zenka/module namespace with
resilient-download logic.

**Caveat found immediately after, same exchange**: that specific pair
(`fetch.file.huggingface.*` / `invoke-model-recover`) turned out NOT to
be an instance of this pattern after all -- they're permanent separate
adapters for two genuinely different, coexisting model populations
(InvokeAI's own store vs. the lmstudio-hosted models the coding zenka
actually uses), not one migrating toward replacing the other. See the
vision file's "second correction" for the full picture. The general
principle below still stands and is still worth applying -- just don't
reuse that specific pair as the example again; it needs a real
same-capability-two-implementations case, not a two-separate-hosts one.

**The stated principle**: some initial redundancy across parallel code
paths is usually beneficial during this kind of transition --
- it provides functional stability on the way to feature completeness
  (nothing depends on the one-and-only path being right immediately)
- it allows alternating upgrades of different code namespaces without
  one upgrade risking breaking the other, parallel one at the same time
- eventually the better-working code path is what gets migrated TO,
  which frees the prior path for its own next round of upgrades

**How to apply**: when I find two code paths doing similar things
(a standalone script and a newer zenka module, two zenki with
overlapping logic, an old and new implementation mid-migration), don't
default to framing this as a gap, inconsistency, or thing to unify
soon -- that's not the user's model of how this project evolves. Ask
whether it's a deliberate transitional redundancy first. It only
becomes worth flagging as a real problem when: the paths have silently
diverged in *behavior* (not just existence), a caller is picking the
wrong/stale one by accident, or the redundancy has clearly outlived its
transitional purpose (the "worse" path is no longer being used for
alternating-upgrade safety by anyone). Otherwise, note it as expected
and move on.

#,,..,...,.,.,..,,,,,,,.,,,,.,,,.,...,,,.,.,,,..,,...,...,...,.,,,..,,..,,...,
#DA6QPXMSBMITDGELXFQFPNRY7TCYBDGHNW34ZEFLSMNOA5YFHZY2E5YYJHJLIXNRBTLSBVMSL6GUK
#\\\|XTUX3AG7JFXB4IIWREVNEQEVABFEQ6DNTG2KSCSIKBCHK3D2MBG \ / AMOS7 \ YOURUM ::
#\[7]5PCVEVDHC2TEJW6CIYZ4HHYDBQC4G755GQPYDHKYQ3GDC2LRLOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
