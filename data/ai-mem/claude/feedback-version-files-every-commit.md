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

#,,.,,,.,,,..,,,.,.,.,,.,,,..,,,,,.,,,,,.,.,.,..,,...,...,...,..,,..,,,,,,,..,
#4DCLZYM2UXT6XZNINHX2KHZ7BRNHZLNHY26AYOIPWNJFJLZWS56VHQMQO3DUJSOVHC4YBXTZGEUCA
#\\\|DMKOOWO3HE3SC5X2PXFU6WPYC26DTUUWXKYQJ6LIUMJBEE72LUP \ / AMOS7 \ YOURUM ::
#\[7]USBJDPZ4OX7KFY3CLTAA46KOBM522SNQEC6GK35N6ZFVWNZTOGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
