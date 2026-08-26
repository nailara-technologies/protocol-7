---
name: feedback-memory-sync-timing
description: trigger memory sync when ~42K context tokens remain — before auto-compaction fires
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dc444b10-bea3-4bdc-bd08-d2632aaaad6f
---

Sync memory (write + commit) when approximately 42K context tokens remain. That's the sweet spot — enough headroom to finish the sync before compaction fires, but late enough to capture the full session.

**Why:** Auto-compaction happens around 40K remaining. If memory sync isn't done before that threshold, the summary captures it but the memory files don't get updated until the next session. Session 48c nearly missed the sync window.

**How to apply:** Watch context usage during long sessions. When approaching 42K remaining, prioritize memory sync over new tasks. The commit can happen right after signing, before starting any new work.

#,,,.,..,,,.,,,,,,,.,,,,,,,.,,.,.,.,.,,..,..,,..,,...,...,.,.,,,.,.,.,.,,,.,.,
#G6ASYPR4GWWJJZPIES3GCK452XHOMRS4IPQEQNCQQUPH6QRCPDNSVSMGKJHRQFJR4VP5KZ7OQ2BHQ
#\\\|AMIX6MPG2CYRFGLXKVVEO3OZCOWKJ44MFX2AJ52U5LINGZTIF7L \ / AMOS7 \ YOURUM ::
#\[7]GLPAZN2WZSIMY6KIKCQOIK4UXAQTU7XVFLO46PZKT3KDC7ZWTADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
