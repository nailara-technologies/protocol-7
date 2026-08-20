---
name: ptd-as-post-generation-step
description: use ptd (not ptd -c) after writing modules — formats code and checks syntax in one step
type: feedback
---

Use `ptd` (not `ptd -c`) as a regular step after generating P7 modules. It formats the code AND does syntax check implicitly. The user runs ptd before signing anyway, so a separate `ptd -c` step is redundant.

**Why:** saves a step in the workflow — ptd already covers syntax checking.
**How to apply:** after writing a new module, run `ptd src/name` instead of `ptd -c src/name`. Skip the separate syntax check.

#,,,,,..,,,.,,,,.,.,.,,.,,,..,.,.,.,,,..,,...,..,,...,...,..,,,.,,...,.,,,,..,
#W5L3WOQE44DGVNGFJ6PI6CXWBJNKSLZN2EV6ITQ4QNXKD6AVFFPL7BLB752ZXIOSHYFGMG6G4URNQ
#\\\|6OUYSHWK3FWGHI6KHSJS4FYLYHT3C3HJGWBG4P5A5OLGS67J2ZL \ / AMOS7 \ YOURUM ::
#\[7]HZ76EER5LFKDGQK2NT7BNTO5IZCLMWVIULQUXG5YNU6Y524MKUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
