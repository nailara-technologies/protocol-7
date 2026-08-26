---
name: task.show multiline description escaping
description: task.show must escape newlines in description/context; parsers must unescape
type: feedback
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
---
task.cmd.show embeds description and context into a line-oriented header block via sprintf.
If the description contains newlines (e.g. a multiline prompt), downstream parsers that
iterate lines and match `^description\s+:\s+(.*)$` will silently capture only the first line.

**Why:** discovered when job assessment prompts (4000+ byte profile + job data) were truncated
to just `:local: :simple: you are a job matching assistant.` — model received no actual data.

**How to apply:** any time task.show or a similar header-format module embeds a potentially
multiline value, escape `\n` → `\\n` in the emitted string, and unescape after parsing.
Current fix lives in `task.cmd.show` (lines 66-67) and `models.handler.task-poll-step` (unescape step).

#,,.,,.,.,,.,,,,,,,.,,,.,,...,...,..,,,,.,..,,..,,...,...,..,,,.,,,,.,,.,,.,,,
#N2E3TFZEGC7F2SIO2DPADNPLT3ISXYTC35J6OKM6GBJEPDXCK3JWTP3TULAUPPS2UEUKOS4T72DAA
#\\\|ZGAKJZKXN27RJML2HF2VOZU47ZVTZGJBB2DJ6P5GSRP7XBAJKSO \ / AMOS7 \ YOURUM ::
#\[7]3G3YQBMYF5TDXQMBDOZU35OCRQRJVTL6F5MYIZCSNPWU4E2A5GCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
