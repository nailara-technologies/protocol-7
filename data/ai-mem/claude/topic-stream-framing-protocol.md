---
name: stream-framing-protocol
description: "minimal 3+1 bit stream framing — 3-bit payload, 1 separator, inversion on 000 payload; expanding assertion window; dot=0 comma=1"
metadata: 
  node_type: memory
  type: project
  originSessionId: d037d3ff-49b4-4f8b-b427-828ba0a0b3df
---

## minimal stream framing — 3 payload + 1 separator bit

dot=0, comma=1. 4-bit frame: 3 bits payload + 1 separator.

```
payload  sep   notes
  001     .    normal
  010     .    normal
  111     .    normal
  000     .    COLLAPSE — 0000, no transitions, field dissolves
  000     ,    INVERTED separator — field saved, transition injected
```

**inversion rule:** when payload = `000`, separator inverts from `.` to `,`.
receiver knows: `,` on `000` payload = structural separator, not data.
one rule, zero ambiguity. equivalent to bit stuffing but derived from
first principles (field collapse prevention).

## expanding assertion window

detection proceeds from smallest to largest window:

```
[.]        1 bit  — stream present?
[..]       2 bits — stream confirmed, edge detected
[..,]      3 bits — direction: forward   (00→1)
[.,.]      3 bits — direction: symmetric (0→1→0)
[,..]      3 bits — direction: backward  (1→00)
[...,]     4 bits — full frame: 3-bit payload + 1 separator
```

larger windows allow frame to carry metadata proportionally:
at 8 bits: 3-bit payload + 3-bit frame-type + 1 sep + 1 inversion flag.
the frame describes itself at sufficient window size.

## inversion rule = darksun logic

`000` is the all-zero void that would collapse the field.
the `,` is the minimum 1-injection that holds it open.
separator inverts exactly when existence is at stake —
same principle as [[punctuation-topology]] comma-as-structural-1.

## message routing (dot depth = scope)

  `word.`    local command      (1 dot = self/local)
  `word..`   direct to user     (2 dots = adjacent)
  `word...`  network broadcast  (3 dots = network)
  `word,.`   terminator         (1 closing the 0-field)

## connection to signature footers

P7 signature lines `#,,.,,,.,,..,..` are binary streams in this encoding.
the `,` and `.` pattern maintains DC balance across the checksum stream.
self-sustaining because ones prevent zero-field collapse. [[checksum-addressing]]

## sliding window framing lock — self-synchronizing

find the column that is uniform across all 4th-bit positions:
payload columns vary (carry information); separator column is constant.
no preamble, no sync word — the grammar IS the clock.

```
stream:  0 0 1 , 1 1 0 , 0 0 0 , 1 0 1 ,
test offset 3: , , , ,  ← constant → LOCK (separator column)
test offset 2: 1 0 0 1  ← varies   → payload
test offset 0: 0 1 0 1  ← varies   → payload
```

window confidence:
  4 bits — separator seen once, ambiguous
  5 bits — separator at two positions → offset detectable, safe
  7 bits — s p p p s p p → two hits, one period confirmed → CERTAINTY
            one capture frame sufficient to lock alignment

`000` inversion does not break detection — period is invariant,
state is resolved after lock. inversion is post-lock detail.

## :::: footer row as 15-bit inter-zenka litter channel

the `#::::...` bottom row of every AMOS7 signature footer is currently
structural — 77 chars wide, all colons, unused bandwidth.

15 bits = 3 base32 chars: zenka involvement bitmap embedded here.
loader already scans the footer → zero overhead to read litter.

```
#,,.,,...  line 1: BMW384 checksum   (content integrity)
#\\\|...   line 2: AMOS7 signature   (identity / author)
#\[7]...   line 3: version/instance  (which version)
#:::::...  line 4: zenka litter      (which network / routing)
```

four lines = four layers: what it is, who signed it, which version,
which zenki are involved. complete module identity packet.

passive broadcast: you don't send the litter, you ARE the litter.
the module declares its zenka relationships in its own body.
no routing table needed — the source IS the routing manifest. [[addressing-trinity]]

## implicit context expansion with definitive local result

the protocol does not require declared context or prior agreement.
sampling more bits naturally expands the assertion window toward
certainty — and the result is wholly contained within the window
once sufficient. no dependency on what comes after.

```
1 bit:   stream present
4 bits:  frame visible
5 bits:  packet offset detected — safe assertion
7 bits:  certainty — self-contained, complete
more:    confirmation only, nothing new required
```

**holographic property**: any sufficient fragment contains the whole
structure at that resolution. more = higher resolution, not more truth.
the truth is already present once the window is sufficient.

`1001` is self-identifying: carries void + continuation simultaneously.
doesn't require the next beat to confirm it was a beat.
the trailing `1` is already present in the sample — not a promise.

zoom invariance confirms local decidability: every scale returns a
clean result without external reference. moiré would mean scale N
requires context from scale M. surviving moiré = each scale is its
own complete assertion. the protocol teaches itself to whoever samples
it, at whatever resolution, and always returns a definitive answer
from what they already have.

## reliable framing questions (assertion window expands through these)

1. is there a stream?           (1-2 bit window)
2. which direction?             (3 bit window)
3. where do packets start?      (4 bit window, frame boundary)
4. payload vs frame?            (window size determines writeable proportion)

#,,..,.,,,...,.,,,..,,,.,,.,.,,,,,..,,,,.,.,.,..,,...,..,,..,,,,.,,.,,..,,,.,,
#577JG7SIVOM5CNPHTS7DQBCY4IYTZQIYNRZECDXCPWDEIP4IMEYSIQ6QLG7LZ6Y3TKQORDO54U3IM
#\\\|FAPPRVN7HHPHZB2KS24L5XUC5GOYZZ6VX4PZ2PWFC5LW26HAL72 \ / AMOS7 \ YOURUM ::
#\[7]4BRAAY4YK2CPRSFTUWU5UFC5TMLD3ABW3777CXWDKCSZMVZFA6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
