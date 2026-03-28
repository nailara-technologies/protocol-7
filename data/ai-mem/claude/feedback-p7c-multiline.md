---
name: p7c-multiline-args
description: p7c cannot handle multiline task descriptions — use single-line or base32r encoding
type: feedback
---

p7c coding.submit with multiline heredoc text causes "protocol error [ reply type not valid ]" because p7c sends args as a single protocol line and newlines corrupt framing.

**Why:** p7c uses the P7 protocol framing which is line-delimited. Newlines in args break the frame boundary.

**How to apply:** Always submit coding tasks as single-line descriptions via p7c. For detailed multi-line instructions, either: (1) create a context template YAML instead, (2) base32r encode the text, or (3) collapse newlines to spaces before submitting.

#,,..,.,.,...,,..,.,.,,..,,..,,..,...,..,,,,.,..,,...,...,...,..,,...,...,,,.,
#MX5PP3EU6AAT5VFDBUM2AS2KOH3GDAS26SXF4A66ADKUSNIILOR7VRHFXIGTQAHNBQ4HEQMG3EG72
#\\\|2Q6SC4PFWVGQSQJTTZBBCO6G3QDNSRKT4MMNQ6GJDPLQNBAPMRH \ / AMOS7 \ YOURUM ::
#\[7]M7UMCHWDH6XMDU4QRZ4QJFAVXZK6DHLOERKGM5VURN75XGQZPWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
