---
name: feedback-oversize-single-line-protocol
description: P7's TRUE/FALSE/WAIT wire path is one unbounded line — oversized content there wedges the session input buffer irresolvably, not just inefficiently
metadata:
  type: feedback
  originSessionId: 47367c65-b043-47a7-be00-11d29ff7b99d
---

An oversized payload sent through the single-line command/reply path
(`(cmd_id)CMD args\n`, used by TRUE/FALSE/WAIT and plain command
invocation) doesn't just waste bandwidth — it can wedge the receiving
session's input buffer **irresolvably**. This is a correctness risk, not
a style nit.

**Why:** that path has no framing/length-prefix, just a newline
terminator; the parser has no way to know in advance how much to expect.

**How to apply:** never put structured/bulk content into a plain `args`
string. Use `mode=>'size'` (auto-fragments via STRM-SIZE when needed) or
explicit STRM with `base.strm.local.register` for anything whose size
isn't a small bounded token. See
[[feedback-p7-route-send-wire-protocol]] for the verified reply-shape
details and why base32-wrapping a payload is an unrelated workaround, not
a fix for this.

#,,,.,,..,.,.,..,,...,..,,.,.,,,,,,.,,.,.,..,,..,,...,...,.,.,,,,,..,,...,,.,,
#5A2UNHYMV2EI5XI3K7VAB2CBM2YQ7SHXIVRKYQEF7EKJE7MVQXG2NXEOTPXJMAYP5OFPGBZ6TJT3G
#\\\|3FHEXFI5G7O4ORENBKQXMPYGWAZ2OSKMTHI44U7VCCBES73RXUJ \ / AMOS7 \ YOURUM ::
#\[7]P4NAQRTE4TEZYPVG7GVTMNSJUHKQDGZZJU5GLHQUAAUY2FJW6GDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
