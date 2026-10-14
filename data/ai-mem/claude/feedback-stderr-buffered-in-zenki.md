---
name: feedback-stderr-buffered-in-zenki
description: in bin/Protocol-7 zenki STDERR is buffered while log lines \ console output go to STDOUT -- a terminal escape [ color ] printed to STDERR lands out of order [ late, even at exit ] ; put terminal state on the stream the visible text uses
metadata:
  type: feedback
---

2026-10-14 : the start-up stderr color [ `print STDERR $colors{'p7_fg_0002'}`
in bin/Protocol-7 ] showed up in a pty capture only AFTER ten STDOUT log
lines ; a re-set I added on STDERR before the console handler came out at
exit. one terminal = one color state, so a reset on STDOUT clears a color
set via STDERR -- only the ORDER differs, by buffering.

**Why:** the first fix looked right in code and did nothing ; only a raw
`script -qc '<cmd>' /dev/null | cat -v` capture showed where the bytes landed.

**How to apply:** terminal escapes that must sit next to some text go on
that text's stream [ console log + command output = STDOUT ]. verify color \
escape changes with a raw pty capture, not by reading the code. related :
[[git-color-forced-verification-pitfall]].

#,,.,,.,,,...,,.,,.,.,,.,,..,,,,,,,,,,...,,.,,..,,...,.,.,...,..,,..,,.,.,..,,
#WAU4PIFZZE5RLADWLRZ72EDP5HH57OMRI2N3F7MBYT2W5OCXA3FC3CRTMM2MIMWB5T2RGEV2CXYCQ
#\\\|EL3UETIYY5RPTT7OY2J7ZETWLUK4XWXBCIDCI2KZEJSFCN26LS3 \ / AMOS7 \ YOURUM ::
#\[7]S37UNRHHWQ64NSQMRUZLMAKBSBJ2EK6LM7NPNYH6NAHWVY645SAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
