---
name: STRM / STRM-SIZE unbounded-total gap
description: unbounded streaming not supported ; open requires declared total ; needed for audio relay + webcam frame streams
type: project
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
STRM / STRM-SIZE protocol currently requires a declared total at open
[ `open N` where N is mandatory positive integer ]. Receiver at
base.handler.command:712 captures `(\d+)` unconditionally ; STRM-SIZE
receiver at base.handler.command:961 asserts `received_bytes !=
total_bytes` on close [ would reject 0-total ].

**Why:** primary drivers are audio stream relay and webcam frame
streams — both are inherently unbounded, producer cannot know total
up-front. File zenka use cases [ file with known size ] are fine.

**How to apply:** when designing stream-emit wrapper API
[ base.stream.open/push/close ], keep `total` nullable in the
signature but reject undef at runtime until the protocol extension
lands. Extension path :

  - `open 0` or `open ?` as sentinel for unknown-total
  - skip `received == total` assertion when total is 0/undef
  - close frame becomes sole completion signal
  - STRM-SIZE variant : still allow incremental extraction,
    just never knows "complete" — consumer polls via close

Spin a kimi/coding task for this when audio/webcam relay becomes
concrete. Not blocking cancel-stream work.

#,,..,,..,,,,,,.,,.,,,.,,,.,,,..,,,,,,,,.,.,.,..,,...,...,,..,,,.,,,.,,.,,.,,,
#3SVP6NJDDI4ZZ6FSCLVZRNEO7M7ECPTFHPKKWCJYY4JO5PBIPOZQ3BYVRWRV4TETPLXOMA4BM7D4O
#\\\|KPONIA3AXFMQL7BRPGLVABQKCKGXDD2EYUEQ5V5HWQUZYXLVJR5 \ / AMOS7 \ YOURUM ::
#\[7]22Z7BKXIAMZTDUPIHKN5L4RRMZNP67TC4AIHAJHCFHY3TMA76ECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
