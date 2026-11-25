---
name: network-silence-is-a-feature
description: network \ discovery code : knowing when to stay silent [ no probe, no announce, no fallback try ] matters as much as connecting from scratch
metadata:
  type: feedback
---

owner 2026-11-23, agreeing that RENEW does not re-probe and `blocked` networks are never
probed : "when to stay silent is equally important to knowing how to get something connected
from scratch".

**Why:** every probe, announce or fallback attempt leaks presence and costs traffic ; on foreign
networks [ roaming, [[net-zenka]] roles external \ unknown ] silence is the safe default.

**How to apply:** for net \ nameserv \ discover \ power work, every new outbound action names its
trigger and its quiet cases [ which events do NOT cause it, which roles \ policies exclude it ] ;
quiet can also mean MOVED ON [ owner ] : once two hosts handshake into an authenticated
protocol-7 session, the awareness lives inside that session -- no more broadcast \ probe
between them ; when the session ends, they fall back to the regular discovery path until they
handshake back in. try only what was observed before, never sweep all interfaces ; repeats ride base.interval.next.

#,,.,,..,,,.,,.,,,..,,,,,,..,,,,.,,.,,,,,,,.,,..,,...,...,,..,,..,.,.,.,.,..,,
#5O7F4BBJ6EN4AXRHAKSBIRJQJAARQCN777QSKSQIGXKK4ES5DFASCCDG3FM6D3FNQUP2H6YQU37RS
#\\\|L5XROCTT6YF3SWTUEQ7O2AZLLQAWWITFFBMHRW5AU3TFNUGQU5U \ / AMOS7 \ YOURUM ::
#\[7]QSVJGM4Z7LCATHVU65R5ERACTZ7FFT4RR255NUSUX5E7NLZNSKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
