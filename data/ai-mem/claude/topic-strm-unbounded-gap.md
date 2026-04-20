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

#,,,,,..,,,.,,,.,,...,.,.,..,,,..,.,.,,,.,...,..,,...,...,.,.,,.,,,.,,,.,,,,.,
#F5UYNYSO3H2XO4OYS2DCILWM7SSVHSPMBWSTU46HSJI7T7XRV42NRT4XWHOI5AOP7AV4P2MNBPGNA
#\\\|CNSXUQY4UZIZB3PZM3B6ETUHQB2K43BE6NXFK5OY5ON3KCWGYHA \ / AMOS7 \ YOURUM ::
#\[7]S35GZUUOKEY3ULDDD5QBX44UGN5ZPOSHC7IF6DKCGBZLHJ4VNOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
