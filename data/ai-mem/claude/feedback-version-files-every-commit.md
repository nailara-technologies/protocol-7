---
name: feedback-version-files-every-commit
description: "three version-bump files belong in every commit, not in any feature batch"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 143295dd-3613-490e-8329-cda25b2cd167
---

`configuration/protocol-7.src-ver`, `read-me/md/README.md`, and
`read-me/project-identity/source-code-versions.md` carry the version-number
update and are **required in every commit**. taeki stages them before each
commit; the pre-commit hook also auto-stages version files ("[ staging
version files ]" in hook output).

**Why:** they are per-commit version boilerplate, not feature content.

**How to apply:** when grouping batched commits, never hold these three back
or sort them into a feature group — let them travel with whatever commit is
being made. Don't treat a diff in them as meaningful feature work.

#,,,.,,,.,...,.,.,,..,..,,,..,..,,..,,.,.,.,.,..,,...,..,,.,,,...,,,.,,..,.,.,
#6PIC3THUJW2FP7JT6534HZMXIJTXMNYE5ZFUALBB4MPHXM2L3ZAEBETZ5G7DWG5R3YMMXCJIFLXGC
#\\\|NSNVS3EMJIDE5WAY5UHMUDQLZ3B23GM6WW23CR2SW2H27SOM35O \ / AMOS7 \ YOURUM ::
#\[7]4N6ZFZHOS77V7Q5L55SRXS53BDC6UXC2NSKHICXYJA5ZLZODIUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
