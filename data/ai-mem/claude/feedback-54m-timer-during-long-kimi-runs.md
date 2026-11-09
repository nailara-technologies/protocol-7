---
name: feedback-54m-timer-during-long-kimi-runs
description: start a 54 minute background timer beside any long kimi wait so the one hour prompt cache does not expire
metadata:
  type: feedback
---

while waiting on a kimi run or anything else that can pass an hour, start a background command that exits after 54 minutes, and restart it on each wake until the work is done. one small cached turn replaces a cache revival of about 3 dollars.

**Why:** owner 2026-11-08 : two kimi runs passed the hour and the cache expired, once by 3 minutes. 54 rather than 59 leaves room for system lag and network glitches.

**How to apply:** beside the [[kimi-wrapper-exit-not-done]] waiter, run in the background `perl -e 'select undef,undef,undef,3240'` [ foreground sleep is blocked ]. on each wake reply in one line and do no other work.

#,,.,,...,,,,,,,.,..,,.,.,..,,.,.,,,,,.,,,.,.,..,,...,...,.,,,,.,,,.,,,..,...,
#JO7TFKAS7S43CDJALT5TRQ7RT3T6WXYEHBSWRH2JJCKIE5Q2BGEZHSV3YVYROE6VB3544W3Q5MD7A
#\\\|JYMM3J7WHL3KJJ756L77ZA5WKTK664LX7SFSKAONAJM7SJNVX7P \ / AMOS7 \ YOURUM ::
#\[7]JE3S3MGHHYKPGB3LLWVX3TLVLQNQ7XAQDRT4UPTKYNRZXLYDJKAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
