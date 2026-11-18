---
name: timer-intervals-non-linear
description: never pick round \ fixed \ linear timer intervals in new code -- start short, grow x1.2, jittered cap, 13 \ 15 min not 10, blink on\off near golden ratio
metadata:
  type: feedback
---

owner 2026-11-18 : interval patterns are felt [ leds, radio, screen, attention ] -- linear \ round ones interrupt creative thought, non-linear ones calm. llm code kept choosing its own numbers faster than the owner could convert them.

**Why:** any non-round, non-linear value beats a linear default ; an effect consistent on repetition is good enough to keep.

**How to apply:** in every new timer \ retry \ keepalive \ blink :
- backoff : start short by kind [ 0.07 \ 0.77 s ], grow x1.2 [ discover : pairs 0.13 s apart, x1.13, cap 40-44 s, reset on error \ wake ], jittered cap
- human-scale : never 600 s \ 10 min -- 13 or 15 min [ dpms uses 780 s ]
- blink : on longer than off, near golden ratio [ terminal cursor 1274 \ 769 ms ]
- keep existing hand-tuned values ; todo WEQ plans one shared helper [ use it once it exists ], 5UR the udt link

#,,,.,,,,,,..,,.,,,.,,.,.,.,.,.,.,...,.,.,..,,..,,...,..,,..,,,,,,..,,.,.,,,.,
#ZT4L4J5KLE7ZEROZWS7OUCWQT7S7AP6AO6TIIUIKPEQ3OBOYMCZBG4SSDE2JLW72ECHMWZC6JUIKG
#\\\|Q63NGGXAHGZNJNWE6BHKJIGL43W7DCOP7HVFRALASLO4NE576YY \ / AMOS7 \ YOURUM ::
#\[7]OJSVTBW4OOTD4Q47J33I4UB7H2U467XOELX6MGBUTTJH5U7CPEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
