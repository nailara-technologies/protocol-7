---
name: reference-spdx-marker-flags-suspect-session
description: trailing "SPDX-License-Identifier: ISC" line in a p7 module marks a file from a specific low-quality authoring session, not a real license declaration
metadata:
  type: reference
---

A trailing `# SPDX-License-Identifier: ISC` line just before the AMOS7 data-signature
footer in a Protocol-7 module file is NOT a real license convention — Protocol-7's `base`
branch is public domain (see README.md), and Protocol-7 modules don't otherwise carry
per-file SPDX tags. A prior low-quality authoring session fabricated this line — a model
unilaterally asserting a license on public-domain code, which the user considers
unacceptable regardless of intent. The user left the line in place deliberately, as a
marker for files from that session that still need review.

**Do not remove these lines yet** — they're the only record of which files came from
that session and need review. There is now a tracked cleanup task,
data/tasks/spdx-license-string-cleanup.md: review each flagged file, fix/rewrite as
needed, and only then strip the line — with no replacement license string, since the
repo doesn't use per-file tags at all.

As of 2026-08-09, `grep -rl "SPDX-License-Identifier" src/` turns up ~30 files,
overwhelmingly the `pager.*` namespace (`pager.buffer.virtual`, `pager.source.*`,
`pager.filter.*`, `pager.sort.*`, `pager.view.*`, `pager.init-code`, `pager.editor.*`,
the three `base.editor.*` stubs), plus `storage.9p.mount`/`umount`, a few `context.tree.*`
and `context.template.resolve`, and `base.decode.bmw-L13`.

**How to apply:** when reading or building on any of these files (or anything else that
turns up with this marker), treat them as unverified — plausible interface shape, but
don't assume the implementation is correct or trust it as a design reference without
reading it closely first. This came up while assessing pager.editor.integration as a
"safe" first integration target for [[editor-namespace-interface-design]] work — it's
low blast-radius (dead stub code) but NOT necessarily sound code to copy.

#,,.,,.,,,...,,.,,..,,,.,,.,.,,,.,.,.,,,.,..,,..,,...,..,,,..,,..,,,.,.,.,,,.,
#PXEMQGW27L37X6H45ZEE6SIXRQWQLV6OVCGHBELDCOY5ZPL32HNCCQJPEYLCPCHDVTYBRK3BT6VYC
#\\\|O5RXA3DBXBDBSG4UHIKYKPFYZQW7WMPIEOZZSCC4PLCOSPV4ZXJ \ / AMOS7 \ YOURUM ::
#\[7]KFGAWJMV5BZID2T75K3UAUZ22FCZDD2F2OOK3Y53WY7AFPOSYQAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
