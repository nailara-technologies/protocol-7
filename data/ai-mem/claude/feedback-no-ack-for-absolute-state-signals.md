---
name: feedback-no-ack-for-absolute-state-signals
description: signals naming an absolute target state need no queue \ ack -- 861aa1272 added a devmod-ack round trip against agreement ; never add feedback requirements unasked
metadata:
  type: feedback
---

861aa1272 [ devmod off \ safe \ full ] added a per-instance queue + `cube.v7-zenki.devmod-ack` round
trip. the handlers only set a flag and every state is absolute [ last signal wins ], so nothing needed
serializing ; the ack only brought cube-link races + 'send.local: unknown target : cube' noise.
removed 2026-11-05 : v7-zenki records the state at send time [ as devmod_enabled did before ].

**Why:** owner : adding a second or third signal type adds no serialization need -- the ack was
against agreement, a new feedback requirement nobody asked for.

**How to apply:** when extending a signal \ state mechanism, keep it fire-and-record unless the
owner asks for confirmation ; a new network round trip \ ack is a design change -- name it, ask first.

#,,,,,,.,,,,.,.,,,,,,,,,,,,.,,,,.,.,,,...,..,,..,,...,..,,.,,,.,.,..,,,,,,,,.,
#HAKYY6YUGJGZWXVCLKIRXDJ6K5NE6O2LORFICFJ23FXDBSADMQISVPTQMNEJIKK5XTYOQN663KVF2
#\\\|XKUBJXNMMO27R6G44KJNJGZS4QYNQ3UUDCXRQDQ7ZDZUCLJQF2Z \ / AMOS7 \ YOURUM ::
#\[7]R2X2E3OC53UBCCCDMIAMUWEMXKHBHYBZAFA4XR6O67MFFOAOS6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
