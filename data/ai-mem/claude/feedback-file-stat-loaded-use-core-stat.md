---
name: feedback-file-stat-loaded-use-core-stat
description: bin/Protocol-7 loads File::stat -- a plain stat in src returns an object, not the list ; use CORE::stat [ or ->mode \ ->uid ]
metadata:
  type: feedback
---

bin/Protocol-7:277 `use File::stat` : in every src module `my @s = stat $path` holds ONE object, `$s[2]` \ `$s[4]` are undef. found 2026-10-23 in 5M3's jobsite.repair_encoding.write_one \ backup [ owner \ mode restore never fired, backup tar recorded mode 0 + uid 0 ; only undef warnings showed it ]. harnesses that compile src without File::stat pass anyway.

**Why:** the warnings were the only signal of a real defect -- the owner treats warnings as errors for that reason.

**How to apply:** write `CORE::stat` for the list form in src ; mention it in briefs for kimi \ cloud sessions touching file metadata ; a harness should load File::stat like the runtime. related : [[feedback-route-send-buffers-timer-gets-event]] [ stubs hiding runtime differences ].

#,,,.,...,.,,,,,.,.,.,.,.,.,,,...,.,,,,,.,..,,..,,...,...,..,,,,,,,..,.,.,.,,,
#CMPE45MT4CJVC3GMMQADP4VI7L6NQNGTDUFDW73TOY6KZMCXDZWST2TEAWAW6XDWMR3MFB4HZX3Q2
#\\\|BN5HTEKYRYPWPLE6MNQANQKFGRC7NF3K7CR3LONAWGHFZ4ZFMCA \ / AMOS7 \ YOURUM ::
#\[7]J6LYG3EBQHIQGJITLELETYSQERQ4H6YXV3TY7EHHUFQ7BQRIOUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
