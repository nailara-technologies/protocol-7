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

#,,,,,.,.,..,,...,...,,..,.,.,,..,,,,,,,,,.,.,..,,...,...,...,,,,,..,,,,.,.,,,
#OXVNPBCONBFHVJS3BKA25J4F7KAX7U3BAGN6VSCWZYY7RAG3XF6PSI424UVQLTL4WOUAZ2YHFXEMC
#\\\|WM5SXISDLUPANCF7RRMDYUADU4RC34WLG325VZRGBZE6Y33OMGX \ / AMOS7 \ YOURUM ::
#\[7]JCZ6RPCIKZGLR2PMABJFNLF63VHCMNNLJGXXYTR2C5RGGHXAJ4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
