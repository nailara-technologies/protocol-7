---
name: p7c-multiline-args
description: p7c cannot handle multiline task descriptions — use single-line or base32r encoding
type: feedback
---

p7c coding.submit with multiline heredoc text causes "protocol error [ reply type not valid ]" because p7c sends args as a single protocol line and newlines corrupt framing.

**Why:** p7c uses the P7 protocol framing which is line-delimited. Newlines in args break the frame boundary.

**How to apply:** Always submit coding tasks as single-line descriptions via p7c. For detailed multi-line instructions, either: (1) create a context template YAML instead, (2) base32r encode the text, or (3) collapse newlines to spaces before submitting.

#,,..,...,...,..,,...,,,,,,.,,..,,,.,,,,,,.,,,..,,...,...,...,.,.,...,,,,,.,,,
#JJ5N4PSTZWJ7BEZ2O36B2ERMLOR63GZOJICIQXSUKFERR3LLDYCOG5GI5FWVFGGSYPVUCLXCGS4LA
#\\\|B47NTUDU3YGO5BVCF4EMJWRIQ4TIV32TPG6ZZZWT7FEOJHIUL4O \ / AMOS7 \ YOURUM ::
#\[7]4NOLXIJ6BTNQLJ2WDZB3PXVF7EPZ4BDWFINESYWO62E2PWND4WCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
