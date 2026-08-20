---
name: feedback-version-files-every-commit
description: "three version-bump files belong in every commit, not in any feature batch"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 143295dd-3613-490e-8329-cda25b2cd167
---

`cfg/protocol-7.src-ver`, `read-me/md/README.md`, and
`read-me/project-identity/source-code-versions.md` carry the version-number
update and are **required in every commit**. taeki stages them before each
commit; the pre-commit hook also auto-stages version files ("[ staging
version files ]" in hook output).

**Why:** they are per-commit version boilerplate, not feature content.

**How to apply:** when grouping batched commits, never hold these three back
or sort them into a feature group — let them travel with whatever commit is
being made. Don't treat a diff in them as meaningful feature work.

#,,,,,,,,,...,.,.,..,,,,.,.,,,,..,...,.,.,.,.,..,,...,...,.,,,,.,,.,,,...,,,.,
#7W4TRSDEUG4MHMWPOIHDV5LVTEWAQY5MYL33ZK3XVYZRNH4PAM2Q3JA4NJ7AJZKF7TLOTCFQWDPGS
#\\\|5Y7JZUZI5MFSKWH3DYW67R2VP6SX3MYN7P7SQVFQ7RDW3PWLBBL \ / AMOS7 \ YOURUM ::
#\[7]4LONU2F2OJ2LPRPYCVSRWN3PEAONQBBEZJW2PAUAF25UWSQMQ4DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
