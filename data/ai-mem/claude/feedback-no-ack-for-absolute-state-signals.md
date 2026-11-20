---
name: feedback-no-ack-for-absolute-state-signals
description: signals naming an absolute target state need no queue \ ack -- 4b135a2bd added a devmod-ack round trip against agreement ; never add feedback requirements unasked
metadata:
  type: feedback
---

4b135a2bd [ devmod off \ safe \ full ] added a per-instance queue + `cube.v7-zenki.devmod-ack` round
trip. the handlers only set a flag and every state is absolute [ last signal wins ], so nothing needed
serializing ; the ack only brought cube-link races + 'send.local: unknown target : cube' noise.
removed 2026-11-05 : v7-zenki records the state at send time [ as devmod_enabled did before ].

**Why:** owner : adding a second or third signal type adds no serialization need -- the ack was
against agreement, a new feedback requirement nobody asked for.

**How to apply:** when extending a signal \ state mechanism, keep it fire-and-record unless the
owner asks for confirmation ; a new network round trip \ ack is a design change -- name it, ask first.

#,,,.,.,.,,..,,.,,...,,,,,.,.,..,,...,..,,,.,,..,,...,...,.,,,...,,.,,.,.,.,,,
#MX4D5MW4LWZR43J7JIEKHQZDTPEUHWBMLH7FSVEI3PJJFSEEYU53WEJTJVZYYBRBLXWET6BVIZ7RU
#\\\|BVHCYMST4RTINCIMQ4GPBQPM4GPPKMJFRD6LVKXXJQQK26G5WDS \ / AMOS7 \ YOURUM ::
#\[7]6H5SO73Q2T67IWEVXQJSBVT4AA3MHVHXS3BMQBFBGACJD6ZYHKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
