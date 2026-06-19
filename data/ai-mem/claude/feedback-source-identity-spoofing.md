---
name: source-identity-spoofing
description: self-reported hostname/zenka-name strings are not a security boundary; C25519 key-tree identity is the real fix, planned for later
metadata:
  type: project
---

`SOURCE_ZENKA` alias substitution in `base.handler.command` had been silently
prefixing the injected caller identity with the node hostname
(`sprintf('%s.%s', <system.node.name>, $user)`), fixed 2026-06-19 to just
`$user` — found via a `select-region` zenka auth bug ([[topic-zenka-naming-cleanup]]).

**Why this design existed:** an external/remote `p7-log` zenka aggregating
logs from multiple nodes would want each node's *own local* cube to stamp
its hostname before forwarding, so the aggregator can still separate log
files per origin node.

**Why it's not a sound long-term answer:** the value cube adds (`$user`,
the authenticated session identity) is itself not spoofable over the wire —
cube derives it from the session, the zenka can't inject an arbitrary string
there. But the *authenticated identity itself* is currently just a
configured name/key pairing, so a zenka could still be configured/keyed to
claim an identity that isn't really "it." Self-reported source strings
(hostname or zenka name) are fundamentally not a security boundary on their
own.

**How to apply:** when C25519 key-tree-based node/zenka identity work
happens (see [[topic-key-tree-ring-routing]] design — tree answers "who",
ring answers "through what"), source attribution for things like
multi-host log namespacing should derive from unspoofable key identity, not
self-reported name strings or cube-stamped hostnames. Revisit `p7-log.cmd.append`'s
host-namespaced log filename (`<system.node.name>` + zenka name) at that
point — it's a stopgap, not the final design.

#,,..,.,.,..,,.,.,..,,...,.,,,,.,,,,.,,,,,...,..,,...,...,...,.,,,,..,,..,.,.,

#,,.,,.,,,..,,,,.,.,,,.,.,.,.,,..,,,.,...,,.,,..,,...,...,.,.,.,.,.,,,.,,,,.,,
#ZXKGHATW7O64C4GQKJWAXVC2AIBWTN76DURGZK2X6OE2PQQAXQSOOTETYVYU3JWLPK5VDFG4XSZPC
#\\\|CV7QZWKFFIHR7XFUFFFIL7P3O6NMYHZUUOMFC47LZW3MJL7B3GO \ / AMOS7 \ YOURUM ::
#\[7]X3SH4DSN4RWPPTYMUHNJFXS22DAT3CQ35JJX5XY2N36GZQFPZUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
