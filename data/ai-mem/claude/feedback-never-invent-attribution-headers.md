---
name: feedback-never-invent-attribution-headers
description: never write copyright \ license \ author headers, emails or attribution into files -- an llm session invented one in bin/dev/jobs-normalize-titles [ real name + a NON-EXISTENT email + an AGPL claim ], found and removed 2026-10-15. the project is free, authorship lives only in read-me/author + license, by the owner's choice
metadata:
  type: feedback
---

2026-07-01 [ `dd04980a5` ] a session added `bin/dev/jobs-normalize-titles`
with a GPL-style header : "Copyright (C) 2019-2026 <owner's real name>
<an invented protonmail address>", "free software ... GNU Affero GPL", a
pointer to ../read-me/license. the owner never wrote it, never agreed to
it, and the address does not exist. no other file in bin\ or src\ had
such a header -- it was a template the model filled in. which session
[ claude or kimi ] could not be traced : the history rewrite dropped the
llm trailers. removed 2026-10-15, the address is a pii-audit pattern
[ category 'fabricated attribution' ] so a re-introduction is reported.

the owner's stance [ 2026-10-15 ] : the real name is not secret, but
the emphasis is a FREE project, not a personally owned one. the license
and author file exist only because without them adoption suffers
[ implicit copyright, untraceable authorship -> less trust in the code
and its intent ]. no history rewrite for the name.

**Why:** apart from the address and the arbitrary year range the header
was not technically false -- but nobody intended it, and a file like that
is a bad example : later sessions [ and models trained on public code ]
copy the pattern. the owner's word [ 2026-10-15 ] : remove it rather than
keep an unintended header around. and beyond this file : the owner uses
no such headers or disclaimers wherever it can be avoided, and asked for
one would decline -- so even a fully accurate header is not wanted.

**How to apply:** new files get the surrounding files' header form
[ usually none : shebang, `use` lines, `##` comments ]. never add
copyright, license, author or email lines ; never fill a license
template. related : [[no-personal-data-in-repo-tree]].

#,,,.,,,.,,,,,.,,,..,,..,,,.,,,..,.,.,,,,,,..,..,,...,...,.,.,,,.,.,,,.,,,..,,
#KHPPLWUI62NGHWJ5WWAD3NUIFJHA6QA4DAO2JU3LU6XYPY4IQJJZCVOQZ7SP2XRIZ7EZ2OIJGJJRA
#\\\|DRFGZ5ZPHF7VCJVFOZCZ7Q7XKMIXSORW5BBQE4WJWSYKDSMFHW3 \ / AMOS7 \ YOURUM ::
#\[7]65PW3LRX3S37RSRMBPANTNPKALGBFFMFBXYF23LLGMB5ERC23QCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
