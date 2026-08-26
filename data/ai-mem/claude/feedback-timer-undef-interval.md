---
name: feedback-timer-undef-interval
description: event.add_timer with undef after/interval fires at IO::Async max rate — always use explicit fallback
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f5b14fde-ecec-4f58-b7f2-95aaab875b62
---

`event.add_timer({ after => undef, interval => undef, repeat => TRUE })` causes a max-rate tight loop in IO::Async — 100MB/s memory growth.

**Why:** Discovered in memory zenka when `$cfg->{'focus_interval'}` was undef (P7 cfg data not sharing state with defaults), resulting in interval=>undef passed to the decay timer.

**How to apply:** Always guard timer intervals with explicit fallbacks and a floor:
```perl
my $interval = $cfg->{'focus_interval'} // 30;
$interval = 30 if not $interval or $interval < 5;
```
Never pass `$cfg->{'key'}` directly to `after`/`interval` without a `// default` fallback.

#,,..,.,.,,,.,,,.,,,.,..,,,..,.,,,.,.,,..,.,,,..,,...,...,...,,,.,,,,,...,...,
#CXFV6N25HTYQ4H6MHJPELAQQQVNH4EJFIN3673YN2LNKJMCC3NAMF7I7M2A5ZMRYTPZ3I5XO2PQPW
#\\\|KIPQ4ML3VPH7UYD6QTGTIW5HS5VWSYMNA4CTZKQ3NHM6RTVTHBY \ / AMOS7 \ YOURUM ::
#\[7]BIKWVTXMEI537DAJ6UAQ47O2D6GGVDECHTSAWTO66YWYPHIMHKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
